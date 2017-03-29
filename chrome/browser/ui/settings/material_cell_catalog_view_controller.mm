// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/material_cell_catalog_view_controller.h"

#import <UIKit/UIKit.h>

#import "base/mac/foundation_util.h"
#import "base/mac/scoped_nsobject.h"
#include "components/autofill/core/browser/autofill_data_util.h"
#include "components/autofill/core/browser/credit_card.h"
#include "components/grit/components_scaled_resources.h"
#import "ios/chrome/browser/payments/cells/autofill_profile_item.h"
#import "ios/chrome/browser/payments/cells/payments_text_item.h"
#import "ios/chrome/browser/payments/cells/price_item.h"
#import "ios/chrome/browser/ui/authentication/account_control_item.h"
#import "ios/chrome/browser/ui/authentication/signin_promo_item.h"
#import "ios/chrome/browser/ui/authentication/signin_promo_view_mediator.h"
#import "ios/chrome/browser/ui/autofill/cells/cvc_item.h"
#import "ios/chrome/browser/ui/autofill/cells/status_item.h"
#import "ios/chrome/browser/ui/autofill/cells/storage_switch_item.h"
#import "ios/chrome/browser/ui/collection_view/cells/MDCCollectionViewCell+Chrome.h"
#import "ios/chrome/browser/ui/collection_view/cells/collection_view_account_item.h"
#import "ios/chrome/browser/ui/collection_view/cells/collection_view_detail_item.h"
#import "ios/chrome/browser/ui/collection_view/cells/collection_view_footer_item.h"
#import "ios/chrome/browser/ui/collection_view/cells/collection_view_switch_item.h"
#import "ios/chrome/browser/ui/collection_view/cells/collection_view_text_item.h"
#import "ios/chrome/browser/ui/collection_view/collection_view_model.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_article_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_footer_item.h"
#import "ios/chrome/browser/ui/icons/chrome_icon.h"
#import "ios/chrome/browser/ui/settings/cells/account_signin_item.h"
#import "ios/chrome/browser/ui/settings/cells/autofill_data_item.h"
#import "ios/chrome/browser/ui/settings/cells/autofill_edit_item.h"
#import "ios/chrome/browser/ui/settings/cells/native_app_item.h"
#import "ios/chrome/browser/ui/settings/cells/sync_switch_item.h"
#import "ios/chrome/browser/ui/settings/cells/text_and_error_item.h"
#import "ios/chrome/browser/ui/uikit_ui_util.h"
#import "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#import "ios/public/provider/chrome/browser/signin/signin_resources_provider.h"
#import "ios/third_party/material_components_ios/src/components/CollectionCells/src/MaterialCollectionCells.h"
#import "ios/third_party/material_components_ios/src/components/Palettes/src/MaterialPalettes.h"
#import "ios/third_party/material_components_ios/src/components/Typography/src/MaterialTypography.h"

namespace {

typedef NS_ENUM(NSInteger, SectionIdentifier) {
  SectionIdentifierTextCell = kSectionIdentifierEnumZero,
  SectionIdentifierDetailCell,
  SectionIdentifierSwitchCell,
  SectionIdentifierNativeAppCell,
  SectionIdentifierAutofill,
  SectionIdentifierPayments,
  SectionIdentifierAccountCell,
  SectionIdentifierAccountControlCell,
  SectionIdentifierFooters,
  SectionIdentifierContentSuggestionsCell,
};

typedef NS_ENUM(NSInteger, ItemType) {
  ItemTypeTextCheckmark = kItemTypeEnumZero,
  ItemTypeTextDetail,
  ItemTypeText,
  ItemTypeTextError,
  ItemTypeDetailBasic,
  ItemTypeDetailLeftMedium,
  ItemTypeDetailRightMedium,
  ItemTypeDetailLeftLong,
  ItemTypeDetailRightLong,
  ItemTypeDetailBothLong,
  ItemTypeSwitchBasic,
  ItemTypeSwitchDynamicHeight,
  ItemTypeSwitchSync,
  ItemTypeHeader,
  ItemTypeAccountDetail,
  ItemTypeAccountCheckMark,
  ItemTypeAccountSignIn,
  ItemTypeColdStateSigninPromo,
  ItemTypeWarmStateSigninPromo,
  ItemTypeApp,
  ItemTypePaymentsSingleLine,
  ItemTypePaymentsDynamicHeight,
  ItemTypeAutofillDynamicHeight,
  ItemTypeAutofillCVC,
  ItemTypeAutofillStatus,
  ItemTypeAutofillStorageSwitch,
  ItemTypeAccountControlDynamicHeight,
  ItemTypeFooter,
  ItemTypeContentSuggestions,
};

// Image fixed horizontal size.
const CGFloat kHorizontalImageFixedSize = 40;

}  // namespace

