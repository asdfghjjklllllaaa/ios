// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <XCTest/XCTest.h>

#include "base/memory/ptr_util.h"
#include "base/strings/stringprintf.h"
#include "base/strings/sys_string_conversions.h"
#include "components/strings/grit/components_strings.h"
#include "ios/chrome/browser/ui/ui_util.h"
#import "ios/chrome/test/app/chrome_test_util.h"
#include "ios/chrome/test/app/navigation_test_util.h"
#include "ios/chrome/test/app/web_view_interaction_test_util.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/testing/wait_util.h"
#import "ios/web/public/test/earl_grey/web_view_actions.h"
#import "ios/web/public/test/earl_grey/web_view_matchers.h"
#include "ios/web/public/test/http_server/data_response_provider.h"
#import "ios/web/public/test/http_server/http_server.h"
#include "ios/web/public/test/http_server/http_server_util.h"
#include "ios/web/public/test/url_test_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using chrome_test_util::ButtonWithAccessibilityLabelId;
using chrome_test_util::OmniboxText;
using chrome_test_util::WebViewContainingText;

namespace {

// Response shown on the page of |GetDestinationUrl|.
const char kDestinationText[] = "bar!";

// Label for the button in the form.
const char kSubmitButtonLabel[] = "submit";

// Html form template with a submission button named "submit".
const char* kFormHtmlTemplate =
    "<form method='post' action='%s'> submit: "
    "<input value='textfield' id='textfield' type='text'></label>"
    "<input type='submit' value='submit' id='submit'>"
    "</form>";

// GURL of a generic website in the user navigation flow.
const GURL GetGenericUrl() {
  return web::test::HttpServer::MakeUrl("http://generic");
}

// GURL of a page with a form that posts data to |GetDestinationUrl|.
const GURL GetFormUrl() {
  return web::test::HttpServer::MakeUrl("http://form");
}

// GURL of a page with a form that posts data to |GetDestinationUrl|.
const GURL GetFormPostOnSamePageUrl() {
  return web::test::HttpServer::MakeUrl("http://form");
}

// GURL of the page to which the |GetFormUrl| posts data to.
const GURL GetDestinationUrl() {
  return web::test::HttpServer::MakeUrl("http://destination");
}

#pragma mark - TestFormResponseProvider

// URL that redirects to |GetDestinationUrl| with a 302.
const GURL GetRedirectUrl() {
  return web::test::HttpServer::MakeUrl("http://redirect");
}

// URL to return a page that posts to |GetRedirectUrl|.
const GURL GetRedirectFormUrl() {
  return web::test::HttpServer::MakeUrl("http://formRedirect");
}

// A ResponseProvider that provides html response, post response or a redirect.
class TestFormResponseProvider : public web::DataResponseProvider {
 public:
  // TestResponseProvider implementation.
  bool CanHandleRequest(const Request& request) override;
  void GetResponseHeadersAndBody(
      const Request& request,
      scoped_refptr<net::HttpResponseHeaders>* headers,
      std::string* response_body) override;
};

bool TestFormResponseProvider::CanHandleRequest(const Request& request) {
  const GURL& url = request.url;
  return url == GetDestinationUrl() || url == GetRedirectUrl() ||
         url == GetRedirectFormUrl() || url == GetFormPostOnSamePageUrl() ||
         url == GetGenericUrl();
}

void TestFormResponseProvider::GetResponseHeadersAndBody(
    const Request& request,
    scoped_refptr<net::HttpResponseHeaders>* headers,
    std::string* response_body) {
  const GURL& url = request.url;
  if (url == GetRedirectUrl()) {
    *headers = web::ResponseProvider::GetRedirectResponseHeaders(
        GetDestinationUrl().spec(), net::HTTP_FOUND);
    return;
  }

  *headers = web::ResponseProvider::GetDefaultResponseHeaders();
  if (url == GetGenericUrl()) {
    *response_body = "A generic page";
    return;
  }
  if (url == GetFormPostOnSamePageUrl()) {
    if (request.method == "POST") {
      *response_body = request.method + std::string(" ") + request.body;
    } else {
      *response_body =
          "<form method='post'>"
          "<input value='button' type='submit' id='button'></form>";
    }
    return;
  }

  if (url == GetRedirectFormUrl()) {
    *response_body =
        base::StringPrintf(kFormHtmlTemplate, GetRedirectUrl().spec().c_str());
    return;
  } else if (url == GetDestinationUrl()) {
    *response_body = request.method + std::string(" ") + request.body;
    return;
  }
  NOTREACHED();
}

}  // namespace

