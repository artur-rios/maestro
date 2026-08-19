# Task 7 fix round 1 report

## Review findings resolved

- Made recovery acknowledgement keyboard-modal with a closed-loop focus scope,
  explicit initial focus on **Acknowledge recovery codes**, excluded background
  focus, disabled background controls, and a controller guard that rejects all
  competing authentication while acknowledgement is pending. Escape cannot
  dismiss the overlay, and Enter can activate only the acknowledgement action.
- Added `abandonRecoveryCodePresentation()` and invoked it when the page is
  disposed. The original controller-owned plaintext list is cleared
  synchronously; pending service acknowledgement is invalidated without
  authentication. The dialog also clears both its private copy and its
  caller-owned list on disposal.
- Expanded authentication settings into explicit loading, dirty, saving,
  saved, and error states. Google is enabled only for successfully loaded or
  saved valid configuration. Settings fields and save action disable while
  persistence is active.
- Aligned the approved local action copy to **Sign in** and
  **Create local account** while retaining separate standalone Windows and
  email-account Windows actions.
- Added widget regressions for closed-loop Tab/Shift-Tab traversal, Escape and
  Enter behavior, competing-operation rejection, retained-container
  unmount/remount plaintext clearing, ten selectable monospace codes, dialog
  disposal clearing, configuration gating, settings-save busy state, complete
  authentication busy disabling, and protected-shell removal on Google expiry.

## TDD evidence

- RED: a competing Windows sign-in ran while recovery acknowledgement was
  pending. GREEN: the controller rejected it and retained the pending state.
- RED: retaining the provider container across page unmount preserved all ten
  plaintext codes. GREEN: unmount emptied the original list, invalidated the
  pending session, and remount displayed no codes.
- RED: acknowledgement had no initial focus. GREEN: focus remained within the
  dialog through forward and reverse traversal; Escape kept it open and Enter
  acknowledged without invoking Windows authentication.
- RED: settings tests could not represent saved/dirty/saving state and Google
  was enabled while loading. GREEN: the explicit state machine and page gate
  enforce persisted-valid configuration.
- RED: approved **Sign in** semantics were absent. GREEN: both approved local
  labels are exact and the legacy copy is absent.
- RED: dialog disposal left its caller-owned plaintext list populated. GREEN:
  both dialog-held lists are cleared.

## Verification

- Focused Dart analysis of four production and four test files: no issues.
- Combined controller, settings-controller, page, and dialog command: 43 tests
  passed.
- Scoped `git diff --check`: clean.

## Scope hygiene

Only Task 7 presentation/controller files, their focused tests, and this report
are included. Pre-existing generated schema changes and SDD coordination files
remain untouched and unstaged.
