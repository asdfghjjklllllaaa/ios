// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/settings_root_table_view_controller.h"

#include "base/test/scoped_task_environment.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#import "ios/chrome/browser/ui/settings/settings_navigation_controller.h"
#include "ios/chrome/grit/ios_strings.h"
#include "testing/gtest/include/gtest/gtest.h"
#import "testing/gtest_mac.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#include "third_party/ocmock/gtest_support.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

class SettingsRootTableViewControllerTest : public PlatformTest {
 public:
  SettingsRootTableViewController* Controller() {
    return [[SettingsRootTableViewController alloc]
        initWithTableViewStyle:UITableViewStylePlain
                   appBarStyle:ChromeTableViewControllerStyleWithAppBar];
  }

  SettingsNavigationController* NavigationController() {
    if (!chrome_browser_state_) {
      TestChromeBrowserState::Builder test_cbs_builder;
      chrome_browser_state_ = test_cbs_builder.Build();
    }
    return [[SettingsNavigationController alloc]
        initWithRootViewController:nil
                      browserState:chrome_browser_state_.get()
                          delegate:nil];
  }

 protected:
  base::test::ScopedTaskEnvironment scoped_task_environment_;
  std::unique_ptr<TestChromeBrowserState> chrome_browser_state_;
};

TEST_F(SettingsRootTableViewControllerTest, TestUpdateEditButton) {
  SettingsRootTableViewController* controller = Controller();

  id mockController = OCMPartialMock(controller);
  SettingsNavigationController* navigationController = NavigationController();
  OCMStub([mockController navigationController])
      .andReturn(navigationController);

  // Check that there the navigation controller's button if the table view isn't
  // edited and the controller has the default behavior for
  // |shouldShowEditButton|.
  controller.tableView.editing = NO;
  [controller updateEditButton];
  EXPECT_NSEQ(l10n_util::GetNSString(IDS_IOS_NAVIGATION_BAR_DONE_BUTTON),
              controller.navigationItem.rightBarButtonItem.title);

  // Check that there the OK button if the table view is being edited and the
  // controller has the default behavior for |shouldShowEditButton|.
  controller.tableView.editing = YES;
  [controller updateEditButton];
  EXPECT_NSEQ(l10n_util::GetNSString(IDS_IOS_NAVIGATION_BAR_DONE_BUTTON),
              controller.navigationItem.rightBarButtonItem.title);

  // Check that there the OK button if the table view isn't edited and the
  // controller returns YES for |shouldShowEditButton|.
  controller.tableView.editing = NO;
  OCMStub([mockController shouldShowEditButton]).andReturn(YES);
  [controller updateEditButton];
  EXPECT_NSEQ(l10n_util::GetNSString(IDS_IOS_NAVIGATION_BAR_EDIT_BUTTON),
              controller.navigationItem.rightBarButtonItem.title);
}

// Tests that the delete button in the bottom toolbar is displayed only when the
// collection is being edited.
TEST_F(SettingsRootTableViewControllerTest, TestDeleteToolbar) {
  SettingsRootTableViewController* controller = Controller();

  id mockController = OCMPartialMock(controller);
  id mockTableView = OCMPartialMock(controller.tableView);
  SettingsNavigationController* navigationController = NavigationController();
  OCMStub([mockController navigationController])
      .andReturn(navigationController);

  NSIndexPath* testIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
  NSMutableArray* testSelectedItems = [NSMutableArray array];
  [testSelectedItems addObject:testIndexPath];
  ASSERT_TRUE(navigationController.toolbarHidden);

  // Test that if the table view isn't being edited, the toolbar is still
  // hidden.
  controller.tableView.editing = NO;
  [controller tableView:controller.tableView
      didSelectRowAtIndexPath:testIndexPath];
  EXPECT_TRUE(navigationController.toolbarHidden);

  // Test that if the table view is being edited, the toolbar is displayed when
  // the element is selected.
  controller.tableView.editing = YES;
  EXPECT_TRUE(navigationController.toolbarHidden);
  [controller tableView:controller.tableView
      didSelectRowAtIndexPath:testIndexPath];
  EXPECT_FALSE(navigationController.toolbarHidden);

  // Test that if the table view is being edited, the toolbar is not hidden when
  // an element is deselected but some elements are still selected.
  OCMStub([mockTableView indexPathsForSelectedRows])
      .andReturn(testSelectedItems);
  [controller tableView:controller.tableView
      didDeselectRowAtIndexPath:testIndexPath];
  EXPECT_FALSE(navigationController.toolbarHidden);

  // Test that if the table view is being edited, the toolbar is hidden when the
  // last selected element is deselected.
  [testSelectedItems removeAllObjects];
  [controller tableView:controller.tableView
      didDeselectRowAtIndexPath:testIndexPath];
  EXPECT_TRUE(navigationController.toolbarHidden);
}