// Tests submition of HTTP forms POST data including cases involving navigation.
@interface FormsTestCase : ChromeTestCase
@end

@implementation FormsTestCase

// Matcher for a Go button that is interactable.
id<GREYMatcher> GoButtonMatcher() {
  return grey_allOf(grey_accessibilityID(@"Go"), grey_interactable(), nil);
}

// Waits for view with Tab History accessibility ID.
- (void)waitForTabHistoryView {
  GREYCondition* condition = [GREYCondition
      conditionWithName:@"Waiting for Tab History to display."
                  block:^BOOL {
                    NSError* error = nil;
                    id<GREYMatcher> tabHistory =
                        grey_accessibilityID(@"Tab History");
                    [[EarlGrey selectElementWithMatcher:tabHistory]
                        assertWithMatcher:grey_notNil()
                                    error:&error];
                    return error == nil;
                  }];
  GREYAssert([condition waitWithTimeout:testing::kWaitForUIElementTimeout],
             @"Tab History View not displayed.");
}

// Open back navigation history.
- (void)openBackHistory {
  [[EarlGrey selectElementWithMatcher:chrome_test_util::BackButton()]
      performAction:grey_longPress()];
}

// Accepts the warning that the form POST data will be reposted.
- (void)confirmResendWarning {
  id<GREYMatcher> resendWarning =
      chrome_test_util::ButtonWithAccessibilityLabelId(
          IDS_HTTP_POST_WARNING_RESEND);
  [[EarlGrey selectElementWithMatcher:resendWarning]
      performAction:grey_longPress()];
}

// Sets up a basic simple http server for form test with a form located at
// |GetFormUrl|, and posts data to |GetDestinationUrl| upon submission.
- (void)setUpFormTestSimpleHttpServer {
  std::map<GURL, std::string> responses;
  responses[GetGenericUrl()] = "A generic page";
  responses[GetFormUrl()] =
      base::StringPrintf(kFormHtmlTemplate, GetDestinationUrl().spec().c_str());
  responses[GetDestinationUrl()] = kDestinationText;
  web::test::SetUpSimpleHttpServer(responses);
}

// Tests that a POST followed by reloading the destination page resends data.
- (void)testRepostFormAfterReload {
  [self setUpFormTestSimpleHttpServer];
  const GURL destinationURL = GetDestinationUrl();

  [ChromeEarlGrey loadURL:GetFormUrl()];
  chrome_test_util::TapWebViewElementWithId(kSubmitButtonLabel);
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kDestinationText)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];

  [ChromeEarlGrey reload];
  [self confirmResendWarning];

  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kDestinationText)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];
}

// Tests that a POST followed by navigating to a new page and then tapping back
// to the form result page resends data.
- (void)testRepostFormAfterTappingBack {
  [self setUpFormTestSimpleHttpServer];
  const GURL destinationURL = GetDestinationUrl();

  [ChromeEarlGrey loadURL:GetFormUrl()];
  chrome_test_util::TapWebViewElementWithId(kSubmitButtonLabel);
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kDestinationText)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Go to a new page and go back and check that the data is reposted.
  [ChromeEarlGrey loadURL:GetGenericUrl()];
  [ChromeEarlGrey goBack];
  [self confirmResendWarning];
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kDestinationText)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];
}

// Tests that a POST followed by tapping back to the form page and then tapping
// forward to the result page resends data.
- (void)testRepostFormAfterTappingBackAndForward {
  [self setUpFormTestSimpleHttpServer];
  const GURL destinationURL = GetDestinationUrl();

  [ChromeEarlGrey loadURL:GetFormUrl()];
  chrome_test_util::TapWebViewElementWithId(kSubmitButtonLabel);
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kDestinationText)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];

  [ChromeEarlGrey goBack];
  [ChromeEarlGrey goForward];
  [self confirmResendWarning];
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kDestinationText)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];
}

