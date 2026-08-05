# Issue 1 verification evidence

This record traces [issue #1](https://github.com/artur-rios/maestro/issues/1)
to the implementation and verification evidence used for review.

- Implementation SHA: `29cfbc177e73425e7c927040db0a1b0bc14a6b68`
- CI run: [31031548104](https://github.com/artur-rios/maestro/actions/runs/31031548104)
- Toolchain: Flutter 3.44.8 and Dart 3.12.2, with dependencies retained in
  `pubspec.lock`
- Publisher signing: unconfigured. The MSIX is test-signed for packaging
  validation; production publisher credentials are still required for a trusted
  release. Release manifests fail closed unless a configured Ed25519 signature
  verifies.

## Requirement traceability

| Requirement | Implementation | Automated evidence | Local result | CI job | Artifact |
| --- | --- | --- | --- | --- | --- |
| IR-01 | `lib/core/`, `lib/features/foundation/`, `lib/platform/`; `tooling/verify_architecture.dart` | `test/tooling/architecture_test.dart` | Architecture validator and `flutter analyze` passed | `analyze-test` | All packages consume the validated architecture |
| IR-02 | `lib/core/storage/database/database_factory.dart`, `maestro_database.dart`, `schema_versions.dart` | `database_factory_test.dart`, `maestro_database_test.dart`, `migration_test.dart` | Full 39-test suite passed | `analyze-test` | Database foundation is included in every desktop package |
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
flutter test                              # 39 tests passed
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

The artifacts from CI run 31031548104 were downloaded together, a release
manifest was generated, and `tooling/release/verify_release.dart` returned
`release-verification: passed` with `publisher-signing: unconfigured`.

| Artifact | SHA-256 |
| --- | --- |
| `maestro-linux-x64.AppImage` | `b5fb64ef91b0af51eb292e2341bc27167b8a971c7c3476a8e72d70771975e96e` |
| `maestro-linux-amd64.deb` | `4a8b7f3fed1901cc2a7a2a0bcac3c1ccbe2d8da7b58d5d4b3c0a282425e44b80` |
| `maestro-windows-x64.msix` | `12b2564dd660722a02fc879066edc07d60fdcff7de8b94e21b86708800b96764` |
| `maestro-windows-x64.zip` | `9ef5bc06550c2a8dd4d12006edfdc0494b586e8e97fbe39e63d9b52c26e31faf` |
