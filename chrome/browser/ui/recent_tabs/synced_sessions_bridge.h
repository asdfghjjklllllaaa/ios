// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_RECENT_TABS_SYNCED_SESSIONS_BRIDGE_H_
#define IOS_CHROME_BROWSER_UI_RECENT_TABS_SYNCED_SESSIONS_BRIDGE_H_

#import <Foundation/Foundation.h>

#include <memory>

#include "base/callback_list.h"
#include "base/macros.h"
#include "services/identity/public/cpp/identity_manager.h"

namespace ios {
class ChromeBrowserState;
}

namespace identity {
class IdentityManager;
}

@protocol SyncedSessionsObserver
// Reloads the session data.
- (void)reloadSessions;
@end

namespace synced_sessions {

// Bridge class that will notify the panel when the remote sessions content
// change.
class SyncedSessionsObserverBridge
    : public identity::IdentityManager::Observer {
 public:
  SyncedSessionsObserverBridge(id<SyncedSessionsObserver> owner,
                               ios::ChromeBrowserState* browserState);
  ~SyncedSessionsObserverBridge() override;
  // identity::IdentityManager::Observer implementation.
  void OnPrimaryAccountCleared(
      const AccountInfo& previous_primary_account_info) override;

  // Returns true if user is signed in.
  bool IsSignedIn();

 private:
  void OnForeignSessionChanged();

  __weak id<SyncedSessionsObserver> owner_ = nil;
  identity::IdentityManager* identity_manager_ = nullptr;
  ScopedObserver<identity::IdentityManager, identity::IdentityManager::Observer>
      identity_manager_observer_;
  std::unique_ptr<base::CallbackList<void()>::Subscription>
      foreign_session_updated_subscription_;

  DISALLOW_COPY_AND_ASSIGN(SyncedSessionsObserverBridge);
};

}  // namespace synced_sessions

#endif  // IOS_CHROME_BROWSER_UI_RECENT_TABS_SYNCED_SESSIONS_BRIDGE_H_
