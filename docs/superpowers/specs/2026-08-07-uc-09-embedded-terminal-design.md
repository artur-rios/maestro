# UC-09 Use the Embedded Terminal Design

## Scope and boundaries

UC-09 owns one thing: an interactive platform shell, rooted at the selected
project folder, embedded in the project workspace. It is not a run view. It
streams nothing into run history, writes no attempt evidence, and has no
relationship to `RunOrchestrator` — an agent step and a user shell are different
processes with different lifetimes.

Three existing facts shape the design:

- `lib/platform/terminal/terminal_port.dart` already declares `TerminalPort` and
  `TerminalSession` with `output`, `write`, and `close`. Nothing implements them.
  UC-09 fills that hole rather than opening a new one.
- `xterm` and `flutter_pty` are already declared in `pubspec.yaml` and named by
  the Technology Stack Document as the terminal emulator and PTY. Neither has
  ever been imported.
- BR-18 says a project registration never gives Maestro ownership of the project
  folder. The terminal starts *in* that folder and owns nothing there. What
  Maestro owns is the shell process, and only for the session's lifetime.

Terminal output is transient. It is scrollback in a widget, not durable
evidence, so nothing here touches the database.

## Platform layer

### The port

`TerminalPort` grows what an interactive session actually needs, and
`TerminalSession` grows the rest of FR-TE-04:

```dart
abstract interface class TerminalSession {
  Stream<Uint8List> get output;
  Future<TerminalExit> get exit;

  Future<void> write(Uint8List bytes);
  Future<void> resize({required int columns, required int rows});
  Future<TerminalClosure> close();
}

abstract interface class TerminalPort implements CapabilityProbe {
  Future<TerminalSession> start({
    required String workingDirectory,
    required int columns,
    required int rows,
  });
}
```

- `TerminalExit(int exitCode)` completes when the shell ends for any reason,
  which is what AF-03 renders.
- `TerminalClosure { closed, incomplete }` reports whether the process tree is
  actually gone. This mirrors UC-08's `CancellationOutcome`: a session whose
  descendants survived is not a closed session, and the view must not claim it
  is.
- `start` throws a typed `TerminalStartFailure(kind, message, remediation)` with
  `kind` in `{ shellUnavailable, ptyUnavailable, folderUnavailable }`. It either
  returns a live session or throws — never a half-started one, which is AF-01's
  "does not create a partial session".

Selection, copy, and paste are the remaining part of FR-TE-04. They are terminal
*emulator* behavior, not PTY behavior: `xterm`'s `TerminalView` owns the
selection model and the clipboard, and paste arrives back through `write`. The
port deliberately has no API for them.

### Shell resolution (FR-TE-02, AF-01)

`lib/platform/terminal/platform_shell.dart` resolves the shell through the
existing `ExecutableLocator`, so PATH semantics, Windows extensions, and the
permission checks are the ones the repository already uses:

| Platform | Candidates, in order | Arguments |
| --- | --- | --- |
| Windows | `pwsh`, then `powershell` | `-NoLogo` |
| Linux | `bash` | `-i` |

Windows prefers PowerShell 7 and falls back to Windows PowerShell, matching
`ExecutableResolver._findPowerShell`'s existing reasoning. No candidate resolving
is `shellUnavailable`; a candidate found but not executable is the same kind with
a different message, because the user's remediation differs (install versus fix
permissions) and the guidance carries it.

`ShellResolver` is a pure function of the locator's answers, so AF-01 is unit
testable on both platforms from either platform.

### PTY session (FR-TE-03, FR-TE-05, AF-02)

`PtyTerminalPort` starts the resolved shell through `flutter_pty` with
`workingDirectory` set to the project folder — that is FR-TE-03 in one argument,
and the reason the shell is the *project's* terminal rather than a generic one.
Before starting, it stats the folder; a missing or inaccessible folder is
`folderUnavailable` and nothing is spawned (AF-02, startup half).

`flutter_pty` needs the plugin's native library, so it cannot run under
`flutter test`. It sits behind a one-method seam:

```dart
abstract interface class PtyHandle {
  int get pid;
  Stream<Uint8List> get output;
  Future<int> get exitCode;
  void write(Uint8List bytes);
  void resize(int columns, int rows);
  void kill(TerminalSignal signal);
}
```

`FlutterPtyHandle` is the thin production adapter over `Pty`; every behavior worth
testing — closure escalation, exit propagation, idempotency, ownership
bookkeeping — lives in `PtyTerminalSession`, which takes a `PtyHandle` and is
fully faked in unit tests. The pattern matches `OwnedStepProcessLauncher`, which
separates the same way.

**Closure (FR-TE-05).** `close()` escalates rather than assuming a single signal
is enough, the same shape UC-08 established for run cancellation:

1. Signal the shell to terminate and wait, bounded, for `exitCode`.
2. On timeout, kill it and wait again.
3. Still alive → `TerminalClosure.incomplete`.

On Linux, `flutter_pty` puts the shell in its own session, so signalling the
leader reaches the descendants. On Windows, closing the ConPTY ends the shell,
and a `taskkill /T /F /PID` escalation covers descendants that outlive it. That
escalation is a `TerminalTreeTerminator` port with a platform implementation, so
the escalation *policy* is testable without killing anything.

