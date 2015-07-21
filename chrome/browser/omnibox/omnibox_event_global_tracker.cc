// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/omnibox/omnibox_event_global_tracker.h"

#include "base/memory/singleton.h"

OmniboxEventGlobalTracker* OmniboxEventGlobalTracker::GetInstance() {
  return Singleton<OmniboxEventGlobalTracker>::get();
}

scoped_ptr<base::CallbackList<void(OmniboxLog*)>::Subscription>
OmniboxEventGlobalTracker::RegisterCallback(const OnURLOpenedCallback& cb) {
  return on_url_opened_callback_list_.Add(cb);
}

void OmniboxEventGlobalTracker::OnURLOpened(OmniboxLog* log) {
  on_url_opened_callback_list_.Notify(log);
}

OmniboxEventGlobalTracker::OmniboxEventGlobalTracker() {}

OmniboxEventGlobalTracker::~OmniboxEventGlobalTracker() {}
