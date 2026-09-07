# Dependency inventory

**Audit date:** 2026-09-07

## Verified implementation

- Working tree: uncommitted dependency refresh; no CI run cites this state yet.
- Selected toolchain: Flutter 3.47.2 stable and its bundled Dart 3.13.2 SDK
- Local gates run against this resolution: `dart format --set-exit-if-changed`,
  `dart run tooling/verify_architecture.dart`,
  `dart run tooling/verify_workflows.dart`, `flutter analyze` (clean), and
  `flutter test` (full suite green).
- Pub graph: `flutter pub outdated` reports every direct and dev dependency at
  its latest stable release. The six remaining entries are transitive packages
  whose newer `latest` is held back by the Flutter SDK's own constraints; each
  has `current == upgradable == resolvable`, so none can move without an
  override, and Maestro uses no `dependency_overrides`.
- Publisher signing: `unconfigured`; the release verifier fails closed if a
  signature is present but cannot be verified.

## Toolchain

| Dependency | Current | Latest stable | Selected | Source | Reason |
| --- | --- | --- | --- | --- | --- |
| Flutter SDK | 3.47.2 | 3.47.2 | 3.47.2 | [Flutter Windows release metadata](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) | The current stable Flutter release is selected. |
| Dart SDK | 3.13.2 | 3.13.2 (bundled with Flutter 3.47.2) | 3.13.2 | [Flutter Windows release metadata](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) | Flutter 3.47.2 bundles this Dart SDK; keep the toolchain pair aligned. |

## Direct Dart packages

