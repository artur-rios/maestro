# Dependency inventory

**Audit date:** 2026-08-05

## Toolchain

| Dependency | Current | Latest stable | Selected | Source | Reason |
| --- | --- | --- | --- | --- | --- |
| Flutter SDK | 3.44.8 | 3.44.8 | 3.44.8 | [Flutter Windows release metadata](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) | The current stable Flutter release is already selected. |
| Dart SDK | 3.12.2 | 3.12.2 (bundled with Flutter 3.44.8) | 3.12.2 | [Flutter Windows release metadata](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) | Flutter 3.44.8 bundles this Dart SDK; keep the toolchain pair aligned. |

## Direct Dart packages

| Dependency | Current | Latest stable | Selected | Source | Reason |
| --- | --- | --- | --- | --- | --- |
| flutter | SDK 3.44.8 | SDK 3.44.8 | SDK 3.44.8 | [Flutter Windows release metadata](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) | Flutter SDK package; follows the selected Flutter SDK. |
| cupertino_icons | 1.0.9 | 1.0.9 | 1.0.9 | [pub.dev 1.0.9](https://pub.dev/packages/cupertino_icons/versions/1.0.9) | Current resolved version is latest stable. |
| flutter_riverpod | 3.4.2 | 3.4.2 | 3.4.2 | [pub.dev 3.4.2](https://pub.dev/packages/flutter_riverpod/versions/3.4.2) | Current resolved version is latest stable. |
| drift | 2.34.0 | 2.34.3 | 2.34.0 | [pub.dev 2.34.3](https://pub.dev/packages/drift/versions/2.34.3) | Keep the newest version that compiles with the SDK-resolvable `drift_dev` generator; see Exceptions. |
| drift_flutter | 0.3.1 | 0.3.1 | 0.3.1 | [pub.dev 0.3.1](https://pub.dev/packages/drift_flutter/versions/0.3.1) | Current resolved version is latest stable. |
| sqlite3 | 3.5.1 | 3.5.1 | 3.5.1 | [pub.dev 3.5.1](https://pub.dev/packages/sqlite3/versions/3.5.1) | Current resolved version is latest stable. |
| xterm | 4.0.0 | 4.0.0 | 4.0.0 | [pub.dev 4.0.0](https://pub.dev/packages/xterm/versions/4.0.0) | Current resolved version is latest stable. |
| flutter_pty | 0.4.2 | 0.4.2 | 0.4.2 | [pub.dev 0.4.2](https://pub.dev/packages/flutter_pty/versions/0.4.2) | Current resolved version is latest stable. |
| flutter_secure_storage | 10.3.1 | 10.3.1 | 10.3.1 | [pub.dev 10.3.1](https://pub.dev/packages/flutter_secure_storage/versions/10.3.1) | Current resolved version is latest stable. |
| sodium | 4.0.4 | 4.0.4 | 4.0.4 | [pub.dev 4.0.4](https://pub.dev/packages/sodium/versions/4.0.4) | Current resolved version is latest stable. |
| uuid | 4.6.0 | 4.6.0 | 4.6.0 | [pub.dev 4.6.0](https://pub.dev/packages/uuid/versions/4.6.0) | Current resolved version is latest stable. |
| path_provider | 2.1.6 | 2.1.6 | 2.1.6 | [pub.dev 2.1.6](https://pub.dev/packages/path_provider/versions/2.1.6) | Current resolved version is latest stable. |
| package_info_plus | 10.2.1 | 10.2.1 | 10.2.1 | [pub.dev 10.2.1](https://pub.dev/packages/package_info_plus/versions/10.2.1) | Current resolved version is latest stable. |
| logging | 1.3.0 | 1.3.0 | 1.3.0 | [pub.dev 1.3.0](https://pub.dev/packages/logging/versions/1.3.0) | Current resolved version is latest stable. |
| path | 1.9.1 | 1.9.1 | 1.9.1 | [pub.dev 1.9.1](https://pub.dev/packages/path/versions/1.9.1) | Current resolved version is latest stable. |
| crypto | 3.0.7 | 3.0.7 | 3.0.7 | [pub.dev 3.0.7](https://pub.dev/packages/crypto/versions/3.0.7) | Current resolved version is latest stable. |
| archive | 4.0.9 | 4.0.9 | 4.0.9 | [pub.dev 4.0.9](https://pub.dev/packages/archive/versions/4.0.9) | Current resolved version is latest stable. |
| win32 | 6.4.0 | 6.4.0 | 6.4.0 | [pub.dev 6.4.0](https://pub.dev/packages/win32/versions/6.4.0) | Current resolved version is latest stable. |
| ffi | 2.2.0 | 2.2.0 | 2.2.0 | [pub.dev 2.2.0](https://pub.dev/packages/ffi/versions/2.2.0) | Current resolved version is latest stable. |
| flutter_test | SDK 3.44.8 | SDK 3.44.8 | SDK 3.44.8 | [Flutter Windows release metadata](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) | Flutter SDK package; follows the selected Flutter SDK. |
| integration_test | SDK 3.44.8 | SDK 3.44.8 | SDK 3.44.8 | [Flutter Windows release metadata](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) | Flutter SDK package; follows the selected Flutter SDK. |
| flutter_lints | 6.0.0 | 6.0.0 | 6.0.0 | [pub.dev 6.0.0](https://pub.dev/packages/flutter_lints/versions/6.0.0) | Current resolved version is latest stable. |
| drift_dev | 2.34.0 | 2.34.5 | 2.34.0 | [pub.dev 2.34.5](https://pub.dev/packages/drift_dev/versions/2.34.5) | Flutter 3.44.8's test graph prevents analyzer 13, required by newer releases; see Exceptions. |
| build_runner | 2.15.1 | 2.16.0 | 2.15.1 | [pub.dev 2.16.0](https://pub.dev/packages/build_runner/versions/2.16.0) | Flutter 3.44.8 pins `meta` below the analyzer requirement of newer releases; see Exceptions. |
| msix | 3.18.0 | 3.18.0 | 3.18.0 | [pub.dev 3.18.0](https://pub.dev/packages/msix/versions/3.18.0) | Current resolved version is latest stable. |
| yaml | 3.1.3 | 3.1.3 | 3.1.3 | [pub.dev 3.1.3](https://pub.dev/packages/yaml/versions/3.1.3) | Current resolved version is latest stable. |

## Resolved transitive Dart packages

`dart pub deps --json` and `pubspec.lock` resolve the following complete transitive graph. `Current resolved` and `Selected stable resolved` are intentionally the same lockfile value after Task 2 resolution. Hosted packages use [pub.dev](https://pub.dev) provenance. Flutter SDK packages are grouped only where their Flutter ownership and resolved `0.0.0` SDK version are explicit.

| Package | Current resolved | Selected stable resolved | Source / provenance | Reason |
| --- | --- | --- | --- | --- |
| _fe_analyzer_shared | 99.0.0 | 99.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| analyzer | 12.1.0 | 12.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| args | 2.7.0 | 2.7.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| async | 2.13.1 | 2.13.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| boolean_selector | 2.1.2 | 2.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| build | 4.0.7 | 4.0.7 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| build_config | 1.3.2 | 1.3.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| build_daemon | 4.1.4 | 4.1.4 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| built_collection | 5.1.1 | 5.1.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| built_value | 8.12.7 | 8.12.7 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| characters | 1.4.1 | 1.4.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| charcode | 1.4.0 | 1.4.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| checked_yaml | 2.0.4 | 2.0.4 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| cli_config | 0.2.0 | 0.2.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| cli_util | 0.4.2 | 0.4.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| clock | 1.1.2 | 1.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| code_assets | 1.2.1 | 1.2.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| collection | 1.19.1 | 1.19.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| console | 4.1.0 | 4.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| convert | 3.1.2 | 3.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| coverage | 1.15.1 | 1.15.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| csslib | 1.0.2 | 1.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| dart_style | 3.1.8 | 3.1.8 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| equatable | 2.1.0 | 2.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| fake_async | 1.3.3 | 1.3.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| ffi_leak_tracker | 0.1.2 | 0.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| file | 7.0.1 | 7.0.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| fixnum | 1.1.1 | 1.1.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_driver, flutter_web_plugins, fuchsia_remote_debug_protocol, sky_engine | Flutter SDK 3.44.8 (lockfile 0.0.0) | Flutter SDK 3.44.8 (lockfile 0.0.0) | Flutter SDK; pub deps --json | Flutter-owned SDK packages. |
| flutter_secure_storage_darwin | 0.3.2 | 0.3.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_secure_storage_linux | 3.0.1 | 3.0.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_secure_storage_platform_interface | 2.0.3 | 2.0.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_secure_storage_web | 2.1.1 | 2.1.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_secure_storage_windows | 4.2.2 | 4.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| freezed_annotation | 3.1.0 | 3.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| frontend_server_client | 4.0.0 | 4.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| get_it | 9.2.1 | 9.2.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| glob | 2.1.3 | 2.1.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| graphs | 2.3.2 | 2.3.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| hooks | 2.0.2 | 2.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| html | 0.15.6 | 0.15.6 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| http | 1.6.0 | 1.6.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| http_multi_server | 3.2.2 | 3.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| http_parser | 4.1.2 | 4.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| image | 4.9.1 | 4.9.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| io | 1.0.5 | 1.0.5 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| jni | 1.0.3 | 1.0.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| jni_flutter | 1.0.2 | 1.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| jni_util | 1.0.0 | 1.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| json_annotation | 4.12.0 | 4.12.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| leak_tracker | 11.0.2 | 11.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| leak_tracker_flutter_testing | 3.0.10 | 3.0.10 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| leak_tracker_testing | 3.0.2 | 3.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| lints | 6.1.0 | 6.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| listen | 1.0.1 | 1.0.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| matcher | 0.12.19 | 0.12.19 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| material_color_utilities | 0.13.0 | 0.13.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| meta | 1.18.0 | 1.18.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| mime | 2.0.0 | 2.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| native_toolchain_c | 0.19.2 | 0.19.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| node_preamble | 2.0.2 | 2.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| objective_c | 9.5.0 | 9.5.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| package_config | 2.2.0 | 2.2.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| package_info_plus_platform_interface | 4.1.0 | 4.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| path_provider_android | 2.3.1 | 2.3.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| path_provider_foundation | 2.6.0 | 2.6.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| path_provider_linux | 2.2.2 | 2.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| path_provider_platform_interface | 2.1.3 | 2.1.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| path_provider_windows | 2.3.0 | 2.3.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| petitparser | 7.0.2 | 7.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| platform | 3.1.6 | 3.1.6 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| plugin_platform_interface | 2.1.8 | 2.1.8 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| pool | 1.5.2 | 1.5.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| posix | 6.5.2 | 6.5.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| process | 5.0.5 | 5.0.5 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| pub_semver | 2.2.0 | 2.2.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| pubspec_parse | 1.5.0 | 1.5.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| quiver | 3.2.2 | 3.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| recase | 4.1.0 | 4.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| record_use | 0.6.0 | 0.6.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| riverpod | 3.4.2 | 3.4.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| shelf | 1.4.2 | 1.4.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| shelf_packages_handler | 3.0.2 | 3.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| shelf_static | 1.1.3 | 1.1.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| shelf_web_socket | 3.0.0 | 3.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| source_gen | 4.2.4 | 4.2.4 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| source_map_stack_trace | 2.1.2 | 2.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| source_maps | 0.10.13 | 0.10.13 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| source_span | 1.10.2 | 1.10.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| sqlcipher_flutter_libs | 0.7.0+eol | 0.7.0+eol | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| sqlite3_flutter_libs | 0.6.0+eol | 0.6.0+eol | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| sqlparser | 0.44.5 | 0.44.5 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| stack_trace | 1.12.1 | 1.12.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| state_notifier | 1.0.0 | 1.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| stream_channel | 2.1.4 | 2.1.4 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| stream_transform | 2.1.1 | 2.1.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| string_scanner | 1.4.1 | 1.4.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| sync_http | 0.3.1 | 0.3.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| term_glyph | 1.2.2 | 1.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| test | 1.31.0 | 1.31.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| test_api | 0.7.11 | 0.7.11 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| test_core | 0.6.17 | 0.6.17 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| typed_data | 1.4.0 | 1.4.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| vector_math | 2.2.0 | 2.2.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| vm_service | 15.2.0 | 15.2.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| watcher | 1.2.1 | 1.2.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| web | 1.1.1 | 1.1.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| web_socket | 1.0.1 | 1.0.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| web_socket_channel | 3.0.3 | 3.0.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| webdriver | 3.1.0 | 3.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| webkit_inspection_protocol | 1.2.1 | 1.2.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| xdg_directories | 1.1.0 | 1.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| xml | 7.0.1 | 7.0.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| zmodem | 0.0.6 | 0.0.6 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |

### Final `flutter pub outdated --json` comparison

The final machine-readable check reports 20 package entries: 1 direct, 2 dev, and 17 transitive. All 20 have `current == upgradable`. All 17 transitive entries also have `upgradable == resolvable`, so **no transitive package has a newer resolvable stable version**. Their newer `latest` values are SDK-constrained graph exceptions: transitive packages cannot be upgraded independently, and Maestro does not use `dependency_overrides`. The one `resolvable > current` entry is the direct `drift` package, whose project-level compile exception is documented below.

| Package | Kind | Current | Upgradable | Resolvable | Latest stable | Disposition |
| --- | --- | --- | --- | --- | --- | --- |
| _fe_analyzer_shared | transitive | 99.0.0 | 99.0.0 | 99.0.0 | 105.0.0 | SDK-constrained transitive exception. |
| analyzer | transitive | 12.1.0 | 12.1.0 | 12.1.0 | 14.1.0 | SDK-constrained transitive exception. |
| build | transitive | 4.0.7 | 4.0.7 | 4.0.7 | 4.0.10 | SDK-constrained transitive exception. |
| build_runner | dev | 2.15.1 | 2.15.1 | 2.15.1 | 2.16.0 | Direct dev exception; see Exceptions. |
| cli_util | transitive | 0.4.2 | 0.4.2 | 0.4.2 | 0.5.2 | SDK-constrained transitive exception. |
| dart_style | transitive | 3.1.8 | 3.1.8 | 3.1.8 | 3.1.12 | SDK-constrained transitive exception. |
| drift | direct | 2.34.0 | 2.34.0 | 2.34.3 | 2.34.3 | Project-level compile exception; see Exceptions. |
| drift_dev | dev | 2.34.0 | 2.34.0 | 2.34.0 | 2.34.5 | Direct dev exception; see Exceptions. |
| flutter_secure_storage_darwin | transitive | 0.3.2 | 0.3.2 | 0.3.2 | 0.4.0 | SDK-constrained transitive exception. |
| hooks | transitive | 2.0.2 | 2.0.2 | 2.0.2 | 2.1.0 | SDK-constrained transitive exception. |
| matcher | transitive | 0.12.19 | 0.12.19 | 0.12.19 | 0.12.20 | SDK-constrained transitive exception. |
| meta | transitive | 1.18.0 | 1.18.0 | 1.18.0 | 1.19.0 | SDK-constrained transitive exception. |
| native_toolchain_c | transitive | 0.19.2 | 0.19.2 | 0.19.2 | 0.19.3 | SDK-constrained transitive exception. |
| package_config | transitive | 2.2.0 | 2.2.0 | 2.2.0 | 3.0.0 | SDK-constrained transitive exception. |
| record_use | transitive | 0.6.0 | 0.6.0 | 0.6.0 | 1.0.0 | SDK-constrained transitive exception. |
| sqlparser | transitive | 0.44.5 | 0.44.5 | 0.44.5 | 0.45.0 | SDK-constrained transitive exception. |
| test | transitive | 1.31.0 | 1.31.0 | 1.31.0 | 1.31.2 | SDK-constrained transitive exception. |
| test_api | transitive | 0.7.11 | 0.7.11 | 0.7.11 | 0.7.13 | SDK-constrained transitive exception. |
| test_core | transitive | 0.6.17 | 0.6.17 | 0.6.17 | 0.6.19 | SDK-constrained transitive exception. |
| vector_math | transitive | 2.2.0 | 2.2.0 | 2.2.0 | 2.4.2 | SDK-constrained transitive exception. |

## Ubuntu apt-get dependencies

All versions are intentionally unpinned: the `ubuntu-24.04` GitHub-hosted runner resolves them from the current [Ubuntu 24.04 (Noble) stable repositories](https://packages.ubuntu.com/noble/). The workflow's `apt-get update` immediately precedes each installation, so a build selects the repository-provided stable package version at execution time.

| Package | Current / selected | Source / provenance | Reason |
| --- | --- | --- | --- |
| clang | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI build prerequisite; intentionally not hard-pinned. |
| cmake | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI build prerequisite; intentionally not hard-pinned. |
| ninja-build | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI build prerequisite; intentionally not hard-pinned. |
| pkg-config | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI build prerequisite; intentionally not hard-pinned. |
| libgtk-3-dev | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI build prerequisite; intentionally not hard-pinned. |
| libsecret-1-dev | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI test and build prerequisite; intentionally not hard-pinned. |
| libsqlite3-dev | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI test prerequisite; intentionally not hard-pinned. |
| libjsoncpp-dev | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI build prerequisite; intentionally not hard-pinned. |
| libayatana-appindicator3-dev | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI build prerequisite; intentionally not hard-pinned. |
| dbus-x11 | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI integration-test prerequisite; intentionally not hard-pinned. |
| gnome-keyring | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI integration-test prerequisite; intentionally not hard-pinned. |
| xvfb | Ubuntu 24.04 stable repository version | [Ubuntu Noble packages](https://packages.ubuntu.com/noble/) | CI integration-test prerequisite; intentionally not hard-pinned. |

## GitHub Actions and packaging tools

| Dependency | Current | Latest stable | Selected | Source | Reason |
| --- | --- | --- | --- | --- | --- |
| actions/checkout | `11d5960a326750d5838078e36cf38b85af677262` (v4) | v7.0.1 (v7) | `3d3c42e5aac5ba805825da76410c181273ba90b1` | [release](https://github.com/actions/checkout/releases/tag/v7.0.1), [v7 tag API](https://api.github.com/repos/actions/checkout/git/ref/tags/v7) | Stable-major tag resolved to an immutable commit SHA. |
| subosito/flutter-action | `1a449444c387b1966244ae4d4f8c696479add0b2` (v2) | v2.23.0 (v2) | `1a449444c387b1966244ae4d4f8c696479add0b2` | [release](https://github.com/subosito/flutter-action/releases/tag/v2.23.0), [v2 tag API](https://api.github.com/repos/subosito/flutter-action/git/ref/tags/v2) | Current immutable revision resolves from the latest stable major tag. |
| actions/upload-artifact | `ea165f8d65b6e75b540449e92b4886f43607fa02` (v4) | v7.0.1 (v7) | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | [release](https://github.com/actions/upload-artifact/releases/tag/v7.0.1), [v7 tag API](https://api.github.com/repos/actions/upload-artifact/git/ref/tags/v7) | Stable-major tag resolved to an immutable commit SHA. |
| actions/download-artifact | `d3f86a106a0bac45b974a628896c90dbdf5c8093` (v4) | v8.0.1 (v8) | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` | [release](https://github.com/actions/download-artifact/releases/tag/v8.0.1), [v8 tag API](https://api.github.com/repos/actions/download-artifact/git/ref/tags/v8) | Stable-major tag resolved to an immutable commit SHA. |
| actions/attest-build-provenance | `977bb373ede98d70efdf65b84cb5f73e068dcc2a` (v3) | v4.1.1 (v4) | `0f67c3f4856b2e3261c31976d6725780e5e4c373` | [release](https://github.com/actions/attest-build-provenance/releases/tag/v4.1.1), [v4 tag API](https://api.github.com/repos/actions/attest-build-provenance/git/ref/tags/v4) | Annotated stable-major tag resolved to its immutable commit SHA. |
| softprops/action-gh-release | `3bb12739c298aeb8a4eeaf626c5b8d85266b0e65` (v2) | v3.0.2 (v3) | `3d0d9888cb7fd7b750713d6e236d1fcb99157228` | [release](https://github.com/softprops/action-gh-release/releases/tag/v3.0.2), [v3 tag API](https://api.github.com/repos/softprops/action-gh-release/git/ref/tags/v3) | Annotated stable-major tag resolved to its immutable commit SHA. |
| appimagetool x86_64 | [continuous asset](https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage); SHA-256 `a6d71e2b6cd66f8e8d16c37ad164658985e0cf5fcaa950c90a482890cb9d13e0` | 1.9.1 | 1.9.1 asset; SHA-256 `ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0` | [1.9.1 release asset](https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage) | `continuous` is a mutable rolling release; select immutable stable 1.9.1 asset. |

## Exceptions

Flutter 3.44.8 and Dart 3.12.2 cannot resolve the newest stable build-time package set. Running `flutter pub get` with `build_runner ^2.16.0` exits 1 because `flutter_test` from the Flutter SDK pins `meta 1.18.0`, while `build_runner >=2.15.2` requires `analyzer >=13.3.0`, which requires `meta ^1.18.3`. Maestro therefore retains the newest resolvable stable `build_runner`, 2.15.1, without a transitive override.

Running `flutter pub get` with `drift_dev 2.34.5` also exits 1. `drift_dev >=2.34.1+1` requires analyzer 13, while the Flutter SDK test packages and Riverpod's `test` dependency keep the graph below analyzer 13 and pin `test_api 0.7.11`. Pub resolves `drift_dev 2.34.0`, but pairing it with `drift 2.34.3` fails to compile the migration test because the runtime's Drift 3 preview API replaced `GeneratedDatabase.allSchemaEntities` with `GeneratedDatabase.schema`, which the older generator does not implement. Maestro therefore keeps the compatible `drift 2.34.0` / `drift_dev 2.34.0` pair. No `dependency_overrides` are used.

The mutable appimagetool `continuous` release is separately excluded from stable-release selection in favor of the immutable 1.9.1 release asset.
