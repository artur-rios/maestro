# Testing Specification Document — Maestro

## 1. Purpose

This document defines how each use case and platform requirement is tested. Tests ship in the same change as
the behavior they verify. Tools and versions are defined in the
[Technology Stack Document](Technology%20Stack%20Document.md); the delivery gate is defined in the
[Development Workflow Document](Development%20Workflow%20Document.md).

## 2. Testing Philosophy

1. **Behavior-driven.** Tests describe observable behavior and requirements, not private implementation.
2. **Right layer.** Pure rules use unit tests; view models and widgets use UI tests; repositories, migrations,
   platform adapters, and complete use cases use integration or contract tests.
3. **Deterministic isolation.** Unit tests replace clocks, IDs, files, Git, GitHub, CLIs, authentication,
   updates, PTYs, and persistence through interfaces and hand-written fakes.
4. **Realistic boundaries.** Integration tests use real temporary SQLite databases, Git repositories,
   worktrees, process trees, and platform runners where the behavior depends on them.
5. **Requirement traceability.** Every `FR`, `NFR`, `IR`, main flow, and applicable `AF` has named test evidence.
6. **Risk over percentages.** Coverage reports expose omissions and regressions, but no fixed percentage may
   replace meaningful behavior and edge-case coverage.

## 3. What to Test for Each Use Case

| Artifact | Test kind | Location |
| --- | --- | --- |
| Domain entity, value object, policy, and state transition | Unit | `test/features/<feature>/domain/` |
| View model, command, and repository behavior | Unit | `test/features/<feature>/application/` |
| Widget rendering, keyboard behavior, and accessibility semantics | Widget | `test/features/<feature>/presentation/` |
| Drift repository, query, transaction, compaction, and migration | Integration | `test/features/<feature>/data/` |
| Git, GitHub, PTY, process-tree, OS-auth, CLI, and updater interface | Contract | `test/platform/<adapter>/` |
| Complete user flow on a desktop target | Desktop integration | `integration_test/<feature>/` |
| Responsiveness, bounded buffering, and concurrent runs | Performance integration | `integration_test/performance/` |

Plain immutable data carriers with no validation, transformation, equality customization, or behavior do not
receive empty tests. Their behavior is exercised through the consumer that gives them meaning.

## 4. Test Project Layout

```text
lib/
  core/
  features/<feature>/{presentation,application,domain,data}/
  platform/<adapter>/
test/
  core/
  features/<feature>/{presentation,application,domain,data}/
  platform/<adapter>/
integration_test/
  features/
  platform/
  performance/
test_support/
  fakes/
  fixtures/
  builders/
```

The test tree mirrors production ownership. Files use `<production_file>_test.dart`; integration files use
`<scenario>_integration_test.dart`.

## 5. Naming and Structure

Every test uses Given-When-Then naming:

```text
GivenDirtyProject_WhenStartingRun_ThenStartIsBlocked
```

Every body follows the same shape:

```dart
test('GivenDirtyProject_WhenStartingRun_ThenStartIsBlocked', () async {
  // Given: arrange explicit state and fakes.
  // When: invoke one behavior.
  // Then: assert result, state, effects, and relevant audit evidence.
});
```

## 6. Unit and Widget Testing Standard

### 6.1 Scope

A unit test exercises one public behavior without real files, network, processes, platform channels, wall
clock, or production database. A widget test renders the smallest meaningful view, drives it through semantic
user actions, and asserts visible state and accessibility semantics.

### 6.2 Test Doubles

Use state-based fakes for repositories and external adapters, spies only when an interaction is itself the
requirement, and deterministic clocks and ID generators. Do not introduce a second mocking approach.

### 6.3 Coverage per Unit

- Main success behavior and state transition.
- Every validation boundary and prohibited action.
- Not-found, unauthenticated, unavailable-dependency, and stale-state behavior.
- Cancellation, retry, duplicate-event, and idempotency behavior where applicable.
- Secret redaction, audit emission, and no-source-folder-deletion invariants.
- Widget loading, empty, populated, degraded, error, keyboard, and semantics states.

## 7. Integration, Contract, and Performance Testing Standard

### 7.1 Scope

Repository tests use real temporary database files for migrations and in-memory databases for transactional
behavior. Git tests create disposable repositories and worktrees. PTY and process tests start harmless fixture
process trees. Desktop integration tests enter through the UI and assert both visible outcomes and persisted
state.

### 7.2 External Dependencies

Normal CI uses deterministic fake AI CLIs and a fake GitHub boundary. Adapter contract suites verify command
construction, streaming, cancellation, redaction, retry classification, and response parsing. Opt-in smoke
suites may use installed authenticated CLIs and a designated GitHub test repository; they must never mutate a
developer's real project or rely on production credentials.

Operating-system jobs run real PTY, process-tree, authentication-adapter, packaging, and installer tests on
their target platform. Update tests use locally served signed and tampered fixtures before any live-release
smoke test.

### 7.3 Coverage per Entry Point

For every use case, cover its main flow and every applicable `AF`, including resulting database state, audit
evidence, files or Git effects, process state, and visible guidance. Explicit resilience suites cover dirty
repositories, branch conflicts, missing tools, invalid credentials, network loss, CLI crashes, undecodable
output, storage failure, termination resistance, corrupt retry context, rejected review, stale tests, update
tampering, and installer failure.

### 7.4 Performance Evidence

Run at least two simultaneous streaming fixture workflows while navigating, opening history, and issuing
controls. Assert that buffers remain bounded, output ordering and durable bytes are preserved, and the UI does
not become unresponsive. Trend startup, memory, CPU, database size, and log latency; investigate material
regressions without imposing an arbitrary universal numeric gate.

## 8. Per-Use-Case Workflow

1. Trace the target `UC` to all `FR`, `NFR`, `IR`, main-flow steps, and alternative flows.
2. Write failing tests at the lowest correct layer for each behavior.
3. Implement until the focused tests pass.
4. Add adapter, migration, widget, and desktop integration coverage required by the boundaries changed.
5. Run focused suites, then the complete required suite.
6. Review coverage and mutation-risk areas for untested meaningful branches.
7. Record commands and results in the run and pull request.

## 9. Running the Suites

```bash
flutter test
```

| Suite | Command |
| --- | --- |
| Unit and widget | `flutter test test` |
| Coverage | `flutter test --coverage` |
| Desktop integration on Windows | `flutter test integration_test -d windows` |
| Desktop integration on Linux | `flutter test integration_test -d linux` |
| Focused file | `flutter test <test-file>` |
| Opt-in external smoke | Platform CI workflow with explicit smoke-test flag and isolated credentials |

Folders separate normal, integration, performance, and opt-in smoke suites so fast deterministic tests remain
the default developer loop.
