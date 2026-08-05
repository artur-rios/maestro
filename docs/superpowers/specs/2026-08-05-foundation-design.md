# Maestro Foundation Design

**Date:** 2026-08-05

**Issue:** [#1 — Establish the Maestro desktop and delivery foundation](https://github.com/artur-rios/maestro/issues/1)

**Status:** Approved for implementation planning

## Purpose

Issue #1 establishes the executable, architectural, platform, persistence,
testing, packaging, and delivery foundation for Maestro. It must make later
use cases safe to implement without prematurely delivering their feature
behavior.

Maestro is a local-first Flutter desktop application for Windows and Linux.
Its backend executes inside the desktop process, with narrowly scoped native
adapters where Dart cannot provide reliable operating-system integration.

## Decisions

- Use a single-package, modular Flutter application rather than a Dart
  multi-package workspace or a second backend language.
- Target Windows and Linux only in the initial scaffold.
- Pin Flutter 3.44.8 stable and Dart 3.12.2 in repository and CI
  configuration, while retaining `pubspec.lock`.
- Use `dev.artur-rios.maestro` as the public application identifier. Where a
  language or tool forbids hyphens, use a compatible sanitized identifier
  while preserving the public identifier in package metadata.
- Keep native code limited to process ownership and termination, PTY support
  where the selected Dart package needs it, and future OS credential
  authentication.
- Produce SHA-256 checksums and GitHub artifact attestations from the first
  release pipeline. Enable publisher-certificate signing only after signing
  credentials are configured.

## Architecture

The repository contains one Flutter application with inward-pointing
dependencies:

```text
lib/
  app/
  core/
    errors/
    logging/
    security/
    storage/
  features/
    foundation/
      presentation/
      application/
      domain/
      data/
  platform/
    auth/
    git/
    github/
    process/
    terminal/
    updates/
test/
integration_test/
test_support/
tooling/
  packaging/
  release/
windows/
linux/
.github/workflows/
```

`lib/app` owns bootstrap, routing, theme, and dependency composition.
`lib/core` owns cross-feature primitives. Feature modules use presentation,
application, domain, and data layers. Platform and data implementations depend
on contracts defined by inward layers; domain code does not import Flutter,
database, process, or command-line dependencies.

The first UI is a responsive application shell with startup diagnostics. It
proves that configuration, storage, database, logging, and platform composition
work, and reports degraded optional capabilities without implementing later
use cases.

## Application Bootstrap

Startup proceeds through explicit, observable stages:

1. Resolve and validate OS application-data paths.
2. Initialize redacted structured logging.
3. Load non-secret configuration and retention defaults.
4. Initialize protected credential storage.
5. Open and migrate the Drift database in a background isolate.
6. Construct platform adapters and probe their capabilities.
7. Reconcile Maestro-owned stale execution resources.
8. Render the application shell with ready, degraded, or blocking diagnostics.

Optional tool failures do not prevent the shell from opening. Failures that
would risk corruption, such as an unsuccessful database migration, stop the
affected stage and expose an actionable typed error.

## Persistence and Configuration

Drift owns the SQLite schema and executes database work outside the UI isolate.
The foundation schema includes only infrastructure records needed by issue #1:

- schema and migration metadata;
- application settings and configurable defaults;
- retained or compacted diagnostic log metadata;
- reconciliation records for Maestro-owned execution resources.

Feature entities such as projects, workflows, and runs belong to later issues.
Migrations are transactional and tested from every retained schema version.

Non-secret configuration is stored beneath the platform application-data
directory. Secrets use OS-protected credential storage and never enter SQLite,
diagnostic logs, workflow snapshots, or process command strings. Defaults are
versioned and user overrides survive upgrades.

## Execution and Process Ownership

The foundation defines an isolated execution context for every future run:

- immutable workflow snapshot reference;
- working directory and environment;
- process supervisor;
- PTY session;
- cancellation token;
- bounded live-log stream;
- durable log sink;
- ownership metadata used for recovery.

Windows adapters assign every run process to a dedicated Job Object. Linux
adapters start every run in a dedicated process group. Cancellation terminates
the entire owned process tree immediately and is idempotent. Normal completion,
cancellation, timeout, startup failure, and application-crash recovery produce
distinct terminal outcomes.

Startup reconciliation detects abandoned Maestro-managed processes and
worktrees. Cleanup is restricted to resources with Maestro ownership metadata.
If ownership cannot be proven, Maestro reports the resource and leaves it
untouched.

Source repositories are protected boundaries. Project removal, reconciliation,
and cleanup can remove Maestro records and Maestro-created auxiliary resources,
but must never remove or recursively clean a configured source directory.

## Logs and Responsiveness

Run output flows through bounded, backpressure-aware buffers so the UI can show
near-real-time logs without allowing an agent process to exhaust memory or
starve the UI isolate. Batches are sized by elapsed time and buffered volume,
not by an artificial fixed delay.

Retention and maximum-size defaults are configurable. Older logs may be
compacted into durable storage after the configured period and reconstructed
on demand. Compaction never discards the only durable representation of a log.
Sensitive values and credentials are redacted before both live display and
persistence.

## Platform Contracts and Capability Probes

Typed contracts isolate all external systems:

- Git;
- GitHub CLI and repository operations;
- Claude Code;
- OpenAI Codex;
- OpenCode;
- OS authentication;
- protected credential storage;
- process supervision;
- PTY/terminal sessions;
- update discovery, verification, and installation.

Each adapter exposes a capability probe that distinguishes missing executable,
missing authentication, unsupported version, permission denial, malformed
output, unavailable platform feature, and transient execution failure. Probe
results are structured values rather than exceptions used for routine control
flow.

Issue #1 supplies contracts, production-safe probes, and hand-written fakes.
Later issues implement feature behavior through these contracts.

## Error Handling and Recovery

Errors are typed by domain and include an actionable remediation where one is
known. Logging uses stable event names and structured context, with secrets,
tokens, and password-like values redacted at the logging boundary.

Retry policy belongs to the application layer and is limited to operations
known to be safe and idempotent. Native and process adapters return enough
context to distinguish a command failure from an adapter or transport failure.
Cleanup failures are retained for reconciliation rather than silently ignored.

## Testing Strategy

The foundation test suite includes:

- pure Dart unit tests for domain and application policies;
- Flutter widget tests for bootstrap and degraded-state presentation;
- Drift migration and background-isolate tests;
- contract tests shared by production adapters and hand-written fakes;
- concurrent execution tests proving at least two isolated contexts;
- real platform tests for normal process completion and descendant-tree
  termination;
- stale-resource reconciliation tests;
- protected-path tests proving source directories cannot be deleted;
- packaging and update-manifest verification tests;
- Windows and Linux integration smoke tests.

Platform tests run on matching GitHub-hosted runners. Tests that require a real
external CLI use controlled fixtures or a harmless probe and never rely on a
developer's authentication.

## Continuous Integration and Releases

Pull-request CI performs, in order:

1. toolchain and lockfile validation;
2. generated-code consistency checks;
3. formatting and static analysis;
4. unit, widget, migration, and contract tests;
5. platform integration tests;
6. release-mode Windows and Linux builds;
7. packaging smoke tests.

Tagged release workflows build on matching Windows and Ubuntu runners and
produce:

- a portable Windows ZIP;
- a Windows MSIX package;
- a Linux AppImage;
- an Ubuntu-compatible `.deb` package;
- a SHA-256 checksum manifest;
- GitHub-signed artifact provenance attestations.

Actions and third-party build tooling are pinned to immutable commit SHAs or
exact versions. Release workflows fail closed when an expected artifact,
checksum, attestation, or configured signature is missing.

The repository does not currently have publisher signing credentials. The
pipeline therefore implements the signing hooks and validates their
configuration, but trusted MSIX publisher signing remains disabled until the
required GitHub secrets are supplied. GitHub artifact attestations provide
cryptographically signed build provenance in the meantime; they do not replace
an operating-system-trusted publisher certificate.

## Update Foundation

The update boundary uses a signed release manifest containing version,
platform, package type, download location, digest, size, and minimum compatible
version. The foundation supports parsing, signature and digest verification,
compatibility decisions, staged downloads, and production installer adapters
for every published installation type.

The foundation update engine performs configurable scheduled and manual checks
without blocking the UI, selects only an artifact matching the running
platform, architecture, and installation type, verifies it before execution,
and crosses an explicit user-approval boundary before invoking an installer.
The update engine preserves the application-data directory and reports a typed
result after the new version launches or installation fails. Clean-machine
tests cover install, launch, update, and data preservation for each package
type.

Issue #1 exposes this capability through the foundation diagnostics shell and
testable application services. UC-14 later delivers the complete update
experience: release-note presentation, routine notifications, progress and
recovery UX, and history integration. UC-14 must reuse rather than replace the
foundation update engine.

## Documentation

The root README and project documentation will describe:

- installation of the pinned Flutter toolchain;
- clean-clone dependency setup;
- Windows and Ubuntu build prerequisites;
- local analysis, test, build, and packaging commands;
- application-data and log locations;
- release artifacts and verification;
- required signing secrets and their absence in the initial repository;
- the difference between GitHub provenance and publisher signing.

## Scope Boundaries

Issue #1 delivers the application scaffold, architectural boundaries,
infrastructure contracts, platform probes, persistence/migration foundation,
process-ownership mechanisms, tests, packaging scripts, CI, release provenance,
and update contracts.

It does not deliver project management, workflow editing, workflow execution,
agent orchestration, authentication screens, GitHub unit-of-work behavior, or
the complete update-management experience. Those behaviors belong to issues
#2 through #15. The update engine and package-specific installation capability
required by IR-15 remain in issue #1.

## Acceptance Evidence

Issue #1 is ready for review when fresh evidence demonstrates:

- repository layout and dependency rules match this design;
- formatting and static analysis pass;
- unit, widget, migration, contract, concurrency, process, reconciliation, and
  protected-path tests pass on their supported platforms;
- the empty-feature application starts with operational diagnostics;
- Windows and Linux release builds succeed on matching runners;
- all four package formats are produced and structurally validated;
- checksums and GitHub artifact attestations are generated for tagged releases;
- every published package type passes install, approved-update, and
  data-preservation smoke tests on a clean supported system;
- clean-clone setup, test, build, and packaging instructions are reproducible;
- publisher signing is either successful when credentials exist or explicitly
  reported as unconfigured without being misrepresented as complete.

## Requirement Traceability

| Requirement | Design realization | Primary evidence |
| --- | --- | --- |
| IR-01 | Single-package inward dependency architecture | Architecture tests and analyzer rules |
| IR-02 | Drift database and transactional migrations in a background isolate | Migration and isolate tests |
| IR-03 | Per-user data, log, update, and worktree paths | Path-policy unit and platform tests |
| IR-04 | Independent execution context and supervisor per run | Concurrent-context tests |
| IR-05 | Windows Job Objects and Linux process groups | Descendant-tree cancellation tests |
| IR-06 | Durable-state reconciliation before stale-resource cleanup | Reconciliation integration tests |
| IR-07 | Source directories treated as non-owned protected boundaries | Protected-path tests |
| IR-08 | Typed external-system contracts, probes, and fakes | Adapter contract tests |
| IR-09 | Unit, widget, integration, migration, and platform suites | GitHub Actions jobs |
| IR-10 | Native builds on matching Windows and Ubuntu runners | Release-build jobs |
| IR-11 | Checksums, signed manifest hooks, and signed provenance attestations | Release verification job |
| IR-12 | Portable Windows ZIP and installable MSIX | Windows package smoke tests |
| IR-13 | AppImage and Ubuntu-compatible `.deb` | Ubuntu package smoke tests |
| IR-14 | Pinned Flutter/Dart selection and retained dependency lockfile | Toolchain validation job |
| IR-15 | Scheduled checks, explicit approval, verified package-specific installation, and data preservation | Clean-system update smoke tests |

## Sources

- [Flutter desktop support](https://docs.flutter.dev/platform-integration/desktop)
- [Build and release a Windows desktop app](https://docs.flutter.dev/deployment/windows)
- [Build Linux apps with Flutter](https://docs.flutter.dev/platform-integration/linux/building)
- [Flutter continuous delivery](https://docs.flutter.dev/deployment/cd)
- [GitHub artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)
