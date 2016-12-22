// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_READING_LIST_READING_LIST_WEB_STATE_OBSERVER_H_
#define IOS_CHROME_BROWSER_READING_LIST_READING_LIST_WEB_STATE_OBSERVER_H_

#include "base/macros.h"
#include "base/timer/timer.h"
#include "ios/web/public/web_state/web_state_observer.h"
#include "url/gurl.h"

class ReadingListModel;

namespace web {
class NavigationItem;
}

// Observes the loading of pages coming from the reading list, determines
// whether loading an offline version of the page is needed, and actually
// trigger the loading of the offline page (if possible).
class ReadingListWebStateObserver : public web::WebStateObserver {
 public:
  static ReadingListWebStateObserver* FromWebState(
      web::WebState* web_state,
      ReadingListModel* reading_list_model);

  ~ReadingListWebStateObserver() override;

 private:
  ReadingListWebStateObserver(web::WebState* web_state,
                              ReadingListModel* reading_list_model);

  // Looks at the loading percentage. If less than 25% * time, attemps to load
  // the offline version of that page.
  // |time| is the number of seconds since |StartCheckingProgress| was called.
  void VerifyIfReadingListEntryStartedLoading();

  friend class ReadingListWebStateObserverUserDataWrapper;

  // Stops checking the loading of the |pending_url_|.
  // The WebState will still be observed, but no action will be done on events.
  void StopCheckingProgress();

  // Loads the offline version of the URL in place of the current page.
  void LoadOfflineReadingListEntry(web::NavigationItem* item);

  // Returns if the current page with |url| has an offline version that can be
  // displayed if the normal loading fails.
  bool IsUrlAvailableOffline(const GURL& url) const;

  // Checks if |item| should be observed or not.
  // A non-null item should be observed if it is not already loading an offline
  // URL.
  bool ShouldObserveItem(web::NavigationItem* item) const;

  // WebContentsObserver implementation.
  void PageLoaded(
      web::PageLoadCompletionStatus load_completion_status) override;
  void WebStateDestroyed() override;

  // Starts checking that the current navigation is loading quickly enough [1].
  // If not, starts to load a distilled version of the page (if there is any).
  // [1] A page loading quickly enough is a page that has loaded 25% within
  // 1 second, 50% within 2 seconds and 75% within 3 seconds.
  void DidStartLoading() override;

  ReadingListModel* reading_list_model_;
  std::unique_ptr<base::Timer> timer_;
  GURL pending_url_;
  int try_number_;

  DISALLOW_COPY_AND_ASSIGN(ReadingListWebStateObserver);
};

#endif  // IOS_CHROME_BROWSER_READING_LIST_READING_LIST_WEB_STATE_OBSERVER_H_
