# Maestro Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver issue #1 as a tested Windows/Linux Flutter desktop foundation with isolated runtime infrastructure, native process-tree control, reproducible packages, and verified update delivery.

**Architecture:** Build one feature-first Flutter package whose domain and application contracts are implemented by data and platform adapters. Keep SQLite off the UI isolate, isolate each future run behind an execution context, and restrict native integration to typed process, PTY, credential, package-installer, and update boundaries.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, Riverpod, Drift/SQLite, xterm/flutter_pty, flutter_secure_storage, sodium, Dart FFI, GitHub Actions, MSIX, AppImage, and Debian packaging.

## Global Constraints

- Target Windows and Linux desktop only.
- Pin Flutter 3.44.8 stable and Dart 3.12.2; commit `pubspec.lock`.
- Preserve `dev.artur-rios.maestro` as public identity; use `dev.artur_rios.maestro` only where identifier grammar forbids hyphens.
- Keep domain and application layers free of Flutter, Drift, process, command-line, and platform imports.
- Keep every in-memory log buffer bounded and redact secrets before display or persistence.
- Never delete or recursively clean a configured project source directory.
- Treat a resource as Maestro-owned only when durable ownership metadata proves it.
- Support at least two independently supervised run contexts.
- Require explicit user approval before invoking any update installer.
- Emit SHA-256 checksums and GitHub artifact attestations; fail publisher signing closed when credentials are configured but invalid.
- Use Given-When-Then test names and hand-written fakes.
- Make each task pass its focused tests before committing it.

---

## File Map

| Area | Files | Responsibility |
| --- | --- | --- |
| Toolchain/app | `.flutter-version`, `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/app/maestro_app.dart` | Reproducible desktop scaffold and composition root |
| Core | `lib/core/errors/*`, `lib/core/logging/*`, `lib/core/storage/*` | Results, failures, redaction, paths, bounded streams |
| Foundation feature | `lib/features/foundation/{domain,application,data,presentation}/*` | Startup state, bootstrap orchestration, diagnostics UI |
| Database | `lib/core/storage/database/*` | Drift schema, migrations, background isolate |
| Platform contracts | `lib/platform/*/*_port.dart`, `lib/platform/*/*_adapter.dart` | Typed external-system boundaries and probes |
| Execution | `lib/platform/process/*`, `lib/platform/terminal/*` | Run context, Job Objects/process groups, PTY lifecycle |
| Recovery | `lib/features/foundation/application/reconcile_resources.dart`, `lib/core/storage/owned_path_policy.dart` | Durable reconciliation and source protection |
| Updates | `lib/platform/updates/*`, `tooling/update/*` | Manifest verification, staging, approval, installers |
| Packaging | `tooling/packaging/*`, `tooling/release/*` | ZIP, MSIX, AppImage, `.deb`, checksums, signatures |
| Automation | `.github/workflows/ci.yml`, `.github/workflows/release.yml` | Matching-runner verification and publication |
| Documentation | `README.md`, `docs/development/*` | Clean-clone build, test, package, update, and signing guidance |

## Requirement-to-Task Map

| Requirement | Implemented by |
| --- | --- |
| IR-01 | Tasks 1, 5, and 12 |
| IR-02 | Task 3 |
| IR-03 | Tasks 2 and 3 |
| IR-04 | Task 6 |
| IR-05 | Task 7 |
| IR-06 | Task 8 |
| IR-07 | Tasks 2 and 8 |
| IR-08 | Tasks 5, 7, 9, and 10 |
| IR-09 | Tasks 3–13 |
| IR-10 | Tasks 11–13 |
| IR-11 | Tasks 9, 11, and 12 |
| IR-12 | Tasks 10–13 |
| IR-13 | Tasks 10–13 |
| IR-14 | Tasks 1 and 12 |
| IR-15 | Tasks 9–13 |

### Task 1: Create the pinned desktop scaffold and app shell

**Files:**
- Create: `.flutter-version`
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `lib/main.dart`
- Create: `lib/app/maestro_app.dart`
- Create: `test/app/maestro_app_test.dart`
- Generate: `.metadata`, `windows/**`, `linux/**`
- Modify: `windows/runner/Runner.rc`
- Modify: `linux/CMakeLists.txt`

**Interfaces:**
- Produces: `class MaestroApp extends StatelessWidget`
- Produces: `const MaestroApp({super.key})`

- [ ] **Step 1: Generate only the supported desktop hosts**

Run:

```powershell
& 'C:\Program Files\Flutter\flutter\bin\flutter.bat' create --platforms=windows,linux --org dev.artur_rios --project-name maestro .
```

Expected: Flutter creates Windows/Linux hosts without Android, iOS, macOS, or web directories.

- [ ] **Step 2: Pin the toolchain and resolve foundation dependencies**

Write `.flutter-version` as:

```text
3.44.8
```

Run:

```powershell
& 'C:\Program Files\Flutter\flutter\bin\flutter.bat' pub add flutter_riverpod drift drift_flutter sqlite3 xterm flutter_pty flutter_secure_storage sodium sodium_libs uuid path_provider package_info_plus logging path crypto archive win32 ffi
& 'C:\Program Files\Flutter\flutter\bin\flutter.bat' pub add --dev drift_dev build_runner test msix
```

Expected: `pubspec.lock` records concrete releases compatible with Flutter 3.44.8.
Add the SDK-owned integration framework explicitly to `dev_dependencies`:

```yaml
integration_test:
  sdk: flutter
```

- [ ] **Step 3: Write the failing shell test**

```dart
testWidgets('GivenAppStart_WhenRendered_ThenFoundationShellIsVisible', (tester) async {
  await tester.pumpWidget(const MaestroApp());
  expect(find.text('Maestro'), findsOneWidget);
  expect(find.bySemanticsLabel('Foundation status'), findsOneWidget);
});
```

- [ ] **Step 4: Run the focused test and verify the red state**

Run: `flutter test test/app/maestro_app_test.dart`

Expected: FAIL because `MaestroApp` and its foundation status semantics do not exist.

- [ ] **Step 5: Add the minimal accessible application shell**

```dart
class MaestroApp extends StatelessWidget {
  const MaestroApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Maestro',
        home: Scaffold(
          appBar: AppBar(title: const Text('Maestro')),
          body: const Semantics(
            label: 'Foundation status',
            child: Center(child: Text('Initializing foundation')),
          ),
        ),
      );
}
```

Set public package metadata to `dev.artur-rios.maestro` in Windows/Linux package resources while retaining sanitized native namespaces.

- [ ] **Step 6: Verify scaffold quality**

Run:

```powershell
flutter test test/app/maestro_app_test.dart
dart format --output=none --set-exit-if-changed lib test
flutter analyze
```

Expected: focused test passes; formatting and analysis exit 0.

- [ ] **Step 7: Commit the scaffold**

```powershell
git add .flutter-version pubspec.yaml pubspec.lock analysis_options.yaml .metadata lib test windows linux
git commit -m "feat: scaffold maestro desktop app"
```

### Task 2: Establish typed failures, redaction, and application paths

**Files:**
- Create: `lib/core/errors/failure.dart`
- Create: `lib/core/errors/result.dart`
- Create: `lib/core/logging/secret_redactor.dart`
- Create: `lib/core/storage/application_paths.dart`
- Create: `test/core/logging/secret_redactor_test.dart`
- Create: `test/core/storage/application_paths_test.dart`

**Interfaces:**
- Produces: `sealed class Result<T>`, `Success<T>`, `FailureResult<T>`
- Produces: `sealed class MaestroFailure`
- Produces: `String SecretRedactor.redact(String input, {Map<String, String> environment = const {}})`
- Produces: `ApplicationPaths.fromRoot(Directory root)` with `databaseFile`, `logsDirectory`, `updatesDirectory`, and `worktreesDirectory`

- [ ] **Step 1: Write failing redaction and path-policy tests**

```dart
test('GivenCredentials_WhenRedacting_ThenSecretsAreAbsent', () {
  final value = SecretRedactor().redact(
    'Authorization: Bearer abc password=hunter2 TOKEN=xyz',
    environment: {'TOKEN': 'xyz'},
  );
  expect(value, isNot(contains('abc')));
  expect(value, isNot(contains('hunter2')));
  expect(value, isNot(contains('xyz')));
});

test('GivenRoot_WhenBuildingPaths_ThenEveryPathStaysUnderRoot', () {
  final root = Directory(p.join('tmp', 'maestro-user'));
  final paths = ApplicationPaths.fromRoot(root);
  for (final path in paths.all) {
    expect(p.isWithin(root.path, path), isTrue);
  }
});
```

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `flutter test test/core/logging test/core/storage/application_paths_test.dart`

Expected: FAIL because the redactor and path model are undefined.

- [ ] **Step 3: Implement immutable results, failures, redaction, and paths**

Use exhaustive sealed types:

```dart
sealed class Result<T> { const Result(); }
final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}
final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final MaestroFailure failure;
}
```

Normalize every derived path with `package:path`, reject traversal outside the root, and replace authorization headers, password assignments, token assignments, and exact environment secret values with `[REDACTED]`.

- [ ] **Step 4: Verify focused and core tests**

Run: `flutter test test/core`

Expected: all core tests pass.

- [ ] **Step 5: Commit core primitives**

```powershell
git add lib/core test/core
git commit -m "feat: add safe core primitives"
```

### Task 3: Add background-isolate SQLite and verified migrations

**Files:**
- Create: `lib/core/storage/database/maestro_database.dart`
- Create: `lib/core/storage/database/maestro_database.g.dart`
- Create: `lib/core/storage/database/database_factory.dart`
- Create: `lib/core/storage/database/schema_versions.dart`
- Create: `test/core/storage/database/maestro_database_test.dart`
- Create: `test/core/storage/database/migration_test.dart`