@implementation MaterialCellCatalogViewController {
  base::scoped_nsobject<SigninPromoViewMediator> _coldStateMediator;
  base::scoped_nsobject<SigninPromoViewMediator> _warmStateMediator;
}

- (instancetype)init {
  self = [super initWithStyle:CollectionViewControllerStyleAppBar];
  if (self) {
    [self loadModel];
  }
  return self;
}

- (void)loadModel {
  [super loadModel];
  CollectionViewModel* model = self.collectionViewModel;

  // Text cells.
  [model addSectionWithIdentifier:SectionIdentifierTextCell];

  CollectionViewTextItem* textHeader = [
      [[CollectionViewTextItem alloc] initWithType:ItemTypeHeader] autorelease];
  textHeader.text = @"CollectionViewTextCell";
  textHeader.textFont = [MDCTypography body2Font];
  textHeader.textColor = [[MDCPalette greyPalette] tint500];
  [model setHeader:textHeader
      forSectionWithIdentifier:SectionIdentifierTextCell];

  CollectionViewTextItem* textCell = [[[CollectionViewTextItem alloc]
      initWithType:ItemTypeTextCheckmark] autorelease];
  textCell.text = @"Text cell 1";
  textCell.accessoryType = MDCCollectionViewCellAccessoryCheckmark;
  [model addItem:textCell toSectionWithIdentifier:SectionIdentifierTextCell];
  CollectionViewTextItem* textCell2 = [[[CollectionViewTextItem alloc]
      initWithType:ItemTypeTextDetail] autorelease];
  textCell2.text =
      @"Text cell with text that is so long it must truncate at some point";
  textCell2.accessoryType = MDCCollectionViewCellAccessoryDetailButton;
  [model addItem:textCell2 toSectionWithIdentifier:SectionIdentifierTextCell];
  CollectionViewTextItem* textCell3 =
      [[[CollectionViewTextItem alloc] initWithType:ItemTypeText] autorelease];
  textCell3.text = @"Truncated text cell with three lines:";
  textCell3.detailText = @"One title line and two detail lines, so it should "
                         @"wrap nicely at some point.";
  textCell3.numberOfDetailTextLines = 0;
  [model addItem:textCell3 toSectionWithIdentifier:SectionIdentifierTextCell];
  CollectionViewTextItem* smallTextCell =
      [[[CollectionViewTextItem alloc] initWithType:ItemTypeText] autorelease];
  smallTextCell.text = @"Text cell with small font but height of 48.";
  smallTextCell.textFont = [smallTextCell.textFont fontWithSize:8];
  [model addItem:smallTextCell
      toSectionWithIdentifier:SectionIdentifierTextCell];

  // Text and Error cell.
  TextAndErrorItem* textAndErrorItem =
      [[[TextAndErrorItem alloc] initWithType:ItemTypeTextError] autorelease];
  textAndErrorItem.text = @"Text and Error cell";
  textAndErrorItem.shouldDisplayError = YES;
  textAndErrorItem.accessoryType =
      MDCCollectionViewCellAccessoryDisclosureIndicator;
  [model addItem:textAndErrorItem
      toSectionWithIdentifier:SectionIdentifierTextCell];

  // Detail cells.
  [model addSectionWithIdentifier:SectionIdentifierDetailCell];
  CollectionViewDetailItem* detailBasic = [[[CollectionViewDetailItem alloc]
      initWithType:ItemTypeDetailBasic] autorelease];
  detailBasic.text = @"Preload Webpages";
  detailBasic.detailText = @"Only on Wi-Fi";
  detailBasic.accessoryType = MDCCollectionViewCellAccessoryDisclosureIndicator;
  [model addItem:detailBasic
      toSectionWithIdentifier:SectionIdentifierDetailCell];
  CollectionViewDetailItem* detailMediumLeft =
      [[[CollectionViewDetailItem alloc] initWithType:ItemTypeDetailLeftMedium]
          autorelease];
  detailMediumLeft.text = @"A long string but it should fit";
  detailMediumLeft.detailText = @"Detail";
  [model addItem:detailMediumLeft
      toSectionWithIdentifier:SectionIdentifierDetailCell];
  CollectionViewDetailItem* detailMediumRight =
      [[[CollectionViewDetailItem alloc] initWithType:ItemTypeDetailRightMedium]
          autorelease];
  detailMediumRight.text = @"Main";
  detailMediumRight.detailText = @"A long string but it should fit";
  [model addItem:detailMediumRight
      toSectionWithIdentifier:SectionIdentifierDetailCell];
  CollectionViewDetailItem* detailLongLeft = [[[CollectionViewDetailItem alloc]
      initWithType:ItemTypeDetailLeftLong] autorelease];
  detailLongLeft.text =
      @"This is a very long main text that is intended to overflow";
  detailLongLeft.detailText = @"Detail Text";
  [model addItem:detailLongLeft
      toSectionWithIdentifier:SectionIdentifierDetailCell];
  CollectionViewDetailItem* detailLongRight = [[[CollectionViewDetailItem alloc]
      initWithType:ItemTypeDetailRightLong] autorelease];
  detailLongRight.text = @"Main Text";
  detailLongRight.detailText =
      @"This is a very long detail text that is intended to overflow";
  [model addItem:detailLongRight
      toSectionWithIdentifier:SectionIdentifierDetailCell];
  CollectionViewDetailItem* detailLongBoth = [[[CollectionViewDetailItem alloc]
      initWithType:ItemTypeDetailBothLong] autorelease];
  detailLongBoth.text =
      @"This is a very long main text that is intended to overflow";
  detailLongBoth.detailText =
      @"This is a very long detail text that is intended to overflow";
  [model addItem:detailLongBoth
      toSectionWithIdentifier:SectionIdentifierDetailCell];

  // Switch cells.
  [model addSectionWithIdentifier:SectionIdentifierSwitchCell];
  [model addItem:[self basicSwitchItem]
      toSectionWithIdentifier:SectionIdentifierSwitchCell];
  [model addItem:[self longTextSwitchItem]
      toSectionWithIdentifier:SectionIdentifierSwitchCell];
  [model addItem:[self syncSwitchItem]
      toSectionWithIdentifier:SectionIdentifierSwitchCell];

  // Native app cells.
  [model addSectionWithIdentifier:SectionIdentifierNativeAppCell];
  NativeAppItem* fooApp =
      [[[NativeAppItem alloc] initWithType:ItemTypeApp] autorelease];
  fooApp.name = @"App Foo";
  fooApp.state = NativeAppItemSwitchOff;
  [model addItem:fooApp toSectionWithIdentifier:SectionIdentifierNativeAppCell];
  NativeAppItem* barApp =
      [[[NativeAppItem alloc] initWithType:ItemTypeApp] autorelease];
  barApp.name = @"App Bar";
  barApp.state = NativeAppItemSwitchOn;
  [model addItem:barApp toSectionWithIdentifier:SectionIdentifierNativeAppCell];
  NativeAppItem* bazApp =
      [[[NativeAppItem alloc] initWithType:ItemTypeApp] autorelease];
  bazApp.name = @"App Baz Qux Bla Bug Lorem ipsum dolor sit amet";
  bazApp.state = NativeAppItemInstall;
  [model addItem:bazApp toSectionWithIdentifier:SectionIdentifierNativeAppCell];

  // Autofill cells.
  [model addSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self autofillItemWithMainAndTrailingText]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self autofillItemWithLeadingTextOnly]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self autofillItemWithAllText]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self autofillEditItem]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self autofillEditItemWithIcon]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self cvcItem]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self cvcItemWithDate]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self cvcItemWithError]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self statusItemVerifying]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self statusItemVerified]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self statusItemError]
      toSectionWithIdentifier:SectionIdentifierAutofill];
  [model addItem:[self storageSwitchItem]
      toSectionWithIdentifier:SectionIdentifierAutofill];

  // Payments cells.
  [model addSectionWithIdentifier:SectionIdentifierPayments];
  [model addItem:[self paymentsItemWithWrappingTextandOptionalImage]
      toSectionWithIdentifier:SectionIdentifierPayments];
  PriceItem* priceItem1 =
      [[[PriceItem alloc] initWithType:ItemTypePaymentsSingleLine] autorelease];
  priceItem1.item = @"Total";
  priceItem1.notification = @"Updated";
  priceItem1.price = @"USD $100.00";
  [model addItem:priceItem1 toSectionWithIdentifier:SectionIdentifierPayments];
  PriceItem* priceItem2 =
      [[[PriceItem alloc] initWithType:ItemTypePaymentsSingleLine] autorelease];
  priceItem2.item = @"Price label is long and should get clipped";
  priceItem2.notification = @"Updated";
  priceItem2.price = @"USD $1,000,000.00";
  [model addItem:priceItem2 toSectionWithIdentifier:SectionIdentifierPayments];
  PriceItem* priceItem3 =
      [[[PriceItem alloc] initWithType:ItemTypePaymentsSingleLine] autorelease];
  priceItem3.item = @"Price label is long and should get clipped";
  priceItem3.notification = @"Should get clipped too";
  priceItem3.price = @"USD $1,000,000.00";
  [model addItem:priceItem3 toSectionWithIdentifier:SectionIdentifierPayments];
  PriceItem* priceItem4 =
      [[[PriceItem alloc] initWithType:ItemTypePaymentsSingleLine] autorelease];
  priceItem4.item = @"Price label is long and should get clipped";
  priceItem4.notification = @"Should get clipped too";
  priceItem4.price = @"USD $1,000,000,000.00";
  [model addItem:priceItem4 toSectionWithIdentifier:SectionIdentifierPayments];

  AutofillProfileItem* profileItem1 = [[[AutofillProfileItem alloc]
      initWithType:ItemTypePaymentsDynamicHeight] autorelease];
  profileItem1.name = @"Profile Name gets wrapped if it's too long";
  profileItem1.address = @"Profile Address also gets wrapped if it's too long";
  profileItem1.phoneNumber = @"123-456-7890";
  profileItem1.email = @"foo@bar.com";
  profileItem1.notification = @"Some fields are missing";
  [model addItem:profileItem1
      toSectionWithIdentifier:SectionIdentifierPayments];
  AutofillProfileItem* profileItem2 = [[[AutofillProfileItem alloc]
      initWithType:ItemTypePaymentsDynamicHeight] autorelease];
  profileItem1.name = @"All fields are optional";
  profileItem2.phoneNumber = @"123-456-7890";
  profileItem2.notification = @"Some fields are missing";
  [model addItem:profileItem2
      toSectionWithIdentifier:SectionIdentifierPayments];
  AutofillProfileItem* profileItem3 = [[[AutofillProfileItem alloc]
      initWithType:ItemTypePaymentsDynamicHeight] autorelease];
  profileItem3.address = @"All fields are optional";
  profileItem3.email = @"foo@bar.com";
  [model addItem:profileItem3
      toSectionWithIdentifier:SectionIdentifierPayments];

  // Account cells.
  [model addSectionWithIdentifier:SectionIdentifierAccountCell];
  [model addItem:[self accountItemDetailWithError]
      toSectionWithIdentifier:SectionIdentifierAccountCell];
  [model addItem:[self accountItemCheckMark]
      toSectionWithIdentifier:SectionIdentifierAccountCell];
  [model addItem:[self accountSignInItem]
      toSectionWithIdentifier:SectionIdentifierAccountCell];
  [model addItem:[self coldStateSigninPromoItem]
      toSectionWithIdentifier:SectionIdentifierAccountCell];
  [model addItem:[self warmStateSigninPromoItem]
      toSectionWithIdentifier:SectionIdentifierAccountCell];

  // Account control cells.
  [model addSectionWithIdentifier:SectionIdentifierAccountControlCell];
  [model addItem:[self accountControlItem]
      toSectionWithIdentifier:SectionIdentifierAccountControlCell];
  [model addItem:[self accountControlItemWithExtraLongText]
      toSectionWithIdentifier:SectionIdentifierAccountControlCell];

  // Content Suggestions cells.
  [model addSectionWithIdentifier:SectionIdentifierContentSuggestionsCell];
  [model addItem:[self contentSuggestionsArticleItem]
      toSectionWithIdentifier:SectionIdentifierContentSuggestionsCell];
  [model addItem:[self contentSuggestionsFooterItem]
      toSectionWithIdentifier:SectionIdentifierContentSuggestionsCell];

  // Footers.
  [model addSectionWithIdentifier:SectionIdentifierFooters];
  [model addItem:[self shortFooterItem]
      toSectionWithIdentifier:SectionIdentifierFooters];
  [model addItem:[self longFooterItem]
      toSectionWithIdentifier:SectionIdentifierFooters];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = @"Cell Catalog";

  // Customize collection view settings.
  self.styler.cellStyle = MDCCollectionViewCellStyleCard;
}

