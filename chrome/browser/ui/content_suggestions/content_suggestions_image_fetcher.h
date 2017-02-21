// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_CONTENT_SUGGESTIONS_CONTENT_SUGGESTIONS_IMAGE_UPDATER_H_
#define IOS_CHROME_BROWSER_UI_CONTENT_SUGGESTIONS_CONTENT_SUGGESTIONS_IMAGE_UPDATER_H_

#import <Foundation/Foundation.h>

namespace gfx {
class Image;
}

@class ContentSuggestionIdentifier;

// Protocol for an object able to fetch the image associated with a suggestion.
@protocol ContentSuggestionsImageFetcher

// Fetches the image associated with the |suggestionIdentifier| and passes it to
// the |callback|.
- (void)fetchImageForSuggestion:
            (ContentSuggestionIdentifier*)suggestionIdentifier
                       callback:(void (^)(const gfx::Image&))callback;

@end

#endif  // IOS_CHROME_BROWSER_UI_CONTENT_SUGGESTIONS_CONTENT_SUGGESTIONS_IMAGE_UPDATER_H_