**Interfaces:**
- Produces: `Future<MaestroDatabase> DatabaseFactory.open(ApplicationPaths paths)`
- Produces: `MaestroDatabase(QueryExecutor executor)`
- Produces tables: `settings`, `diagnostic_log_segments`, `owned_resources`

- [ ] **Step 1: Write failing database behavior tests**

```dart
test('GivenNewDatabase_WhenOpened_ThenFoundationTablesAreUsable', () async {
  final database = MaestroDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  await database.into(database.settings).insert(
    SettingsCompanion.insert(key: 'retentionDays', value: '30'),
  );
  expect(await database.select(database.settings).getSingle(), isNotNull);
});

test('GivenVersionOneDatabase_WhenMigrated_ThenExistingSettingsRemain', () async {
  final result = await migrationHarness.migrateFrom(1, currentSchemaVersion);
  expect(result.settings['retentionDays'], '30');
  expect(result.integrityCheck, 'ok');
});
```

- [ ] **Step 2: Run tests and verify the red state**

Run: `flutter test test/core/storage/database`

Expected: FAIL because schema, companions, and migration harness do not exist.

- [ ] **Step 3: Define the schema and background factory**

Use Drift table primary keys and UTC microsecond timestamps. Open production storage with `driftDatabase(name: 'maestro')` and `DriftIsolate.spawn`/`connect` so query execution is outside the UI isolate. Run `PRAGMA integrity_check` after migrations and return a blocking `StorageFailure` if it is not `ok`.

- [ ] **Step 4: Generate schema code and migration fixtures**

Run:

```powershell
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/core/storage/database/maestro_database.dart test/fixtures/schema
```

Expected: generated code and schema snapshot are deterministic.

- [ ] **Step 5: Verify database and migration behavior**

Run: `flutter test test/core/storage/database`

Expected: new-database, migration, rollback, and integrity tests pass.

- [ ] **Step 6: Commit persistence foundation**

```powershell
git add lib/core/storage/database test/core/storage/database test/fixtures/schema
git commit -m "feat: add isolated sqlite foundation"
```

### Task 4: Implement observable application bootstrap and diagnostics

**Files:**
- Create: `lib/features/foundation/domain/foundation_status.dart`
- Create: `lib/features/foundation/application/foundation_probe.dart`
- Create: `lib/features/foundation/application/bootstrap_foundation.dart`
- Create: `lib/features/foundation/presentation/foundation_controller.dart`
- Create: `lib/features/foundation/presentation/foundation_page.dart`
- Modify: `lib/app/maestro_app.dart`
- Create: `test/features/foundation/application/bootstrap_foundation_test.dart`
- Create: `test/features/foundation/presentation/foundation_page_test.dart`
- Create: `test_support/fakes/fake_foundation_probe.dart`

**Interfaces:**
- Produces: `enum FoundationHealth { ready, degraded, blocked }`
- Produces: `record FoundationCheck(String id, FoundationHealth health, String message, String? remediation)`
- Produces: `Future<FoundationReport> BootstrapFoundation.call()`

- [ ] **Step 1: Write failing orchestration and widget tests**

```dart
test('GivenOptionalProbeFailure_WhenBootstrapping_ThenReportIsDegraded', () async {
  final report = await BootstrapFoundation([
    FakeFoundationProbe.ready('database'),
    FakeFoundationProbe.degraded('codex', 'Sign in to Codex'),
  ])();
  expect(report.health, FoundationHealth.degraded);
  expect(report.checks, hasLength(2));
});

testWidgets('GivenDegradedFoundation_WhenRendered_ThenRemediationIsVisible', (tester) async {
  await tester.pumpWidget(testApp(report: degradedReport));
  expect(find.text('Sign in to Codex'), findsOneWidget);
  expect(find.bySemanticsLabel('Foundation degraded'), findsOneWidget);
});
```

- [ ] **Step 2: Run focused tests and verify failure**

Run: `flutter test test/features/foundation`

Expected: FAIL because the report, bootstrap service, controller, and page are absent.

- [ ] **Step 3: Implement ordered bootstrap and Riverpod composition**

Run probes in the approved order: paths, logging, settings, protected storage, database, platform capabilities, reconciliation. Accumulate optional failures; stop dependent stages after a blocking failure. Expose one `AsyncNotifier<FoundationReport>` and render loading, ready, degraded, and blocked states with keyboard-focusable remediation controls.

- [ ] **Step 4: Verify foundation tests**

Run: `flutter test test/features/foundation test/app`

Expected: all bootstrap and widget states pass.

- [ ] **Step 5: Commit bootstrap diagnostics**

```powershell
git add lib/app lib/features/foundation test/app test/features/foundation test_support/fakes
git commit -m "feat: add foundation diagnostics"
```

### Task 5: Scaffold typed external adapters and capability probes