// Tests that a POST followed by a new request and then index navigation to get
// back to the result page resends data.
- (void)testRepostFormAfterIndexNavigation {
  [self setUpFormTestSimpleHttpServer];
  const GURL destinationURL = GetDestinationUrl();

  [ChromeEarlGrey loadURL:GetFormUrl()];
  chrome_test_util::TapWebViewElementWithId(kSubmitButtonLabel);
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kDestinationText)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Go to a new page and go back to destination through back history.
  [ChromeEarlGrey loadURL:GetGenericUrl()];
  [self openBackHistory];
  [self waitForTabHistoryView];
  id<GREYMatcher> historyItem = grey_text(
      base::SysUTF16ToNSString(web::GetDisplayTitleForUrl(destinationURL)));
  [[EarlGrey selectElementWithMatcher:historyItem] performAction:grey_tap()];
  [ChromeEarlGrey waitForPageToFinishLoading];

  [self confirmResendWarning];
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kDestinationText)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];
}

// When data is not reposted, the request is canceled.
- (void)testRepostFormCancelling {
  [self setUpFormTestSimpleHttpServer];
  const GURL destinationURL = GetDestinationUrl();

  [ChromeEarlGrey loadURL:GetFormUrl()];
  chrome_test_util::TapWebViewElementWithId(kSubmitButtonLabel);
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kDestinationText)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];

  [ChromeEarlGrey goBack];
  [ChromeEarlGrey goForward];

  // Abort the reload.
  // TODO (crbug.com/705020): Use something like ElementToDismissContextMenu
  // to cancel form repost.
  if (IsIPadIdiom()) {
    // On tablet, dismiss the popover.
    GREYElementMatcherBlock* matcher = [[GREYElementMatcherBlock alloc]
        initWithMatchesBlock:^BOOL(UIView* view) {
          return [NSStringFromClass([view class]) hasPrefix:@"UIDimmingView"];
        }
        descriptionBlock:^(id<GREYDescription> description) {
          [description appendText:@"class prefixed with UIDimmingView"];
        }];
    [[EarlGrey selectElementWithMatcher:matcher]
        performAction:grey_tapAtPoint(CGPointMake(50.0f, 50.0f))];
  } else {
    // On handset, dismiss via the cancel button.
    [[EarlGrey selectElementWithMatcher:chrome_test_util::CancelButton()]
        performAction:grey_tap()];
  }
  [ChromeEarlGrey waitForPageToFinishLoading];

  // Verify that navigation was cancelled, and forward navigation is possible.
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kSubmitButtonLabel)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(GetFormUrl().GetContent())]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:chrome_test_util::ForwardButton()]
      assertWithMatcher:grey_interactable()];
}

// Tests that pressing the button on a POST-based form changes the page and that
// the back button works as expected afterwards.
- (void)testGoBackButtonAfterFormSubmission {
  [self setUpFormTestSimpleHttpServer];
  GURL destinationURL = GetDestinationUrl();

  [ChromeEarlGrey loadURL:GetFormUrl()];
  chrome_test_util::TapWebViewElementWithId(kSubmitButtonLabel);
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kDestinationText)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Go back and verify the browser navigates to the original URL.
  [ChromeEarlGrey goBack];
  [[EarlGrey selectElementWithMatcher:WebViewContainingText(kSubmitButtonLabel)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(GetFormUrl().GetContent())]
      assertWithMatcher:grey_notNil()];
}

