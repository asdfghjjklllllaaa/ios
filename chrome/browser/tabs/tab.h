// Copyright 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_TABS_TAB_H_
#define IOS_CHROME_BROWSER_TABS_TAB_H_

#import <UIKit/UIKit.h>

#include "ios/web/public/user_agent.h"
#include "ui/base/page_transition_types.h"

namespace web {
class WebState;
}

// The header name and value for the data reduction proxy to request an image to
// be reloaded without optimizations.
extern NSString* const kProxyPassthroughHeaderName;
extern NSString* const kProxyPassthroughHeaderValue;

// Information related to a single tab. The WebState is similar to desktop
// Chrome's WebContents in that it encapsulates rendering. Acts as the
// delegate for the WebState in order to process info about pages having
// loaded.
@interface Tab : NSObject

// The Webstate associated with this Tab.
@property(nonatomic, readonly) web::WebState* webState;

// Creates a new Tab with the given WebState.
- (instancetype)initWithWebState:(web::WebState*)webState;

- (instancetype)init NS_UNAVAILABLE;

@end

#endif  // IOS_CHROME_BROWSER_TABS_TAB_H_