**Files:**
- Create: `lib/platform/common/capability.dart`
- Create: `lib/platform/common/command_runner.dart`
- Create: `lib/platform/git/git_port.dart`
- Create: `lib/platform/github/github_port.dart`
- Create: `lib/platform/agents/agent_cli_port.dart`
- Create: `lib/platform/auth/authentication_port.dart`
- Create: `lib/platform/terminal/terminal_port.dart`
- Create: `lib/platform/updates/update_port.dart`
- Create: `lib/platform/common/executable_probe.dart`
- Create: `test/platform/common/executable_probe_test.dart`
- Create: `test_support/fakes/fake_command_runner.dart`

**Interfaces:**
- Produces: `enum CapabilityState { available, missing, unauthenticated, incompatible, denied, malformed, unsupported, transientFailure }`
- Produces: `Future<Capability> CapabilityProbe.probe()`
- Produces: `Future<CommandResult> CommandRunner.run(CommandRequest request)`
- Produces: `AgentCliKind { claudeCode, codex, openCode }`

- [ ] **Step 1: Write failing executable-probe contract cases**

```dart
test('GivenMissingExecutable_WhenProbed_ThenCapabilityIsMissing', () async {
  final probe = ExecutableProbe(fakeRunner.missing('codex'), command: 'codex');
  expect((await probe.probe()).state, CapabilityState.missing);
});

test('GivenMalformedVersion_WhenProbed_ThenCapabilityIsMalformed', () async {
  final probe = ExecutableProbe(fakeRunner.stdout('unexpected'), command: 'opencode');
  expect((await probe.probe()).state, CapabilityState.malformed);
});
```

- [ ] **Step 2: Run the contract test and verify failure**

Run: `flutter test test/platform/common/executable_probe_test.dart`

Expected: FAIL because typed capabilities and command boundaries are absent.

- [ ] **Step 3: Implement contracts, probes, and fakes**

Represent commands as executable plus argument list, working directory, allowlisted environment, and timeout. Never construct a shell command string. Add harmless version/auth probes for Git, `gh`, Claude Code, Codex, and OpenCode; classify exit codes and parsing failures without throwing for routine unavailability.

- [ ] **Step 4: Verify every adapter contract**

Run: `flutter test test/platform`

Expected: missing, unauthenticated, incompatible, denied, malformed, unsupported, timeout, and success cases pass.

- [ ] **Step 5: Commit platform boundaries**

```powershell
git add lib/platform test/platform test_support/fakes
git commit -m "feat: add typed platform adapters"
```

### Task 6: Add isolated run contexts and bounded ordered logging

**Files:**
- Create: `lib/platform/process/run_execution_context.dart`
- Create: `lib/platform/process/process_supervisor.dart`
- Create: `lib/core/logging/bounded_log_buffer.dart`
- Create: `lib/core/logging/durable_log_sink.dart`
- Create: `test/platform/process/run_execution_context_test.dart`
- Create: `test/core/logging/bounded_log_buffer_test.dart`

**Interfaces:**
- Produces: `RunExecutionContext.create({required UuidValue runId, required Directory workingDirectory, required Map<String, String> environment})`
- Produces: `Future<ProcessOutcome> ProcessSupervisor.cancel()`
- Produces: `Stream<LogBatch> BoundedLogBuffer.stream`
- Produces: `Future<void> DurableLogSink.append(LogBatch batch)`

- [ ] **Step 1: Write failing concurrency and backpressure tests**

```dart
test('GivenTwoRuns_WhenCreated_ThenSupervisorsAndEnvironmentsAreIndependent', () {
  final first = contextBuilder.create(runId: firstId, environment: {'RUN': 'one'});
  final second = contextBuilder.create(runId: secondId, environment: {'RUN': 'two'});
  expect(first.supervisor, isNot(same(second.supervisor)));
  expect(first.environment['RUN'], 'one');
  expect(second.environment['RUN'], 'two');
});

test('GivenOutputBeyondMemoryLimit_WhenBuffered_ThenBytesStayOrderedAndBounded', () async {
  final buffer = BoundedLogBuffer(maxBytes: 1024, sink: fakeSink);
  await buffer.add(List.filled(4096, 65));
  expect(buffer.inMemoryBytes, lessThanOrEqualTo(1024));
  expect(fakeSink.joinedBytes, orderedOriginalBytes);
});
```

- [ ] **Step 2: Run focused tests and verify failure**

Run: `flutter test test/platform/process/run_execution_context_test.dart test/core/logging/bounded_log_buffer_test.dart`

Expected: FAIL because execution contexts and bounded buffers do not exist.

- [ ] **Step 3: Implement isolation and bounded batching**

Copy and freeze each environment map, create a supervisor and cancellation token per context, sequence every output chunk monotonically, flush on byte threshold or short timer, and spill overflow to the durable sink before releasing memory. Preserve undecodable bytes and derive display text with replacement characters.

- [ ] **Step 4: Verify concurrency, ordering, and redaction**

Run: `flutter test test/platform/process test/core/logging`

Expected: two-run isolation, idempotent cancellation, bounded memory, durable ordering, and pre-sink redaction pass.

- [ ] **Step 5: Commit execution contexts**

```powershell
git add lib/platform/process lib/core/logging test/platform/process test/core/logging
git commit -m "feat: add isolated run contexts"
```

