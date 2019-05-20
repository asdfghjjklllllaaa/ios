// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/navigation/crw_wk_navigation_handler.h"

#include "base/feature_list.h"
#include "base/metrics/histogram_macros.h"
#include "base/strings/sys_string_conversions.h"
#include "base/timer/timer.h"
#import "ios/net/http_response_headers_util.h"
#include "ios/web/common/features.h"
#import "ios/web/navigation/crw_pending_navigation_info.h"
#import "ios/web/navigation/crw_wk_navigation_states.h"
#import "ios/web/navigation/navigation_context_impl.h"
#import "ios/web/navigation/navigation_manager_impl.h"
#include "ios/web/navigation/navigation_manager_util.h"
#import "ios/web/navigation/wk_navigation_action_policy_util.h"
#import "ios/web/navigation/wk_navigation_action_util.h"
#import "ios/web/navigation/wk_navigation_util.h"
#include "ios/web/public/browser_state.h"
#import "ios/web/public/download/download_controller.h"
#import "ios/web/public/url_scheme_util.h"
#import "ios/web/public/web_client.h"
#import "ios/web/web_state/user_interaction_state.h"
#import "ios/web/web_state/web_state_impl.h"
#import "ios/web/web_view/wk_web_view_util.h"
#import "net/base/mac/url_conversions.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using web::wk_navigation_util::IsPlaceholderUrl;
using web::wk_navigation_util::kReferrerHeaderName;
using web::wk_navigation_util::IsRestoreSessionUrl;

@interface CRWWKNavigationHandler ()

// Returns the WebStateImpl from self.delegate.
@property(nonatomic, readonly, assign) web::WebStateImpl* webStateImpl;
// Returns the NavigationManagerImpl from self.webStateImpl.
@property(nonatomic, readonly, assign)
    web::NavigationManagerImpl* navigationManagerImpl;
// Returns the UserInteractionState from self.delegate.
@property(nonatomic, readonly, assign)
    web::UserInteractionState* userInteractionState;

@end

@implementation CRWWKNavigationHandler {
  // Used to poll for a SafeBrowsing warning being displayed. This is created in
  // |decidePolicyForNavigationAction| and destroyed once any of the following
  // happens: 1) a SafeBrowsing warning is detected; 2) any WKNavigationDelegate
  // method is called; 3) |stopLoading| is called.
  base::RepeatingTimer _safeBrowsingWarningDetectionTimer;
}

