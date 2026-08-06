# UC-01 Local Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver UC-01 local operating-system and email/password authentication with protected verifiers, redacted audit evidence, and full-control session gating.

**Architecture:** Add a feature-first authentication slice around pure domain values and an application service. Drift persists non-secret metadata and audits, existing protected storage owns verifier bytes, Sodium owns password hashing, and the existing authentication platform port owns OS verification.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, Riverpod 3.4.2, Drift 2.34.0, Sodium 4.0.4, flutter_secure_storage 10.3.1, UUID 4.6.0.

## Global Constraints

- Implement UC-01 main flow and AF-01 through AF-04.
- Trace tests to FR-AU-01 through FR-AU-07 and BR-21.
- Passwords are at least eight characters and plaintext is never persisted or logged.
- Every authenticated local user has the single full-control permission set.
- Production code follows a witnessed red-green TDD cycle.
- Files use the feature-first MVVM boundaries enforced by `tooling/verify_architecture.dart`.

---

### Task 1: Authentication domain and application service

**Files:**
- Create: `lib/features/authentication/domain/authentication_models.dart`
- Create: `lib/features/authentication/application/authentication_service.dart`
- Test: `test/features/authentication/domain/authentication_models_test.dart`
- Test: `test/features/authentication/application/authentication_service_test.dart`

**Interfaces:**
- Produces: `NormalizedEmail.parse(String)`, `LocalPassword.validate(String)`, `LocalUser`, `AuthenticatedSession.fullControl`, `LocalUserRepository`, `PasswordVerifierStore`, `PasswordHasher`, `AuditRepository`, and `AuthenticationService`.
- Consumes: `AuthenticationPort`, deterministic clock, and UUIDv7 generator callbacks.

- [ ] **Step 1: Write failing domain tests**

```dart
test('GivenMixedCaseEmail_WhenParsed_ThenCanonicalValueIsLowercase', () {
  expect(NormalizedEmail.parse(' User@Example.COM ').value, 'user@example.com');
});

test('GivenShortPassword_WhenValidated_ThenMinimumAndGuidanceAreReturned', () {
  expect(() => LocalPassword.validate('short'), throwsA(isA<PasswordTooShort>()));
});
```

- [ ] **Step 2: Run the domain test and verify RED**

Run `flutter test test/features/authentication/domain/authentication_models_test.dart`; expect missing authentication types.

- [ ] **Step 3: Implement the domain values and session policy**

```dart
final class AuthenticatedSession {
  const AuthenticatedSession.fullControl(this.userId)
    : canManageRecords = true,
      canRunWorkflows = true,
      canDeliverChanges = true;
  final String userId;
  final bool canManageRecords;
  final bool canRunWorkflows;
  final bool canDeliverChanges;
}
```

- [ ] **Step 4: Run the domain test and verify GREEN**

Run the same focused command; expect all domain tests to pass.

- [ ] **Step 5: Write failing service tests for main flow and AF-01 through AF-04**

```dart
test('GivenDuplicateNormalizedEmail_WhenCreating_ThenNothingIsStored', () async {
  users.existingEmail = 'user@example.com';
  final result = await service.createAccount(' User@Example.com ', 'password1');
  expect(result, isA<FailureResult<AuthenticatedSession>>());
  expect(verifiers.writes, isEmpty);
});
```

- [ ] **Step 6: Run the service tests and verify RED**

Run `flutter test test/features/authentication/application/authentication_service_test.dart`; expect the service API to be absent.

- [ ] **Step 7: Implement minimal orchestration and rollback behavior**

```dart
Future<Result<AuthenticatedSession>> signInWithEmail(
  String email,
  String password,
);
Future<Result<AuthenticatedSession>> createAccount(
  String email,
  String password,
);
Future<Result<AuthenticatedSession>> signInWithOperatingSystem();
void signOut();
```

- [ ] **Step 8: Run domain and service tests and verify GREEN**