### Task 7: Implement whole-process-tree ownership on Windows and Linux

**Files:**
- Create: `lib/platform/process/native_process_tree.dart`
- Create: `lib/platform/process/windows_job_process_tree.dart`
- Create: `lib/platform/process/linux_group_process_tree.dart`
- Create: `lib/platform/process/process_tree_factory.dart`
- Create: `test/platform/process/process_tree_contract.dart`
- Create: `integration_test/platform/process_tree_integration_test.dart`
- Create: `test_support/fixtures/process_tree_child.dart`

**Interfaces:**
- Produces: `Future<OwnedProcess> NativeProcessTree.start(ProcessStartRequest request)`
- Produces: `Future<ProcessOutcome> OwnedProcess.terminateTree()`
- Consumes: `CommandRequest` and `SecretRedactor`

- [ ] **Step 1: Write the platform contract and failing descendant test**

```dart
testWidgets('GivenParentWithChild_WhenTreeIsCancelled_ThenBothExit', (tester) async {
  final tree = ProcessTreeFactory.current();
  final owned = await tree.start(fixtureParentRequest);
  final childPid = await fixture.waitForChildPid(owned);
  await owned.terminateTree();
  expect(await processProbe.isAlive(owned.pid), isFalse);
  expect(await processProbe.isAlive(childPid), isFalse);
});
```

- [ ] **Step 2: Run on the current Windows target and verify failure**

Run: `flutter test integration_test/platform/process_tree_integration_test.dart -d windows`

Expected: FAIL because the Windows Job Object implementation is absent.

- [ ] **Step 3: Implement native ownership**

On Windows, create one Job Object per owned process, set `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`, assign the spawned process immediately, and retain the handle until terminal outcome. On Linux, launch a group leader with `setpgid(0, 0)` and cancel using `killpg` with bounded TERM-to-KILL escalation. Return a termination failure until every known descendant has exited.

- [ ] **Step 4: Verify native lifecycle scenarios**

Run on each matching OS:

```text
flutter test integration_test/platform/process_tree_integration_test.dart -d windows
flutter test integration_test/platform/process_tree_integration_test.dart -d linux
```

Expected: normal completion, descendant cancellation, repeated cancellation, startup failure, and resistant-child escalation pass.

- [ ] **Step 5: Commit process-tree control**

```powershell
git add lib/platform/process test/platform/process integration_test/platform test_support/fixtures
git commit -m "feat: supervise native process trees"
```

### Task 8: Reconcile owned resources without touching source projects

**Files:**
- Create: `lib/core/storage/owned_path_policy.dart`
- Create: `lib/features/foundation/application/reconcile_resources.dart`
- Create: `lib/features/foundation/domain/reconciliation_report.dart`
- Create: `test/core/storage/owned_path_policy_test.dart`
- Create: `test/features/foundation/application/reconcile_resources_test.dart`

**Interfaces:**
- Produces: `OwnershipDecision OwnedPathPolicy.evaluate(String candidate)`
- Produces: `Future<ReconciliationReport> ReconcileResources.call()`
- Consumes: `OwnedResources` Drift table and `NativeProcessTree`

- [ ] **Step 1: Write failing protection and ordering tests**

```dart
test('GivenSourceFolder_WhenCleanupRequested_ThenDeletionIsDenied', () {
  final policy = OwnedPathPolicy(appPaths: paths, sourcePaths: [source.path]);
  expect(policy.evaluate(source.path), OwnershipDecision.protectedSource);
});

test('GivenStaleWorktree_WhenRunStateIsActive_ThenWorktreeIsNotRemoved', () async {
  final report = await reconciler(records: [staleWorktree], runs: [activeRun])();
  expect(report.removed, isEmpty);
  expect(fakeFileSystem.exists(staleWorktree.path), isTrue);
});
```

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/core/storage/owned_path_policy_test.dart test/features/foundation/application/reconcile_resources_test.dart`

Expected: FAIL because path ownership and reconciliation are absent.

- [ ] **Step 3: Implement fail-closed ownership and reconciliation**

Canonicalize paths, reject filesystem roots and app/source ancestors, require candidates to be descendants of Maestro's worktree/update directories, and require a matching durable ownership record. Reconcile run state before process or worktree cleanup; retain failed cleanup records with typed remediation.

- [ ] **Step 4: Verify cleanup invariants**

Run: `flutter test test/core/storage test/features/foundation/application/reconcile_resources_test.dart`

Expected: source, symlink/junction escape, unknown ownership, active run, duplicate cleanup, and safe stale-resource cases pass.

- [ ] **Step 5: Commit recovery safeguards**

```powershell
git add lib/core/storage lib/features/foundation test/core/storage test/features/foundation
git commit -m "feat: reconcile owned resources safely"
```

### Task 9: Add protected storage and signed update manifests

**Files:**
- Create: `lib/core/security/protected_storage.dart`
- Create: `lib/core/security/platform_protected_storage.dart`
- Create: `lib/platform/updates/release_manifest.dart`
- Create: `lib/platform/updates/manifest_verifier.dart`
- Create: `test/core/security/protected_storage_contract.dart`
- Create: `test/platform/updates/manifest_verifier_test.dart`
- Create: `test_support/fixtures/updates/{trusted_public_key,tampered_manifest,signed_manifest}.json`

**Interfaces:**
- Produces: `Future<void> ProtectedStorage.write(String key, Uint8List value)`
- Produces: `Future<Uint8List?> ProtectedStorage.read(String key)`
- Produces: `Result<VerifiedReleaseManifest> ManifestVerifier.verify(Uint8List manifest, Uint8List signature)`

- [ ] **Step 1: Write failing secret and tamper tests**

```dart
test('GivenStoredSecret_WhenReadBack_ThenPlaintextNeverEntersDatabaseOrLogs', () async {
  await storage.write('update-key', secret);
  expect(await storage.read('update-key'), secret);
  expect(fakeDatabase.allText, isNot(contains(utf8.decode(secret))));
  expect(fakeLogger.allText, isNot(contains(utf8.decode(secret))));
});

