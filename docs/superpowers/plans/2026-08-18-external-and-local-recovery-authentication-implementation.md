# External and Local Recovery Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add browser-based Google/Heimdall authentication, Windows credential choices for local accounts, and creation-only one-use recovery codes.

**Architecture:** Keep authentication orchestration in `AuthenticationService`, with explicit ports for settings, recovery-code storage, native credentials, browser OAuth, and Heimdall. Drift stores non-secret configuration and recovery-code digests; protected storage retains only local password verifiers; external tokens and OAuth artifacts remain in memory.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, Riverpod 3.4.2, Drift 2.34.0, Sodium 4.0.4, `http`, `url_launcher`, `crypto`, native Windows/Linux method channels.

**Spec:** `docs/superpowers/specs/2026-08-18-external-and-local-recovery-authentication-design.md`

## Global Constraints

- The API base URI comes from `String.fromEnvironment('HEIMDALL_API_BASE_URL', defaultValue: 'http://localhost:8080')`; do not expose it in the settings UI.
- Persist only `authentication.google.oauth_client_id` and `authentication.heimdall.scope_id` in `Settings`.
- Use OAuth authorization-code flow with PKCE and a loopback callback; never include a client secret.
- Send Google ID token and persisted scope UUID to `POST /api/auth/google` in the Heimdall `DataOutput` envelope format.
- Never persist or log OAuth authorization codes, PKCE verifiers, Google ID tokens, Heimdall bearer tokens, local passwords, or recovery-code plaintext.
- Create exactly ten 128-bit CSPRNG recovery codes only while creating an email/password account; no regeneration or email/password-reset alternative exists.
- Store only SHA-256 canonical-code digests and consume an unused recovery code atomically before changing the protected password verifier.
- Preserve the existing Windows-only account flow and add an email-account Windows credential action using the existing OS verifier.
- All operations must obey the authentication operation-generation guard and preserve current redacted audit conventions.

---

## Planned file structure

- `lib/features/authentication/domain/external_authentication_models.dart` — configuration, recovery-code, and external-session values.
- `lib/features/authentication/application/external_authentication_ports.dart` — ports and DTOs for settings, codes, OAuth, and Heimdall.
- `lib/features/authentication/data/drift_authentication_settings_repository.dart` — `Settings` persistence.
- `lib/features/authentication/data/drift_recovery_code_repository.dart` — digest storage and conditional redemption.
- `lib/features/authentication/data/google_browser_authorizer.dart` — PKCE loopback browser authorization and token exchange.
- `lib/features/authentication/data/heimdall_authentication_gateway.dart` — bounded HTTP integration with the documented API.
- `lib/features/authentication/presentation/authentication_settings_controller.dart` — persisted configuration UI state.
- `lib/features/authentication/presentation/recovery_code_dialog.dart` — one-time display/acknowledgement.
- existing authentication service, controller, page, database, composition, and tests — integration points.