| Dependency | Current | Latest stable | Selected | Source | Reason |
| --- | --- | --- | --- | --- | --- |
| archive | 4.2.0 | 4.2.0 | 4.2.0 | [pub.dev 4.2.0](https://pub.dev/packages/archive/versions/4.2.0) | Current resolved version is latest stable. |
| crypto | 3.0.7 | 3.0.7 | 3.0.7 | [pub.dev 3.0.7](https://pub.dev/packages/crypto/versions/3.0.7) | Current resolved version is latest stable. |
| drift | 2.34.4 | 2.34.4 | 2.34.4 | [pub.dev 2.34.4](https://pub.dev/packages/drift/versions/2.34.4) | Current resolved version is latest stable. |
| drift_flutter | 0.3.1 | 0.3.1 | 0.3.1 | [pub.dev 0.3.1](https://pub.dev/packages/drift_flutter/versions/0.3.1) | Current resolved version is latest stable. |
| ffi | 2.2.0 | 2.2.0 | 2.2.0 | [pub.dev 2.2.0](https://pub.dev/packages/ffi/versions/2.2.0) | Current resolved version is latest stable. |
| file_selector | 1.1.0 | 1.1.0 | 1.1.0 | [pub.dev 1.1.0](https://pub.dev/packages/file_selector/versions/1.1.0) | Current resolved version is latest stable. |
| flutter | SDK 3.47.2 | SDK 3.47.2 | SDK 3.47.2 | [Flutter Windows release metadata](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) | Flutter SDK package; follows the selected Flutter SDK. |
| flutter_pty | 0.4.2 | 0.4.2 | 0.4.2 | [pub.dev 0.4.2](https://pub.dev/packages/flutter_pty/versions/0.4.2) | Current resolved version is latest stable. |
| flutter_riverpod | 3.4.3 | 3.4.3 | 3.4.3 | [pub.dev 3.4.3](https://pub.dev/packages/flutter_riverpod/versions/3.4.3) | Current resolved version is latest stable. |
| flutter_secure_storage | 11.0.0 | 11.0.0 | 11.0.0 | [pub.dev 11.0.0](https://pub.dev/packages/flutter_secure_storage/versions/11.0.0) | Current resolved version is latest stable. |
| http | 1.6.0 | 1.6.0 | 1.6.0 | [pub.dev 1.6.0](https://pub.dev/packages/http/versions/1.6.0) | Current resolved version is latest stable. |
| path | 1.9.1 | 1.9.1 | 1.9.1 | [pub.dev 1.9.1](https://pub.dev/packages/path/versions/1.9.1) | Current resolved version is latest stable. |
| path_provider | 2.1.6 | 2.1.6 | 2.1.6 | [pub.dev 2.1.6](https://pub.dev/packages/path_provider/versions/2.1.6) | Current resolved version is latest stable. |
| sodium | 4.1.0+1 | 4.1.0+1 | 4.1.0+1 | [pub.dev 4.1.0+1](https://pub.dev/packages/sodium/versions/4.1.0+1) | Current resolved version is latest stable. |
| sqlite3 | 3.5.2 | 3.5.2 | 3.5.2 | [pub.dev 3.5.2](https://pub.dev/packages/sqlite3/versions/3.5.2) | Current resolved version is latest stable. |
| url_launcher | 6.3.2 | 6.3.2 | 6.3.2 | [pub.dev 6.3.2](https://pub.dev/packages/url_launcher/versions/6.3.2) | Current resolved version is latest stable. |
| uuid | 4.6.0 | 4.6.0 | 4.6.0 | [pub.dev 4.6.0](https://pub.dev/packages/uuid/versions/4.6.0) | Current resolved version is latest stable. |
| win32 | 6.4.0 | 6.4.0 | 6.4.0 | [pub.dev 6.4.0](https://pub.dev/packages/win32/versions/6.4.0) | Current resolved version is latest stable. |
| window_manager | 0.5.2 | 0.5.2 | 0.5.2 | [pub.dev 0.5.2](https://pub.dev/packages/window_manager/versions/0.5.2) | Current resolved version is latest stable. |
| xterm | 4.0.0 | 4.0.0 | 4.0.0 | [pub.dev 4.0.0](https://pub.dev/packages/xterm/versions/4.0.0) | Current resolved version is latest stable. |
| build_runner | 2.16.1 | 2.16.1 | 2.16.1 | [pub.dev 2.16.1](https://pub.dev/packages/build_runner/versions/2.16.1) | Current resolved version is latest stable. |
| drift_dev | 2.34.6 | 2.34.6 | 2.34.6 | [pub.dev 2.34.6](https://pub.dev/packages/drift_dev/versions/2.34.6) | Current resolved version is latest stable. |
| flutter_lints | 6.0.0 | 6.0.0 | 6.0.0 | [pub.dev 6.0.0](https://pub.dev/packages/flutter_lints/versions/6.0.0) | Current resolved version is latest stable. |
| flutter_test | SDK 3.47.2 | SDK 3.47.2 | SDK 3.47.2 | [Flutter Windows release metadata](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) | Flutter SDK package; follows the selected Flutter SDK. |
| integration_test | SDK 3.47.2 | SDK 3.47.2 | SDK 3.47.2 | [Flutter Windows release metadata](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) | Flutter SDK package; follows the selected Flutter SDK. |
| msix | 3.18.0 | 3.18.0 | 3.18.0 | [pub.dev 3.18.0](https://pub.dev/packages/msix/versions/3.18.0) | Current resolved version is latest stable. |
| yaml | 3.1.4 | 3.1.4 | 3.1.4 | [pub.dev 3.1.4](https://pub.dev/packages/yaml/versions/3.1.4) | Current resolved version is latest stable. |

## Resolved transitive Dart packages

`dart pub deps --json` and `pubspec.lock` resolve the following complete transitive graph. `Current resolved` and `Selected stable resolved` are intentionally the same lockfile value after Task 2 resolution. Hosted packages use [pub.dev](https://pub.dev) provenance. Flutter SDK packages are grouped only where their Flutter ownership and resolved `0.0.0` SDK version are explicit.

| Package | Current resolved | Selected stable resolved | Source / provenance | Reason |
| --- | --- | --- | --- | --- |
| _fe_analyzer_shared | 107.0.0 | 107.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| analyzer | 14.3.0 | 14.3.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| args | 2.7.0 | 2.7.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| async | 2.13.1 | 2.13.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| boolean_selector | 2.1.2 | 2.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| build | 4.0.11 | 4.0.11 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| build_config | 1.3.3 | 1.3.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| build_daemon | 4.1.6 | 4.1.6 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| built_collection | 5.1.1 | 5.1.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| built_value | 8.13.0 | 8.13.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| characters | 1.4.1 | 1.4.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| charcode | 1.4.0 | 1.4.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| checked_yaml | 2.0.4 | 2.0.4 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| cli_util | 0.5.2 | 0.5.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| clock | 1.1.3 | 1.1.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| code_assets | 1.2.1 | 1.2.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| collection | 1.19.1 | 1.19.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| console | 4.1.0 | 4.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| convert | 3.1.2 | 3.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| cross_file | 0.3.5+5 | 0.3.5+5 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| csslib | 1.0.2 | 1.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| dart_style | 3.1.13 | 3.1.13 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| equatable | 2.1.0 | 2.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| fake_async | 1.3.3 | 1.3.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| ffi_leak_tracker | 0.1.2 | 0.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| file | 7.0.1 | 7.0.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| file_selector_android | 0.5.2+10 | 0.5.2+10 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| file_selector_ios | 0.5.3+6 | 0.5.3+6 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| file_selector_linux | 0.9.4+1 | 0.9.4+1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| file_selector_macos | 0.9.5+1 | 0.9.5+1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| file_selector_platform_interface | 2.7.0 | 2.7.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| file_selector_web | 0.9.5 | 0.9.5 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| file_selector_windows | 0.9.3+6 | 0.9.3+6 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| fixnum | 1.1.1 | 1.1.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_driver | Flutter SDK 3.47.2 (lockfile 0.0.0) | Flutter SDK 3.47.2 (lockfile 0.0.0) | Flutter SDK; pubspec.lock | Flutter-owned SDK package. |
| flutter_secure_storage_darwin | 0.4.0 | 0.4.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_secure_storage_linux | 3.0.2 | 3.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_secure_storage_platform_interface | 2.0.3 | 2.0.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_secure_storage_web | 2.1.1 | 2.1.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_secure_storage_windows | 4.2.2 | 4.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| flutter_web_plugins | Flutter SDK 3.47.2 (lockfile 0.0.0) | Flutter SDK 3.47.2 (lockfile 0.0.0) | Flutter SDK; pubspec.lock | Flutter-owned SDK package. |
| freezed_annotation | 3.1.0 | 3.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| fuchsia_remote_debug_protocol | Flutter SDK 3.47.2 (lockfile 0.0.0) | Flutter SDK 3.47.2 (lockfile 0.0.0) | Flutter SDK; pubspec.lock | Flutter-owned SDK package. |
| get_it | 9.2.1 | 9.2.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| glob | 2.2.0 | 2.2.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| graphs | 2.3.2 | 2.3.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| hooks | 2.2.0 | 2.2.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| html | 0.15.7 | 0.15.7 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| http_multi_server | 3.2.2 | 3.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| http_parser | 4.1.2 | 4.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| image | 4.9.2 | 4.9.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| io | 1.1.0 | 1.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| jni | 1.0.3 | 1.0.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| jni_flutter | 1.0.3 | 1.0.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| jni_util | 1.0.0 | 1.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| json_annotation | 4.12.0 | 4.12.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| leak_tracker | 11.0.2 | 11.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| leak_tracker_flutter_testing | 3.0.10 | 3.0.10 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| leak_tracker_testing | 3.0.2 | 3.0.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| lints | 6.1.0 | 6.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| listen | 1.0.1 | 1.0.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| logging | 1.3.0 | 1.3.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| matcher | 0.12.20 | 0.12.20 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| material_color_utilities | 0.13.0 | 0.13.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| meta | 1.19.0 | 1.19.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| mime | 2.1.0 | 2.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| native_toolchain_c | 0.19.3 | 0.19.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| objective_c | 9.5.0 | 9.5.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| package_config | 3.0.0 | 3.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| path_provider_android | 2.3.1 | 2.3.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| path_provider_foundation | 2.6.0 | 2.6.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| path_provider_linux | 2.2.2 | 2.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| path_provider_platform_interface | 2.1.3 | 2.1.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| path_provider_windows | 2.3.0 | 2.3.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| platform | 3.2.0 | 3.2.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| plugin_platform_interface | 2.1.8 | 2.1.8 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| pool | 1.5.3 | 1.5.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| posix | 6.5.2 | 6.5.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| process | 5.0.6 | 5.0.6 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| pub_semver | 2.2.1 | 2.2.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| pubspec_parse | 1.6.0 | 1.6.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| quiver | 3.2.2 | 3.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| recase | 4.1.0 | 4.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| record_use | 1.1.1 | 1.1.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| riverpod | 3.4.3 | 3.4.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| screen_retriever | 0.2.2 | 0.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| screen_retriever_linux | 0.2.2 | 0.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| screen_retriever_macos | 0.2.2 | 0.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| screen_retriever_platform_interface | 0.2.2 | 0.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| screen_retriever_windows | 0.2.2 | 0.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| shelf | 1.4.2 | 1.4.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| shelf_web_socket | 3.0.0 | 3.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| sky_engine | Flutter SDK 3.47.2 (lockfile 0.0.0) | Flutter SDK 3.47.2 (lockfile 0.0.0) | Flutter SDK; pubspec.lock | Flutter-owned SDK package. |
| source_gen | 4.3.0 | 4.3.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| source_span | 1.10.2 | 1.10.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| sqlcipher_flutter_libs | 0.7.0+eol | 0.7.0+eol | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| sqlite3_flutter_libs | 0.6.0+eol | 0.6.0+eol | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| sqlparser | 0.45.0 | 0.45.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| stack_trace | 1.12.2 | 1.12.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| state_notifier | 1.0.0 | 1.0.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| stream_channel | 2.1.4 | 2.1.4 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| stream_transform | 2.1.2 | 2.1.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| string_scanner | 1.4.1 | 1.4.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| sync_http | 0.3.1 | 0.3.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| term_glyph | 1.2.2 | 1.2.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| test_api | 0.7.12 | 0.7.12 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| typed_data | 1.4.0 | 1.4.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| url_launcher_android | 6.3.33 | 6.3.33 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| url_launcher_ios | 6.4.2 | 6.4.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| url_launcher_linux | 3.2.3 | 3.2.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| url_launcher_macos | 3.2.6 | 3.2.6 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| url_launcher_platform_interface | 2.3.2 | 2.3.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| url_launcher_web | 2.4.3 | 2.4.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| url_launcher_windows | 3.1.6 | 3.1.6 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| vector_math | 2.4.2 | 2.4.2 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| vm_service | 15.3.0 | 15.3.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| watcher | 1.2.1 | 1.2.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| web | 1.1.1 | 1.1.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| web_socket | 1.0.1 | 1.0.1 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| web_socket_channel | 3.0.3 | 3.0.3 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| webdriver | 3.1.0 | 3.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| xdg_directories | 1.1.0 | 1.1.0 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| yaml_edit | 2.2.4 | 2.2.4 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |
| zmodem | 0.0.6 | 0.0.6 | [pub.dev](https://pub.dev); pubspec.lock | Locked hosted transitive. |

### Final `flutter pub outdated --json` comparison

The machine-readable check reports six entries, all transitive. Every direct and
dev dependency is absent from the report, which is how `pub` says each one is
already at its latest stable release. All six transitive entries have
`current == upgradable == resolvable`: their newer `latest` versions are
constrained by the Flutter SDK's own package graph, transitive packages cannot
be upgraded independently, and Maestro uses no `dependency_overrides`.

| Package | Kind | Current | Upgradable | Resolvable | Latest stable | Disposition |
| --- | --- | --- | --- | --- | --- | --- |
| cli_util | transitive | 0.5.2 | 0.5.2 | 0.5.2 | 0.6.0 | SDK-constrained transitive exception. |
| code_assets | transitive | 1.2.1 | 1.2.1 | 1.2.1 | 2.0.0 | SDK-constrained transitive exception. |
| material_color_utilities | transitive | 0.13.0 | 0.13.0 | 0.13.0 | 0.13.1 | SDK-constrained transitive exception. |
| native_toolchain_c | transitive | 0.19.3 | 0.19.3 | 0.19.3 | 0.19.4 | SDK-constrained transitive exception. |
| objective_c | transitive | 9.5.0 | 9.5.0 | 9.5.0 | 9.6.0 | SDK-constrained transitive exception. |
| test_api | transitive | 0.7.12 | 0.7.12 | 0.7.12 | 0.7.14 | SDK-constrained transitive exception. |

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
| actions/checkout | `3d3c42e5aac5ba805825da76410c181273ba90b1` (v7) | v7.0.1 (v7) | `3d3c42e5aac5ba805825da76410c181273ba90b1` | [release](https://github.com/actions/checkout/releases/tag/v7.0.1), [v7 tag API](https://api.github.com/repos/actions/checkout/git/ref/tags/v7) | Current immutable revision resolves from the latest stable major tag. |
| subosito/flutter-action | `1a449444c387b1966244ae4d4f8c696479add0b2` (v2) | v2.23.0 (v2) | `1a449444c387b1966244ae4d4f8c696479add0b2` | [release](https://github.com/subosito/flutter-action/releases/tag/v2.23.0), [v2 tag API](https://api.github.com/repos/subosito/flutter-action/git/ref/tags/v2) | Current immutable revision resolves from the latest stable major tag. |
| actions/upload-artifact | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` (v7) | v7.0.1 (v7) | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | [release](https://github.com/actions/upload-artifact/releases/tag/v7.0.1), [v7 tag API](https://api.github.com/repos/actions/upload-artifact/git/ref/tags/v7) | Current immutable revision resolves from the latest stable major tag. |
| actions/download-artifact | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` (v8) | v8.0.1 (v8) | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` | [release](https://github.com/actions/download-artifact/releases/tag/v8.0.1), [v8 tag API](https://api.github.com/repos/actions/download-artifact/git/ref/tags/v8) | Current immutable revision resolves from the latest stable major tag. |
| actions/attest-build-provenance | `0f67c3f4856b2e3261c31976d6725780e5e4c373` (v4) | v4.1.1 (v4) | `0f67c3f4856b2e3261c31976d6725780e5e4c373` | [release](https://github.com/actions/attest-build-provenance/releases/tag/v4.1.1), [v4 tag API](https://api.github.com/repos/actions/attest-build-provenance/git/ref/tags/v4) | Current immutable revision resolves from the latest annotated stable major tag. |
| softprops/action-gh-release | `3d0d9888cb7fd7b750713d6e236d1fcb99157228` (v3) | v3.0.2 (v3) | `3d0d9888cb7fd7b750713d6e236d1fcb99157228` | [release](https://github.com/softprops/action-gh-release/releases/tag/v3.0.2), [v3 tag API](https://api.github.com/repos/softprops/action-gh-release/git/ref/tags/v3) | Current immutable revision resolves from the latest annotated stable major tag. |
| appimagetool x86_64 | 1.9.1 asset; SHA-256 `ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0` | 1.9.1 | 1.9.1 asset; SHA-256 `ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0` | [1.9.1 release asset](https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage) | Current packaging uses the immutable stable release asset and verifies its published digest. |

## Exact-head desktop artifacts

The four packages uploaded by CI run
[31044364973](https://github.com/artur-rios/maestro/actions/runs/31044364973)
were downloaded together and checked with
`tooling/release/verify_release.dart`. The verifier returned
`release-verification: passed` and `publisher-signing: unconfigured`.

| Artifact | Size (bytes) | SHA-256 |
| --- | ---: | --- |
| `maestro-linux-x64.AppImage` | 11,139,576 | `f5b35e73cafd80ae73ff08587bc96dee6158e741adcfad5d1a433a9af7457ece` |
| `maestro-linux-amd64.deb` | 9,112,000 | `d329a1655f03424864ec1bbd49ebfc91d0aba5e3d59505787847e43aa782989a` |
| `maestro-windows-x64.msix` | 15,621,593 | `2451b6c67e6d472e38d6a1316c3d3293085d75cae7b4eb6335f8be03aa9b631b` |
| `maestro-windows-x64.zip` | 13,623,893 | `4fdd46a1ea11f42d94069d7d93c6cb51a589fe8a84d55866e3c902736b694235` |

## Exceptions

The `build_runner`, `drift_dev`, and `drift` exceptions recorded in the previous
audit are resolved. They were all consequences of the Flutter 3.44.8 pin, whose
SDK packages held `meta` and `analyzer` below what the newer build-time
releases require. Flutter 3.47.2 lifts that constraint, so Maestro now runs
`drift 2.34.4` with `drift_dev 2.34.6` and `build_runner 2.16.1` with no
override and no compile exception in the migration-verifier path.

`build_runner 2.16` removed `--delete-conflicting-outputs`; the flag is accepted
and ignored, and the CI step no longer passes it.

AppImageTool rolling releases are excluded from stable-release selection in
favor of the immutable 1.9.1 release asset.