test('GivenTamperedManifest_WhenVerified_ThenUpdateIsRejected', () {
  final result = verifier.verify(tamperedManifest, trustedSignature);
  expect(result, isA<FailureResult<VerifiedReleaseManifest>>());
});
```

- [ ] **Step 2: Run focused tests and verify failure**

Run: `flutter test test/core/security test/platform/updates/manifest_verifier_test.dart`

Expected: FAIL because protected storage and signature verification are absent.

- [ ] **Step 3: Implement secure storage and canonical verification**

Store bytes through `flutter_secure_storage`, base64-encoding only at that boundary. Define canonical UTF-8 JSON with sorted keys and no insignificant whitespace. Verify Ed25519 signatures with sodium before parsing artifact URLs, then validate version, platform, architecture, package type, byte size, and SHA-256 digest.

- [ ] **Step 4: Verify security contracts**

Run: `flutter test test/core/security test/platform/updates`

Expected: trusted, tampered, wrong-platform, wrong-architecture, wrong-package, expired-key, and secret-redaction cases pass.

- [ ] **Step 5: Commit protected update trust**

```powershell
git add lib/core/security lib/platform/updates test/core/security test/platform/updates test_support/fixtures/updates
git commit -m "feat: verify trusted update manifests"
```

### Task 10: Implement approved update checks, staging, and installers

**Files:**
- Create: `lib/platform/updates/update_service.dart`
- Create: `lib/platform/updates/update_approval.dart`
- Create: `lib/platform/updates/update_downloader.dart`
- Create: `lib/platform/updates/package_installer.dart`
- Create: `lib/platform/updates/windows_package_installer.dart`
- Create: `lib/platform/updates/linux_package_installer.dart`
- Create: `tooling/update/replace_windows_zip.ps1`
- Create: `tooling/update/replace_appimage.sh`
- Create: `test/platform/updates/update_service_test.dart`
- Create: `test/platform/updates/package_installer_contract.dart`

**Interfaces:**
- Produces: `Future<Result<UpdateCandidate?>> UpdateService.check(UpdateCheckReason reason)`
- Produces: `Future<Result<UpdateOutcome>> UpdateService.install(UpdateCandidate candidate, UpdateApproval approval)`
- Produces: `Future<Result<void>> PackageInstaller.install(StagedUpdate update)`

- [ ] **Step 1: Write failing approval and selection tests**

```dart
test('GivenMatchingUpdate_WhenApprovalIsDenied_ThenInstallerIsNotInvoked', () async {
  final outcome = await service.install(candidate, UpdateApproval.denied);
  expect(outcome, isA<FailureResult<UpdateOutcome>>());
  expect(fakeInstaller.calls, isEmpty);
});