### Task 1: Add external-auth dependencies and migration scaffolding

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/storage/database/schema_versions.dart`
- Modify: `lib/core/storage/database/maestro_database.dart`
- Modify: `test/fixtures/schema/drift_schema_v7.json`
- Modify: `test/core/storage/database/maestro_database_migration_test.dart`

**Interfaces:**
- Produces `LocalRecoveryCodes` Drift table: `id`, `userId`, `digest`, `issuedAt`, `consumedAt`.
- Produces schema version `7` and `local_recovery_codes_unused_digest` lookup index.

- [ ] **Step 1: Write failing migration tests**

```dart
test('GivenVersion6Database_WhenMigrated_ThenRecoveryCodeTableExists', () async {
  final database = await openMigratedDatabase(fromVersion: 6);
  final rows = await database.customSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'local_recovery_codes'",
  ).get();
  expect(rows, hasLength(1));
});
```

- [ ] **Step 2: Run the focused migration test and verify it fails**

Run: `flutter test test/core/storage/database/maestro_database_migration_test.dart`

Expected: FAIL because schema version 6 has no recovery-code table.

- [ ] **Step 3: Add the smallest schema and dependency changes**

```dart
class LocalRecoveryCodes extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(LocalUsers, #id, onDelete: KeyAction.cascade)();
  TextColumn get digest => text().unique()();
  DateTimeColumn get issuedAt => dateTime()();
  DateTimeColumn get consumedAt => dateTime().nullable()();
  @override Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
```

Add `http: ^1.6.0` and `url_launcher: ^6.3.2`, register the table, set version 7, create its table and index when `from < 7`, then regenerate Drift output with `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Regenerate fixture and run focused checks**

Run: `flutter test test/core/storage/database/maestro_database_migration_test.dart && dart run build_runner build --delete-conflicting-outputs`

Expected: PASS and generated database code contains `localRecoveryCodes`.

- [ ] **Step 5: Commit the migration deliverable**

```powershell
git add pubspec.yaml pubspec.lock lib/core/storage/database test/fixtures/schema/drift_schema_v7.json test/core/storage/database/maestro_database_migration_test.dart
git commit -m "feat: add recovery code storage"
```

### Task 2: Define pure external and recovery authentication values

**Files:**
- Create: `lib/features/authentication/domain/external_authentication_models.dart`
- Test: `test/features/authentication/domain/external_authentication_models_test.dart`

**Interfaces:**
- Produces `ExternalAuthenticationConfiguration`, `RecoveryCode`, `NewRecoveryCodeSet`, and `ExternalAuthenticatedIdentity`.
- `RecoveryCode.generate(Random random)` returns canonical code text and `digest`; `RecoveryCode.parse(String)` rejects malformed display input.

- [ ] **Step 1: Write failing value-object tests**

```dart
test('GivenGeneratedRecoveryCode_WhenPersisted_ThenDigestDoesNotContainPlaintext', () {
  final code = RecoveryCode.generate(_deterministicRandom());
  expect(code.display, matches(RegExp(r'^[A-Z0-9]{4}(-[A-Z0-9]{4}){4}$')));
  expect(code.digest, isNot(contains(code.display)));
});

test('GivenInvalidScope_WhenConfigurationCreated_ThenItThrows', () {
  expect(() => ExternalAuthenticationConfiguration(clientId: 'desktop-client', scopeId: 'bad'), throwsFormatException);
});
```

- [ ] **Step 2: Run the domain test and verify it fails**

Run: `flutter test test/features/authentication/domain/external_authentication_models_test.dart`

Expected: FAIL because the models do not exist.

- [ ] **Step 3: Implement pure validation and code generation**

```dart
final class RecoveryCode {
  static const int count = 10;
  factory RecoveryCode.generate(Random random) { /* 16 secure random bytes, canonical base32 groups, SHA-256 digest */ }
  factory RecoveryCode.parse(String input) { /* remove hyphens, validate alphabet and length */ }
  final String display;
  final String digest;
}
```

Use `Random.secure()` in production through an injected generator, uppercase Crockford-style non-ambiguous symbols, and a lower-level canonical string for digesting. Validate scope with `UuidValue.fromString` or a strict UUID parser; require a nonempty OAuth client ID.

- [ ] **Step 4: Run the domain tests**

Run: `flutter test test/features/authentication/domain/external_authentication_models_test.dart`

Expected: PASS, including exact ten-code set generation and input normalization.

- [ ] **Step 5: Commit the domain deliverable**

```powershell
git add lib/features/authentication/domain/external_authentication_models.dart test/features/authentication/domain/external_authentication_models_test.dart
git commit -m "feat: define external authentication values"
```

### Task 3: Add settings and recovery-code repository ports and Drift adapters

**Files:**
- Create: `lib/features/authentication/application/external_authentication_ports.dart`
- Create: `lib/features/authentication/data/drift_authentication_settings_repository.dart`
- Create: `lib/features/authentication/data/drift_recovery_code_repository.dart`
- Test: `test/features/authentication/data/drift_authentication_settings_repository_test.dart`
- Test: `test/features/authentication/data/drift_recovery_code_repository_test.dart`

**Interfaces:**
- Produces `AuthenticationSettingsRepository.load/save`.
- Produces `RecoveryCodeRepository.saveAll` and `Future<bool> consumeUnusedDigest(String digest, DateTime consumedAt)`.

- [ ] **Step 1: Write failing persistence tests**

```dart
test('GivenSavedConfiguration_WhenLoaded_ThenItRoundTrips', () async {
  await repository.save(const ExternalAuthenticationConfiguration(
    clientId: '123.apps.googleusercontent.com', scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
  ));
  expect(await repository.load(), const ExternalAuthenticationConfiguration(
    clientId: '123.apps.googleusercontent.com', scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
  ));
});

test('GivenAlreadyConsumedDigest_WhenConsumedAgain_ThenItReturnsFalse', () async {
  await codes.saveAll(userId, <StoredRecoveryCode>[code]);
  expect(await codes.consumeUnusedDigest(code.digest, now), isTrue);
  expect(await codes.consumeUnusedDigest(code.digest, now.add(const Duration(seconds: 1))), isFalse);
});
```

- [ ] **Step 2: Run the repository tests and verify they fail**

Run: `flutter test test/features/authentication/data/drift_authentication_settings_repository_test.dart test/features/authentication/data/drift_recovery_code_repository_test.dart`

Expected: FAIL because the ports and adapters do not exist.

- [ ] **Step 3: Implement transaction-safe adapters**

```dart
Future<bool> consumeUnusedDigest(String digest, DateTime consumedAt) async {
  final updated = await (_database.update(_database.localRecoveryCodes)
        ..where((row) => row.digest.equals(digest) & row.consumedAt.isNull()))
      .write(LocalRecoveryCodesCompanion(consumedAt: Value(consumedAt)));
  return updated == 1;
}
```

Persist configuration with upserts under the two exact keys. Insert all recovery-code rows within one Drift transaction. Do not expose a list/read method for stored digests.

- [ ] **Step 4: Run persistence tests**

Run: `flutter test test/features/authentication/data/drift_authentication_settings_repository_test.dart test/features/authentication/data/drift_recovery_code_repository_test.dart`

Expected: PASS, including transaction rollback and conditional-consumption cases.

- [ ] **Step 5: Commit the repository deliverable**

```powershell
git add lib/features/authentication/application/external_authentication_ports.dart lib/features/authentication/data/drift_authentication_settings_repository.dart lib/features/authentication/data/drift_recovery_code_repository.dart test/features/authentication/data/drift_authentication_settings_repository_test.dart test/features/authentication/data/drift_recovery_code_repository_test.dart
git commit -m "feat: persist authentication settings and codes"
```

### Task 4: Implement browser PKCE authorization and Heimdall gateway

**Files:**
- Create: `lib/features/authentication/data/google_browser_authorizer.dart`
- Create: `lib/features/authentication/data/heimdall_authentication_gateway.dart`
- Test: `test/features/authentication/data/google_browser_authorizer_test.dart`
- Test: `test/features/authentication/data/heimdall_authentication_gateway_test.dart`

**Interfaces:**
- Produces `GoogleBrowserAuthorizer.authorize(ExternalAuthenticationConfiguration configuration): Future<GoogleIdToken>`.
- Produces `HeimdallAuthenticationGateway.signInWithGoogle({required String scopeId, required String idToken}): Future<ExternalTokenGrant>`.

- [ ] **Step 1: Write failing HTTP and callback tests**

```dart
test('GivenCallbackWithWrongState_WhenAuthorize_ThenItRejectsWithoutTokenExchange', () async {
  final result = authorizer.authorize(configuration);
  await callbackClient.get(Uri.parse('${fakeBrowser.redirectUri}?code=code&state=wrong'));
  await expectLater(result, throwsA(isA<OAuthCallbackStateMismatch>()));
  expect(tokenClient.requests, isEmpty);
});

test('GivenHeimdallSuccessEnvelope_WhenGoogleSignIn_ThenItReturnsGrant', () async {
  client.enqueueJson(200, {'success': true, 'data': {'token': 'jwt', 'expiresAt': '2026-08-18T12:00:00Z', 'emailVerified': true}});
  final grant = await gateway.signInWithGoogle(scopeId: scopeId, idToken: 'id-token');
  expect(grant.token, 'jwt');
  expect(client.lastJsonBody, {'scopeId': scopeId, 'idToken': 'id-token'});
});
```

- [ ] **Step 2: Run the gateway tests and verify they fail**

Run: `flutter test test/features/authentication/data/google_browser_authorizer_test.dart test/features/authentication/data/heimdall_authentication_gateway_test.dart`

Expected: FAIL because neither adapter exists.

- [ ] **Step 3: Implement bounded adapters**

```dart
final class HeimdallAuthenticationGateway implements ExternalAuthenticationGateway {
  @override
  Future<ExternalTokenGrant> signInWithGoogle({required String scopeId, required String idToken}) async {
    final response = await _client.post(_baseUri.resolve('/api/auth/google'), headers: {'content-type': 'application/json'}, body: jsonEncode({'scopeId': scopeId, 'idToken': idToken}));
    return _parseGrant(response);
  }
}
```

Generate a random verifier/state, SHA-256 base64url PKCE challenge, listen only on loopback, open the browser with `url_launcher`, accept exactly one matching callback, exchange only an authorization code, and always close the server. Bound response parsing to the documented `success/data/token/expiresAt/emailVerified` envelope. Inject browser, HTTP client, loopback server factory, clock, and random bytes for tests.

- [ ] **Step 4: Run focused adapter tests**

Run: `flutter test test/features/authentication/data/google_browser_authorizer_test.dart test/features/authentication/data/heimdall_authentication_gateway_test.dart`

Expected: PASS for success, cancellation, timeout, state mismatch, malformed Google response, HTTP rejection, and malformed Heimdall envelope.

- [ ] **Step 5: Commit the external adapter deliverable**

```powershell
git add lib/features/authentication/data/google_browser_authorizer.dart lib/features/authentication/data/heimdall_authentication_gateway.dart test/features/authentication/data/google_browser_authorizer_test.dart test/features/authentication/data/heimdall_authentication_gateway_test.dart
git commit -m "feat: add google heimdall authentication"
```

### Task 5: Extend AuthenticationService for all new flows

**Files:**
- Modify: `lib/features/authentication/domain/authentication_models.dart`
- Modify: `lib/features/authentication/application/authentication_service.dart`
- Test: `test/features/authentication/application/authentication_service_test.dart`

**Interfaces:**
- Produces `createAccount` result containing `AuthenticatedSession` plus a one-time `NewRecoveryCodeSet`.
- Produces `signInWithLocalWindowsCredentials(String email)`, `signInWithGoogle()`, `recoverLocalAccount(String email, String recoveryCode, String newPassword)`, and `acknowledgeRecoveryCodes()`.

- [ ] **Step 1: Write failing service tests for each new branch**

```dart
test('GivenEmailAccountAndVerifiedWindowsCredentials_WhenSigningIn_ThenItOpensThatEmailSession', () async {
  final result = await service.signInWithLocalWindowsCredentials('person@example.com');
  expect(result.valueOrNull?.userId, emailUser.id);
});

test('GivenUnusedRecoveryCode_WhenRecovering_ThenItConsumesCodeAndReplacesVerifier', () async {
  final result = await service.recoverLocalAccount('person@example.com', displayedCode, 'new-password');
  expect(result.valueOrNull?.userId, emailUser.id);
  expect(await codes.consumeUnusedDigest(digest, now), isFalse);
});
```

- [ ] **Step 2: Run the focused service test and verify it fails**

Run: `flutter test test/features/authentication/application/authentication_service_test.dart`

Expected: FAIL because the service exposes none of the new operations.

- [ ] **Step 3: Implement minimal service orchestration**

```dart
Future<Result<AuthenticatedSession>> signInWithLocalWindowsCredentials(String email) async {
  final user = await _users.findByEmail(_validatedEmail(email)!);
  if (user == null || user.authenticationMethod != AuthenticationMethod.emailPassword) return _invalidCredentials();
  final verified = await _operatingSystemAuthentication.authenticateCurrentUser();
  return verified.fold(onFailure: FailureResult.new, onSuccess: (_) => _completeLocalSignIn(user, generation));
}
```

Add session source/token-expiry fields; decode only JWT payload `sub` for an external actor and reject malformed/missing subject. Persist all ten code digests in the same compensating account creation workflow. Require acknowledgement before publishing the created session. Consume recovery code before replacing the verifier, then audit redacted success/failure. Never add an email-reset or regeneration operation.

- [ ] **Step 4: Run service tests**

Run: `flutter test test/features/authentication/application/authentication_service_test.dart`

Expected: PASS for external sign-in, token expiry/sign-out clearing, Windows alternatives, acknowledgement gate, recovery success/failure/concurrency, and stale operations.

- [ ] **Step 5: Commit the service deliverable**

```powershell
git add lib/features/authentication/domain/authentication_models.dart lib/features/authentication/application/authentication_service.dart test/features/authentication/application/authentication_service_test.dart
git commit -m "feat: extend authentication service"
```

### Task 6: Compose production implementations and configuration controller

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/features/authentication/presentation/authentication_settings_controller.dart`
- Test: `test/app/production_authentication_composition_test.dart`
- Test: `test/features/authentication/presentation/authentication_settings_controller_test.dart`

**Interfaces:**
- Produces `AuthenticationSettingsController.load/save(String clientId, String scopeId)` and `AuthenticationConfigurationState`.
- Production composition injects Drift settings/codes, browser authorizer, and Heimdall gateway into `AuthenticationService`.

- [ ] **Step 1: Write failing composition/controller tests**

```dart
test('GivenProductionComposition_WhenCreated_ThenExternalAuthenticationPortsAreWired', () async {
  final composition = await composeProductionApp(paths: paths, database: database, window: window);
  expect(composition.authenticationService, isNotNull);
});

test('GivenInvalidConfiguration_WhenSaved_ThenControllerShowsValidationFailure', () async {
  await controller.save(' ', 'not-a-uuid');
  expect(container.read(authenticationSettingsControllerProvider), isA<AuthenticationConfigurationError>());
});
```

- [ ] **Step 2: Run focused tests and verify they fail**

Run: `flutter test test/app/production_authentication_composition_test.dart test/features/authentication/presentation/authentication_settings_controller_test.dart`

Expected: FAIL because the composition and controller do not supply external configuration.

- [ ] **Step 3: Wire production composition and controller**

```dart
final authenticationService = AuthenticationService(
  users: authenticationRepository,
  recoveryCodes: DriftRecoveryCodeRepository(database),
  settings: DriftAuthenticationSettingsRepository(database, clock: now),
  googleAuthorizer: GoogleBrowserAuthorizer(),
  externalGateway: HeimdallAuthenticationGateway(baseUri: Uri.parse(const String.fromEnvironment('HEIMDALL_API_BASE_URL', defaultValue: 'http://localhost:8080'))),
  // existing collaborators...
);
```

Keep constructor seams injectable so widget and composition tests continue to use fakes. The controller loads on build, clears validation errors on input changes, and never stores token or code text.

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/app/production_authentication_composition_test.dart test/features/authentication/presentation/authentication_settings_controller_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit composition deliverable**

```powershell
git add lib/main.dart lib/features/authentication/presentation/authentication_settings_controller.dart test/app/production_authentication_composition_test.dart test/features/authentication/presentation/authentication_settings_controller_test.dart
git commit -m "feat: compose external authentication"
```

### Task 7: Build sign-in, configuration, and recovery presentation

**Files:**
- Modify: `lib/features/authentication/presentation/authentication_controller.dart`
- Modify: `lib/features/authentication/presentation/authentication_page.dart`
- Create: `lib/features/authentication/presentation/recovery_code_dialog.dart`
- Test: `test/features/authentication/presentation/authentication_controller_test.dart`
- Test: `test/features/authentication/presentation/authentication_page_test.dart`
- Test: `test/features/authentication/presentation/recovery_code_dialog_test.dart`

**Interfaces:**
- Produces controller events `signInWithGoogle`, `signInWithLocalWindowsCredentials`, `recoverLocalAccount`, and `acknowledgeRecoveryCodes`.
- Produces semantic labels `Continue with Google`, `Use Windows credentials`, `Recover local account`, and `Acknowledge recovery codes`.

- [ ] **Step 1: Write failing controller and widget tests**

```dart
testWidgets('GivenNewLocalAccount_WhenCreated_ThenItShowsRecoveryCodesBeforeWorkspace', (tester) async {
  await tester.tap(find.text('Create local account'));
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Recovery codes'), findsOneWidget);
  expect(find.bySemanticsLabel('Acknowledge recovery codes'), findsOneWidget);
});

testWidgets('GivenEmailEntered_WhenUseWindowsCredentialsTapped_ThenItInvokesEmailWindowsSignIn', (tester) async {
  await tester.enterText(find.bySemanticsLabel('Email address'), 'person@example.com');
  await tester.tap(find.bySemanticsLabel('Use Windows credentials'));
  expect(service.windowsEmailAttempts, 1);
});
```

- [ ] **Step 2: Run the presentation tests and verify they fail**

Run: `flutter test test/features/authentication/presentation/authentication_controller_test.dart test/features/authentication/presentation/authentication_page_test.dart test/features/authentication/presentation/recovery_code_dialog_test.dart`

Expected: FAIL because controls and recovery dialog do not exist.

- [ ] **Step 3: Implement the new presentation states and controls**

```dart
FilledButton.icon(
  onPressed: busy ? null : _signInWithGoogle,
  icon: const Icon(Icons.account_circle_outlined),
  label: const Text('Continue with Google'),
)
```

Add external configuration fields behind a settings affordance, with save action and validation. Put password sign-in and email Windows sign-in together; keep standalone Windows-only sign-in separate. Add recovery form fields for email/code/new password/confirmation. Render the code dialog only from the service's one-time creation result, use selectable monospace text, and clear plaintext state on acknowledgement or widget disposal.

- [ ] **Step 4: Run presentation tests**

Run: `flutter test test/features/authentication/presentation/authentication_controller_test.dart test/features/authentication/presentation/authentication_page_test.dart test/features/authentication/presentation/recovery_code_dialog_test.dart`

Expected: PASS for busy disabling, error copy, source-specific controls, acknowledgement gating, and no password-reset alternative.

- [ ] **Step 5: Commit presentation deliverable**

```powershell
git add lib/features/authentication/presentation/authentication_controller.dart lib/features/authentication/presentation/authentication_page.dart lib/features/authentication/presentation/recovery_code_dialog.dart test/features/authentication/presentation/authentication_controller_test.dart test/features/authentication/presentation/authentication_page_test.dart test/features/authentication/presentation/recovery_code_dialog_test.dart
git commit -m "feat: present external and recovery sign-in"
```

### Task 8: Run end-to-end verification and update verification documentation

**Files:**
- Modify: `docs/development/uc-01-verification.md`
- Modify: `README.md`
- Test: `integration_test/foundation_startup_integration_test.dart`

**Interfaces:**
- Consumes all previous public authentication interfaces.
- Produces traceable manual verification instructions for local recovery, Windows alternatives, Google configuration, and mocked Heimdall sign-in.

- [ ] **Step 1: Write failing integration/verification assertions**

```dart
testWidgets('GivenNoAuthenticatedSession_WhenStartupCompletes_ThenGoogleAndRecoveryActionsAreAvailable', (tester) async {
  await pumpMaestro(tester, configuredComposition);
  expect(find.bySemanticsLabel('Continue with Google'), findsOneWidget);
  expect(find.bySemanticsLabel('Recover local account'), findsOneWidget);
});
```

- [ ] **Step 2: Run the integration test and verify it fails if UI wiring is incomplete**

Run: `flutter test integration_test/foundation_startup_integration_test.dart`

Expected: PASS only after Task 7; otherwise use the failure to complete missing wiring.

- [ ] **Step 3: Document exact verification and run format/analyze/tests**

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test test/features/authentication
flutter test
```

Document build-time API-base override, persisted configuration keys, expected loopback/browser behavior, recovery-code one-time display, and that loss of all codes is unrecoverable by design.

- [ ] **Step 4: Run the complete verification suite**

Run: `dart format --set-exit-if-changed .; flutter analyze; flutter test`

Expected: all commands exit 0.

- [ ] **Step 5: Commit verification evidence**

```powershell
git add README.md docs/development/uc-01-verification.md integration_test/foundation_startup_integration_test.dart
git commit -m "docs: verify external authentication"
```

## Plan self-review

- Spec coverage: Tasks 1–3 implement schema, configuration, and digest-only recovery persistence; Task 4 implements PKCE, browser, Google, and Heimdall; Task 5 implements all session, Windows, recovery, audit, and stale-operation behavior; Tasks 6–7 compose and present it; Task 8 verifies and documents it.
- Placeholder scan: no unassigned work or deferred steps remain; every task names exact files, interfaces, commands, and test assertions.
- Type consistency: `ExternalAuthenticationConfiguration`, `RecoveryCodeRepository`, `GoogleBrowserAuthorizer`, `HeimdallAuthenticationGateway`, and the listed `AuthenticationService` methods are introduced before their consumers.
