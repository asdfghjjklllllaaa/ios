// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_PAYMENTS_CELLS_PAYMENTS_HAS_ACCESSORY_TYPE_H_
#define IOS_CHROME_BROWSER_PAYMENTS_CELLS_PAYMENTS_HAS_ACCESSORY_TYPE_H_

#import "ios/third_party/material_components_ios/src/components/CollectionCells/src/MaterialCollectionCells.h"

// Protocol adopted by the payments collection view items that set the accessory
// view type on their represented cells.
@protocol PaymentsHasAccessoryType

// The accessory view type for the represented cell.
@property(nonatomic) MDCCollectionViewCellAccessoryType accessoryType;

@end

#endif  // IOS_CHROME_BROWSER_PAYMENTS_CELLS_PAYMENTS_HAS_ACCESSORY_TYPE_H_