test('GivenMultipleArtifacts_WhenChecking_ThenInstalledPackageTypeIsSelected', () async {
  final candidate = await service.check(UpdateCheckReason.manual);
  expect(candidate.value!.artifact.packageType, installedPackageType);
});
```

- [ ] **Step 2: Run focused tests and verify failure**

Run: `flutter test test/platform/updates/update_service_test.dart test/platform/updates/package_installer_contract.dart`

Expected: FAIL because update orchestration and installers are absent.

- [ ] **Step 3: Implement the non-blocking update pipeline**

Schedule checks with an injectable clock; download to `ApplicationPaths.updatesDirectory`; enforce byte limit while streaming; verify signature and digest; require an approval value tied to the verified candidate digest; invoke only the matching installer. Use MSIX deployment APIs for MSIX, a detached replacement helper for ZIP, verified atomic AppImage replacement, and `pkexec` plus the platform package manager for `.deb`.

- [ ] **Step 4: Verify updater behavior**

Run: `flutter test test/platform/updates`

Expected: manual/scheduled checks, no-update, network loss, oversized download, tamper rejection, approval denial, installer failure, and preserved data-root cases pass.

- [ ] **Step 5: Commit update engine**

```powershell
git add lib/platform/updates tooling/update test/platform/updates
git commit -m "feat: add approved update engine"
```

### Task 11: Build reproducible Windows and Linux packages

**Files:**
- Create: `tooling/packaging/package_windows.ps1`
- Create: `tooling/packaging/package_linux.sh`
- Create: `tooling/packaging/maestro.desktop`
- Create: `tooling/packaging/debian/control`
- Create: `tooling/release/create_manifest.dart`
- Create: `tooling/release/sign_manifest.dart`
- Create: `tooling/release/verify_release.dart`
- Create: `test/tooling/release_manifest_test.dart`

**Interfaces:**
- Produces: `dist/maestro-windows-x64.zip`, `dist/maestro-windows-x64.msix`
- Produces: `dist/maestro-linux-x64.AppImage`, `dist/maestro-linux-amd64.deb`
- Produces: `dist/release-manifest.json`, `.sig`, and `SHA256SUMS`

- [ ] **Step 1: Write the failing release-manifest test**

```dart
test('GivenFourArtifacts_WhenManifestCreated_ThenEveryDigestAndSizeMatches', () async {
  final manifest = await createManifest(fourFixtureArtifacts);
  expect(manifest.artifacts, hasLength(4));
  for (final artifact in manifest.artifacts) {
    expect(artifact.sha256, await sha256Of(artifact.file));
    expect(artifact.size, await artifact.file.length());
  }
});
```

- [ ] **Step 2: Run the focused test and verify failure**

Run: `flutter test test/tooling/release_manifest_test.dart`

Expected: FAIL because deterministic manifest creation is absent.

- [ ] **Step 3: Implement packaging and release verification**

Windows script builds release mode, copies the complete runner bundle and VC++ runtime into a ZIP, then invokes MSIX packaging with `dev.artur-rios.maestro` metadata. Linux script builds release mode, stages the bundle with `.desktop` metadata, invokes pinned `appimagetool`, and builds a Debian package with `dpkg-deb`. Manifest creation sorts artifacts by platform/package type and writes canonical JSON, SHA-256 sums, and an Ed25519 signature when the release key is supplied.

- [ ] **Step 4: Run structural package checks on matching systems**

Run on Windows: `pwsh tooling/packaging/package_windows.ps1 -Version 0.1.0`

Run on Ubuntu: `bash tooling/packaging/package_linux.sh 0.1.0`

Then run: `dart run tooling/release/verify_release.dart dist`

Expected: four packages have expected contents; checksums match; unsigned local mode is clearly labeled; configured signing fails closed on invalid or missing key material.

- [ ] **Step 5: Commit packaging tooling**

```powershell
git add tooling test/tooling pubspec.yaml pubspec.lock
git commit -m "build: package desktop releases"
```

### Task 12: Add matching-runner CI and signed release provenance

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release.yml`
- Create: `.github/dependabot.yml`
- Create: `.github/pull_request_body.md`
- Create: `tooling/verify_architecture.dart`
- Create: `test/tooling/architecture_test.dart`

**Interfaces:**
- Produces CI jobs: `analyze`, `test`, `windows-platform`, `linux-platform`
- Produces release jobs: `windows-package`, `linux-package`, `release`

- [ ] **Step 1: Write a failing dependency-boundary test**

```dart
test('GivenDomainSources_WhenImportsAreScanned_ThenOutwardDependenciesAreAbsent', () async {
  final violations = await verifyArchitecture(Directory('lib'));
  expect(violations, isEmpty);
});
```

Seed the scanner fixture with one forbidden `package:flutter` import and confirm the test reports its exact path before removing the fixture violation.

- [ ] **Step 2: Run architecture verification**

Run: `flutter test test/tooling/architecture_test.dart`

Expected: initial fixture run fails with the forbidden import; corrected fixture run passes.

- [ ] **Step 3: Implement CI workflows with immutable action pins**

CI must validate `.flutter-version`, run generated-code consistency, `dart format`, `flutter analyze`, unit/widget/migration tests, coverage, process/platform integration tests, release builds, and package smoke tests. Release runs only for `v*` tags, downloads both runner artifacts, verifies the release manifest, creates GitHub attestations with `id-token: write` and `attestations: write`, and publishes only after every verification job succeeds.

The pull-request template contains sections for the linked issue, requirement
traceability, verification commands/results, Windows/Linux artifacts, security
and data-safety review, and the publisher-signing status.

- [ ] **Step 4: Validate workflow syntax and local command parity**

Run:

```powershell
dart run tooling/verify_architecture.dart
flutter test
flutter analyze
```

Expected: local gates exit 0 and every workflow command exists in repository documentation.

- [ ] **Step 5: Commit automation**

```powershell
git add .github tooling/verify_architecture.dart test/tooling/architecture_test.dart
git commit -m "ci: verify desktop foundation"
```

### Task 13: Add clean-system smoke coverage and operational documentation

