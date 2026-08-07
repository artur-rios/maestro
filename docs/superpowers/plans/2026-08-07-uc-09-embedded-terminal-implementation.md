# UC-09 Use the Embedded Terminal — Implementation Plan

Design: [UC-09 Use the Embedded Terminal Design](../specs/2026-08-07-uc-09-embedded-terminal-design.md).
Issue: [#10](https://github.com/artur-rios/maestro/issues/10). Branch:
`feature/uc-09-use-the-embedded-terminal`, from `main`.

Each step is test-first: write the failing tests named per the Testing
Specification's Given-When-Then convention, then implement until they pass.
Commit at the end of each numbered step.

## 1. Terminal port vocabulary

No tests of their own — these are the types the next steps assert against, and
the Testing Specification exempts plain data carriers from empty tests.

Extend `lib/platform/terminal/terminal_port.dart` with `TerminalExit`,
`TerminalClosure { closed, incomplete }`, `TerminalStartFailureKind
{ shellUnavailable, ptyUnavailable, folderUnavailable }`,
`TerminalStartFailure`, `resize`, `exit`, and the `columns`/`rows` arguments on
`TerminalPort.start`.

## 2. Shell resolution (FR-TE-02, AF-01)

Tests — `test/platform/terminal/platform_shell_test.dart`:
`GivenWindows_WhenResolvingTheShell_ThenPowerShellSevenIsPreferred`,
`GivenWindowsWithoutPowerShellSeven_WhenResolvingTheShell_ThenWindowsPowerShellIsUsed`,
`GivenLinux_WhenResolvingTheShell_ThenBashIsUsed`,
`GivenNoShellOnPath_WhenResolvingTheShell_ThenTheShellIsReportedUnavailable`,
`GivenAnInaccessibleShell_WhenResolvingTheShell_ThenRemediationNamesPermissions`.

Create `lib/platform/terminal/platform_shell.dart` with `ShellCommand`
(executable plus arguments) and `ShellResolver`, driven by the existing
`ExecutableLocator` and an injected `isWindows` flag so both platforms are
covered from either.

## 3. PTY session behavior (FR-TE-04, FR-TE-05)

Tests — `test/platform/terminal/pty_terminal_session_test.dart`:
`GivenALiveSession_WhenTheShellWrites_ThenTheBytesReachTheOutputStream`,
`GivenALiveSession_WhenTheUserTypes_ThenTheBytesReachTheShell`,
`GivenALiveSession_WhenTheViewResizes_ThenThePtyIsResized`,
`GivenALiveSession_WhenTheShellExits_ThenTheExitCodeIsReported`,
`GivenALiveSession_WhenClosing_ThenTheShellIsSignalledBeforeItIsKilled`,
`GivenAShellThatIgnoresTermination_WhenClosing_ThenClosureIsIncomplete`,
`GivenAnAlreadyExitedShell_WhenClosing_ThenNoSignalIsSentAndClosureSucceeds`,
`GivenAClosedSession_WhenClosingAgain_ThenTheShellIsNotSignalledTwice`,
`GivenAStartedSession_WhenItCloses_ThenTheOwnedProcessRecordIsResolved`.

Create `lib/platform/terminal/pty_terminal_session.dart` with the `PtyHandle`
seam, `TerminalSignal`, `TerminalTreeTerminator`, and `PtyTerminalSession`
implementing `TerminalSession`. Ownership is optional and, when present, uses the
existing `RunOwnedResourceStore`-style registration with a
`DurableProcessIdentity`.

## 4. PTY port, folder guard, and probe (FR-TE-01, FR-TE-03, AF-01, AF-02)

Tests — `test/platform/terminal/pty_terminal_port_test.dart`:
`GivenAMissingProjectFolder_WhenStartingATerminal_ThenNoProcessIsStarted`,
`GivenAnUnavailableShell_WhenStartingATerminal_ThenNoPartialSessionIsCreated`,
`GivenAnAvailableShell_WhenStartingATerminal_ThenTheProjectFolderIsTheWorkingDirectory`,
`GivenAnAvailableShell_WhenProbing_ThenTheCapabilityIsAvailable`,
`GivenNoShell_WhenProbing_ThenTheCapabilityIsDegradedWithRemediation`.

Create `lib/platform/terminal/pty_terminal_port.dart` with `PtyTerminalPort`
(resolver, folder access, and a `PtyLauncher` seam) plus `FlutterPtyHandle`, the
one file that imports `flutter_pty`.

## 5. Application service (AF-01, AF-02)

Tests — `test/features/terminal/application/open_project_terminal_test.dart`:
`GivenAnAvailableProjectFolder_WhenOpeningATerminal_ThenASessionIsReturned`,
`GivenAMissingProjectFolder_WhenOpeningATerminal_ThenFolderUnavailableIsReturned`,
`GivenAMissingProjectFolder_WhenOpeningATerminal_ThenTheProjectRecordIsUntouched`,
`GivenAnUnavailableShell_WhenOpeningATerminal_ThenShellUnavailableIsReturnedWithRemediation`,
`GivenAnUnexpectedStartFailure_WhenOpeningATerminal_ThenTheRawErrorIsNotSurfaced`.

Create `lib/features/terminal/domain/terminal_models.dart` and
`lib/features/terminal/application/open_project_terminal.dart`.

## 6. Presentation controller (FR-TE-04, AF-03)

Tests — `test/features/terminal/presentation/project_terminal_controller_test.dart`:
`GivenAnIdleController_WhenOpening_ThenTheStatusBecomesRunning`,
`GivenARunningSession_WhenTheShellWrites_ThenTheTerminalRendersTheBytes`,
`GivenARunningSession_WhenTheTerminalEmitsInput_ThenTheSessionReceivesIt`,
`GivenARunningSession_WhenTheTerminalResizes_ThenTheSessionIsResized`,
`GivenARunningSession_WhenTheShellExitsUnexpectedly_ThenTheExitResultIsShownAndAFreshSessionIsOffered`,
`GivenAnExitedSession_WhenOpeningAgain_ThenANewSessionStarts`,
`GivenARunningSession_WhenClosingLeavesProcessesAlive_ThenIncompleteClosureIsReported`,
`GivenAFailedOpen_WhenTheFailureIsShown_ThenItCarriesRemediation`,
`GivenARunningSession_WhenTheControllerIsDisposed_ThenTheSessionIsClosed`.

Create `lib/features/terminal/presentation/project_terminal_controller.dart`.

## 7. Presentation panel (FR-TE-01, NFR-11)

Tests — `test/features/terminal/presentation/project_terminal_panel_test.dart`:
`GivenAClosedPanel_WhenItRenders_ThenOnlyTheOpenActionIsOffered`,
`GivenARunningSession_WhenThePanelRenders_ThenTheTerminalViewAndCloseActionAreShown`,
`GivenAnExitedSession_WhenThePanelRenders_ThenTheExitResultIsAnnounced`,
`GivenAFailedOpen_WhenThePanelRenders_ThenTheFailureAndRemediationAreAnnounced`,
`GivenThePanel_WhenTraversingWithTheKeyboard_ThenTheActionsAreReachable`,
`GivenThePanel_WhenInspectingSemantics_ThenTheTerminalIsLabelled`.

Create `lib/features/terminal/presentation/project_terminal_panel.dart` with a
bounded `Terminal(maxLines: 5000)`.

## 8. Workspace wiring

Tests — `test/features/projects/presentation/project_workspace_page_test.dart`
(existing file):
`GivenATerminalBuilder_WhenAnAvailableProjectIsSelected_ThenTheTerminalPanelIsShown`,
`GivenAnUnavailableProjectFolder_WhenItIsSelected_ThenNoTerminalPanelIsShown`.

Add the optional `terminalBuilder` to `ProjectWorkspacePage` and `MaestroApp`,
and compose `PtyTerminalPort`, `OpenProjectTerminal`, and the panel in
`lib/main.dart`. Add the `shell` capability probe to
`ProductionFoundation.probes`, covered in
`test/features/foundation/data/production_foundation_test.dart` by
`GivenAnAvailableShell_WhenProbingTheFoundation_ThenTheShellCheckIsReady`.

## 9. Desktop integration (FR-TE-03, FR-TE-05)

Tests — `integration_test/terminal/embedded_terminal_integration_test.dart`:
`GivenARegisteredProjectFolder_WhenOpeningATerminal_ThenTheShellStartsInThatFolder`,
`GivenALiveTerminal_WhenACommandIsTyped_ThenItsOutputIsRendered`,
`GivenALiveTerminal_WhenTheViewResizes_ThenTheShellObservesTheNewSize`,
`GivenALiveTerminal_WhenItIsClosed_ThenTheShellProcessTreeIsGone`.

Real shell, temporary folder, no project source touched.

## 10. Verify and deliver

```bash
flutter analyze
```

```bash
dart run tooling/verify_architecture.dart
```

```bash
dart run tooling/verify_workflows.dart
```

```bash
flutter test
```

Then write `docs/development/uc-09-verification.md` tracing FR-TE-01..05, BR-18,
NFR-03, NFR-11, NFR-12, the main flow, and AF-01..03; mark `#10` done in the
README backlog and update the M-04 milestone count to `4 / 4 closed`; open the
pull request into `main` with `Closes #10`.
