// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_WEB_STATE_UI_JS_WINDOW_ERROR_MANAGER_H_
#define IOS_WEB_WEB_STATE_UI_JS_WINDOW_ERROR_MANAGER_H_

#include "base/macros.h"

namespace base {
class DictionaryValue;
}
class GURL;
namespace web {
class WebState;
class WebFrame;

// Handles "window.error" message from injected JavaScript and DLOG it.
class JsWindowErrorManager final {
 public:
  explicit JsWindowErrorManager(WebState* web_state);
  ~JsWindowErrorManager();

 private:
  bool OnJsMessage(const base::DictionaryValue& message,
                   const GURL& page_url,
                   bool has_user_gesture,
                   bool in_main_frame,
                   WebFrame* sender_frame);

  WebState* web_state_impl_ = nullptr;

  DISALLOW_COPY_AND_ASSIGN(JsWindowErrorManager);
};

}  // namespace web

#endif  // IOS_WEB_WEB_STATE_UI_JS_WINDOW_ERROR_MANAGER_H_