- (instancetype)init {
  if (self = [super init]) {
    _navigationStates = [[CRWWKNavigationStates alloc] init];
  }
  return self;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView*)webView
    decidePolicyForNavigationAction:(WKNavigationAction*)action
                    decisionHandler:
                        (void (^)(WKNavigationActionPolicy))decisionHandler {
  [self didReceiveWKNavigationDelegateCallback];

  self.webProcessCrashed = NO;
  if ([self.delegate navigationHandlerWebViewBeingDestroyed:self]) {
    decisionHandler(WKNavigationActionPolicyCancel);
    return;
  }

  GURL requestURL = net::GURLWithNSURL(action.request.URL);

  // Workaround for a WKWebView bug where the web content loaded using
  // |-loadHTMLString:baseURL| clobbers the next WKBackForwardListItem. It works
  // by detecting back/forward navigation to a clobbered item and replacing the
  // clobberred item and its forward history using a partial session restore in
  // the current web view. There is an unfortunate caveat: if the workaround is
  // triggered in a back navigation to a clobbered item, the restored forward
  // session is inserted after the current item before the back navigation, so
  // it doesn't fully replaces the "bad" history, even though user will be
  // navigated to the expected URL and may not notice the issue until they
  // review the back history by long pressing on "Back" button.
  //
  // TODO(crbug.com/887497): remove this workaround once iOS ships the fix.
  if (web::GetWebClient()->IsSlimNavigationManagerEnabled() &&
      action.targetFrame.mainFrame) {
    GURL webViewURL = net::GURLWithNSURL(webView.URL);
    GURL currentWKItemURL =
        net::GURLWithNSURL(webView.backForwardList.currentItem.URL);
    GURL backItemURL = net::GURLWithNSURL(webView.backForwardList.backItem.URL);
    web::NavigationContextImpl* context =
        [self contextForPendingMainFrameNavigationWithURL:webViewURL];
    bool willClobberHistory =
        action.navigationType == WKNavigationTypeBackForward &&
        requestURL == backItemURL && webView.backForwardList.currentItem &&
        requestURL != currentWKItemURL && currentWKItemURL == webViewURL &&
        context &&
        (context->GetPageTransition() & ui::PAGE_TRANSITION_FORWARD_BACK);

    UMA_HISTOGRAM_BOOLEAN("IOS.WKWebViewClobberedHistory", willClobberHistory);

    if (willClobberHistory && base::FeatureList::IsEnabled(
                                  web::features::kHistoryClobberWorkaround)) {
      decisionHandler(WKNavigationActionPolicyCancel);
      self.navigationManagerImpl
          ->ApplyWKWebViewForwardHistoryClobberWorkaround();
      return;
    }
  }

  // The page will not be changed until this navigation is committed, so the
  // retrieved state will be pending until |didCommitNavigation| callback.
  [self updatePendingNavigationInfoFromNavigationAction:action];

  if (web::GetWebClient()->IsSlimNavigationManagerEnabled() &&
      action.targetFrame.mainFrame &&
      action.navigationType == WKNavigationTypeBackForward) {
    web::NavigationContextImpl* context =
        [self contextForPendingMainFrameNavigationWithURL:requestURL];
    if (context) {
      // Context is null for renderer-initiated navigations.
      int index = web::GetCommittedItemIndexWithUniqueID(
          self.navigationManagerImpl, context->GetNavigationItemUniqueID());
      self.navigationManagerImpl->SetPendingItemIndex(index);
    }
  }

  // If this is a placeholder navigation, pass through.
  if (IsPlaceholderUrl(requestURL)) {
    decisionHandler(WKNavigationActionPolicyAllow);
    return;
  }

  ui::PageTransition transition =
      [self.delegate navigationHandler:self
          pageTransitionFromNavigationType:action.navigationType];
  BOOL isMainFrameNavigationAction = [self isMainFrameNavigationAction:action];
  if (isMainFrameNavigationAction) {
    web::NavigationContextImpl* context =
        [self contextForPendingMainFrameNavigationWithURL:requestURL];
    if (context) {
      DCHECK(!context->IsRendererInitiated() ||
             (context->GetPageTransition() & ui::PAGE_TRANSITION_FORWARD_BACK));
      transition = context->GetPageTransition();
      if (context->IsLoadingErrorPage()) {
        // loadHTMLString: navigation which loads error page into WKWebView.
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
      }
    }
  }

  if (web::GetWebClient()->IsSlimNavigationManagerEnabled()) {
    // WKBasedNavigationManager doesn't use |loadCurrentURL| for reload or back/
    // forward navigation. So this is the first point where a form repost would
    // be detected. Display the confirmation dialog.
    if ([action.request.HTTPMethod isEqual:@"POST"] &&
        (action.navigationType == WKNavigationTypeFormResubmitted)) {
      self.webStateImpl->ShowRepostFormWarningDialog(
          base::BindOnce(^(bool shouldContinue) {
            if (shouldContinue) {
              decisionHandler(WKNavigationActionPolicyAllow);
            } else {
              decisionHandler(WKNavigationActionPolicyCancel);
              if (action.targetFrame.mainFrame) {
                [self.pendingNavigationInfo setCancelled:YES];
                self.webStateImpl->SetIsLoading(false);
              }
            }
          }));
      return;
    }
  }

  // Invalid URLs should not be loaded.
  if (!requestURL.is_valid()) {
    decisionHandler(WKNavigationActionPolicyCancel);
    // The HTML5 spec indicates that window.open with an invalid URL should open
    // about:blank.
    BOOL isFirstLoadInOpenedWindow =
        self.webStateImpl->HasOpener() &&
        !self.webStateImpl->GetNavigationManager()->GetLastCommittedItem();
    BOOL isMainFrame = action.targetFrame.mainFrame;
    if (isFirstLoadInOpenedWindow && isMainFrame) {
      GURL aboutBlankURL(url::kAboutBlankURL);
      web::NavigationManager::WebLoadParams loadParams(aboutBlankURL);
      loadParams.referrer =
          [self.delegate currentReferrerForNavigationHandler:self];

      self.webStateImpl->GetNavigationManager()->LoadURLWithParams(loadParams);
    }
    return;
  }

  // First check if the navigation action should be blocked by the controller
  // and make sure to update the controller in the case that the controller
  // can't handle the request URL. Then use the embedders' policyDeciders to
  // either: 1- Handle the URL it self and return false to stop the controller
  // from proceeding with the navigation if needed. or 2- return true to allow
  // the navigation to be proceeded by the web controller.
  BOOL allowLoad = YES;
  if (web::GetWebClient()->IsAppSpecificURL(requestURL)) {
    allowLoad = [self shouldAllowAppSpecificURLNavigationAction:action
                                                     transition:transition];
    if (allowLoad && !self.webStateImpl->HasWebUI()) {
      [self.delegate navigationHandler:self createWebUIForURL:requestURL];
    }
  }

  BOOL webControllerCanShow =
      web::UrlHasWebScheme(requestURL) ||
      web::GetWebClient()->IsAppSpecificURL(requestURL) ||
      requestURL.SchemeIs(url::kFileScheme) ||
      requestURL.SchemeIs(url::kAboutScheme) ||
      requestURL.SchemeIs(url::kBlobScheme);

  if (allowLoad) {
    // If the URL doesn't look like one that can be shown as a web page, it may
    // handled by the embedder. In that case, update the web controller to
    // correctly reflect the current state.
    if (!webControllerCanShow) {
      if (!web::features::StorePendingItemInContext()) {
        if ([self isMainFrameNavigationAction:action]) {
          [self.delegate navigationHandlerStopLoading:self];
        }
      }

      // Purge web view if last committed URL is different from the document
      // URL. This can happen if external URL was added to the navigation stack
      // and was loaded using Go Back or Go Forward navigation (in which case
      // document URL will point to the previous page).  If this is the first
      // load for a NavigationManager, there will be no last committed item, so
      // check here.
      // TODO(crbug.com/850760): Check if this code is still needed. The current
      // implementation doesn't put external apps URLs in the history, so they
      // shouldn't be accessable by Go Back or Go Forward navigation.
      web::NavigationItem* lastCommittedItem =
          self.webStateImpl->GetNavigationManager()->GetLastCommittedItem();
      if (lastCommittedItem) {
        GURL lastCommittedURL = lastCommittedItem->GetURL();
        if (lastCommittedURL !=
            [self.delegate navigationHandlerDocumentURL:self]) {
          [self.delegate navigationHandlerRequirePageReconstruction:self];
          [self.delegate navigationHandler:self
                            setDocumentURL:lastCommittedURL
                                   context:nullptr];
        }
      }
    }
  }

  if (allowLoad) {
    BOOL userInteractedWithRequestMainFrame =
        self.userInteractionState->HasUserTappedRecently(webView) &&
        net::GURLWithNSURL(action.request.mainDocumentURL) ==
            self.userInteractionState->LastUserInteraction()->main_document_url;
    web::WebStatePolicyDecider::RequestInfo requestInfo(
        transition, isMainFrameNavigationAction,
        userInteractedWithRequestMainFrame);

    allowLoad =
        self.webStateImpl->ShouldAllowRequest(action.request, requestInfo);
    // The WebState may have been closed in the ShouldAllowRequest callback.
    if ([self.delegate navigationHandlerWebViewBeingDestroyed:self]) {
      decisionHandler(WKNavigationActionPolicyCancel);
      return;
    }
  }

  if (!webControllerCanShow && web::features::StorePendingItemInContext()) {
    allowLoad = NO;
  }

  if (allowLoad) {
    if ([[action.request HTTPMethod] isEqualToString:@"POST"]) {
      web::NavigationItemImpl* item =
          self.navigationManagerImpl->GetCurrentItemImpl();
      // TODO(crbug.com/570699): Remove this check once it's no longer possible
      // to have no current entries.
      if (item)
        [self cachePOSTDataForRequest:action.request inNavigationItem:item];
    }
  } else {
    if (action.targetFrame.mainFrame) {
      [self.pendingNavigationInfo setCancelled:YES];
      // Discard the pending item to ensure that the current URL is not
      // different from what is displayed on the view. Discard only happens
      // if the last item was not a native view, to avoid ugly animation of
      // inserting the webview.
      [self discardNonCommittedItemsIfLastCommittedWasNotNativeView];

      web::NavigationContextImpl* context =
          [self contextForPendingMainFrameNavigationWithURL:requestURL];
      if (context) {
        // Destroy associated pending item, because this will be the last
        // WKWebView callback for this navigation context.
        context->ReleaseItem();
      }

      if (![self.delegate navigationHandlerWebViewBeingDestroyed:self] &&
          [self shouldClosePageOnNativeApplicationLoad]) {
        // Loading was started for user initiated navigations and should be
        // stopped because no other WKWebView callbacks are called.
        // TODO(crbug.com/767092): Loading should not start until
        // webView.loading is changed to YES.
        self.webStateImpl->SetIsLoading(false);
        self.webStateImpl->CloseWebState();
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
      }
    }

    if (![self.delegate navigationHandlerWebViewBeingDestroyed:self]) {
      // Loading was started for user initiated navigations and should be
      // stopped because no other WKWebView callbacks are called.
      // TODO(crbug.com/767092): Loading should not start until webView.loading
      // is changed to YES.
      self.webStateImpl->SetIsLoading(false);
    }
  }

  // Only try to detect a SafeBrowsing warning if one isn't already displayed,
  // since the detection logic won't be able to distinguish between the current
  // warning and a warning for the page that's about to be loaded. Also, since
  // the purpose of running this logic is to ensure that the right URL is
  // displayed in the omnibox, don't try to detect a SafeBrowsing warning for
  // iframe navigations, because the omnibox already shows the correct main
  // frame URL in that case.
  if (allowLoad && isMainFrameNavigationAction &&
      !web::IsSafeBrowsingWarningDisplayedInWebView(webView)) {
    __weak CRWWKNavigationHandler* weakSelf = self;
    __weak WKWebView* weakWebView = webView;
    const base::TimeDelta kDelayUntilSafeBrowsingWarningCheck =
        base::TimeDelta::FromMilliseconds(20);
    _safeBrowsingWarningDetectionTimer.Start(
        FROM_HERE, kDelayUntilSafeBrowsingWarningCheck, base::BindRepeating(^{
          __strong __typeof(weakSelf) strongSelf = weakSelf;
          __strong __typeof(weakWebView) strongWebView = weakWebView;
          if (web::IsSafeBrowsingWarningDisplayedInWebView(strongWebView)) {
            // Extract state from an existing navigation context if one exists.
            // Create a new context rather than just re-using the existing one,
            // since the existing context will continue to be used if the user
            // decides to proceed to the unsafe page. In that case, WebKit
            // continues the navigation with the same WKNavigation* that's
            // associated with the existing context.
            web::NavigationContextImpl* existingContext = [strongSelf
                contextForPendingMainFrameNavigationWithURL:requestURL];
            bool hasUserGesture =
                existingContext ? existingContext->HasUserGesture() : false;
            bool isRendererInitiated =
                existingContext ? existingContext->IsRendererInitiated() : true;
            std::unique_ptr<web::NavigationContextImpl> context =
                web::NavigationContextImpl::CreateNavigationContext(
                    strongSelf.webStateImpl, requestURL, hasUserGesture,
                    transition, isRendererInitiated);
            [strongSelf navigationManagerImpl] -> AddTransientItem(requestURL);
            strongSelf.webStateImpl->OnNavigationStarted(context.get());
            strongSelf.webStateImpl->OnNavigationFinished(context.get());
            strongSelf->_safeBrowsingWarningDetectionTimer.Stop();
            if (!existingContext) {
              // If there's an existing context, observers will already be aware
              // of a load in progress. Otherwise, observers need to be notified
              // here, so that if the user decides to go back to the previous
              // page (stopping the load), observers will be aware of a possible
              // URL change and the URL displayed in the omnibox will get
              // updated.
              DCHECK(strongWebView.loading);
              strongSelf.webStateImpl->SetIsLoading(true);
            }
          }
        }));
  }

  if (!allowLoad) {
    decisionHandler(WKNavigationActionPolicyCancel);
    return;
  }
  BOOL isOffTheRecord = self.webStateImpl->GetBrowserState()->IsOffTheRecord();
  decisionHandler(web::GetAllowNavigationActionPolicy(isOffTheRecord));
}

