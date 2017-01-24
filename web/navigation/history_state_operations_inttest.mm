// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/memory/ptr_util.h"
#include "base/strings/string_number_conversions.h"
#include "base/test/ios/wait_util.h"
#import "ios/web/public/navigation_item.h"
#import "ios/web/public/navigation_manager.h"
#import "ios/web/public/test/http_server.h"
#include "ios/web/public/test/http_server_util.h"
#import "ios/web/public/test/web_view_interaction_test_util.h"
#import "ios/web/public/web_state/web_state.h"
#import "ios/web/test/web_int_test.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/gtest_mac.h"
#include "url/url_canon.h"

namespace {

// URL for the test window.location test file.  The page at this URL contains
// several buttons that trigger window.location commands.  The page supports
// several JavaScript functions:
// - updateUrlToLoadText(), which takes a URL and updates a div on the page to
//   contain that text.  This URL is used as the parameter for window.location
//   function calls triggered by button taps.
// - getUrl(), which returns the URL that was set via updateUrlToLoadText().
// - isOnLoadTextVisible(), which returns whether a placeholder string is
//   present on the page.  This string is added to the page in the onload event
//   and is removed once a button is tapped.  Verifying that the onload text is
//   visible after tapping a button is equivalent to checking that a load has
//   occurred as the result of the button tap.
const char kHistoryStateOperationsTestUrl[] =
    "http://ios/testing/data/http_server_files/state_operations.html";

// Button IDs used in the window.location test page.
const char kPushStateId[] = "push-state";
const char kReplaceStateId[] = "replace-state";

// JavaScript functions on the history state test page.
NSString* const kUpdateStateParamsScriptFormat =
    @"updateStateParams('%s', '%s', '%s')";
NSString* const kOnLoadCheckScript = @"isOnLoadPlaceholderTextVisible()";
NSString* const kNoOpCheckScript = @"isNoOpPlaceholderTextVisible()";

}  // namespace

// Test fixture for integration tests involving html5 window.history state
// operations.
class HistoryStateOperationsTest : public web::WebIntTest {
 protected:
  void SetUp() override {
    web::WebIntTest::SetUp();

    // History state tests use file-based test pages.
    web::test::SetUpFileBasedHttpServer();

    // Load the history state test page.
    state_operations_url_ =
        web::test::HttpServer::MakeUrl(kHistoryStateOperationsTestUrl);
    LoadUrl(state_operations_url());
  }

  // The URL of the window.location test page.
  const GURL& state_operations_url() { return state_operations_url_; }

  // Sets the parameters to use for state operations on the test page.  This
  // function executes a script that populates JavaScript values on the test
  // page.  When the "push-state" or "replace-state" buttons are tapped, these
  // parameters will be passed to their corresponding JavaScript function calls.
  void SetStateParams(const std::string& state_object,
                      const std::string& title,
                      const GURL& url) {
    ASSERT_EQ(state_operations_url(), GetLastCommittedItem()->GetURL());
    std::string url_spec = url.possibly_invalid_spec();
    NSString* set_params_script = [NSString
        stringWithFormat:kUpdateStateParamsScriptFormat, state_object.c_str(),
                         title.c_str(), url_spec.c_str()];
    ExecuteJavaScript(set_params_script);
  }

  // Executes JavaScript to check whether the onload text is visible.
  bool IsOnLoadTextVisible() {
    return [ExecuteJavaScript(kOnLoadCheckScript) boolValue];
  }

  // Executes JavaScript to check whether the no-op text is visible.
  bool IsNoOpTextVisible() {
    return [ExecuteJavaScript(kNoOpCheckScript) boolValue];
  }

  // Waits for the NoOp text to be visible.
  void WaitForNoOpText() {
    base::test::ios::WaitUntilCondition(^bool {
      return IsNoOpTextVisible();
    });
  }

 private:
  GURL state_operations_url_;
};

// Tests that calling window.history.pushState() is a no-op for unresolvable
// URLs.
TEST_F(HistoryStateOperationsTest, NoOpPushUnresolvable) {
  // Perform a window.history.pushState() with an unresolvable URL.  This will
  // clear the OnLoad and NoOp text, so checking below that the NoOp text is
  // displayed and the OnLoad text is empty ensures that no navigation occurred
  // as the result of the pushState() call.
  std::string empty_state;
  std::string empty_title;
  GURL unresolvable_url("http://www.google.invalid");
  SetStateParams(empty_state, empty_title, unresolvable_url);
  ASSERT_TRUE(web::test::TapWebViewElementWithId(web_state(), kPushStateId));
  WaitForNoOpText();
}