**Files:**
- Create: `integration_test/foundation_startup_integration_test.dart`
- Create: `integration_test/performance/concurrent_streams_integration_test.dart`
- Create: `tooling/smoke/windows_install_update.ps1`
- Create: `tooling/smoke/linux_install_update.sh`
- Modify: `README.md`
- Create: `docs/development/building-and-testing.md`
- Create: `docs/development/releases-and-signing.md`
- Create: `docs/development/application-data.md`

**Interfaces:**
- Consumes all issue #1 foundation services and release packages
- Produces clean-clone, install, update, data-preservation, and diagnostics evidence

- [ ] **Step 1: Write failing startup and concurrent-stream smoke tests**

```dart
testWidgets('GivenCleanProfile_WhenMaestroStarts_ThenFoundationBecomesOperational', (tester) async {
  await app.main();
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Foundation ready'), findsOneWidget);
});

testWidgets('GivenTwoStreamingRuns_WhenNavigating_ThenBuffersStayBounded', (tester) async {
  final harness = await ConcurrentRunHarness.start(count: 2, bytesPerRun: 1048576);
  await tester.tap(find.byKey(const Key('foundation-navigation')));
  await tester.pump();
  expect(harness.maxInMemoryBytes, lessThanOrEqualTo(harness.configuredLimit));
  expect(harness.allDurableBytesOrdered, isTrue);
});
```

- [ ] **Step 2: Run smoke tests and verify the red state**

Run on Windows: `flutter test integration_test/foundation_startup_integration_test.dart integration_test/performance/concurrent_streams_integration_test.dart -d windows`

Expected: FAIL until the production composition root and fixture harness are wired.

- [ ] **Step 3: Wire production bootstrap and document exact operations**

Compose real paths, database, protected storage, probes, reconciliation, and update services in `main.dart`. Document Flutter 3.44.8 installation, Windows Visual Studio prerequisites, Ubuntu build packages, dependency resolution, code generation, all test commands, package commands, artifact verification, data locations, recovery, release key secrets, GitHub attestations, and the absence of a trusted publisher certificate.

- [ ] **Step 4: Run the complete local verification available on Windows**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
flutter analyze
flutter test
flutter test integration_test -d windows
flutter build windows --release
pwsh tooling/packaging/package_windows.ps1 -Version 0.1.0
dart run tooling/release/verify_release.dart dist
```

Expected: every command exits 0; Windows ZIP/MSIX and verification outputs exist.

- [ ] **Step 5: Confirm Linux CI acceptance**

Push the feature branch and wait for the Ubuntu jobs that run Linux tests, build, AppImage/`.deb` packaging, install/update/data-preservation smoke tests, and artifact verification.

Expected: all required Windows and Linux jobs pass. If publisher credentials remain absent, the release report says `publisher-signing: unconfigured` and does not claim a trusted publisher signature.

- [ ] **Step 6: Commit documentation and smoke coverage**

```powershell
git add lib/main.dart integration_test tooling/smoke README.md docs/development/building-and-testing.md docs/development/releases-and-signing.md docs/development/application-data.md
git commit -m "docs: add foundation operations guide"
```

### Task 14: Perform issue traceability review and open the pull request

**Files:**
- Create: `docs/development/issue-1-verification.md`
- Modify: none outside evidence corrections found by verification

**Interfaces:**
- Consumes: IR-01 through IR-15 evidence from tasks 1–13
- Produces: review-ready pull request for issue #1

- [ ] **Step 1: Record traceable evidence**

Create a table with one row for each IR-01 through IR-15 containing implementation files, test names, local command result, CI job, and package artifact. Record the exact commit SHA and workflow run URL.

- [ ] **Step 2: Run final repository gates from a clean checkout**

Run:

```powershell
git status --short
flutter pub get
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
flutter analyze
flutter test
flutter test integration_test -d windows
flutter build windows --release
```

Expected: clean generated-code diff, analysis exit 0, all Windows-available tests pass, and release build exits 0.

- [ ] **Step 3: Verify remote CI and artifacts**

Run:

```powershell
$run = gh run list --branch feature/issue-1-foundation --limit 1 --json databaseId,status,conclusion | ConvertFrom-Json | Select-Object -First 1
if ($null -eq $run) { throw 'No workflow run found for feature/issue-1-foundation' }
gh run watch $run.databaseId --exit-status
gh run download $run.databaseId --dir .artifacts/issue-1
dart run tooling/release/verify_release.dart .artifacts/issue-1
```

Expected: Windows and Ubuntu jobs pass and the downloaded artifacts verify.

- [ ] **Step 4: Commit verification evidence**

```powershell
git add docs/development/issue-1-verification.md
git commit -m "test: record foundation evidence"
```

- [ ] **Step 5: Push and open the pull request**

```powershell
git push -u origin feature/issue-1-foundation
gh pr create --base main --head feature/issue-1-foundation --title "feat: establish maestro foundation" --body-file .github/pull_request_body.md
```

Expected: the pull request links issue #1, summarizes IR-01 through IR-15, includes test/build/package evidence, states the publisher-signing limitation, and stops for human review without merging.