Run `flutter test test/features/authentication`; expect all focused tests to pass.

- [ ] **Step 9: Commit**

Commit as `feat: add authentication domain service`.

### Task 2: Drift metadata and redacted audit persistence

**Files:**
- Modify: `lib/core/storage/database/maestro_database.dart`
- Modify: `lib/core/storage/database/schema_versions.dart`
- Create: `lib/features/authentication/data/drift_authentication_repository.dart`
- Modify: `test/core/storage/database/migration_test.dart`
- Create: `test/features/authentication/data/drift_authentication_repository_test.dart`
- Regenerate: `lib/core/storage/database/maestro_database.g.dart`, `test/generated/schema.dart`, `test/generated/schema_v2.dart`, `test/fixtures/schema/drift_schema_v2.json`

**Interfaces:**
- Consumes: `LocalUserRepository` and `AuditRepository` from Task 1.
- Produces: `DriftAuthenticationRepository` with normalized-email uniqueness and ordered audit writes.

- [ ] **Step 1: Write failing persistence tests**

```dart
test('GivenCaseVariantEmail_WhenInserted_ThenUniqueConstraintRejectsIt', () async {
  await repository.save(user(email: 'user@example.com'));
  await expectLater(repository.save(user(email: 'USER@example.com')), throwsA(anything));
});
```

- [ ] **Step 2: Run the persistence test and verify RED**

Run `flutter test test/features/authentication/data/drift_authentication_repository_test.dart`; expect missing tables/repository.

- [ ] **Step 3: Add schema version 2, migration, and repository implementation**

```dart
class LocalUsers extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().nullable().unique()();
  TextColumn get authMethod => text()();
  TextColumn get verifierKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAuthenticatedAt => dateTime().nullable()();
  @override Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
```

- [ ] **Step 4: Regenerate Drift artifacts and migration fixtures**

Run `dart run build_runner build --delete-conflicting-outputs` and `dart run drift_dev schema steps` using the repository's established fixture workflow.

- [ ] **Step 5: Run persistence and migration tests and verify GREEN**

Run `flutter test test/features/authentication/data test/core/storage/database/migration_test.dart`.

- [ ] **Step 6: Commit**

Commit as `feat: persist authentication records`.

### Task 3: Protected verifier and Sodium hashing adapters

**Files:**
- Create: `lib/features/authentication/data/protected_password_verifier_store.dart`
- Create: `lib/features/authentication/data/sodium_password_hasher.dart`
- Test: `test/features/authentication/data/protected_password_verifier_store_test.dart`
- Test: `test/features/authentication/data/sodium_password_hasher_test.dart`

**Interfaces:**
- Consumes: `ProtectedStorage`, `PasswordVerifierStore`, and `PasswordHasher`.
- Produces: UTF-8 protected verifier storage and Sodium Argon2 verifier generation/verification.

- [ ] **Step 1: Write failing adapter tests**

```dart
test('GivenPassword_WhenHashed_ThenVerifierAcceptsOnlyOriginal', () async {
  final verifier = await hasher.create('correct horse battery staple');
  expect(await hasher.verify(verifier, 'correct horse battery staple'), isTrue);
  expect(await hasher.verify(verifier, 'wrong password'), isFalse);
});
```

- [ ] **Step 2: Run adapter tests and verify RED**

Run `flutter test test/features/authentication/data/protected_password_verifier_store_test.dart test/features/authentication/data/sodium_password_hasher_test.dart`.

- [ ] **Step 3: Implement protected storage and Sodium adapters**

```dart
final hash = sodium.crypto.pwhash.str(
  password: password,
  opsLimit: sodium.crypto.pwhash.opsLimitInteractive,
  memLimit: sodium.crypto.pwhash.memLimitInteractive,
);
```

- [ ] **Step 4: Run adapter tests and verify GREEN**

Run the same focused command; expect the original password to pass and a different password to fail.

- [ ] **Step 5: Commit**

Commit as `feat: protect password verifiers`.

