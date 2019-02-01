// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/signin/identity_test_environment_chrome_browser_state_adaptor.h"

#include <memory>
#include <utility>

#include "base/bind.h"
#include "components/signin/core/browser/fake_profile_oauth2_token_service.h"
#include "components/signin/ios/browser/profile_oauth2_token_service_ios_delegate.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/signin/account_fetcher_service_factory.h"
#include "ios/chrome/browser/signin/account_tracker_service_factory.h"
#include "ios/chrome/browser/signin/fake_gaia_cookie_manager_service_builder.h"
#include "ios/chrome/browser/signin/gaia_cookie_manager_service_factory.h"
#include "ios/chrome/browser/signin/identity_manager_factory.h"
#include "ios/chrome/browser/signin/profile_oauth2_token_service_factory.h"
#include "ios/chrome/browser/signin/profile_oauth2_token_service_ios_provider_impl.h"
#include "ios/chrome/browser/signin/signin_client_factory.h"
#include "ios/chrome/browser/signin/signin_manager_factory.h"

namespace {

std::unique_ptr<KeyedService> BuildFakeSigninManager(
    web::BrowserState* browser_state) {
  ios::ChromeBrowserState* chrome_browser_state =
      ios::ChromeBrowserState::FromBrowserState(browser_state);
  std::unique_ptr<SigninManager> manager(new FakeSigninManager(
      SigninClientFactory::GetForBrowserState(chrome_browser_state),
      ProfileOAuth2TokenServiceFactory::GetForBrowserState(
          chrome_browser_state),
      ios::AccountTrackerServiceFactory::GetForBrowserState(
          chrome_browser_state),
      ios::GaiaCookieManagerServiceFactory::GetForBrowserState(
          chrome_browser_state)));
  manager->Initialize(nullptr);
  ios::SigninManagerFactory::GetInstance()
      ->NotifyObserversOfSigninManagerCreationForTesting(manager.get());
  return manager;
}

std::unique_ptr<KeyedService> BuildFakeOAuth2TokenService(
    web::BrowserState* context) {
  ios::ChromeBrowserState* browser_state =
      ios::ChromeBrowserState::FromBrowserState(context);
  std::unique_ptr<OAuth2TokenServiceDelegate> delegate =
      std::make_unique<ProfileOAuth2TokenServiceIOSDelegate>(
          SigninClientFactory::GetForBrowserState(browser_state),
          std::make_unique<ProfileOAuth2TokenServiceIOSProviderImpl>(),
          ios::AccountTrackerServiceFactory::GetForBrowserState(browser_state));
  return std::make_unique<FakeProfileOAuth2TokenService>(
      browser_state->GetPrefs(), std::move(delegate));
}

std::unique_ptr<KeyedService> BuildFakeAccountFetcherService(
    web::BrowserState* context) {
  ios::ChromeBrowserState* browser_state =
      ios::ChromeBrowserState::FromBrowserState(context);
  auto account_fetcher_service = std::make_unique<FakeAccountFetcherService>();
  account_fetcher_service->Initialize(
      SigninClientFactory::GetForBrowserState(browser_state),
      ProfileOAuth2TokenServiceFactory::GetForBrowserState(browser_state),
      ios::AccountTrackerServiceFactory::GetForBrowserState(browser_state),
      std::make_unique<TestImageDecoder>());
  return account_fetcher_service;
}

TestChromeBrowserState::TestingFactories GetIdentityTestEnvironmentFactories() {
  return {{ios::AccountFetcherServiceFactory::GetInstance(),
           base::BindRepeating(&BuildFakeAccountFetcherService)},
          {ios::GaiaCookieManagerServiceFactory::GetInstance(),
           base::BindRepeating(&BuildFakeGaiaCookieManagerService)},
          {ProfileOAuth2TokenServiceFactory::GetInstance(),
           base::BindRepeating(&BuildFakeOAuth2TokenService)},
          {ios::SigninManagerFactory::GetInstance(),
           base::BindRepeating(&BuildFakeSigninManager)}};
}

}  // namespace

// static
std::unique_ptr<TestChromeBrowserState>
IdentityTestEnvironmentChromeBrowserStateAdaptor::
    CreateChromeBrowserStateForIdentityTestEnvironment() {
  return CreateChromeBrowserStateForIdentityTestEnvironment(
      TestChromeBrowserState::TestingFactories());
}

// static
std::unique_ptr<TestChromeBrowserState>
IdentityTestEnvironmentChromeBrowserStateAdaptor::
    CreateChromeBrowserStateForIdentityTestEnvironment(
        const TestChromeBrowserState::TestingFactories& input_factories) {
  TestChromeBrowserState::Builder builder;

  for (auto& input_factory : input_factories) {
    builder.AddTestingFactory(input_factory.first, input_factory.second);
  }

  return CreateChromeBrowserStateForIdentityTestEnvironment(builder);
}

// static
std::unique_ptr<TestChromeBrowserState>
IdentityTestEnvironmentChromeBrowserStateAdaptor::
    CreateChromeBrowserStateForIdentityTestEnvironment(
        TestChromeBrowserState::Builder& builder) {
  for (auto& identity_factory : GetIdentityTestEnvironmentFactories()) {
    builder.AddTestingFactory(identity_factory.first, identity_factory.second);
  }

  return builder.Build();
}

// static
void IdentityTestEnvironmentChromeBrowserStateAdaptor::
    SetIdentityTestEnvironmentFactoriesOnBrowserContext(
        TestChromeBrowserState* browser_state) {
  for (const auto& factory_pair : GetIdentityTestEnvironmentFactories()) {
    factory_pair.first->SetTestingFactory(browser_state, factory_pair.second);
  }
}

// static
void IdentityTestEnvironmentChromeBrowserStateAdaptor::
    AppendIdentityTestEnvironmentFactories(
        TestChromeBrowserState::TestingFactories* factories_to_append_to) {
  TestChromeBrowserState::TestingFactories identity_factories =
      GetIdentityTestEnvironmentFactories();
  factories_to_append_to->insert(factories_to_append_to->end(),
                                 identity_factories.begin(),
                                 identity_factories.end());
}

IdentityTestEnvironmentChromeBrowserStateAdaptor::
    IdentityTestEnvironmentChromeBrowserStateAdaptor(
        ios::ChromeBrowserState* browser_state)
    : identity_test_env_(
          ios::AccountTrackerServiceFactory::GetForBrowserState(browser_state),
          static_cast<FakeAccountFetcherService*>(
              ios::AccountFetcherServiceFactory::GetForBrowserState(
                  browser_state)),
          static_cast<FakeProfileOAuth2TokenService*>(
              ProfileOAuth2TokenServiceFactory::GetForBrowserState(
                  browser_state)),
          static_cast<FakeSigninManager*>(
              ios::SigninManagerFactory::GetForBrowserState(browser_state)),
          ios::GaiaCookieManagerServiceFactory::GetForBrowserState(
              browser_state),
          IdentityManagerFactory::GetForBrowserState(browser_state)) {}
