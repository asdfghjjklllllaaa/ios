// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#ifndef IOS_WEB_VIEW_INTERNAL_CRIWV_WEB_VIEW_IMPL_H_
#define IOS_WEB_VIEW_INTERNAL_CRIWV_WEB_VIEW_IMPL_H_

#import "ios/web_view/public/criwv_web_view.h"

namespace ios_web_view {
class CRIWVBrowserState;
}

@interface CRIWVWebViewImpl : NSObject<CRIWVWebView>

// Designated initializer.
- (instancetype)initWithBrowserState:
    (ios_web_view::CRIWVBrowserState*)browserState;

@end

#endif  // IOS_WEB_VIEW_INTERNAL_CRIWV_WEB_VIEW_IMPL_H_