#pragma mark MDCCollectionViewStylingDelegate

- (CGFloat)collectionView:(nonnull UICollectionView*)collectionView
    cellHeightAtIndexPath:(nonnull NSIndexPath*)indexPath {
  CollectionViewItem* item =
      [self.collectionViewModel itemAtIndexPath:indexPath];
  switch (item.type) {
    case ItemTypeContentSuggestions:
    case ItemTypeFooter:
    case ItemTypeSwitchDynamicHeight:
    case ItemTypeSwitchSync:
    case ItemTypeAccountControlDynamicHeight:
    case ItemTypeTextCheckmark:
    case ItemTypeTextDetail:
    case ItemTypeText:
    case ItemTypeTextError:
    case ItemTypeAutofillCVC:
    case ItemTypeAutofillStatus:
    case ItemTypeAutofillStorageSwitch:
    case ItemTypePaymentsDynamicHeight:
    case ItemTypeAutofillDynamicHeight:
    case ItemTypeColdStateSigninPromo:
    case ItemTypeWarmStateSigninPromo:
      return [MDCCollectionViewCell
          cr_preferredHeightForWidth:CGRectGetWidth(collectionView.bounds)
                             forItem:item];
    case ItemTypeApp:
      return MDCCellDefaultOneLineWithAvatarHeight;
    case ItemTypeAccountDetail:
      return MDCCellDefaultTwoLineHeight;
    case ItemTypeAccountCheckMark:
      return MDCCellDefaultTwoLineHeight;
    case ItemTypeAccountSignIn:
      return MDCCellDefaultThreeLineHeight;
    default:
      return MDCCellDefaultOneLineHeight;
  }
}