- (void)webView:(WKWebView*)webView
    decidePolicyForNavigationResponse:(WKNavigationResponse*)WKResponse
                      decisionHandler:
                          (void (^)(WKNavigationResponsePolicy))handler {
  [self didReceiveWKNavigationDelegateCallback];

  // If this is a placeholder navigation, pass through.
  GURL responseURL = net::GURLWithNSURL(WKResponse.response.URL);
  if (IsPlaceholderUrl(responseURL)) {
    handler(WKNavigationResponsePolicyAllow);
    return;
  }

  scoped_refptr<net::HttpResponseHeaders> headers;
  if ([WKResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
    headers = net::CreateHeadersFromNSHTTPURLResponse(
        static_cast<NSHTTPURLResponse*>(WKResponse.response));
    // TODO(crbug.com/551677): remove |OnHttpResponseHeadersReceived| and attach
    // headers to web::NavigationContext.
    self.webStateImpl->OnHttpResponseHeadersReceived(headers.get(),
                                                     responseURL);
  }

  // The page will not be changed until this navigation is committed, so the
  // retrieved state will be pending until |didCommitNavigation| callback.
  [self updatePendingNavigationInfoFromNavigationResponse:WKResponse];

  BOOL shouldRenderResponse = [self shouldRenderResponse:WKResponse];
  if (!shouldRenderResponse) {
    if (web::UrlHasWebScheme(responseURL)) {
      [self createDownloadTaskForResponse:WKResponse HTTPHeaders:headers.get()];
    } else {
      // DownloadTask only supports web schemes, so do nothing.
    }
    // Discard the pending item to ensure that the current URL is not different
    // from what is displayed on the view.
    [self discardNonCommittedItemsIfLastCommittedWasNotNativeView];
    if (!web::features::StorePendingItemInContext()) {
      // Loading will be stopped in webView:didFinishNavigation: callback. This
      // call is here to preserve the original behavior when pending item is not
      // stored in NavigationContext.
      self.webStateImpl->SetIsLoading(false);
    }
  } else {
    shouldRenderResponse = self.webStateImpl->ShouldAllowResponse(
        WKResponse.response, WKResponse.forMainFrame);
  }

  if (!shouldRenderResponse && WKResponse.canShowMIMEType &&
      WKResponse.forMainFrame) {
    self.pendingNavigationInfo.cancelled = YES;
  }

  if (web::GetWebClient()->IsSlimNavigationManagerEnabled() &&
      !WKResponse.forMainFrame && !webView.loading) {
    // This is the terminal callback for iframe navigation and there is no
    // pending main frame navigation. Last chance to flip IsLoading to false.
    self.webStateImpl->SetIsLoading(false);
  }

  handler(shouldRenderResponse ? WKNavigationResponsePolicyAllow
                               : WKNavigationResponsePolicyCancel);
}

- (void)webView:(WKWebView*)webView
    didStartProvisionalNavigation:(WKNavigation*)navigation {
  [self didReceiveWKNavigationDelegateCallback];
}

- (void)webView:(WKWebView*)webView
    didReceiveServerRedirectForProvisionalNavigation:(WKNavigation*)navigation {
  [self didReceiveWKNavigationDelegateCallback];
}

- (void)webView:(WKWebView*)webView
    didFailProvisionalNavigation:(WKNavigation*)navigation
                       withError:(NSError*)error {
  [self didReceiveWKNavigationDelegateCallback];
}

- (void)webView:(WKWebView*)webView
    didCommitNavigation:(WKNavigation*)navigation {
  [self didReceiveWKNavigationDelegateCallback];
}

- (void)webView:(WKWebView*)webView
    didFinishNavigation:(WKNavigation*)navigation {
  [self didReceiveWKNavigationDelegateCallback];
}

- (void)webView:(WKWebView*)webView
    didFailNavigation:(WKNavigation*)navigation
            withError:(NSError*)error {
  [self didReceiveWKNavigationDelegateCallback];
}

- (void)webView:(WKWebView*)webView
    didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge
                    completionHandler:
                        (void (^)(NSURLSessionAuthChallengeDisposition,
                                  NSURLCredential*))completionHandler {
  [self didReceiveWKNavigationDelegateCallback];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView*)webView {
  [self didReceiveWKNavigationDelegateCallback];
}

#pragma mark - Private methods

- (web::NavigationManagerImpl*)navigationManagerImpl {
  return &(self.webStateImpl->GetNavigationManagerImpl());
}

- (web::WebStateImpl*)webStateImpl {
  return [self.delegate webStateImplForNavigationHandler:self];
}

- (web::UserInteractionState*)userInteractionState {
  return [self.delegate userInteractionStateForNavigationHandler:self];
}

// This method should be called on receiving WKNavigationDelegate callbacks. It
// will log a metric if the callback occurs after the reciever has already been
// closed. It also stops the SafeBrowsing warning detection timer, since after
// this point it's too late for a SafeBrowsing warning to be displayed for the
// navigation for which the timer was started.
- (void)didReceiveWKNavigationDelegateCallback {
  if ([self.delegate navigationHandlerWebViewBeingDestroyed:self]) {
    UMA_HISTOGRAM_BOOLEAN("Renderer.WKWebViewCallbackAfterDestroy", true);
  }
  _safeBrowsingWarningDetectionTimer.Stop();
}

// Extracts navigation info from WKNavigationAction and sets it as a pending.
// Some pieces of navigation information are only known in
// |decidePolicyForNavigationAction|, but must be in a pending state until
// |didgo/Navigation| where it becames current.
- (void)updatePendingNavigationInfoFromNavigationAction:
    (WKNavigationAction*)action {
  if (action.targetFrame.mainFrame) {
    self.pendingNavigationInfo = [[CRWPendingNavigationInfo alloc] init];
    self.pendingNavigationInfo.referrer =
        [action.request valueForHTTPHeaderField:kReferrerHeaderName];
    self.pendingNavigationInfo.navigationType = action.navigationType;
    self.pendingNavigationInfo.HTTPMethod = action.request.HTTPMethod;
    self.pendingNavigationInfo.hasUserGesture =
        web::GetNavigationActionInitiationType(action) ==
        web::NavigationActionInitiationType::kUserInitiated;
  }
}

// Returns YES if the navigation action is associated with a main frame request.
- (BOOL)isMainFrameNavigationAction:(WKNavigationAction*)action {
  if (action.targetFrame) {
    return action.targetFrame.mainFrame;
  }
  // According to WKNavigationAction documentation, in the case of a new window
  // navigation, target frame will be nil. In this case check if the
  // |sourceFrame| is the mainFrame.
  return action.sourceFrame.mainFrame;
}

// Returns YES if the given |action| should be allowed to continue for app
// specific URL. If this returns NO, the navigation should be cancelled.
// App specific pages have elevated privileges and WKWebView uses the same
// renderer process for all page frames. With that Chromium does not allow
// running App specific pages in the same process as a web site from the
// internet. Allows navigation to app specific URL in the following cases:
//   - last committed URL is app specific
//   - navigation not a new navigation (back-forward or reload)
//   - navigation is typed, generated or bookmark
//   - navigation is performed in iframe and main frame is app-specific page
- (BOOL)shouldAllowAppSpecificURLNavigationAction:(WKNavigationAction*)action
                                       transition:
                                           (ui::PageTransition)pageTransition {
  GURL requestURL = net::GURLWithNSURL(action.request.URL);
  DCHECK(web::GetWebClient()->IsAppSpecificURL(requestURL));
  if (web::GetWebClient()->IsAppSpecificURL(
          self.webStateImpl->GetLastCommittedURL())) {
    // Last committed page is also app specific and navigation should be
    // allowed.
    return YES;
  }

  if (!ui::PageTransitionIsNewNavigation(pageTransition)) {
    // Allow reloads and back-forward navigations.
    return YES;
  }

  if (ui::PageTransitionTypeIncludingQualifiersIs(pageTransition,
                                                  ui::PAGE_TRANSITION_TYPED)) {
    return YES;
  }

  if (ui::PageTransitionTypeIncludingQualifiersIs(
          pageTransition, ui::PAGE_TRANSITION_GENERATED)) {
    return YES;
  }

  if (ui::PageTransitionTypeIncludingQualifiersIs(
          pageTransition, ui::PAGE_TRANSITION_AUTO_BOOKMARK)) {
    return YES;
  }

  // If the session is being restored, allow the navigation.
  if (IsRestoreSessionUrl([self.delegate navigationHandlerDocumentURL:self])) {
    return YES;
  }

  GURL mainDocumentURL = net::GURLWithNSURL(action.request.mainDocumentURL);
  if (web::GetWebClient()->IsAppSpecificURL(mainDocumentURL) &&
      !action.sourceFrame.mainFrame) {
    // AppSpecific URLs are allowed inside iframe if the main frame is also
    // app specific page.
    return YES;
  }

  return NO;
}

// Caches request POST data in the given session entry.
- (void)cachePOSTDataForRequest:(NSURLRequest*)request
               inNavigationItem:(web::NavigationItemImpl*)item {
  NSUInteger maxPOSTDataSizeInBytes = 4096;
  NSString* cookieHeaderName = @"cookie";

  DCHECK(item);
  const bool shouldUpdateEntry =
      ui::PageTransitionCoreTypeIs(item->GetTransitionType(),
                                   ui::PAGE_TRANSITION_FORM_SUBMIT) &&
      ![request HTTPBodyStream] &&  // Don't cache streams.
      !item->HasPostData() &&
      item->GetURL() == net::GURLWithNSURL([request URL]);
  const bool belowSizeCap =
      [[request HTTPBody] length] < maxPOSTDataSizeInBytes;
  DLOG_IF(WARNING, shouldUpdateEntry && !belowSizeCap)
      << "Data in POST request exceeds the size cap (" << maxPOSTDataSizeInBytes
      << " bytes), and will not be cached.";

  if (shouldUpdateEntry && belowSizeCap) {
    item->SetPostData([request HTTPBody]);
    item->ResetHttpRequestHeaders();
    item->AddHttpRequestHeaders([request allHTTPHeaderFields]);
    // Don't cache the "Cookie" header.
    // According to NSURLRequest documentation, |-valueForHTTPHeaderField:| is
    // case insensitive, so it's enough to test the lower case only.
    if ([request valueForHTTPHeaderField:cookieHeaderName]) {
      // Case insensitive search in |headers|.
      NSSet* cookieKeys = [item->GetHttpRequestHeaders()
          keysOfEntriesPassingTest:^(id key, id obj, BOOL* stop) {
            NSString* header = (NSString*)key;
            const BOOL found =
                [header caseInsensitiveCompare:cookieHeaderName] ==
                NSOrderedSame;
            *stop = found;
            return found;
          }];
      DCHECK_EQ(1u, [cookieKeys count]);
      item->RemoveHttpRequestHeaderForKey([cookieKeys anyObject]);
    }
  }
}

// Discards non committed items, only if the last committed URL was not loaded
// in native view. But if it was a native view, no discard will happen to avoid
// an ugly animation where the web view is inserted and quickly removed.
- (void)discardNonCommittedItemsIfLastCommittedWasNotNativeView {
  GURL lastCommittedURL = self.webStateImpl->GetLastCommittedURL();
  BOOL previousItemWasLoadedInNativeView =
      [self.delegate navigationHandler:self
             shouldLoadURLInNativeView:lastCommittedURL];
  if (!previousItemWasLoadedInNativeView)
    self.navigationManagerImpl->DiscardNonCommittedItems();
}

// If YES, the page should be closed if it successfully redirects to a native
// application, for example if a new tab redirects to the App Store.
- (BOOL)shouldClosePageOnNativeApplicationLoad {
  // The page should be closed if it was initiated by the DOM and there has been
  // no user interaction with the page since the web view was created, or if
  // the page has no navigation items, as occurs when an App Store link is
  // opened from another application.
  BOOL rendererInitiatedWithoutInteraction =
      self.webStateImpl->HasOpener() &&
      !self.userInteractionState
           ->UserInteractionRegisteredSinceWebViewCreated();
  BOOL noNavigationItems = !(self.navigationManagerImpl->GetItemCount());
  return rendererInitiatedWithoutInteraction || noNavigationItems;
}

// Extracts navigation info from WKNavigationResponse and sets it as a pending.
// Some pieces of navigation information are only known in
// |decidePolicyForNavigationResponse|, but must be in a pending state until
// |didCommitNavigation| where it becames current.
- (void)updatePendingNavigationInfoFromNavigationResponse:
    (WKNavigationResponse*)response {
  if (response.isForMainFrame) {
    if (!self.pendingNavigationInfo) {
      self.pendingNavigationInfo = [[CRWPendingNavigationInfo alloc] init];
    }
    self.pendingNavigationInfo.MIMEType = response.response.MIMEType;
  }
}

// Returns YES if response should be rendered in WKWebView.
- (BOOL)shouldRenderResponse:(WKNavigationResponse*)WKResponse {
  if (!WKResponse.canShowMIMEType) {
    return NO;
  }

  GURL responseURL = net::GURLWithNSURL(WKResponse.response.URL);
  if (responseURL.SchemeIs(url::kDataScheme) && WKResponse.forMainFrame) {
    // Block rendering data URLs for renderer-initiated navigations in main
    // frame to prevent abusive behavior (crbug.com/890558).
    web::NavigationContext* context =
        [self contextForPendingMainFrameNavigationWithURL:responseURL];
    if (context->IsRendererInitiated()) {
      return NO;
    }
  }

  return YES;
}

// Creates DownloadTask for the given navigation response. Headers are passed
// as argument to avoid extra NSDictionary -> net::HttpResponseHeaders
// conversion.
- (void)createDownloadTaskForResponse:(WKNavigationResponse*)WKResponse
                          HTTPHeaders:(net::HttpResponseHeaders*)headers {
  const GURL responseURL = net::GURLWithNSURL(WKResponse.response.URL);
  const int64_t contentLength = WKResponse.response.expectedContentLength;
  const std::string MIMEType =
      base::SysNSStringToUTF8(WKResponse.response.MIMEType);

  std::string contentDisposition;
  if (headers) {
    headers->GetNormalizedHeader("content-disposition", &contentDisposition);
  }

  ui::PageTransition transition = ui::PAGE_TRANSITION_AUTO_SUBFRAME;
  if (WKResponse.forMainFrame) {
    web::NavigationContextImpl* context =
        [self contextForPendingMainFrameNavigationWithURL:responseURL];
    context->SetIsDownload(true);
    context->ReleaseItem();
    // Navigation callbacks can only be called for the main frame.
    self.webStateImpl->OnNavigationFinished(context);
    transition = context->GetPageTransition();
    bool transitionIsLink = ui::PageTransitionTypeIncludingQualifiersIs(
        transition, ui::PAGE_TRANSITION_LINK);
    if (transitionIsLink && !context->HasUserGesture()) {
      // Link click is not possible without user gesture, so this transition
      // was incorrectly classified and should be "client redirect" instead.
      // TODO(crbug.com/549301): Remove this workaround when transition
      // detection is fixed.
      transition = ui::PAGE_TRANSITION_CLIENT_REDIRECT;
    }
  }
  web::DownloadController::FromBrowserState(
      self.webStateImpl->GetBrowserState())
      ->CreateDownloadTask(self.webStateImpl, [NSUUID UUID].UUIDString,
                           responseURL, contentDisposition, contentLength,
                           MIMEType, transition);
}

#pragma mark - Public methods

- (void)stopLoading {
  self.pendingNavigationInfo.cancelled = YES;
  _safeBrowsingWarningDetectionTimer.Stop();
}

- (base::RepeatingTimer*)safeBrowsingWarningDetectionTimer {
  return &_safeBrowsingWarningDetectionTimer;
}

// Returns context for pending navigation that has |URL|. null if there is no
// matching pending navigation.
- (web::NavigationContextImpl*)contextForPendingMainFrameNavigationWithURL:
    (const GURL&)URL {
  // Here the enumeration variable |navigation| is __strong to allow setting it
  // to nil.
  for (__strong id navigation in [self.navigationStates pendingNavigations]) {
    if (navigation == [NSNull null]) {
      // null is a valid navigation object passed to WKNavigationDelegate
      // callbacks and represents window opening action.
      navigation = nil;
    }

    web::NavigationContextImpl* context =
        [self.navigationStates contextForNavigation:navigation];
    if (context && context->GetUrl() == URL) {
      return context;
    }
  }
  return nullptr;
}

@end