// Tests that a POST followed by a redirect does not show the popup.
- (void)testRepostFormCancellingAfterRedirect {
  web::test::SetUpHttpServer(base::MakeUnique<TestFormResponseProvider>());
  const GURL destinationURL = GetDestinationUrl();

  [ChromeEarlGrey loadURL:GetRedirectFormUrl()];

  // Submit the form, which redirects before printing the data.
  chrome_test_util::TapWebViewElementWithId(kSubmitButtonLabel);

  // Check that the redirect changes the POST to a GET.
  [[EarlGrey selectElementWithMatcher:WebViewContainingText("GET")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];

  [ChromeEarlGrey reload];

  // Check that the popup did not show
  id<GREYMatcher> resendWarning =
      ButtonWithAccessibilityLabelId(IDS_HTTP_POST_WARNING_RESEND);
  [[EarlGrey selectElementWithMatcher:resendWarning]
      assertWithMatcher:grey_nil()];
  [[EarlGrey selectElementWithMatcher:WebViewContainingText("GET")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];
}

// Tests that pressing the button on a POST-based form with same-page action
// does not change the page URL and that the back button works as expected
// afterwards.
- (void)testPostFormToSamePage {
// TODO(crbug.com/714303): Re-enable this test on devices.
#if !TARGET_IPHONE_SIMULATOR
  EARL_GREY_TEST_DISABLED(@"Test disabled on device.");
#endif

  web::test::SetUpHttpServer(base::MakeUnique<TestFormResponseProvider>());
  const GURL formURL = GetFormPostOnSamePageUrl();

  // Open the first URL so it's in history.
  [ChromeEarlGrey loadURL:GetGenericUrl()];

  // Open the second URL, tap the button, and verify the browser navigates to
  // the expected URL.
  [ChromeEarlGrey loadURL:formURL];
  chrome_test_util::TapWebViewElementWithId("button");
  [ChromeEarlGrey waitForWebViewContainingText:"POST"];
  [[EarlGrey selectElementWithMatcher:OmniboxText(formURL.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Go back once and verify the browser navigates to the form URL.
  [ChromeEarlGrey goBack];
  [[EarlGrey selectElementWithMatcher:OmniboxText(formURL.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Go back a second time and verify the browser navigates to the first URL.
  [ChromeEarlGrey goBack];
  [[EarlGrey selectElementWithMatcher:OmniboxText(GetGenericUrl().GetContent())]
      assertWithMatcher:grey_notNil()];
}

// Tests that submitting a POST-based form by tapping the 'Go' button on the
// keyboard navigates to the correct URL and the back button works as expected
// afterwards.
- (void)testPostFormEntryWithKeyboard {
// TODO(crbug.com/704618): Re-enable this test on devices.
#if !TARGET_IPHONE_SIMULATOR
  EARL_GREY_TEST_DISABLED(@"Test disabled on device.");
#endif

  [self setUpFormTestSimpleHttpServer];
  const GURL destinationURL = GetDestinationUrl();

  [ChromeEarlGrey loadURL:GetFormUrl()];
  [self submitFormUsingKeyboardGoButtonWithInputID:"textfield"];

  // Verify that the browser navigates to the expected URL.
  [ChromeEarlGrey waitForWebViewContainingText:"bar!"];
  [[EarlGrey selectElementWithMatcher:OmniboxText(destinationURL.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Go back and verify that the browser navigates to the original URL.
  [ChromeEarlGrey goBack];
  [[EarlGrey selectElementWithMatcher:OmniboxText(GetFormUrl().GetContent())]
      assertWithMatcher:grey_notNil()];
}

// Tap the text field indicated by |ID| to open the keyboard, and then
// press the keyboard's "Go" button to submit the form.
- (void)submitFormUsingKeyboardGoButtonWithInputID:(const std::string&)ID {
  // Disable EarlGrey's synchronization since it is blocked by opening the
  // keyboard from a web view.
  [[GREYConfiguration sharedInstance]
          setValue:@NO
      forConfigKey:kGREYConfigKeySynchronizationEnabled];

  // Wait for web view to be interactable before tapping.
  GREYCondition* interactableCondition = [GREYCondition
      conditionWithName:@"Wait for web view to be interactable."
                  block:^BOOL {
                    NSError* error = nil;
                    id<GREYMatcher> webViewMatcher = WebViewInWebState(
                        chrome_test_util::GetCurrentWebState());
                    [[EarlGrey selectElementWithMatcher:webViewMatcher]
                        assertWithMatcher:grey_interactable()
                                    error:&error];
                    return !error;
                  }];
  GREYAssert(
      [interactableCondition waitWithTimeout:testing::kWaitForUIElementTimeout],
      @"Web view did not become interactable.");

  web::WebState* currentWebState = chrome_test_util::GetCurrentWebState();
  [[EarlGrey selectElementWithMatcher:web::WebViewInWebState(currentWebState)]
      performAction:web::WebViewTapElement(currentWebState, ID)];

  // Wait until the keyboard shows up before tapping.
  GREYCondition* condition = [GREYCondition
      conditionWithName:@"Wait for the keyboard to show up."
                  block:^BOOL {
                    NSError* error = nil;
                    [[EarlGrey selectElementWithMatcher:GoButtonMatcher()]
                        assertWithMatcher:grey_notNil()
                                    error:&error];
                    return (error == nil);
                  }];
  GREYAssert([condition waitWithTimeout:testing::kWaitForUIElementTimeout],
             @"No keyboard with 'Go' button showed up.");

  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(@"Go")]
      performAction:grey_tap()];

  // Reenable synchronization now that the keyboard has been closed.
  [[GREYConfiguration sharedInstance]
          setValue:@YES
      forConfigKey:kGREYConfigKeySynchronizationEnabled];
}

@end
