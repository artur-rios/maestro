# UC-09 verification evidence

This record traces [issue #10](https://github.com/artur-rios/maestro/issues/10)
and [UC-09](../requirements/Use%20Case%20Specification%20Document.md#uc-09-use-the-embedded-terminal)
to the implementation and local verification evidence prepared for review.

- Toolchain: Flutter 3.44.9 and Dart 3.12.2 on Windows.
- Local full-suite result: 743 tests passed.
- Static analysis and architecture/workflow verification: passed.
- Terminal-focused coverage: 45 named scenarios across platform, application,
  presentation, workspace composition, and a real-shell integration test.

## Requirement traceability

| Requirement | Implementation | Verified evidence |
| --- | --- | --- |
| FR-TE-01 | `ProjectTerminalPanel` embeds an `xterm` view in the selected project workspace; `ProjectWorkspacePage`, `MaestroApp`, and `main.dart` compose it only for an available project folder. | Panel, workspace, and composition tests verify the open action, rendered view, semantics, and availability gate. |
| FR-TE-02 | `ShellResolver` chooses `pwsh` then Windows PowerShell on Windows and Bash on Linux, returning typed remediation when no usable shell is found. | `platform_shell_test.dart` covers each platform choice, preference order, missing shell, and inaccessible shell. |
| FR-TE-03 | `PtyTerminalPort` validates the folder before spawning and sends it as the PTY working directory. If post-launch ownership initialization fails, it closes the spawned process tree before returning a typed failure. | Port tests reject a missing folder without launch, assert the launch request uses the project directory, and prove ownership setup failure closes the tree; integration coverage starts a real shell in a temporary project folder. |
| FR-TE-04 | `ProjectTerminalController` relays UTF-8 output, input, and resize between `Terminal` and `TerminalSession`; `TerminalView` supplies selection, copy, and paste. | Session and controller tests cover output, input, resize, status transitions, and terminal rendering. |
| FR-TE-05 | `PtyTerminalSession.close` escalates from termination to kill through `TerminalTreeTerminator`, resolves owned-process bookkeeping, and reports incomplete closure without claiming success. | Session tests cover escalation, incomplete and idempotent closure; `embedded_terminal_integration_test.dart` proves a real terminal process tree is gone after close. |
| BR-18 / NFR-03 | Terminal startup only accesses the registered folder and never changes its project record; `Terminal(maxLines: 5000)` bounds transient scrollback. | `open_project_terminal_test.dart` proves unavailable folders leave project state untouched; controller tests exercise terminal construction and disposal. |
| NFR-11 / NFR-12 | Terminal actions and state messages are keyboard reachable, semantically labelled, announced through live regions, and carry remediation. | Panel tests cover keyboard reachability, semantics, exit announcement, and typed failure remediation. |

## Use-case flow evidence

| Flow | Evidence and outcome |
| --- | --- |
| Main flow | The user opens the terminal panel; the application checks folder availability, resolves the platform shell, starts a PTY in the project folder, relays the interactive terminal stream, and closes the owned process tree on explicit close. |
| AF-01 — shell or PTY unavailable | The port returns a typed start failure before a session is exposed; the application maps it to a remediable user-facing failure. |
| AF-02 — project folder unavailable | Both application and platform guards refuse startup before spawning, leave the project record untouched, and the workspace omits the terminal for unavailable folders. While running, the controller rechecks availability every five seconds; loss of access closes the session and presents folder remediation. |
| AF-03 — unexpected shell exit | The controller records and announces the exit code, preserves visible terminal output, and offers a fresh session without automatic restart. |

## Local verification commands

```text
flutter analyze
No issues found! (ran in 54.7s)

dart run tooling/verify_architecture.dart
architecture-verification: passed

dart run tooling/verify_workflows.dart
workflow-verification: passed

flutter test
743 tests passed
```

The Flutter tool initially stalled because its stale SDK lock and sandboxed
user-level state file prevented startup. After removing the stale lock and
allowing Flutter to update its normal state, all commands above completed with
exit code zero.
