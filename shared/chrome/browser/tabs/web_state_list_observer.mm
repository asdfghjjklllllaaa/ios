// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/shared/chrome/browser/tabs/web_state_list_observer.h"

WebStateListObserver::WebStateListObserver() = default;

WebStateListObserver::~WebStateListObserver() = default;

void WebStateListObserver::WebStateInsertedAt(WebStateList* web_state_list,
                                              web::WebState* web_state,
                                              int index) {}

void WebStateListObserver::WebStateMoved(WebStateList* web_state_list,
                                         web::WebState* web_state,
                                         int from_index,
                                         int to_index) {}

void WebStateListObserver::WebStateReplacedAt(WebStateList* web_state_list,
                                              web::WebState* old_web_state,
                                              web::WebState* new_web_state,
                                              int index) {}

void WebStateListObserver::WebStateDetachedAt(WebStateList* web_state_list,
                                              web::WebState* web_state,
                                              int index) {}