- (MDCCollectionViewCellStyle)collectionView:(UICollectionView*)collectionView
                         cellStyleForSection:(NSInteger)section {
  NSInteger sectionIdentifier =
      [self.collectionViewModel sectionIdentifierForSection:section];
  switch (sectionIdentifier) {
    case SectionIdentifierFooters:
      // Display the Learn More footer in the default style with no "card" UI
      // and no section padding.
      return MDCCollectionViewCellStyleDefault;
    default:
      return self.styler.cellStyle;
  }
}

- (BOOL)collectionView:(UICollectionView*)collectionView
    shouldHideItemBackgroundAtIndexPath:(NSIndexPath*)indexPath {
  NSInteger sectionIdentifier =
      [self.collectionViewModel sectionIdentifierForSection:indexPath.section];
  switch (sectionIdentifier) {
    case SectionIdentifierFooters:
      // Display the Learn More footer without any background image or
      // shadowing.
      return YES;
    default:
      return NO;
  }
}

- (BOOL)collectionView:(nonnull UICollectionView*)collectionView
    hidesInkViewAtIndexPath:(nonnull NSIndexPath*)indexPath {
  NSInteger sectionIdentifier =
      [self.collectionViewModel sectionIdentifierForSection:indexPath.section];
  if (sectionIdentifier == SectionIdentifierFooters)
    return YES;
  CollectionViewItem* item =
      [self.collectionViewModel itemAtIndexPath:indexPath];
  switch (item.type) {
    case ItemTypeApp:
    case ItemTypeAutofillStorageSwitch:
    case ItemTypeColdStateSigninPromo:
    case ItemTypeSwitchBasic:
    case ItemTypeSwitchDynamicHeight:
    case ItemTypeSwitchSync:
    case ItemTypeWarmStateSigninPromo:
      return YES;
    default:
      return NO;
  }
}

