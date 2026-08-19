# Final fixes report

## Outcome

All findings in the final branch review were addressed.

## Fixes

- Recovery-code consumption now requires the resolved local user ID and digest.
  The Drift update predicates on user ID, digest, and unused state in one atomic
  statement. Service and repository regressions exercise two distinct users and
  prove that one account's code cannot reset another account's verifier or be
  consumed by the failed attempt.
- Google browser, token-exchange, Heimdall, and malformed persisted-configuration
  failures now cross application boundaries through port-owned typed failure
  kinds. The service maps every kind to a fixed `MaestroFailure` code, message,
  and remediation without retaining the original cause. The controller preserves
  those codes and redacted messages instead of collapsing them.
- The email-account Windows action now probes `AuthenticationPort`. It remains
  disabled unless the capability is available and displays password-or-recovery
  guidance when unsupported or unavailable. Native denial remains
  non-enumerating invalid credentials, while unavailability and other typed
  platform failures retain distinct stable codes and safe remediation.
- Application composition now supplies the production authentication port to
  presentation, and controller disposal tolerates late recovery-dialog cleanup.
- The loopback redirect URI is captured while the listener remains bound and the
  same immutable URI is reused for both browser authorization and token exchange.
- Application and startup fixtures now provide the settings and capability ports
  required by the feature, and their assertions use the approved Windows label.

## Regression coverage

- Two-account recovery-code ownership at the service and Drift repository layers.
- Every concrete Google/OAuth and Heimdall typed failure, plus malformed stored
  configuration, at both service and controller layers.
- Native denial versus unavailable Windows credentials at service/controller
  layers.
- Unsupported Windows capability at the widget layer and production capability
  composition.
- A production-shaped real loopback callback completing through token exchange,
  including probe rejection and post-callback listener closure.
- Throwing token-exchange abort cleanup after the listener has already closed.
- Application-shell and production-startup composition with the feature ports.

## Verification

- `dart format --set-exit-if-changed`: passed for all scoped files.
- `flutter analyze`: passed with no issues.
- `dart run tooling/verify_architecture.dart`: passed.
- Review-focused Flutter tests: 138 passed.
- Authentication-page widget suite: 29 passed.
- Google browser authorizer suite: 9 passed.
- Maestro application-shell suite: 14 passed.
- Foundation startup integration suite: 4 passed.
