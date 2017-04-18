// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_SHOWCASE_PAYMENTS_SC_PAYMENTS_SELECTOR_COORDINATOR_H_
#define IOS_SHOWCASE_PAYMENTS_SC_PAYMENTS_SELECTOR_COORDINATOR_H_

#import <UIKit/UIKit.h>

#import "ios/showcase/common/navigation_coordinator.h"

// Coordinator responsible for creating and presenting a
// PaymentRequestSelectorViewController.
@interface SCPaymentsSelectorCoordinator : NSObject<NavigationCoordinator>
@end

#endif  // IOS_SHOWCASE_PAYMENTS_SC_PAYMENTS_SELECTOR_COORDINATOR_H_
