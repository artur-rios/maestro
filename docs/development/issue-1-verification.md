# Issue 1 verification evidence

This record traces [issue #1](https://github.com/artur-rios/maestro/issues/1)
to the implementation and verification evidence used for review.

- Implementation SHA: `2d41a64c56e665917f8f9b5a37b58cada9438cdd`
- CI run: [31044364973](https://github.com/artur-rios/maestro/actions/runs/31044364973)
- Toolchain: Flutter 3.44.8 and Dart 3.12.2, with dependencies retained in
  `pubspec.lock`
- Dependency status: the final `flutter pub outdated --json` audit has no newer
  resolvable stable package that passes the required compatibility gates. The
  only resolver-only candidate is `drift 2.34.3`; it fails the migration
  verifier because the SDK-resolvable generator still implements the removed
  `GeneratedDatabase.allSchemaEntities` getter rather than
  `GeneratedDatabase.schema`.
- Publisher signing: unconfigured. The MSIX is test-signed for packaging
  validation; production publisher credentials are still required for a trusted
  release. Release manifests fail closed unless a configured Ed25519 signature
  verifies.

## Requirement traceability

| Requirement | Implementation | Automated evidence | Local result | CI job | Artifact |
| --- | --- | --- | --- | --- | --- |
| IR-01 | `lib/core/`, `lib/features/foundation/`, `lib/platform/`; `tooling/verify_architecture.dart` | `test/tooling/architecture_test.dart` | Architecture validator and `flutter analyze` passed | `analyze-test` | All packages consume the validated architecture |
| IR-02 | `lib/core/storage/database/database_factory.dart`, `maestro_database.dart`, `schema_versions.dart` | `database_factory_test.dart`, `maestro_database_test.dart`, `migration_test.dart` | Full 45-test suite passed | `analyze-test` | Database foundation is included in every desktop package |
| IR-03 | `lib/core/storage/application_paths.dart` | `application_paths_test.dart` | Per-user database, logs, updates, and worktree paths passed | `analyze-test` | All desktop packages |
| IR-04 | `lib/platform/process/run_execution_context.dart`, `process_supervisor.dart` | `run_execution_context_test.dart`, `concurrent_streams_integration_test.dart` | Two concurrent 1 MiB streams passed | `windows-platform`, `linux-platform` | All desktop packages |
| IR-05 | `windows_job_process_tree.dart`, `linux_group_process_tree.dart`, `native_process_tree.dart` | `process_tree_contract_test.dart`, `process_tree_integration_test.dart` | Contract and native Windows descendant cancellation passed | `analyze-test`, `windows-platform`, `linux-platform` | Native Windows and Linux packages |
| IR-06 | `reconcile_resources.dart`, `drift_owned_resource_store.dart`, `local_owned_resource_cleaner.dart` | `reconcile_resources_test.dart` | Durable-state reconciliation cases passed | `analyze-test` | All desktop packages |
| IR-07 | `lib/core/storage/owned_path_policy.dart` | `owned_path_policy_test.dart`, `reconcile_resources_test.dart` | Source-protection and fail-closed cleanup cases passed | `analyze-test` | All desktop packages |
| IR-08 | Typed ports under `lib/platform/{agents,auth,git,github,terminal,updates}/` | `executable_probe_test.dart`, protected-storage and update contract tests | Adapter and capability contracts passed | `analyze-test` | All desktop packages |
| IR-09 | `.github/workflows/ci.yml` | Unit, widget, migration, integration, performance, and native platform suites | Full local suite and three Windows integration targets passed | `analyze-test`, `windows-platform`, `linux-platform` | CI uploads both platform artifact sets |
| IR-10 | Native runner jobs in `.github/workflows/ci.yml` and `.github/workflows/release.yml` | Native release-build steps | Windows release build passed locally | `windows-platform`, `linux-platform` | Windows artifacts build on Windows; Linux artifacts build on Ubuntu |
| IR-11 | `tooling/release/{create_manifest,sign_manifest,verify_release}.dart`; release attestations | `release_manifest_test.dart` and release verifier | Manifest, checksum, and signature-policy verification passed | Release workflow `verify`, `attest`, and `release` jobs | `release-manifest.json`, `SHA256SUMS`, GitHub attestations, and `release-manifest.sig` when signing is configured |
| IR-12 | `tooling/packaging/package_windows.ps1` | `windows_install_update.ps1` | ZIP/MSIX creation and portable update-staging smoke passed | `windows-platform` | `maestro-windows-x64.zip`, `maestro-windows-x64.msix` |
| IR-13 | `tooling/packaging/package_linux.sh` | `linux_install_update.sh` | Exercised on the Ubuntu runner | `linux-platform` | `maestro-linux-x64.AppImage`, `maestro-linux-amd64.deb` |
| IR-14 | `.fvmrc`, `pubspec.lock`, pinned actions and appimagetool digest | Generated-code, workflow, and lockfile checks | Clean dependency resolution and generated-code diff passed | All CI jobs | Toolchain and lockfile remain in the source revision attached to each release |
| IR-15 | `update_service.dart`, `update_downloader.dart`, platform package installers, replacement scripts | `update_service_test.dart`, `manifest_verifier_test.dart`, `package_installer_contract_test.dart`, platform smoke scripts | Approval, digest, size-limit, and Windows portable-update cases passed | `analyze-test`, `windows-platform`, `linux-platform` | ZIP, MSIX, AppImage, and DEB update paths |

## Verification commands

The following gates passed from the feature worktree before push:

```text
flutter pub get
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
dart run tooling/verify_architecture.dart
dart run tooling/verify_workflows.dart
flutter analyze
flutter test                              # 45 tests passed
flutter test integration_test/platform/process_tree_integration_test.dart -d windows
flutter test integration_test/foundation_startup_integration_test.dart -d windows
flutter test integration_test/performance/concurrent_streams_integration_test.dart -d windows
flutter build windows --release
tooling/packaging/package_windows.ps1
tooling/smoke/windows_install_update.ps1
dart run tooling/release/verify_release.dart dist
```

The CI run passed the platform-independent gates on Ubuntu, ran native
integration tests and release builds on their matching Windows and Ubuntu
runners, packaged all four installation types, and executed install/update
smoke tests before uploading artifacts.

## Downloaded artifact verification

The artifacts from CI run 31044364973 were downloaded together, a release
manifest was generated, and `tooling/release/verify_release.dart` returned
`release-verification: passed` with `publisher-signing: unconfigured`.

| Artifact | SHA-256 |
| --- | --- |
| `maestro-linux-x64.AppImage` | `f5b35e73cafd80ae73ff08587bc96dee6158e741adcfad5d1a433a9af7457ece` |
| `maestro-linux-amd64.deb` | `d329a1655f03424864ec1bbd49ebfc91d0aba5e3d59505787847e43aa782989a` |
| `maestro-windows-x64.msix` | `2451b6c67e6d472e38d6a1316c3d3293085d75cae7b4eb6335f8be03aa9b631b` |
| `maestro-windows-x64.zip` | `4fdd46a1ea11f42d94069d7d93c6cb51a589fe8a84d55866e3c902736b694235` |

## Supply-chain pins

| Dependency | Selected immutable version or digest |
| --- | --- |
| `actions/checkout` | `3d3c42e5aac5ba805825da76410c181273ba90b1` (v7) |
| `subosito/flutter-action` | `1a449444c387b1966244ae4d4f8c696479add0b2` (v2) |
| `actions/upload-artifact` | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` (v7) |
| `actions/download-artifact` | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` (v8) |
| `actions/attest-build-provenance` | `0f67c3f4856b2e3261c31976d6725780e5e4c373` (v4) |
| `softprops/action-gh-release` | `3d0d9888cb7fd7b750713d6e236d1fcb99157228` (v3) |
| `appimagetool-x86_64.AppImage` | 1.9.1; SHA-256 `ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0` |
