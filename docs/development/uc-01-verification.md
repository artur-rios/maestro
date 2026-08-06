# UC-01 verification evidence

This record traces [issue #2](https://github.com/artur-rios/maestro/issues/2)
and [UC-01](../requirements/Use%20Case%20Specification%20Document.md#uc-01-authenticate-locally)
to the implementation and local verification evidence prepared for review.

- Verified source SHA: `eec7d69b5708aee6af8df827535de0baf9387c51`
- Toolchain: Flutter 3.44.8 and Dart 3.12.2
- Local full-suite result: 116 tests passed
- Native build evidence: the Windows debug runner built successfully at the
  verified source SHA
- Pending delivery evidence: pull-request CI and Ubuntu Linux compilation have
  not run yet and must pass before merge

## Requirement traceability

| Requirement | Implementation | Automated evidence | Verified outcome |
| --- | --- | --- | --- |
| FR-AU-01 | `MethodChannelAuthentication` and the Windows Hello/Linux PAM hosts implement operating-system verification through `dev.artur-rios.maestro/authentication`. | `method_channel_authentication_test.dart`; Windows debug compilation | Typed availability, approval, denial, unavailable, malformed, and sanitized-exception paths pass. The Windows runner compiles; Linux remains CI-gated. |
| FR-AU-02 | Account creation normalizes email addresses, enforces database uniqueness, stores non-secret user metadata, and opens a session only after all writes succeed. | `authentication_models_test.dart`; `authentication_service_test.dart`; `drift_authentication_repository_test.dart`; account-creation widget test | Mixed-case normalization, duplicate rejection before mutation, case-insensitive persistence uniqueness, and successful creation pass. |
| FR-AU-03 | `LocalPassword.validate` requires at least eight characters before verifier creation. | Domain, service, and widget tests for seven-, eight-, and short-password cases | Short passwords are rejected without storage mutation; eight characters are accepted. |
| FR-AU-04 | Account-creation UI shows the minimum-length and strong, unique password guidance before submission and after rejection. | `authentication_page_test.dart` | Guidance is visible and is not duplicated after AF-02. |
| FR-AU-05 | Sodium creates salted Argon2 verifier strings; only UTF-8 verifier bytes cross the protected-storage boundary. Password text is not written to Drift, audit details, failures, or presentation state. | `sodium_password_hasher_test.dart`; `protected_password_verifier_store_test.dart`; repository and service audit tests | A verifier accepts only its source password, hashing yields to the event loop, malformed protected bytes fail, and audit/storage assertions contain no submitted credentials. |
| FR-AU-06 | `AuthenticationPage` invokes the protected-content builder only for an authenticated controller state. Sign-out, disposal, failure, and stale completions remain outside the shell. | `authentication_controller_test.dart`; `authentication_page_test.dart`; `maestro_app_test.dart` | Protected content is absent while signed out and after sign-out; late or superseded authentication cannot reopen it. |
| FR-AU-07 / BR-21 | `AuthenticatedSession.fullControl` grants the single local permission set for records, workflows, and delivery. | Domain, service, and successful account-creation widget tests | Every successful authentication path produces full-control flags; no differentiated local role exists. |

## Use-case flow evidence

| Flow | Evidence |
| --- | --- |
| Main flow 1: select OS or email/password authentication | The signed-out page exposes both choices and local-account creation; widget tests drive each path. |
| Main flow 2: obtain and validate credentials without logging secrets | OS replies are parsed into typed results; emails are normalized; passwords are obscured, cleared before awaits, validated, and passed only to verifier operations. Fixed presentation/audit failures exclude credential and native-exception data. |
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
# Exit 0; 116 tests passed
```

The formatter initially rewrote mixed working-copy line endings in
`maestro_database.dart` while producing no textual Git diff. A second run
reported 98 files and zero changes; the content-equivalent working-copy rewrite
was restored so this documentation commit contains no source change.

## Platform and delivery status

- Windows: `flutter build windows --debug` passed at the verified source SHA and
  produced `build/windows/x64/runner/Debug/maestro.exe`. Automated tests use a
  fake OS boundary; no interactive Windows Hello prompt was invoked.
- Linux: the PAM runner and method-channel contract are implemented, and local
  ABI/static checks were recorded during implementation. This Windows host did
  not compile the GTK runner or invoke an interactive PAM prompt. Ubuntu CI is
  the required compilation and platform gate.
- CI and merge: no pull-request CI result, release artifact, or merged revision
  is claimed by this document. Those delivery checks occur after this commit is
  pushed and the pull request is opened.
