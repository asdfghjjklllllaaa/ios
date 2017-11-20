// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <EarlGrey/EarlGrey.h>
#import <XCTest/XCTest.h>

#include "base/test/scoped_feature_list.h"
#include "components/strings/grit/components_strings.h"
#include "ios/chrome/browser/bookmarks/bookmark_new_generation_features.h"
#import "ios/chrome/browser/ui/browser_view_controller.h"
#import "ios/chrome/browser/ui/ntp/new_tab_page_controller.h"
#include "ios/chrome/browser/ui/tools_menu/tools_menu_constants.h"
#include "ios/chrome/browser/ui/ui_util.h"
#import "ios/chrome/browser/ui/uikit_ui_util.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/app/bookmarks_test_util.h"
#import "ios/chrome/test/app/chrome_test_util.h"
#import "ios/chrome/test/app/tab_test_util.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/web/public/test/http_server/http_server.h"
#include "ios/web/public/test/http_server/http_server_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using chrome_test_util::NavigationBarDoneButton;

// Test cases to verify that keyboard commands are and are not registered when
// expected.
@interface KeyboardCommandsTestCase : ChromeTestCase
@end

@implementation KeyboardCommandsTestCase

#pragma mark - Helpers

// Verifies that keyboard commands are registered by the BVC.
- (void)verifyKeyboardCommandsAreRegistered {
  BOOL (^block)
  () = ^BOOL {
    return chrome_test_util::GetRegisteredKeyCommandsCount() > 0;
  };

  GREYCondition* keyboardCommands =
      [GREYCondition conditionWithName:@"Keyboard commands registered"
                                 block:block];

  BOOL success = [keyboardCommands waitWithTimeout:5];
  if (!success) {
    GREYFail(@"No keyboard commands are registered.");
  }
}

// Verifies that no keyboard commands are registered by the BVC.
- (void)verifyNoKeyboardCommandsAreRegistered {
  BOOL (^block)
  () = ^BOOL {
    return chrome_test_util::GetRegisteredKeyCommandsCount() == 0;
  };
  GREYCondition* noKeyboardCommands =
      [GREYCondition conditionWithName:@"No keyboard commands registered"
                                 block:block];

  BOOL success = [noKeyboardCommands waitWithTimeout:5];
  if (!success) {
    GREYFail(@"Some keyboard commands are registered.");
  }
}

// Waits for the bookmark editor to display.
// TODO(crbug.com/638674): Evaluate if this can move to shared code.
- (void)waitForSingleBookmarkEditorToDisplay {
  BOOL (^block)
  () = ^BOOL {
    NSError* error = nil;
    id<GREYMatcher> singleBookmarkEditor =
        grey_accessibilityLabel(@"Single Bookmark Editor");
    [[EarlGrey selectElementWithMatcher:singleBookmarkEditor]
        assertWithMatcher:grey_sufficientlyVisible()
                    error:&error];
    return error != nil;
  };
  GREYCondition* editorDisplayed = [GREYCondition
      conditionWithName:@"Waiting for bookmark editor to display."
                  block:block];

  BOOL success = [editorDisplayed waitWithTimeout:5];
  GREYAssert(success, @"The bookmark editor was not displayed.");
}

#pragma mark - Tests

// Tests that keyboard commands are registered when the BVC is showing without
// modals currently presented.
- (void)testKeyboardCommandsRegistered {
  [self verifyKeyboardCommandsAreRegistered];
}

// Tests that keyboard commands are not registered when Settings are shown.
- (void)testKeyboardCommandsNotRegistered_SettingsPresented {
  [ChromeEarlGreyUI openSettingsMenu];

  [self verifyNoKeyboardCommandsAreRegistered];

  [[EarlGrey selectElementWithMatcher:NavigationBarDoneButton()]
      performAction:grey_tap()];
}

