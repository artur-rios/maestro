# Task 6 report: production authentication composition

## Delivered

- Production composition now supplies Drift-backed authentication settings and
  recovery-code repositories, the browser Google authorizer, and the Heimdall
  gateway to `AuthenticationService`.
- The production gateway is constructed during composition, so its existing
  `HEIMDALL_API_BASE_URL` validation runs before any browser or network action.
- Composition exposes injectable authentication ports for isolated tests and
  passes the settings repository into the app's Riverpod scope.
- Added `AuthenticationSettingsController`, including initial load, validated
  save, input-change error clearing, and redacted state containing only OAuth
  client ID and scope UUID.
- Updated the legacy account-creation controller handoff to preserve the
  recovery-code acknowledgement gate introduced by Task 5. Task 7 remains
  responsible for rendering and acknowledging the one-time code set.

## TDD evidence

- RED: settings-controller focused test failed because the controller module,
  provider, and state types did not exist.
- RED: input-change test failed after temporarily removing `updateInput`.
- GREEN: the focused controller and production-composition tests passed after
  the minimal implementations were added.

## Verification

- `dart analyze` on every changed production and focused-test file: no issues.
- `flutter test test/features/authentication/application/authentication_service_test.dart test/app/production_authentication_composition_test.dart test/features/authentication/presentation/authentication_settings_controller_test.dart`: 63 passed.
- `git diff --check`: clean.

The Flutter commands used a worktree-local `TEMP`/`TMP` directory because the
Sodium native hook cannot rename its fallback DLL across Windows drives.

## Scope hygiene

The pre-existing generated `test/generated/schema_v*.dart` modifications were
not changed or staged.