// Tests that calling window.history.replaceState() is a no-op for unresolvable
// URLs.
TEST_F(HistoryStateOperationsTest, NoOpReplaceUnresolvable) {
  // Perform a window.history.replaceState() with an unresolvable URL.  This
  // will clear the OnLoad and NoOp text, so checking below that the NoOp text
  // is displayed and the OnLoad text is empty ensures that no navigation
  // occurred as the result of the pushState() call.
  std::string empty_state;
  std::string empty_title;
  GURL unresolvable_url("http://www.google.invalid");
  SetStateParams(empty_state, empty_title, unresolvable_url);
  ASSERT_TRUE(web::test::TapWebViewElementWithId(web_state(), kReplaceStateId));
  WaitForNoOpText();
}

// Tests that calling window.history.pushState() is a no-op for URLs with a
// different scheme.
TEST_F(HistoryStateOperationsTest, NoOpPushDifferentScheme) {
  // Perform a window.history.pushState() with a URL with a different scheme.
  // This will clear the OnLoad and NoOp text, so checking below that the NoOp
  // text is displayed and the OnLoad text is empty ensures that no navigation
  // occurred as the result of the pushState() call.
  std::string empty_state;
  std::string empty_title;
  GURL different_scheme_url("https://google.com");
  ASSERT_TRUE(IsOnLoadTextVisible());
  SetStateParams(empty_state, empty_title, different_scheme_url);
  ASSERT_TRUE(web::test::TapWebViewElementWithId(web_state(), kPushStateId));
  WaitForNoOpText();
}

// Tests that calling window.history.replaceState() is a no-op for URLs with a
// different scheme.
TEST_F(HistoryStateOperationsTest, NoOpRelaceDifferentScheme) {
  // Perform a window.history.replaceState() with a URL with a different scheme.
  // This will clear the OnLoad and NoOp text, so checking below that the NoOp
  // text is displayed and the OnLoad text is empty ensures that no navigation
  // occurred as the result of the pushState() call.
  std::string empty_state;
  std::string empty_title;
  GURL different_scheme_url("https://google.com");
  ASSERT_TRUE(IsOnLoadTextVisible());
  SetStateParams(empty_state, empty_title, different_scheme_url);
  ASSERT_TRUE(web::test::TapWebViewElementWithId(web_state(), kReplaceStateId));
  WaitForNoOpText();
}

// Tests that calling window.history.pushState() is a no-op for URLs with a
// origin differing from that of the current page.
TEST_F(HistoryStateOperationsTest, NoOpPushDifferentOrigin) {
  // Perform a window.history.pushState() with a URL with a different origin.
  // This will clear the OnLoad and NoOp text, so checking below that the NoOp
  // text is displayed and the OnLoad text is empty ensures that no navigation
  // occurred as the result of the pushState() call.
  std::string empty_state;
  std::string empty_title;
  std::string new_port_string = base::IntToString(
      web::test::HttpServer::GetSharedInstance().GetPort() + 1);
  url::Replacements<char> port_replacement;
  port_replacement.SetPort(new_port_string.c_str(),
                           url::Component(0, new_port_string.length()));
  GURL different_origin_url =
      state_operations_url().ReplaceComponents(port_replacement);
  ASSERT_TRUE(IsOnLoadTextVisible());
  SetStateParams(empty_state, empty_title, different_origin_url);
  ASSERT_TRUE(web::test::TapWebViewElementWithId(web_state(), kPushStateId));
  WaitForNoOpText();
}

// Tests that calling window.history.replaceState() is a no-op for URLs with a
// origin differing from that of the current page.
TEST_F(HistoryStateOperationsTest, NoOpReplaceDifferentOrigin) {
  // Perform a window.history.replaceState() with a URL with a different origin.
  // This will clear the OnLoad and NoOp text, so checking below that the NoOp
  // text is displayed and the OnLoad text is empty ensures that no navigation
  // occurred as the result of the pushState() call.
  std::string empty_state;
  std::string empty_title;
  std::string new_port_string = base::IntToString(
      web::test::HttpServer::GetSharedInstance().GetPort() + 1);
  url::Replacements<char> port_replacement;
  port_replacement.SetPort(new_port_string.c_str(),
                           url::Component(0, new_port_string.length()));
  GURL different_origin_url =
      state_operations_url().ReplaceComponents(port_replacement);
  ASSERT_TRUE(IsOnLoadTextVisible());
  SetStateParams(empty_state, empty_title, different_origin_url);
  ASSERT_TRUE(web::test::TapWebViewElementWithId(web_state(), kReplaceStateId));
  WaitForNoOpText();
}
