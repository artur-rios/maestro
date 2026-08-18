# Task 7 report: authentication presentation

## Delivered

- Extended `AuthenticationController` with Google, email-account Windows,
  local recovery, and recovery-code acknowledgement events.
- Added an ephemeral recovery-code presentation state. It owns only the
  one-time display strings, clears them on acknowledgement, sign-out, or
  controller disposal, and never persists or logs them.
- Consumed `AuthenticationService.sessionChanges` so remote-session expiry
  immediately removes the protected presentation.
- Kept standalone **Sign in with Windows** separate from the email-account
  **Use Windows credentials** action.
- Added the Google action and compact persisted client-ID/scope settings panel,
  including local validation feedback.
- Added the email/code/new-password/confirmation recovery form with no reset,
  email-link, regeneration, or alternate recovery action.
- Added a non-dismissible acknowledgement dialog containing selectable,
  monospace recovery codes and the exact required semantics.
- Disabled every authentication action while an operation is active and
  cleared password/recovery plaintext on submission, navigation, and disposal.

## TDD evidence

- RED: the first controller test load failed on the missing pending-code state
  and the four missing controller events.
- GREEN: seven controller tests passed after the minimal state/event layer was
  added.
- RED: widget tests failed on all four missing semantic actions, the absent
  settings/recovery forms, and the missing recovery-code dialog module.
- GREEN: 25 widget/dialog tests passed after the presentation was added.
- RED: the external-expiry regression test observed an authenticated
  presentation after the service had revoked its Google session.
- GREEN: subscribing to the existing service session stream returned the
  controller to signed out; all eight controller tests then passed.

## Verification

- Focused analysis of the three production and three test files: no issues.
- Task 7 command covering controller, page, and dialog: 33 tests passed.
- Full `flutter analyze` remains blocked by pre-existing Task 5 fixture drift:
  `integration_test/foundation_startup_integration_test.dart` and
  `test/app/maestro_app_test.dart` omit the five new required
  `AuthenticationService` dependencies. Existing Task 4 curly-brace lint
  infos also remain. Task 7 did not modify those out-of-scope files.

## Scope hygiene

Only the three Task 7 production files, their three focused test files, and
this report are included. Pre-existing generated schema line-ending changes
and SDD coordination artifacts are not staged.