`close()` is idempotent and safe after the shell has already exited: a session
that ended on its own is already closed, and re-closing returns `closed` without
signalling a pid that the operating system may have reused.

**Ownership.** The session registers itself in the existing owned-resource store
as an `OwnedResourceKind.process` with a `DurableProcessIdentity`, and resolves
that record when it closes. If Maestro is killed with a terminal open, startup
reconciliation already sweeps such records — the mechanism UC-06 built for agent
processes covers shells for free. Ownership is optional in the constructor, so
tests and the widget-only path need no store.

**Probe.** `probe()` reports shell availability as a `Capability`, and
`ProductionFoundation.probes` gains it under the id `shell`. The Operations &
Infrastructure Document's startup table already lists "Shell and PTY"; this makes
that row real, and a degraded probe is how the user learns about AF-01 before
opening a terminal rather than after.

## Feature layer

`lib/features/terminal/` — a small feature with no data layer, because there is
nothing to persist.

### Domain

`terminal_models.dart` holds the pure vocabulary: `TerminalSessionStatus`
`{ idle, starting, running, exited, failed }` and `TerminalFailure(code, message,
remediation)` with the four typed codes:

| Code | Cause |
| --- | --- |
| `terminal.shell_unavailable` | AF-01 |
| `terminal.folder_unavailable` | AF-02 |
| `terminal.close_incomplete` | Descendants survived closure |
| `terminal.start_failed` | Anything else, reported without leaking the raw error |

### Application

`OpenProjectTerminal` composes folder availability and the port:

- It re-checks the project folder through the existing
  `ProjectDirectoryAccess` before starting, so a folder that vanished since
  registration fails as AF-02 rather than as an opaque PTY error. The project
  record is untouched either way — the use case's postcondition, and BR-18's
  boundary.
- It maps `TerminalStartFailure` to a `TerminalFailure`, returning
  `Result<TerminalSession>` in the repository's existing style.
- It never opens a session for a folder it could not confirm.

### Presentation

`ProjectTerminalController` (a `ChangeNotifier`, following
`RunControlController`'s generation and disposal guards) owns one session at a
time and bridges it to an `xterm` `Terminal`:

- session bytes → `terminal.write(utf8-decoded)`;
- `terminal.onOutput` (keystrokes and pasted text) → `session.write`;
- `terminal.onResize` → `session.resize`, which is FR-TE-04's resize;
- `exit` completing → status `exited` with the code, and the panel offers
  **Start a fresh session** (AF-03) — the controller never auto-restarts, because
  a shell that died has state the user may want to read;
- `close()` → the escalation above, surfacing `terminal.close_incomplete` when it
  reports `incomplete`.

The controller closes its session on `dispose`, so navigating away or closing the
window does not leave a shell behind.

`ProjectTerminalPanel` renders an `xterm` `TerminalView` with a bounded
scrollback (`Terminal(maxLines: 5000)`), keeping memory bounded per NFR-03
without persisting a byte. Every typed failure it renders carries remediation,
which is NFR-12. It is a collapsed card until the user opens a session,
because a PTY per selected project is a process the user did not ask for. Around
the view: an Open/Close action, a live region for failures and exit results, and
`Semantics` labels matching the existing panels. Selection, copy (Ctrl+Shift+C),
and paste (Ctrl+Shift+V) come from `TerminalView` itself.

## Wiring

`ProjectWorkspacePage` takes an optional `terminalBuilder` of the existing
`RunStartWorkspaceBuilder` shape and renders it below the run panels, gated on
`folderActionsEnabled` — an unavailable folder offers no terminal, which is AF-02
before the fact. `MaestroApp` passes it through, and `main.dart` composes
`PtyTerminalPort` with the owned-resource store. Every seam stays optional, so
existing widget tests that build the workspace without a terminal keep working.

## Verification strategy

Following the Testing Specification, at the lowest correct layer:

- **Platform — shell resolution.** Windows candidate order and the Linux choice,
  the missing-shell and inaccessible-shell paths (AF-01), both driven from a fake
  locator so both platforms are covered from either.
- **Platform — session.** Against a fake `PtyHandle`: output relay, write,
  resize, exit propagation, closure escalation from signal to kill, `incomplete`
  when the tree survives, idempotent and post-exit closure, and ownership
  registered on start and resolved on close.
- **Platform — port.** Missing folder rejected before any spawn (AF-02),
  unresolvable shell rejected without a partial session (AF-01), and the
  capability probe's available and degraded states.
- **Application.** `OpenProjectTerminal`'s main flow and each typed failure.
- **Presentation — controller.** Status transitions, bytes both ways, resize
  forwarding, exit rendering and fresh-session availability (AF-03), incomplete
  closure, and disposal closing the session.
- **Presentation — widget.** Idle, starting, running, exited, and failed states,
  keyboard focus, and semantics.
- **Desktop integration.** A real shell in a temporary folder: echo a marker and
  read it back, resize, close, and assert the process is gone — the one place
  FR-TE-05 can be proven rather than modelled. It runs on the platform CI job,
  like the existing PTY and process-tree suites.
