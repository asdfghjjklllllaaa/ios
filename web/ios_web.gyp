# Copyright 2014 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

{
  'variables': {
    'chromium_code': 1,
   },
  'targets': [
    {
      'target_name': 'ios_web_app',
      'type': 'static_library',
      'include_dirs': [
        '../..',
      ],
      'dependencies': [
        'ios_web',
        'ios_web_thread',
        '../../base/base.gyp:base',
        '../../base/base.gyp:base_i18n',
        '../../crypto/crypto.gyp:crypto',
        '../../net/net.gyp:net',
        '../../ui/base/ui_base.gyp:ui_base',
        '../../ui/gfx/gfx.gyp:gfx',
        '../../ui/gfx/gfx.gyp:gfx_geometry',
      ],
      'sources': [
        'app/web_main.mm',
        'app/web_main_loop.h',
        'app/web_main_loop.mm',
        'app/web_main_runner.h',
        'app/web_main_runner.mm',
        'public/app/web_main.h',
        'public/app/web_main_delegate.h',
        'public/app/web_main_parts.h',
        'public/app/web_main_parts.mm',
      ],
    },
    # Note: any embedder using ios_web will for now need to include either
    # ios_web_thread (any new embedder) or ios_web_content_thread_shim (Chrome).
    # This will become unnecessary once Chrome switches to using ios_web_thread,
    # at which point that will be folded into this target.
    {
      # GN version: //ios/web
      'target_name': 'ios_web',
      'type': 'static_library',
      'include_dirs': [
        '../..',
      ],
      'dependencies': [
        'ios_web_core',
        'js_resources',
        'user_agent',
        '../../base/base.gyp:base',
        '../../components/url_formatter/url_formatter.gyp:url_formatter',
        '../../content/content.gyp:content_browser',
        '../../ios/net/ios_net.gyp:ios_net',
        '../../ios/third_party/blink/blink_html_tokenizer.gyp:blink_html_tokenizer',
        '../../net/net.gyp:net',
        '../../ui/base/ui_base.gyp:ui_base',
        '../../ui/gfx/gfx.gyp:gfx',
        '../../ui/gfx/gfx.gyp:gfx_geometry',
        '../../ui/resources/ui_resources.gyp:ui_resources',
        '../../url/url.gyp:url_lib',
      ],
      'sources': [
        '<(SHARED_INTERMEDIATE_DIR)/ui/resources/grit/webui_resources_map.cc',
        'active_state_manager_impl.h',
        'active_state_manager_impl.mm',
        'alloc_with_zone_interceptor.h',
        'alloc_with_zone_interceptor.mm',
        'browser_state.mm',
        'browser_url_rewriter_impl.cc',
        'browser_url_rewriter_impl.h',
        'browsing_data_managers/crw_browsing_data_manager.h',
        'browsing_data_managers/crw_cookie_browsing_data_manager.h',
        'browsing_data_managers/crw_cookie_browsing_data_manager.mm',
        'browsing_data_partition_impl.h',
        'browsing_data_partition_impl.mm',
        'crw_browsing_data_store.mm',
        'interstitials/html_web_interstitial_impl.h',
        'interstitials/html_web_interstitial_impl.mm',
        'interstitials/native_web_interstitial_impl.h',
        'interstitials/native_web_interstitial_impl.mm',
        'interstitials/web_interstitial_facade_delegate.h',
        'interstitials/web_interstitial_impl.h',
        'interstitials/web_interstitial_impl.mm',
        'load_committed_details.cc',
        'navigation/crw_session_certificate_policy_manager.h',
        'navigation/crw_session_certificate_policy_manager.mm',
        'navigation/crw_session_controller+private_constructors.h',
        'navigation/crw_session_controller.h',
        'navigation/crw_session_controller.mm',
        'navigation/crw_session_entry.h',
        'navigation/crw_session_entry.mm',
        'navigation/navigation_item_facade_delegate.h',
        'navigation/navigation_item_impl.h',
        'navigation/navigation_item_impl.mm',
        'navigation/navigation_manager_delegate.h',
        'navigation/navigation_manager_facade_delegate.h',
        'navigation/navigation_manager_impl.h',
        'navigation/navigation_manager_impl.mm',
        'navigation/nscoder_util.h',
        'navigation/nscoder_util.mm',
        'navigation/time_smoother.cc',
        'navigation/time_smoother.h',
        'navigation/web_load_params.h',
        'navigation/web_load_params.mm',
        'net/cert_policy.cc',
        'net/cert_store_impl.cc',
        'net/cert_store_impl.h',
        'net/cert_verifier_block_adapter.cc',
        'net/cert_verifier_block_adapter.h',
        'net/certificate_policy_cache.cc',
        'net/clients/crw_csp_network_client.h',
        'net/clients/crw_csp_network_client.mm',
        'net/clients/crw_js_injection_network_client.h',
        'net/clients/crw_js_injection_network_client.mm',
        'net/clients/crw_js_injection_network_client_factory.h',
        'net/clients/crw_js_injection_network_client_factory.mm',
        'net/clients/crw_passkit_delegate.h',
        'net/clients/crw_passkit_network_client.h',
        'net/clients/crw_passkit_network_client.mm',
        'net/clients/crw_passkit_network_client_factory.h',
        'net/clients/crw_passkit_network_client_factory.mm',
        'net/clients/crw_redirect_network_client.h',
        'net/clients/crw_redirect_network_client.mm',
        'net/clients/crw_redirect_network_client_factory.h',
        'net/clients/crw_redirect_network_client_factory.mm',
        'net/cookie_notification_bridge.h',
        'net/cookie_notification_bridge.mm',
        'net/crw_cert_policy_cache.h',
        'net/crw_cert_policy_cache.mm',
        'net/crw_cert_verification_controller.h',
        'net/crw_cert_verification_controller.mm',
        'net/crw_request_tracker_delegate.h',
        'net/crw_url_verifying_protocol_handler.h',
        'net/crw_url_verifying_protocol_handler.mm',
        'net/request_group_util.h',
        'net/request_group_util.mm',
        'net/request_tracker_data_memoizing_store.h',
        'net/request_tracker_factory_impl.h',
        'net/request_tracker_factory_impl.mm',
        'net/request_tracker_impl.h',
        'net/request_tracker_impl.mm',
        'net/web_http_protocol_handler_delegate.h',
        'net/web_http_protocol_handler_delegate.mm',
        'public/active_state_manager.h',
        'public/block_types.h',
        'public/browser_state.h',
        'public/browser_url_rewriter.h',
        'public/browsing_data_partition.h',
        'public/browsing_data_partition_client.cc',
        'public/browsing_data_partition_client.h',
        'public/cert_policy.h',
        'public/cert_store.h',
        'public/certificate_policy_cache.h',
        'public/crw_browsing_data_store.h',
        'public/crw_browsing_data_store_delegate.h',
        'public/favicon_status.cc',
        'public/favicon_status.h',
        'public/favicon_url.cc',
        'public/favicon_url.h',
        'public/interstitials/web_interstitial.h',
        'public/interstitials/web_interstitial_delegate.h',
        'public/load_committed_details.h',
        'public/navigation_item.h',
        'public/navigation_manager.h',
        'public/referrer.h',
        'public/referrer_util.cc',
        'public/referrer_util.h',
        'public/security_style.h',
        'public/ssl_status.cc',
        'public/ssl_status.h',
        'public/string_util.h',
        'public/url_scheme_util.h',
        'public/url_util.h',
        'public/user_metrics.h',
        'public/web/url_data_source_ios.h',
        'public/web_client.h',
        'public/web_client.mm',
        'public/web_controller_factory.h',
        'public/web_controller_factory.mm',
        'public/web_kit_constants.h',
        'public/web_state/credential.h',
        'public/web_state/crw_web_controller_observer.h',
        'public/web_state/crw_web_user_interface_delegate.h',
        'public/web_state/crw_web_view_proxy.h',
        'public/web_state/crw_web_view_scroll_view_proxy.h',
        'public/web_state/global_web_state_observer.h',
        'public/web_state/js/crw_js_injection_evaluator.h',
        'public/web_state/js/crw_js_injection_manager.h',
        'public/web_state/js/crw_js_injection_receiver.h',
        'public/web_state/page_display_state.h',
        'public/web_state/page_display_state.mm',
        'public/web_state/ui/crw_content_view.h',
        'public/web_state/ui/crw_generic_content_view.h',
        'public/web_state/ui/crw_native_content.h',
        'public/web_state/ui/crw_native_content_provider.h',
        'public/web_state/ui/crw_web_delegate.h',
        'public/web_state/ui/crw_web_view_content_view.h',
        'public/web_state/url_verification_constants.h',
        'public/web_state/web_state.h',
        'public/web_state/web_state_observer.h',
        'public/web_state/web_state_observer_bridge.h',
        'public/web_state/web_state_policy_decider.h',
        'public/web_state/web_state_user_data.h',
        'public/web_thread.h',
        'public/web_thread_delegate.h',
        'public/web_ui_ios_data_source.h',
        'public/web_view_counter.h',
        'public/web_view_creation_util.h',
        'public/web_view_type.h',
        'string_util.cc',
        'ui_web_view_util.h',
        'ui_web_view_util.mm',
        'url_scheme_util.mm',
        'url_util.cc',
        'user_metrics.cc',
        'weak_nsobject_counter.h',
        'weak_nsobject_counter.mm',
        'web_kit_constants.cc',
        'web_state/blocked_popup_info.h',
        'web_state/blocked_popup_info.mm',
        'web_state/credential.cc',
        'web_state/crw_recurring_task_delegate.h',
        'web_state/crw_web_view_proxy_impl.h',
        'web_state/crw_web_view_proxy_impl.mm',
        'web_state/crw_web_view_scroll_view_proxy.mm',
        'web_state/error_translation_util.h',
        'web_state/error_translation_util.mm',
        'web_state/frame_info.h',
        'web_state/global_web_state_event_tracker.cc',
        'web_state/global_web_state_event_tracker.h',
        'web_state/global_web_state_observer.cc',
        'web_state/js/credential_util.h',
        'web_state/js/credential_util.mm',
        'web_state/js/crw_js_early_script_manager.h',
        'web_state/js/crw_js_early_script_manager.mm',
        'web_state/js/crw_js_injection_manager.mm',
        'web_state/js/crw_js_injection_receiver.mm',
        'web_state/js/crw_js_invoke_parameter_queue.h',
        'web_state/js/crw_js_invoke_parameter_queue.mm',
        'web_state/js/crw_js_plugin_placeholder_manager.h',
        'web_state/js/crw_js_plugin_placeholder_manager.mm',
        'web_state/js/crw_js_window_id_manager.h',
        'web_state/js/crw_js_window_id_manager.mm',
        'web_state/js/page_script_util.h',
        'web_state/js/page_script_util.mm',
        'web_state/ui/crw_context_menu_provider.h',
        'web_state/ui/crw_context_menu_provider.mm',
        'web_state/ui/crw_debug_web_view.h',
        'web_state/ui/crw_debug_web_view.mm',
        'web_state/ui/crw_generic_content_view.mm',
        'web_state/ui/crw_simple_web_view_controller.h',
        'web_state/ui/crw_static_file_web_view.h',
        'web_state/ui/crw_static_file_web_view.mm',
        'web_state/ui/crw_swipe_recognizer_provider.h',
        'web_state/ui/crw_touch_tracking_recognizer.h',
        'web_state/ui/crw_touch_tracking_recognizer.mm',
        'web_state/ui/crw_ui_simple_web_view_controller.h',
        'web_state/ui/crw_ui_simple_web_view_controller.mm',
        'web_state/ui/crw_ui_web_view_web_controller.h',
        'web_state/ui/crw_ui_web_view_web_controller.mm',
        'web_state/ui/crw_web_controller+protected.h',
        'web_state/ui/crw_web_controller.h',
        'web_state/ui/crw_web_controller.mm',
        'web_state/ui/crw_web_controller_container_view.h',
        'web_state/ui/crw_web_controller_container_view.mm',
        'web_state/ui/crw_web_view_content_view.mm',
        'web_state/ui/crw_wk_script_message_router.h',
        'web_state/ui/crw_wk_script_message_router.mm',
        'web_state/ui/crw_wk_simple_web_view_controller.h',
        'web_state/ui/crw_wk_simple_web_view_controller.mm',
        'web_state/ui/crw_wk_web_view_crash_detector.h',
        'web_state/ui/crw_wk_web_view_crash_detector.mm',
        'web_state/ui/crw_wk_web_view_web_controller.h',
        'web_state/ui/crw_wk_web_view_web_controller.mm',
        'web_state/ui/web_view_js_utils.h',
        'web_state/ui/web_view_js_utils.mm',
        'web_state/ui/wk_back_forward_list_item_holder.h',
        'web_state/ui/wk_back_forward_list_item_holder.mm',
        'web_state/ui/wk_web_view_configuration_provider.h',
        'web_state/ui/wk_web_view_configuration_provider.mm',
        'web_state/web_controller_observer_bridge.h',
        'web_state/web_controller_observer_bridge.mm',
        'web_state/web_state.cc',
        'web_state/web_state_facade_delegate.h',
        'web_state/web_state_impl.h',
        'web_state/web_state_impl.mm',
        'web_state/web_state_observer.cc',
        'web_state/web_state_observer_bridge.mm',
        'web_state/web_state_policy_decider.mm',
        'web_state/web_view_internal_creation_util.h',
        'web_state/web_view_internal_creation_util.mm',
        'web_state/wk_web_view_security_util.h',
        'web_state/wk_web_view_security_util.mm',
        'web_view_counter_impl.h',
        'web_view_counter_impl.mm',
        'web_view_creation_util.mm',
        'webui/crw_web_ui_manager.h',
        'webui/crw_web_ui_manager.mm',
        'webui/crw_web_ui_page_builder.h',
        'webui/crw_web_ui_page_builder.mm',
        'webui/shared_resources_data_source_ios.cc',
        'webui/shared_resources_data_source_ios.h',
        'webui/url_data_manager_ios.cc',
        'webui/url_data_manager_ios.h',
        'webui/url_data_manager_ios_backend.cc',
        'webui/url_data_manager_ios_backend.h',
        'webui/url_data_source_ios.cc',
        'webui/url_data_source_ios_impl.cc',
        'webui/url_data_source_ios_impl.h',
        'webui/url_fetcher_block_adapter.h',
        'webui/url_fetcher_block_adapter.mm',
        'webui/web_ui_ios_controller_factory_registry.cc',
        'webui/web_ui_ios_controller_factory_registry.h',
        'webui/web_ui_ios_data_source_impl.cc',
        'webui/web_ui_ios_data_source_impl.h',
        'webui/web_ui_ios_impl.h',
        'webui/web_ui_ios_impl.mm',
      ],
      'link_settings': {
        # TODO(crbug.com/541549): change to regular linking once support for
        # iOS 7 is dropped.
        'xcode_settings': {
          'OTHER_LDFLAGS': [
            '-weak_framework WebKit',
          ]
        },
      },
    },
    # Target that builds the actual WebThread implementation. This is a
    # separate target since it can't yet be used by Chrome (see comment below).
    {
      'target_name': 'ios_web_thread',
      'type': 'static_library',
      'dependencies': [
        '../../base/base.gyp:base',
        '../../net/net.gyp:net',
      ],
      'include_dirs': [
        '../..',
      ],
      'sources': [
        'web_thread_impl.cc',
        'web_thread_impl.h',
      ],
    },
    # Target that builds the files that shim WebThread functions to their
    # corresponding content equivalents. This is a separate target since it
    # is needed by Chrome, which still uses content startup (which creates
    # content threads), but isn't used by web_shell.
    {
      'target_name': 'ios_web_content_thread_shim',
      'type': 'static_library',
      'dependencies': [
        '../../base/base.gyp:base',
        '../../content/content.gyp:content_browser',
      ],
      'include_dirs': [
        '../..',
      ],
      'sources': [
        'web_thread_adapter.cc',
        'web_thread_adapter.h',
      ],
    },
    # Target shared by ios_web and CrNet.
    {
      # GN version: //ios/web:core
      'target_name': 'ios_web_core',
      'type': 'static_library',
      'dependencies': [
        '../../base/base.gyp:base',
      ],
      'include_dirs': [
        '../..',
      ],
      'sources': [
        'crw_network_activity_indicator_manager.h',
        'crw_network_activity_indicator_manager.mm',
        'history_state_util.h',
        'history_state_util.mm',
      ],
    },
    {
      # GN version: //ios/web:web_bundle_ui
      'target_name': 'ios_web_js_bundle_ui',
      'type': 'none',
      'variables': {
        'closure_entry_point': '__crWeb.webBundle',
        'js_bundle_files': [
          'web_state/js/resources/base.js',
          'web_state/js/resources/common.js',
          'web_state/js/resources/console.js',
          'web_state/js/resources/core.js',
          'web_state/js/resources/core_dynamic_ui.js',
          'web_state/js/resources/dialog_overrides.js',
          'web_state/js/resources/message.js',
          'web_state/js/resources/message_dynamic_ui.js',
          'web_state/js/resources/web_bundle_ui.js',
          'web_state/js/resources/window_open_ui.js',
        ],
      },
      'sources': [
        'web_state/js/resources/web_bundle_ui.js',
      ],
      'link_settings': {
        'mac_bundle_resources': [
          '<(SHARED_INTERMEDIATE_DIR)/web_bundle_ui.js',
        ],
      },
      'includes': [
        'js_compile_bundle.gypi'
      ],
    },
    {
      # GN version: //ios/web:web_bundle_wk
      'target_name': 'ios_web_js_bundle_wk',
      'type': 'none',
      'variables': {
        'closure_entry_point': '__crWeb.webBundle',
        'js_bundle_files': [
          'web_state/js/resources/base.js',
          'web_state/js/resources/common.js',
          'web_state/js/resources/console.js',
          'web_state/js/resources/core.js',
          'web_state/js/resources/core_dynamic_wk.js',
          'web_state/js/resources/dialog_overrides.js',
          'web_state/js/resources/message.js',
          'web_state/js/resources/message_dynamic_wk.js',
          'web_state/js/resources/web_bundle_wk.js',
          'web_state/js/resources/window_open_wk.js',
        ],
      },
      'sources': [
        'web_state/js/resources/web_bundle_wk.js',
      ],
      'link_settings': {
        'mac_bundle_resources': [
          '<(SHARED_INTERMEDIATE_DIR)/web_bundle_wk.js',
        ],
      },
      'includes': [
        'js_compile_bundle.gypi'
      ],
    },
    {
      # GN version: //ios/web:js_resources
      'target_name': 'js_resources',
      'type': 'none',
      'dependencies': [
        'ios_web_js_bundle_ui',
        'ios_web_js_bundle_wk',
      ],
      'sources': [
        'web_state/js/resources/plugin_placeholder.js',
        'web_state/js/resources/window_id.js',
        'webui/resources/web_ui.js',
      ],
      'link_settings': {
        'mac_bundle_resources': [
          '<(SHARED_INTERMEDIATE_DIR)/plugin_placeholder.js',
          '<(SHARED_INTERMEDIATE_DIR)/window_id.js',
          '<(SHARED_INTERMEDIATE_DIR)/web_ui.js',
        ],
      },
      'includes': [
        'js_compile_checked.gypi'
      ],
    },
    {
      # GN version: //ios/web:test_support
      'target_name': 'test_support_ios_web',
      'type': 'static_library',
      'dependencies': [
        'ios_web_thread',
        'test_support_ios_web_without_threads',
      ],
      'include_dirs': [
        '../..',
      ],
      'sources': [
        'test/test_web_thread.cc',
        'test/test_web_thread_bundle.cc',
      ],
    },
    {
      'target_name': 'test_support_ios_web_with_content_thread_shim',
      'type': 'static_library',
      'dependencies': [
        'ios_web_content_thread_shim',
        'test_support_ios_web_without_threads',
      ],
      'include_dirs': [
        '../..',
      ],
      'sources': [
        'test/test_web_thread_adapter.cc',
        'test/test_web_thread_bundle_adapter.cc',
      ],
    },
    # A test support target that does not include TestWebThread. This is
    # separate because tests that rely on the the shim thread implementation
    # can't use TestWebThread/TestWebThreadBundle.
    # TODO(stuartmorgan): Fold this into test_support_ios_web once
    # the WebThread-to-BrowserThread shim is gone.
    {
      'target_name': 'test_support_ios_web_without_threads',
      'type': 'static_library',
      'dependencies': [
        'ios_web',
        '../../content/content_shell_and_tests.gyp:test_support_content',
        '../../ios/testing/ios_testing.gyp:ocmock_support',
        '../../ios/third_party/gcdwebserver/gcdwebserver.gyp:gcdwebserver',
        '../../testing/gmock.gyp:gmock',
        '../../testing/gtest.gyp:gtest',
        '../../third_party/ocmock/ocmock.gyp:ocmock',
      ],
      'include_dirs': [
        '../..',
      ],
      'sources': [
        'public/test/crw_test_js_injection_receiver.h',
        'public/test/crw_test_js_injection_receiver.mm',
        'public/test/http_server.h',
        'public/test/http_server.mm',
        'public/test/js_test_util.h',
        'public/test/js_test_util.mm',
        'public/test/response_providers/data_response_provider.h',
        'public/test/response_providers/data_response_provider.mm',
        'public/test/response_providers/file_based_response_provider.h',
        'public/test/response_providers/file_based_response_provider.mm',
        'public/test/response_providers/file_based_response_provider_impl.cc',
        'public/test/response_providers/file_based_response_provider_impl.h',
        'public/test/response_providers/response_provider.cc',
        'public/test/response_providers/response_provider.h',
        'public/test/test_browser_state.cc',
        'public/test/test_browser_state.h',
        'public/test/test_web_client.h',
        'public/test/test_web_client.mm',
        'public/test/test_web_state.cc',
        'public/test/test_web_state.h',
        'public/test/test_web_thread.h',
        'public/test/test_web_thread_bundle.h',
        'public/test/test_web_view_content_view.h',
        'public/test/test_web_view_content_view.mm',
        'public/test/web_test_util.h',
        'test/crw_fake_web_controller_observer.h',
        'test/crw_fake_web_controller_observer.mm',
        'test/web_test.h',
        'test/web_test.mm',
        'test/web_test_suite.cc',
        'test/web_test_suite.h',
        'test/wk_web_view_crash_utils.h',
        'test/wk_web_view_crash_utils.mm',
      ],
    },
    {
      # GN version: //ios/web:user_agent
      'target_name': 'user_agent',
      'type': 'static_library',
      'include_dirs': [
        '../..',
      ],
      'dependencies': [
        '../../base/base.gyp:base'
      ],
      'sources': [
        'public/user_agent.h',
        'public/user_agent.mm',
      ],
    },
  ],
}