### Task 4: Operating-system authentication adapter

**Files:**
- Modify: `lib/platform/auth/authentication_port.dart`
- Create: `lib/platform/auth/method_channel_authentication.dart`
- Modify: `windows/runner/flutter_window.cpp`
- Modify: `linux/runner/my_application.cc`
- Test: `test/platform/auth/method_channel_authentication_test.dart`

**Interfaces:**
- Produces: method channel `dev.artur-rios.maestro/authentication` with `probe` and `authenticateCurrentUser` operations mapped to typed `Capability` and `Result<void>` values.
- Consumes: Windows UserConsentVerifier and Linux's system authentication prompt through the native host.

- [ ] **Step 1: Write failing method-channel contract tests**

```dart
test('GivenNativeDenial_WhenAuthenticating_ThenSecurityFailureIsReturned', () async {
  messenger.reply = <String, Object?>{'status': 'denied'};
  final result = await adapter.authenticateCurrentUser();
  expect(result, isA<FailureResult<void>>());
});
```

- [ ] **Step 2: Run the contract test and verify RED**

Run `flutter test test/platform/auth/method_channel_authentication_test.dart`.

- [ ] **Step 3: Implement Dart channel parsing and native host handlers**

```dart
const MethodChannel _channel = MethodChannel(
  'dev.artur-rios.maestro/authentication',
);
```

- [ ] **Step 4: Run contract tests and platform compilation checks**

Run the focused test, then `flutter build windows --debug`; Linux compilation remains CI-gated on Ubuntu.

- [ ] **Step 5: Commit**

Commit as `feat: add operating system authentication`.

### Task 5: Authentication controller, UI, and protected shell

**Files:**
- Create: `lib/features/authentication/presentation/authentication_controller.dart`
- Create: `lib/features/authentication/presentation/authentication_page.dart`
- Modify: `lib/app/maestro_app.dart`
- Modify: `lib/main.dart`
- Test: `test/features/authentication/presentation/authentication_page_test.dart`
- Modify: `test/app/maestro_app_test.dart`

**Interfaces:**
- Consumes: `AuthenticationService` and production adapters.
- Produces: signed-out/signing-in/authenticated/error presentation states and a protected foundation shell.

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('GivenSignedOut_WhenRendered_ThenProtectedShellIsHidden', (tester) async {
  await tester.pumpWidget(testApp());
  expect(find.text('Foundation ready'), findsNothing);
  expect(find.text('Sign in with your operating system'), findsOneWidget);
});
```

- [ ] **Step 2: Run widget tests and verify RED**

Run `flutter test test/features/authentication/presentation test/app/maestro_app_test.dart`.

- [ ] **Step 3: Implement controller, forms, guidance, and application composition**

```dart
home: AuthenticationPage(
  authenticatedBuilder: (_) => const FoundationPage(),
),
```

- [ ] **Step 4: Run widget tests and verify GREEN**

Run the focused widget command and confirm sign-in, creation, fallback, guidance, protected-shell gating, and sign-out cases pass.

- [ ] **Step 5: Commit**

Commit as `feat: add local authentication UI`.

### Task 6: UC-01 verification and delivery evidence

**Files:**
- Modify: `README.md`
- Create: `docs/development/uc-01-verification.md`

**Interfaces:**
- Produces: traceability evidence for every requirement, main-flow step, alternative flow, test command, and delivery artifact.

- [ ] **Step 1: Run generated-code, format, architecture, workflow, analysis, and full-test gates**

```powershell
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
dart run tooling/verify_architecture.dart
dart run tooling/verify_workflows.dart
flutter analyze
flutter test
```

- [ ] **Step 2: Record exact evidence and update README tracking**

Record commands, counts, and AF/FR mappings in `docs/development/uc-01-verification.md`; change M-02 to `1 / 3 closed` and mark only issue #2's row complete using `✅`.

- [ ] **Step 3: Commit**

Commit as `docs: record uc-01 verification`.

