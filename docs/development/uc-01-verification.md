# UC-01 verification evidence

This record traces [issue #2](https://github.com/artur-rios/maestro/issues/2)
and [UC-01](../requirements/Use%20Case%20Specification%20Document.md#uc-01-authenticate-locally)
to the implementation and local verification evidence prepared for review.

- Verified implementation: the final-review fix commit containing this evidence,
  based on branch revision `0a3c8d5`
- Toolchain: Flutter 3.44.8 and Dart 3.12.2
- Local full-suite result: 124 tests passed
- Native build evidence: the Windows debug runner built successfully for the
  verified implementation
- Pending delivery evidence: pull-request CI and Ubuntu Linux compilation have
  not run yet and must pass before merge

## Requirement traceability

| Requirement | Implementation | Automated evidence | Verified outcome |
| --- | --- | --- | --- |
| FR-AU-01 | `MethodChannelAuthentication` and the Windows Hello/Linux PAM hosts implement operating-system verification through `dev.artur-rios.maestro/authentication`. Windows Hello completions share a reply gate that is deactivated before engine teardown. | `method_channel_authentication_test.dart`; `windows_authentication_lifecycle_contract_test.dart`; Windows debug compilation | Typed availability, approval, denial, unavailable, malformed, sanitized-exception, and callback-lifetime paths pass. Both Windows Hello callbacks are suppressed after teardown; Linux remains CI-gated. |
| FR-AU-02 | Account creation validates and normalizes email addresses, uses production UUIDv7 identifiers, enforces database uniqueness, stores non-secret user metadata, and opens a session only after all writes succeed. | `authentication_models_test.dart`; `authentication_service_test.dart`; `production_authentication_composition_test.dart`; `drift_authentication_repository_test.dart`; account-creation widget tests | Bounded ASCII dot-atom validation, mixed-case normalization, UUIDv7 user/audit persistence, duplicate rejection before mutation, case-insensitive persistence uniqueness, and successful creation pass. |
| FR-AU-03 | `LocalPassword.validate` requires at least eight characters before verifier creation. | Domain, service, and widget tests for seven-, eight-, and short-password cases | Short passwords are rejected without storage mutation; eight characters are accepted. |
| FR-AU-04 | Account-creation UI shows the minimum-length and strong, unique password guidance before submission and after rejection. | `authentication_page_test.dart` | Guidance is visible and is not duplicated after AF-02. |
| FR-AU-05 | Sodium creates salted Argon2 verifier strings; only UTF-8 verifier bytes cross the protected-storage boundary. Password text is not written to Drift, audit details, failures, or presentation state. | `sodium_password_hasher_test.dart`; `protected_password_verifier_store_test.dart`; repository and service audit tests | A verifier accepts only its source password, hashing yields to the event loop, malformed protected bytes fail, and audit/storage assertions contain no submitted credentials. |
| FR-AU-06 | `AuthenticationPage` invokes the protected-content builder only for an authenticated controller state. Sign-out, disposal, failure, and stale completions remain outside the shell. | `authentication_controller_test.dart`; `authentication_page_test.dart`; `maestro_app_test.dart` | Protected content is absent while signed out and after sign-out; late or superseded authentication cannot reopen it. |
| FR-AU-07 / BR-21 | `AuthenticatedSession.fullControl` grants the single local permission set for records, workflows, and delivery. | Domain, service, and successful account-creation widget tests | Every successful authentication path produces full-control flags; no differentiated local role exists. |

## External authentication and local recovery extension

The UC-01 extension adds Google sign-in through Heimdall, Windows credentials
for an existing local email account, and recovery codes for password-backed
local accounts. It retains the existing Windows-only account path.

| Behavior | Automated evidence | Manual verification |
| --- | --- | --- |
| Configured Google sign-in | `authentication_service_test.dart`, `authentication_settings_controller_test.dart`, `drift_authentication_settings_repository_test.dart`, `google_browser_authorizer_test.dart`, and `heimdall_authentication_gateway_test.dart` | Save a valid Google desktop OAuth client ID and Heimdall scope UUID in **Authentication settings**. **Continue with Google** becomes available only after the configuration is loaded or saved. |
| Browser OAuth and Heimdall exchange | `google_browser_authorizer_test.dart` and `heimdall_authentication_gateway_test.dart` use a loopback/browser fake and HTTP client fakes, respectively. | Start with `--dart-define=HEIMDALL_API_BASE_URL=https://<host>` (or the local `http://localhost:8080` default), then use a mock `POST /api/auth/google` endpoint that returns a successful Heimdall `DataOutput` envelope. The system browser opens for Google; the temporary `127.0.0.1` callback accepts the exact generated state, then the app enters the protected workspace. Cancellation, timeout, state mismatch, or rejected/malformed output leaves it signed out. |
| Configuration and secret boundaries | `drift_authentication_settings_repository_test.dart`, service audit tests, and gateway/authorizer tests | Confirm that only `authentication.google.oauth_client_id` and `authentication.heimdall.scope_id` are stored in `Settings`. OAuth code, PKCE verifier, Google ID token, Heimdall bearer token, passwords, and recovery-code plaintext are never persisted or logged. |
| Windows credential alternatives | `authentication_service_test.dart` and `authentication_page_test.dart` | Verify the existing **Sign in with Windows** control for the Windows-only local account. For an existing password-backed local account, enter its email and select **Use Windows credentials**; a successful native credential check opens that same account, while unavailable or denied verification stays signed out. |
| Creation-only recovery codes | `authentication_service_test.dart`, `drift_recovery_code_repository_test.dart`, `recovery_code_dialog_test.dart`, and `authentication_page_test.dart` | Create a local password account and record all ten displayed codes before acknowledgement. The dialog blocks workspace entry and displays the codes only once. Sign out, choose **Recover local account**, and redeem one recorded code with a new valid password. A reused or invalid code fails without an account-enumeration disclosure. |

There is deliberately no recovery-code regeneration, email reset link, or
password-reset API. Loss of every recorded recovery code makes the
password-backed local account unrecoverable.

## Use-case flow evidence

| Flow | Evidence |
| --- | --- |
| Main flow 1: select OS or email/password authentication | The signed-out page exposes both choices and local-account creation; widget tests drive each path. |
| Main flow 2: obtain and validate credentials without logging secrets | OS replies are parsed into typed results; emails are validated by a documented bounded ASCII dot-atom/DNS validator and normalized; passwords are obscured, cleared before awaits, validated, and passed only to verifier operations. Invalid email fails before hashing or storage access. Fixed presentation/audit failures exclude credential and native-exception data. |
| Main flow 3: record successful authentication | Service tests assert success audit writes for OS authentication, email sign-in, and account creation before a session opens. |
| Main flow 4: open a full-permission session | Service and widget tests assert one authenticated transition with all full-control permissions. |
| AF-01: OS verification fails or is unavailable | Contract, service, and widget tests keep the session signed out and restore the direct email/password sign-in action, including from account-creation mode. |
| AF-02: password is shorter than eight characters | Domain, service, and widget tests reject it before mutation and display the minimum plus strength guidance. |
| AF-03: normalized email already exists | Service and Drift tests reject case variants without verifier or user writes; the UI shows credential-neutral copy. |
| AF-04: credentials are invalid | Service tests deny access and append a redacted failed-attempt audit; widget tests show credential-neutral copy and no protected content. |

## Security, concurrency, and rollback evidence

- SQLite stores local-user metadata and ordered redacted audits; protected
  storage owns verifier bytes. Plaintext passwords are neither persisted nor
  logged.
- Unknown principals use generated actor identifiers and redacted audit details;
  native exceptions and malformed channel messages fail closed without carrying
  native diagnostic or credential data across the boundary.
- Production authentication composition uses UUIDv7 for persisted local users,
  audit events, and unknown-principal actor identifiers. A Drift-backed test
  verifies canonical version/variant bits on actual persisted user and audit IDs.
- Windows Hello probe and authentication completions capture a shared reply gate,
  not the window. Gate deactivation is serialized before method-handler removal
  and Flutter controller teardown, so late completions cannot reply to a dead
  engine.
- Sign-out, disposal, and newer operations invalidate earlier generations.
  Deterministic delayed-operation tests prove late OS and email completions
  cannot restore or replace a session.
- Account creation compensates attempted writes in audit, user, verifier order.
  Tests cover invalidation after every persistence stage and prove cleanup
  continues after a deletion failure. Because protected storage and SQLite do
  not share a transaction, an unsuccessful deletion returns a sanitized typed
  cleanup failure and never authenticates.
- Root disposal invalidates authentication before closing the shared database;
  lifecycle tests assert exact-once resource release.

## Local verification commands

The following gates ran from the clean UC-01 feature worktree with `TEMP` and
`TMP` set to the same-drive `build/native-temp` directory where native hooks
required it:

```text
dart run build_runner build --delete-conflicting-outputs
# Exit 0; 360 Drift inputs; 42 outputs written; 297 skipped, 6 same, 21 no-op

git diff --exit-code
# Exit 0; generated artifacts produced no tracked changes

dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
# Exit 0; 98 files, 0 changed after local line-ending normalization

dart run tooling/verify_architecture.dart
# Exit 0; architecture-verification: passed

dart run tooling/verify_workflows.dart
# Exit 0; workflow-verification: passed

flutter analyze
# Exit 0; No issues found

flutter test
# Exit 0; 124 tests passed
```

### External authentication extension commands

Run the following from the feature worktree after resolving dependencies:

```text
dart format --set-exit-if-changed .
flutter analyze
flutter test test/features/authentication
flutter test integration_test/foundation_startup_integration_test.dart
flutter test
```

The startup integration assertion verifies that, with a configured but
unauthenticated composition, **Continue with Google** and **Recover local
account** are both exposed. The full command set is the delivery gate for this
extension; the Task 8 report records the actual local command results rather
than treating the historical 124-test result above as evidence for this change.

The formatter initially rewrote mixed working-copy line endings in
`maestro_database.dart` while producing no textual Git diff. A second run
reported 98 files and zero changes; the content-equivalent working-copy rewrite
was restored so this documentation commit contains no source change.

## Platform and delivery status

- Windows: `flutter build windows --debug` passed for the verified
  implementation and produced `build/windows/x64/runner/Debug/maestro.exe`.
  Automated tests use a fake OS boundary plus a native source/lifecycle
  contract; no interactive Windows Hello prompt was invoked.
- Linux: the PAM runner and method-channel contract are implemented, and local
  ABI/static checks were recorded during implementation. This Windows host did
  not compile the GTK runner or invoke an interactive PAM prompt. Ubuntu CI is
  the required compilation and platform gate.
- CI and merge: no pull-request CI result, release artifact, or merged revision
  is claimed by this document. Those delivery checks occur after this commit is
  pushed and the pull request is opened.
