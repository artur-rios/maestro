# Technology Stack — Maestro

## Platform & Language

- **UI and application runtime:** Flutter and Dart, using the latest stable compatible releases selected at
  implementation time. Exact versions will be pinned in the formal Technology Stack Document.
- **Desktop targets:** Windows and Linux.
- **Architecture:** A single native Flutter desktop process with UI, domain, orchestration, and persistence
  layers written in Dart. This follows Flutter's recommended separation into views, view models, repositories,
  and services, with a domain layer for workflow orchestration.
- **Concurrency:** Dart asynchronous streams for process output and isolates for blocking or CPU-intensive
  work. Each active workflow run is supervised independently so concurrent runs do not block the UI.

This avoids a second backend runtime, keeps domain and integration code in one language, and preserves native
desktop performance. Flutter's architecture guidance supports layered, testable applications, while Dart's
process APIs and isolates provide the primitives needed for concurrent local orchestration.

## Application Type

Maestro is a native desktop application. Its backend runs inside the Flutter application rather than as a
separate service. The application includes:

- A Flutter graphical interface for projects, workflow design, live execution, and history.
- An in-process workflow orchestration engine.
- Platform adapters for Git, GitHub, authentication, process supervision, and packaging.
- An embedded terminal connected to a native pseudo-terminal.

## Data Storage

SQLite stores Maestro-managed data, including users, registered project metadata, workflow definitions,
immutable run snapshots, step executions, logs, lifecycle state, and deletion state. The database runs in a
background isolate so synchronous database work cannot stall Flutter's UI thread.

Source projects remain outside Maestro's storage. Maestro stores a reference to each folder but has no
ownership or deletion control over its contents.

## Data Access

Drift is the selected SQLite data-access layer. It provides type-safe queries, schema migrations, transactions,
reactive streams, and background-isolate support across Windows and Linux. Repositories isolate Drift from the
domain layer so persistence can be tested and evolved without coupling workflow logic to SQL.

## Authentication

Authentication uses a provider boundary with two first-release local implementations:

- Operating-system credential authentication through platform-specific adapters.
- Local email-and-password authentication, with credentials protected by the operating system's secure storage
  facilities and only non-secret account metadata stored in SQLite.

Every locally authenticated user has full control. The provider boundary must support a future external
authentication service, but that external integration is not implemented in the first release.

## Testing

- **Unit and widget tests:** Flutter's `flutter_test` framework.
- **Pure Dart tests:** Dart's `test` framework for domain and orchestration components.
- **Integration tests:** Flutter's `integration_test` framework on Windows and Linux.
- **Test doubles:** Interface-based fakes for AI CLIs, Git, GitHub, authentication, clocks, process supervision,
  and persistence.
- **Persistence tests:** Drift databases created in memory or in isolated temporary files, including migration
  verification.
- **Process tests:** Fake adapters for deterministic coverage plus platform integration tests for real PTY,
  pause, cancellation, termination-tree, and log-stream behavior.

The intended full test command is `flutter test`. Platform integration suites will be executed separately in
the target operating-system CI jobs.

## External Dependencies

- **AI CLIs:** Claude Code, OpenAI Codex, and OpenCode. Maestro relies on their existing local installations
  and authenticated sessions.
- **Source control:** Git installed locally, with GitHub used for issue and pull-request workflows.
- **Shells:** PowerShell 7 on Windows and Bash on Linux.
- **Terminal UI:** `xterm` for terminal emulation.
- **Pseudo-terminal:** `flutter_pty` behind a Maestro-owned adapter, using Windows ConPTY and Unix PTY support.
  The adapter also owns platform-specific process-tree termination so cancellation stops all run-related
  processes, not only the immediate child.
- **Persistence:** SQLite through Drift and its native SQLite integration.
- **Secure secrets:** Operating-system credential and secure-storage facilities through platform adapters.

No email, payment, message-broker, object-storage, or other remote application service is required for the
first release.

## Deployment

GitHub Releases is the distribution target. CI builds and tests artifacts on their target operating systems:

- **Windows:** A portable ZIP containing the Flutter runner and required files, plus an installable MSIX package.
- **Linux:** A portable AppImage, plus an installable Linux package produced for the supported distribution
  targets.

The precise Linux installer formats and supported distribution matrix are not yet decided; they will be
resolved before the formal Operations & Infrastructure Document is written.

Users download portable or installable artifacts from the project's GitHub repository. Store-based publishing
and automatic updating have not been selected.
