# Technology Stack Document — Maestro

## 1. Purpose

This document is the **single source of truth for the technologies used to build Maestro**. Other requirements
documents reference it instead of repeating technology choices or versions. When a technology changes, this
document changes first.

---

## 2. Platform & Language

| Concern | Choice | Notes |
| --- | --- | --- |
| Runtime and UI framework | **Flutter** | Native Windows and Linux desktop targets; resolved version is committed with the project toolchain configuration. |
| Language | **Dart** | The SDK bundled with the selected Flutter release. |
| Version policy | **Latest stable at implementation time** | CI and the dependency lockfile pin the actual resolved releases for reproducible builds. |
| Language settings | Sound null safety, strict analysis, strict inference | Applied project-wide. |
| Architecture | Feature-first MVVM with domain, repository, service, and platform-adapter boundaries | UI and backend execute in one Flutter process. |
| Concurrency | Dart futures, streams, and isolates | Keeps process streaming and database work off latency-sensitive UI paths. |

---

## 3. Libraries

| Package or facility | Version | Used by | Role |
| --- | --- | --- | --- |
| **flutter_riverpod** | `latest stable at implementation time` | UI and composition root | Reactive state management and dependency injection. |
| **drift** | `latest stable at implementation time` | Data layer | Type-safe SQLite queries, transactions, streams, and migrations. |
| **drift_flutter** | `latest stable at implementation time` | Data bootstrap | Native database location and background-isolate integration. |
| **sqlite3** | `latest stable at implementation time` | Data layer | Native SQLite bindings used by Drift. |
| **xterm** | `latest stable at implementation time` | Terminal feature | Flutter terminal emulation and rendering. |
| **flutter_pty** | `latest stable at implementation time` | Process adapter | Native pseudo-terminal access for Windows and Linux. |
| **flutter_secure_storage** | `latest stable at implementation time` | Authentication | Access to operating-system protected secret storage. |
| **sodium** | `latest stable at implementation time` | Authentication and updates | Password hashing and update-manifest signature verification. |
| **uuid** | `latest stable at implementation time` | Domain layer | UUIDv7 identifier generation. |
| **path_provider** | `latest stable at implementation time` | Data and runtime services | Application-data, log, update, and worktree locations. |
| **package_info_plus** | `latest stable at implementation time` | Update service | Installed application version discovery. |
| **logging** | `latest stable at implementation time` | Cross-cutting logging | Structured application and audit event emission. |

The PTY package is isolated behind a Maestro-owned interface. Platform-specific process-group handling uses
Windows job objects and Unix process groups through Dart FFI when the package API cannot guarantee whole-tree
termination.

---

## 4. Data Storage

| Concern | Choice |
| --- | --- |
| Primary datastore | **SQLite** — local, transactional, portable, and appropriate for a single-process desktop application. |
| Database location | Per-user Maestro application-data directory obtained through the platform path provider. |
| Execution model | A dedicated background isolate prevents synchronous SQLite work from blocking the UI. |
| Test storage | In-memory SQLite for repository tests and isolated temporary SQLite files for migration tests. |
| Log compaction | Lossless compression in SQLite-backed segments; compacted segments can be expanded on demand. |

---

## 5. Data Access

| Concern | Choice | Version |
| --- | --- | --- |
| ORM and query layer | **Drift** | `latest stable at implementation time` |
| Native driver | **sqlite3** | `latest stable at implementation time` |
| Migrations | Drift schema-step generation and migration verification | `latest stable at implementation time` |
| Naming convention | `snake_case` tables and columns; singular Dart domain types | — |

Repositories are the domain-facing sources of truth. They expose domain models and streams, own transactions,
and prevent UI and orchestration code from depending on database APIs.

---

## 6. Cross-Cutting Technologies

| Concern | Technology | Version | How it is used |
| --- | --- | --- | --- |
| Input validation | Dart domain value objects and form validators | `Dart SDK` | Validation occurs before commands reach repositories or platform adapters. |
| Logging | `logging` plus Maestro sinks | `latest stable at implementation time` | Structured local application, execution, and audit records with redaction. |
| OS authentication | Windows Hello and Linux PAM adapters | `operating-system supplied` | Verifies the current local user through native platform boundaries. |
| Email/password authentication | `sodium` password hashing plus protected storage | `latest stable at implementation time` | Stores salted password verifiers; plaintext passwords are never retained. |
| Authorization | Maestro domain policies | `Dart SDK` | Every authenticated local user receives the single full-control role. |
| Error model | Sealed Dart result and failure types | `Dart SDK` | Carries typed, actionable failures across layers. |
| Configuration | Drift settings, protected storage, and CI environment variables | — | Separates ordinary settings, secrets, and build-time configuration. |
| Update transport | Dart HTTP client, signed GitHub Release manifest, and platform installers | `Dart SDK / platform supplied` | Checks, verifies, downloads, stages, and invokes an artifact-specific installer. |

---

## 7. Testing Technologies

The [Testing Specification Document](Testing%20Specification%20Document.md) defines how these tools are used.

| Concern | Technology | Version | How it is used |
| --- | --- | --- | --- |
| Unit and widget framework | `flutter_test` | `bundled with selected Flutter SDK` | UI, view-model, repository, and widget behavior. |
| Pure Dart framework | `test` | `latest stable at implementation time` | Domain and orchestration behavior. |
| Desktop integration framework | `integration_test` | `bundled with selected Flutter SDK` | Windows and Linux end-to-end scenarios. |
| Coverage | Flutter coverage runner | `bundled with selected Flutter SDK` | Evidence and trend reporting without a fixed percentage gate. |
| Test doubles | Hand-written fakes behind interfaces | `Dart SDK` | Deterministic replacement of CLIs, Git, GitHub, authentication, time, and updates. |
| Persistence tests | Drift test executors and SQLite | `same resolved versions as production` | In-memory behavior and file-based migration coverage. |

---

## 8. Version Summary

| Category | Package or Tool | Version |
| --- | --- | --- |
| Platform | Flutter | `latest stable at implementation time` |
| Language | Dart | `bundled with selected Flutter SDK` |
| State management | flutter_riverpod | `latest stable at implementation time` |
| Data access | drift | `latest stable at implementation time` |
| Data bootstrap | drift_flutter | `latest stable at implementation time` |
| Database driver | sqlite3 | `latest stable at implementation time` |
| Terminal emulator | xterm | `latest stable at implementation time` |
| Pseudo-terminal | flutter_pty | `latest stable at implementation time` |
| Secure storage | flutter_secure_storage | `latest stable at implementation time` |
| Cryptography | sodium | `latest stable at implementation time` |
| Identifiers | uuid | `latest stable at implementation time` |
| Platform paths | path_provider | `latest stable at implementation time` |
| Package metadata | package_info_plus | `latest stable at implementation time` |
| Logging | logging | `latest stable at implementation time` |
| Unit and widget tests | flutter_test | `bundled with selected Flutter SDK` |
| Dart tests | test | `latest stable at implementation time` |
| Desktop integration tests | integration_test | `bundled with selected Flutter SDK` |
| OS authentication | Windows Hello / Linux PAM | `operating-system supplied` |
| Source control | Git | `installed and managed externally` |
| Collaboration | GitHub | `hosted service` |
| Agent CLI | Claude Code | `installed and managed externally` |
| Agent CLI | OpenAI Codex | `installed and managed externally` |
| Agent CLI | OpenCode | `installed and managed externally` |
| Windows shell | PowerShell | `installed and managed externally` |
| Linux shell | Bash | `installed and managed externally` |
