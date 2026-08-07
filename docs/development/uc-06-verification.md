# UC-06 verification evidence

This record traces [issue #7](https://github.com/artur-rios/maestro/issues/7)
and [UC-06](../requirements/Use%20Case%20Specification%20Document.md#uc-06-start-isolated-workflow-runs)
to implementation and local verification evidence prepared for review.

- Toolchain: Flutter 3.44.8 and Dart 3.12.2.
- Local full-suite result: 540 tests passed on Windows.
- Static analysis and architecture/workflow verification: passed.
- Platform evidence: disposable real Git repositories, real Windows owned
  processes and Job Objects, and platform-gated Linux process-group tests.

## Requirement traceability

| Requirement | Implementation | Named evidence and verified outcome |
| --- | --- | --- |
| FR-PR-07 | `StartIsolatedRun` checks porcelain status, including untracked files, before run persistence or Git mutation. It never resets or cleans the source. | `start_isolated_run_test.dart` blocks dirty source with zero side effects; `run_git_port_integration_test.dart` verifies a real dirty repository remains unchanged. |
| FR-EX-01 / BR-06 | Typed resolvers normalize documented use-case IDs, GitHub issue references, and bounded free-form tasks. Production GitHub resolution uses noninteractive `gh issue view` argv. | `work_item_resolvers_test.dart` covers accessible, missing, inaccessible, malformed, ambiguous, and oversized references without shell interpolation. |
| FR-EX-02 / BR-07 | Schema v5 stores one canonical immutable snapshot with project, source revision, work item, delivery mode, workflow revision, ordered steps, assignments, and non-secret configuration. | `run_models_test.dart`, `drift_run_repository_test.dart`, and direct v1/v2/v3/v4-to-v5 migration tests prove deep immutability and atomic creation. |
| FR-EX-03 | `CommandRunnerRunGitPort` creates only `feature/`, `fix/`, `refactor/`, or `hotfix/` branches using a sanitized work-item slug and run-ID suffix. | Application tests reject conflicts and unsafe inputs; disposable real-Git tests prove distinct branches and preserve concurrent actors' branches. |
| FR-EX-04 / IR-03 | Worktrees are confined below the per-user application-data worktree root. Existing symlink/junction/reparse ancestors and final targets are rejected and rechecked before every mutation. | `local_run_worktree_path_inspector_test.dart` includes a real Windows junction redirect; real-Git tests cover conflicts, partial materialization, and safe compensation. |
| FR-EX-05 | `RunOrchestrator` executes only ordered snapshot steps, serially within a run. Mutable workflow definitions are not reread. | `run_orchestrator_test.dart` proves immutable order, successful advancement, and typed post-attempt failure boundaries. |
| FR-EX-06 | Each attempt writes a strict schema-v1 result file outside the worktree. Only a nonce/attempt-bound, exact-field, bounded UTF-8 result supplies declared context to the next step. | `attempt_result_protocol_test.dart` covers consume-once success, malformed/duplicate/unknown fields, wrong nonce/attempt, oversize, links, atomic quarantine, and swap races; real fixture tests prove second-step handoff. |
| FR-EX-07 / BR-08 / IR-04 | Each run owns an independent execution context, branch, worktree, process tree, log pipeline, and serial loop. | Real Git tests create two same-project worktrees; real process fixtures use a barrier to prove two owned runs overlap while each remains ordered. |
| FR-EX-08 / BR-07 | Execution reads the persisted snapshot and snapshot-step identifiers. Repository constraints reject cross-run attempt, log, and recovery evidence. | Direct-SQL and repository tests reject cross-run references, duplicate active attempts, and stale attempt mutation after advancement. |
| FR-EX-09 | Attempts persist start/completion time, status, exit code, typed failure code, and outcome; terminal run transitions are conditional. | Repository tests cover start, advance, failure, illegal transitions, stale concurrency, and interruption. Real nonzero fixture output remains durable. |
| NFR-01..03 | Output ingestion uses bounded source backpressure, 16 KiB/25 ms coalescing, persist-before-summary, one-latest isolated subscribers, capped live tails, and explicit paged/tail history reads. | Flood tests preserve 200,000 bytes in bounded batches, coalesce 1,000 alternating records in order, keep paused subscriber storage constant, release completed tails, and overlap real processes. |
| NFR-04 / IR-06 | Startup first reconciles durably owned processes, then marks starting/running evidence interrupted, derives recovery offers, and finally cleans resource types safe to remove. | Startup race tests prove exactly-once ordering, early UI waits, later reloads are read-only, and newly live runs are not interrupted. |
| NFR-06 | Child environments are explicit allowlists; parent inheritance is disabled end-to-end. Streaming redaction is stateful across frames, forced 64 KiB boundaries, overlapping exact secrets, long token/Authorization values, and UTF-8 boundaries. | Real environment contract excludes an ambient sentinel; redaction tests prove full and partial secrets are absent while non-secret bytes remain exact. |
| NFR-08 / IR-01 | Run UI, domain/application policy, Drift persistence, and Git/process adapters communicate through typed inward-facing contracts. Concrete filesystem and process recovery remain in data/platform layers. | `architecture_test.dart` and `tooling/verify_architecture.dart` reject outward application/domain dependencies; final architecture verification passes after the result-protocol and process-recovery boundary split. |
| NFR-10 | Immutable snapshots, ordered attempts/log segments, ownership transitions, interruption system evidence, and recovery requests are timestamped and append-only until later lifecycle use cases remove them. | Drift repository tests cover ordered sequences, atomic transitions, prior-evidence preservation, interruption system logs, and durable recovery selection without snapshot mutation. |
| NFR-12 | Every start, Git, work-item, agent, execution, result, cleanup, interruption, and recovery-selection failure crosses the UI boundary as a bounded typed code with actionable guidance. | Controller/widget tests retain user input and render dirty-source, invalid-work-item, stale-base, Git conflict/cleanup-required, CLI, status-read, and stale/invalid/duplicate recovery guidance. |
| IR-05 | Windows uses a kill-on-close Job Object; Linux uses a stopped setsid leader with an exec-invariant start-time/session fingerprint and verified STOP handshake. Ownership is persisted before release. | Windows process contracts and real surviving-child test pass. Linux parser/fake tests cover leader exit, descendants, identity mismatch, and PID/PGID reuse; Linux-only real tests run on the Ubuntu gate. |
| IR-02 | Schema v5 opens through the existing background-isolate database factory and verified migration strategy before protected run features are composed. | Database-factory, integrity, retained-schema migration, production composition, and startup-order tests pass for v1/v2/v3/v4-to-v5 upgrades. |
| IR-08 | Typed ports isolate Git/GitHub work-item resolution, all three AI step executors, process trees, worktree path inspection, result files, ownership, and recovery. | Contract tests use hand-written fakes; production adapter tests and disposable Git/process fixtures exercise argument arrays and platform boundaries without live credentials. |
| IR-09 | Unit, widget, migration, real-Git, process, restart, architecture, and workflow suites are included by the repository's existing `flutter test --coverage`, Windows platform, and Ubuntu platform jobs. | Local Windows full suite and debug build pass; platform-gated Linux STOP/exec/group recovery runs under Ubuntu. GitHub Actions no-start is recorded as infrastructure only under the owner's explicit outage exception. |

## Use-case flow evidence

| Flow | Evidence and outcome |
| --- | --- |
| Main flow 1: select project, workflow, work item, delivery mode, and branch type | `RunStartController` and `RunStartPanel` expose workflow-specific work-item fields, supervised default, all four typed branch choices, retained inputs after failure, and accessible recovery/run state. |
| Main flow 2: validate Git, work item, assignments, and external readiness | Application tests prove strict validation ordering and zero persistence/Git effects on every blocker. Fresh agent preflight is reused from UC-05. |
| Main flow 3: snapshot and isolate | Atomic snapshot persistence precedes pending ownership. Branch registration and phased no-checkout worktree materialization each require explicit creation proof; ambiguous outcomes retain ownership for restart reconciliation. |
| Main flow 4: start first step and stream output | Silent runs immediately publish `running` and their current snapshotted step. Real fixtures stream stdout/stderr through owned platform processes with durable batching. |
| Main flow 5: record success and pass declared context | Successful attempts atomically advance position and pass only validated declared context. Ordinary stdout is never interpreted as control data. |
| Main flow 6: concurrent isolated runs and terminal outcomes | Disposable Git and owned-process tests prove same-project isolation and real overlap. Success, nonzero exit, spawn/stream/persistence/result failures, and interruption persist typed terminal evidence. `RunStartPanel` owns its controller for the lifetime of the selected project, so an unrelated workspace rebuild keeps every active run, tail, and recovery offer visible. |
| AF-01: dirty source | Start is blocked before persistence; guidance requires commit or explicit user-directed discard. Maestro performs no destructive Git command. |
| AF-02: invalid/inaccessible work item | Typed resolver failures retain form input and create no run or Git resource. |
| AF-03: branch/worktree conflict or partial failure | Presence inspection fails closed, truncation is inaccessible, concurrent actors' resources are never deleted, and compensation requires explicit per-invocation creation proof. Unknown outcomes remain durably pending. |
| AF-04: CLI crash/nonzero | The attempt and run fail with timestamps, exit/failure evidence, and redacted logs. Guarded exception tests cover prepare, lookup, start, stream, persistence, result read, and cleanup. |
| AF-05: unexpected application close | Process-first recovery safely reconciles Windows jobs and Linux groups with PID-reuse protection; attempts/runs become interrupted; stale result artifacts are cleaned while branches/worktrees remain; project-scoped valid recovery actions are shown and selected durably with stale/duplicate rejection. |

## Safety and ownership evidence

- Git commands use executable-plus-argument arrays with prompting disabled.
  Advertised main/base revision is compared with local main before isolation.
- Ownership intent is durable before every branch, worktree, result, quarantine,
  or process mutation. Definite creation may be compensated; unknown creation
  remains pending for restart reconciliation.
- Result files are moved atomically into a randomly named, durably owned
  quarantine. Cleanup failures keep quarantine ownership active.
- Interrupted runs retain only recoverable branch/worktree resources. Stale
  per-attempt result data is cleaned after process reconciliation; branch and
  process records never enter the filesystem cleaner.
- Linux recovery validates leader start time, session, and process group before
  signalling. Leader-absent descendants are found by persisted group/session;
  every escalation revalidates ownership, so PID/PGID reuse is never signalled.

## Local verification commands

Commands use the pinned Flutter toolchain. No suite depends on `TEMP`/`TMP`
pointing at the worktree drive; the default temporary directory is used.

```text
flutter test
# Exit 0; 540 tests passed after final Linux PID/PGID reuse hardening.

flutter analyze
# Exit 0; No issues found.

dart run tooling/verify_architecture.dart
# Exit 0; architecture-verification: passed.

dart run tooling/verify_workflows.dart
# Exit 0; workflow-verification: passed.

dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
# Exit 0; no formatting changes.
```

Focused evidence includes real disposable-Git integration, Windows Job Object
process contracts, result-protocol/adversarial fixtures, migration verification,
run controller/widget tests, startup restart races, and project lifecycle/app
composition regression suites.

## Platform and delivery status

- Windows: the full 540-test suite, real Git integration, Windows process/job
  contracts, junction protection, environment isolation, and owned-child
  settlement passed locally.
- Linux: `/proc` parsing and recovery state-machine tests pass on Windows;
  Linux-only real STOP/exec/group-recovery loops are committed and selected by
  the Ubuntu `flutter test --coverage` job. This Windows host cannot execute
  those native Linux cases.
- GitHub Actions was reported unavailable by the repository owner during this
  implementation. A missing/no-start CI check may be treated as infrastructure
  under that explicit exception; code or test failures are not waived.
- Pull-request, merge, issue-closure, and cleanup evidence is added by the
  delivery step after explicit publication approval.