#pragma mark Item models

- (CollectionViewItem*)accountItemDetailWithError {
  CollectionViewAccountItem* accountItemDetail =
      [[[CollectionViewAccountItem alloc] initWithType:ItemTypeAccountDetail]
          autorelease];
  accountItemDetail.image = [UIImage imageNamed:@"default_avatar"];
  accountItemDetail.text = @"Account User Name";
  accountItemDetail.detailText =
      @"Syncing to AccountUserNameAccount@example.com";
  accountItemDetail.accessoryType =
      MDCCollectionViewCellAccessoryDisclosureIndicator;
  accountItemDetail.shouldDisplayError = YES;
  return accountItemDetail;
}

- (CollectionViewItem*)accountItemCheckMark {
  CollectionViewAccountItem* accountItemCheckMark =
      [[[CollectionViewAccountItem alloc] initWithType:ItemTypeAccountCheckMark]
          autorelease];
  accountItemCheckMark.image = [UIImage imageNamed:@"default_avatar"];
  accountItemCheckMark.text = @"Lorem ipsum dolor sit amet, consectetur "
                              @"adipiscing elit, sed do eiusmod tempor "
                              @"incididunt ut labore et dolore magna aliqua.";
  accountItemCheckMark.detailText =
      @"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do "
      @"eiusmod tempor incididunt ut labore et dolore magna aliqua.";
  accountItemCheckMark.accessoryType = MDCCollectionViewCellAccessoryCheckmark;
  return accountItemCheckMark;
}

