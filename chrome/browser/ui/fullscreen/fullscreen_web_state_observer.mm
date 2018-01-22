// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/fullscreen/fullscreen_web_state_observer.h"

#include "base/logging.h"
#import "ios/chrome/browser/ui/fullscreen/fullscreen_model.h"
#import "ios/chrome/browser/ui/fullscreen/fullscreen_web_scroll_view_replacement_handler.h"
#import "ios/chrome/browser/ui/fullscreen/scoped_fullscreen_disabler.h"
#import "ios/web/public/navigation_item.h"
#import "ios/web/public/navigation_manager.h"
#include "ios/web/public/ssl_status.h"
#import "ios/web/public/web_state/web_state.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Returns whether fullscreen should be disabled for |web_state|'s SSL status.
// This will return true if the visible NavigationItem's SSL has a broken
// security style or is showing mixed content.
bool ShouldDisableFullscreenForWebStateSSL(web::WebState* web_state) {
  if (!web_state)
    return false;
  web::NavigationManager* manager = web_state->GetNavigationManager();
  if (!manager)
    return false;
  web::NavigationItem* item = manager->GetVisibleItem();
  if (!item)
    return false;
  const web::SSLStatus& ssl = item->GetSSL();
  return ssl.security_style == web::SECURITY_STYLE_AUTHENTICATION_BROKEN ||
         (ssl.content_status & web::SSLStatus::DISPLAYED_INSECURE_CONTENT) > 0;
}
}  // namespace

FullscreenWebStateObserver::FullscreenWebStateObserver(
    FullscreenController* controller,
    FullscreenModel* model)
    : controller_(controller),
      model_(model),
      scroll_view_replacement_handler_(
          [[FullscreenWebScrollViewReplacementHandler alloc]
              initWithModel:model_]) {
  DCHECK(controller_);
  DCHECK(model_);
}

FullscreenWebStateObserver::~FullscreenWebStateObserver() = default;

void FullscreenWebStateObserver::SetWebState(web::WebState* web_state) {
  if (web_state_ == web_state)
    return;
  if (web_state_)
    web_state_->RemoveObserver(this);
  web_state_ = web_state;
  if (web_state_)
    web_state_->AddObserver(this);
  // Update the model according to the new WebState.
  SetIsLoading(web_state_ ? web_state->IsLoading() : false);
  SetDisableFullscreenForSSL(ShouldDisableFullscreenForWebStateSSL(web_state_));
  // Update the scroll view replacement handler's proxy.
  scroll_view_replacement_handler_.proxy =
      web_state_ ? web_state_->GetWebViewProxy() : nil;
}

void FullscreenWebStateObserver::DidFinishNavigation(
    web::WebState* web_state,
    web::NavigationContext* navigation_context) {
  model_->ResetForNavigation();
  SetDisableFullscreenForSSL(ShouldDisableFullscreenForWebStateSSL(web_state));
}

void FullscreenWebStateObserver::DidStartLoading(web::WebState* web_state) {
  SetIsLoading(true);
}

void FullscreenWebStateObserver::DidStopLoading(web::WebState* web_state) {
  SetIsLoading(false);
}

void FullscreenWebStateObserver::DidChangeVisibleSecurityState(
    web::WebState* web_state) {
  SetDisableFullscreenForSSL(ShouldDisableFullscreenForWebStateSSL(web_state));
}

void FullscreenWebStateObserver::WebStateDestroyed(web::WebState* web_state) {
  DCHECK_EQ(web_state, web_state_);
  SetWebState(nullptr);
}

void FullscreenWebStateObserver::SetDisableFullscreenForSSL(bool disable) {
  if (!!ssl_disabler_.get() == disable)
    return;
  ssl_disabler_ = disable
                      ? std::make_unique<ScopedFullscreenDisabler>(controller_)
                      : nullptr;
}

void FullscreenWebStateObserver::SetIsLoading(bool loading) {
  if (!!loading_disabler_.get() == loading)
    return;
  loading_disabler_ =
      loading ? std::make_unique<ScopedFullscreenDisabler>(controller_)
              : nullptr;
}
