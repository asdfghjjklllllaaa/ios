// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_VIEW_PUBLIC_CWV_TRANSLATE_DELEGATE_H_
#define IOS_WEB_VIEW_PUBLIC_CWV_TRANSLATE_DELEGATE_H_

#import <Foundation/Foundation.h>

// TODO(crbug.com/704946): Make framework style include work everywhere and
// remove this #if.
#if defined(CWV_IMPLEMENTATION)
#include "ios/web_view/public/cwv_export.h"
#else
#include <ChromeWebView/cwv_export.h>
#endif

@protocol CWVTranslateManager;

typedef NS_ENUM(NSInteger, CRIWVTransateStep) {
  CRIWVTransateStepBeforeTranslate,
  CRIWVTransateStepTranslating,
  CRIWVTransateStepAfterTranslate,
  CRIWVTransateStepError,
};

// Delegate interface for the CRIWVTranslate.  Embedders can implement the
// functions in order to customize the behavior.
CWV_EXPORT
@protocol CWVTranslateDelegate

- (void)translateStepChanged:(CRIWVTransateStep)step
                     manager:(id<CWVTranslateManager>)manager;

@end

#endif  // IOS_WEB_VIEW_PUBLIC_CWV_TRANSLATE_DELEGATE_H_