- (CollectionViewItem*)accountSignInItem {
  AccountSignInItem* accountSignInItem = [[[AccountSignInItem alloc]
      initWithType:ItemTypeAccountSignIn] autorelease];
  accountSignInItem.image =
      CircularImageFromImage(ios::GetChromeBrowserProvider()
                                 ->GetSigninResourcesProvider()
                                 ->GetDefaultAvatar(),
                             kHorizontalImageFixedSize);
  return accountSignInItem;
}

- (CollectionViewItem*)coldStateSigninPromoItem {
  _coldStateMediator.reset([[SigninPromoViewMediator alloc] init]);
  return
      [[[SigninPromoItem alloc] initWithType:ItemTypeWarmStateSigninPromo
                                configurator:_coldStateMediator] autorelease];
}

- (CollectionViewItem*)warmStateSigninPromoItem {
  _warmStateMediator.reset([[SigninPromoViewMediator alloc] init]);
  _warmStateMediator.get().userFullName = @"John Doe";
  _warmStateMediator.get().userEmail = @"johndoe@example.com";
  return
      [[[SigninPromoItem alloc] initWithType:ItemTypeColdStateSigninPromo
                                configurator:_warmStateMediator] autorelease];
}

- (CollectionViewItem*)accountControlItem {
  AccountControlItem* item = [[[AccountControlItem alloc]
      initWithType:ItemTypeAccountControlDynamicHeight] autorelease];
  item.image = [UIImage imageNamed:@"settings_sync"];
  item.text = @"Account Sync Settings";
  item.detailText = @"Detail text";
  item.accessoryType = MDCCollectionViewCellAccessoryDisclosureIndicator;
  return item;
}

- (CollectionViewItem*)accountControlItemWithExtraLongText {
  AccountControlItem* item = [[[AccountControlItem alloc]
      initWithType:ItemTypeAccountControlDynamicHeight] autorelease];
  item.image = [ChromeIcon infoIcon];
  item.text = @"Account Control Settings";
  item.detailText =
      @"Detail text detail text detail text detail text detail text.";
  item.accessoryType = MDCCollectionViewCellAccessoryDisclosureIndicator;
  return item;
}