// Tests that keyboard commands are not registered when the bookmark UI is
// shown.
- (void)testKeyboardCommandsNotRegistered_AddBookmarkPresented {
  [ChromeEarlGrey waitForBookmarksToFinishLoading];
  BOOL success = chrome_test_util::ClearBookmarks();
  GREYAssert(success, @"Not all bookmarks were removed.");

  // Bookmark page
  if (IsIPadIdiom()) {
    id<GREYMatcher> bookmarkMatcher =
        chrome_test_util::ButtonWithAccessibilityLabelId(IDS_TOOLTIP_STAR);
    [[EarlGrey selectElementWithMatcher:bookmarkMatcher]
        performAction:grey_tap()];
  } else {
    [ChromeEarlGreyUI openToolsMenu];
    id<GREYMatcher> bookmarkMatcher = grey_accessibilityLabel(@"Add Bookmark");
    [[EarlGrey selectElementWithMatcher:bookmarkMatcher]
        performAction:grey_tap()];
  }

  // Tap on the HUD.
  id<GREYMatcher> edit = chrome_test_util::ButtonWithAccessibilityLabelId(
      IDS_IOS_NAVIGATION_BAR_EDIT_BUTTON);
  [[EarlGrey selectElementWithMatcher:edit] performAction:grey_tap()];

  [self waitForSingleBookmarkEditorToDisplay];

  [self verifyNoKeyboardCommandsAreRegistered];

  id<GREYMatcher> cancel = grey_accessibilityID(@"Cancel");
  [[EarlGrey selectElementWithMatcher:cancel] performAction:grey_tap()];
}

// Tests that keyboard commands are not registered when the Bookmarks UI is
// shown on iPhone and registered on iPad.
- (void)testKeyboardCommandsNotRegistered_BookmarksPresented {
  // TODO(crbug.com/782551): Rewrite this test for the new Bookmarks UI.
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndDisableFeature(kBookmarkNewGeneration);

  // Open Bookmarks
  [ChromeEarlGreyUI openToolsMenu];
  [ChromeEarlGreyUI
      tapToolsMenuButton:grey_accessibilityID(kToolsMenuBookmarksId)];

  if (IsIPadIdiom()) {
    [self verifyKeyboardCommandsAreRegistered];
  } else {
    [self verifyNoKeyboardCommandsAreRegistered];

    [[EarlGrey selectElementWithMatcher:grey_accessibilityID(@"Exit")]
        performAction:grey_tap()];
  }
}

// Tests that keyboard commands are not registered when the Recent Tabs UI is
// shown on iPhone and registered on iPad.
- (void)testKeyboardCommands_RecentTabsPresented {
  // Open Recent Tabs
  id<GREYMatcher> recentTabs = grey_accessibilityID(kToolsMenuOtherDevicesId);
  [ChromeEarlGreyUI openToolsMenu];
  [ChromeEarlGreyUI tapToolsMenuButton:recentTabs];

  if (IsIPadIdiom()) {
    [self verifyKeyboardCommandsAreRegistered];
  } else {
    [self verifyNoKeyboardCommandsAreRegistered];

    id<GREYMatcher> exit = grey_accessibilityID(@"Exit");
    [[EarlGrey selectElementWithMatcher:exit] performAction:grey_tap()];
  }
}

// Tests that when the app is opened on a web page and a key is pressed, the
// web view is the first responder.
- (void)testWebViewIsFirstResponderUponKeyPress {
  web::test::SetUpFileBasedHttpServer();
  GURL URL = web::test::HttpServer::MakeUrl(
      "http://ios/testing/data/http_server_files/pony.html");
  [ChromeEarlGrey loadURL:URL];

  [self verifyKeyboardCommandsAreRegistered];

  UIResponder* firstResponder = GetFirstResponder();
  GREYAssert(
      [firstResponder isKindOfClass:NSClassFromString(@"WKContentView")],
      @"Expected first responder to be a WKContentView. Instead, is a %@",
      NSStringFromClass([firstResponder class]));
}

@end