#pragma mark Private

- (CollectionViewItem*)basicSwitchItem {
  CollectionViewSwitchItem* item = [[[CollectionViewSwitchItem alloc]
      initWithType:ItemTypeSwitchBasic] autorelease];
  item.text = @"Enable awesomeness.";
  item.on = YES;
  return item;
}

- (CollectionViewItem*)longTextSwitchItem {
  CollectionViewSwitchItem* item = [[[CollectionViewSwitchItem alloc]
      initWithType:ItemTypeSwitchDynamicHeight] autorelease];
  item.text = @"Enable awesomeness. This is a very long text that is intended "
              @"to overflow.";
  item.on = YES;
  return item;
}

- (CollectionViewItem*)syncSwitchItem {
  SyncSwitchItem* item =
      [[[SyncSwitchItem alloc] initWithType:ItemTypeSwitchSync] autorelease];
  item.text = @"Cell used in Sync Settings";
  item.detailText =
      @"This is a very long text that is intended to overflow to two lines.";
  item.on = NO;
  return item;
}

- (CollectionViewItem*)paymentsItemWithWrappingTextandOptionalImage {
  PaymentsTextItem* item = [[[PaymentsTextItem alloc]
      initWithType:ItemTypePaymentsDynamicHeight] autorelease];
  item.text = @"If you want to display a long text that wraps to the next line "
              @"and may need to feature an image this is the cell to use.";
  item.image = [UIImage imageNamed:@"app_icon_placeholder"];
  return item;
}

- (CollectionViewItem*)autofillItemWithMainAndTrailingText {
  AutofillDataItem* item = [[[AutofillDataItem alloc]
      initWithType:ItemTypeAutofillDynamicHeight] autorelease];
  item.text = @"Main Text";
  item.trailingDetailText = @"Trailing Detail Text";
  item.accessoryType = MDCCollectionViewCellAccessoryNone;
  return item;
}

- (CollectionViewItem*)autofillItemWithLeadingTextOnly {
  AutofillDataItem* item = [[[AutofillDataItem alloc]
      initWithType:ItemTypeAutofillDynamicHeight] autorelease];
  item.text = @"Main Text";
  item.leadingDetailText = @"Leading Detail Text";
  item.accessoryType = MDCCollectionViewCellAccessoryDisclosureIndicator;
  return item;
}

- (CollectionViewItem*)autofillItemWithAllText {
  AutofillDataItem* item = [[[AutofillDataItem alloc]
      initWithType:ItemTypeAutofillDynamicHeight] autorelease];
  item.text = @"Main Text";
  item.leadingDetailText = @"Leading Detail Text";
  item.trailingDetailText = @"Trailing Detail Text";
  item.accessoryType = MDCCollectionViewCellAccessoryDisclosureIndicator;
  return item;
}

- (CollectionViewItem*)autofillEditItem {
  AutofillEditItem* item = [[[AutofillEditItem alloc]
      initWithType:ItemTypeAutofillDynamicHeight] autorelease];
  item.textFieldName = @"Required Card Number";
  item.textFieldValue = @"4111111111111111";
  item.textFieldEnabled = YES;
  item.required = YES;
  return item;
}

- (CollectionViewItem*)autofillEditItemWithIcon {
  AutofillEditItem* item = [[[AutofillEditItem alloc]
      initWithType:ItemTypeAutofillDynamicHeight] autorelease];
  item.textFieldName = @"Card Number";
  item.textFieldValue = @"4111111111111111";
  item.textFieldEnabled = YES;
  int resourceID =
      autofill::data_util::GetPaymentRequestData(autofill::kVisaCard)
          .icon_resource_id;
  item.cardTypeIcon =
      ResizeImage(NativeImage(resourceID), CGSizeMake(30.0, 30.0),
                  ProjectionMode::kAspectFillNoClipping);
  return item;
}

- (CollectionViewItem*)cvcItem {
  CVCItem* item =
      [[[CVCItem alloc] initWithType:ItemTypeAutofillCVC] autorelease];
  item.instructionsText =
      @"This is a long text explaining to enter card details and what "
      @"will happen afterwards.";
  item.CVCImageResourceID = IDR_CREDIT_CARD_CVC_HINT;
  return item;
}

- (CollectionViewItem*)cvcItemWithDate {
  CVCItem* item =
      [[[CVCItem alloc] initWithType:ItemTypeAutofillCVC] autorelease];
  item.instructionsText =
      @"This is a long text explaining to enter card details and what "
      @"will happen afterwards.";
  item.CVCImageResourceID = IDR_CREDIT_CARD_CVC_HINT;
  item.showDateInput = YES;
  return item;
}

- (CollectionViewItem*)cvcItemWithError {
  CVCItem* item =
      [[[CVCItem alloc] initWithType:ItemTypeAutofillCVC] autorelease];
  item.instructionsText =
      @"This is a long text explaining to enter card details and what "
      @"will happen afterwards. Is this long enough to span 3 lines?";
  item.errorMessage = @"Some error";
  item.CVCImageResourceID = IDR_CREDIT_CARD_CVC_HINT_AMEX;
  item.showNewCardButton = YES;
  item.showCVCInputError = YES;
  return item;
}

- (CollectionViewItem*)statusItemVerifying {
  StatusItem* item =
      [[[StatusItem alloc] initWithType:ItemTypeAutofillStatus] autorelease];
  item.text = @"Verifying…";
  return item;
}

- (CollectionViewItem*)statusItemVerified {
  StatusItem* item =
      [[[StatusItem alloc] initWithType:ItemTypeAutofillStatus] autorelease];
  item.state = StatusItemState::VERIFIED;
  item.text = @"Verified!";
  return item;
}

- (CollectionViewItem*)statusItemError {
  StatusItem* item =
      [[[StatusItem alloc] initWithType:ItemTypeAutofillStatus] autorelease];
  item.state = StatusItemState::ERROR;
  item.text = @"There was a really long error. We can't tell you more, but we "
              @"will still display this long string.";
  return item;
}

- (CollectionViewItem*)storageSwitchItem {
  StorageSwitchItem* item = [[[StorageSwitchItem alloc]
      initWithType:ItemTypeAutofillStorageSwitch] autorelease];
  item.on = YES;
  return item;
}

- (CollectionViewFooterItem*)shortFooterItem {
  CollectionViewFooterItem* footerItem = [[[CollectionViewFooterItem alloc]
      initWithType:ItemTypeFooter] autorelease];
  footerItem.text = @"Hello";
  return footerItem;
}

- (CollectionViewFooterItem*)longFooterItem {
  CollectionViewFooterItem* footerItem = [[[CollectionViewFooterItem alloc]
      initWithType:ItemTypeFooter] autorelease];
  footerItem.text = @"Hello Hello Hello Hello Hello Hello Hello Hello Hello "
                    @"Hello Hello Hello Hello Hello Hello Hello Hello Hello "
                    @"Hello Hello Hello Hello Hello Hello Hello Hello Hello ";
  footerItem.image = [UIImage imageNamed:@"app_icon_placeholder"];
  return footerItem;
}

- (ContentSuggestionsArticleItem*)contentSuggestionsArticleItem {
  ContentSuggestionsArticleItem* articleItem =
      [[ContentSuggestionsArticleItem alloc]
          initWithType:ItemTypeContentSuggestions
                 title:@"This is an incredible article, you should read it!"
              subtitle:@"Really, this is the best article I have ever seen, it "
                       @"is mandatory to read it! It describes how to write "
                       @"the best article."
              delegate:nil
                   url:GURL()];
  articleItem.publisher = @"Top Publisher.com";
  return articleItem;
}

- (ContentSuggestionsFooterItem*)contentSuggestionsFooterItem {
  ContentSuggestionsFooterItem* footerItem =
      [[ContentSuggestionsFooterItem alloc]
          initWithType:ItemTypeContentSuggestions
                 title:@"Footer title"
                 block:nil];
  return footerItem;
}

@end
