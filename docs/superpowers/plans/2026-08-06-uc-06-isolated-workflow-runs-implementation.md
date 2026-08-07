# UC-06 Isolated Workflow Runs Implementation Plan

> Execute task-by-task with test-driven development and independent review at
> each boundary. Preserve typed layered architecture and issue #7 trace.

**Design:**
`docs/superpowers/specs/2026-08-06-uc-06-isolated-workflow-runs-design.md`

## Task 1: Immutable run domain and schema v5

**Create/modify:** run domain/application contracts, Drift schema/repository,
generated schemas, migrations, and focused tests.

1. Add failing Given/When/Then tests for work-item variants, branch work types,
   immutable deep snapshots, ordered snapshot steps, legal lifecycle
   transitions, bounded declared context, and active-project detection.
2. Add schema-v5 run, snapshot, snapshot-step, attempt, and log tables with
   foreign keys, uniqueness constraints, useful lifecycle indexes, and a
   recovery-request record plus a v4-to-v5 migration; regenerate Drift sources
   and schema snapshots.
3. Implement transactional create/advance/fail/interruption operations and
   replace the production no-active-runs stub.
4. Run domain, repository, migration, and project-lifecycle tests; commit.

## Task 2: Preflight, work-item resolution, and Git isolation

**Create/modify:** run-start application service, work-item ports, Git adapter,
owned-resource integration, and disposable-repository tests.

1. Test strict validation ordering for project availability, dirty source,
   missing/ambiguous/inaccessible work items, workflow invariants, and fresh
   agent readiness, proving no persistence or Git mutation on rejection.
   Cover production documented-use-case and typed GitHub-issue resolver
   adapters without requiring live services in deterministic tests.
2. Test main/base revision freshness, deterministic collision-resistant typed
   branches, application-data
   path confinement, branch/worktree conflicts, exact ownership registration,
   and compensation that cleans only partial Maestro-owned resources.
3. Implement resolver contracts, `RunGitPort`, Git argument-array adapter, and
   the transactional start/isolation service. Never invoke reset or clean.
4. Exercise real temporary Git repositories, including two concurrent
   same-project worktrees; run focused suites and commit.

## Task 3: Step execution, streaming logs, and context handoff

**Create/modify:** run orchestrator, executor contracts and adapters, process
streaming support, durable log sink, fixtures, and tests.

1. Write failing tests for snapshotted order, workflow-edit independence,
   attempt timing/outcomes, ordered stdout/stderr persistence, nonzero/spawn
   failures, strict schema-v1 result-file validation, nonce/attempt binding,
   malformed/duplicate/symlink/oversize rejection, split-across-frame secret
   redaction, and next-step handoff.
2. Add asynchronous per-run orchestration with bounded ingestion, capped
   batching, high-watermark backpressure, and fixed-size UI tails. Persist
   redacted frames before publishing batched summaries; keep runs serial
   internally and independent across run IDs.
3. Implement safe Claude Code, Codex, and OpenCode invocation adapters using
   executable/argument arrays, explicit models, run worktrees, and existing
   owned-process supervision.
4. Verify fixture processes on Windows/Linux, allowlisted environments,
   pre-mutation ownership, process cleanup, two overlapping runs, bounded
   memory, responsive event/navigation latency, byte-loss-free backpressure,
   and full failure evidence; run focused suites and commit.

## Task 4: Startup interruption, controller, UI, and composition

**Create/modify:** reconciliation service, run-start presentation, app
composition/providers, controller/widget/integration tests.

1. Test restart conversion of starting/running work to interrupted, preserved
   logs/worktrees, the exact valid recovery action set, durable action
   selection and stale/invalid rejection, idempotence, and ordering before
   generic owned-resource reconciliation.
2. Test project/workflow selection, work-item-specific fields, supervised
   default, branch work type, retained inputs after typed failures, successful
   run identity/status/output tail, concurrency, stale completion, and sign-out.
3. Implement the run-start workspace and production composition using the
   shared database, application paths, agent preflight, Git, and process ports.
4. Run presentation, composition, restart, and project-lifecycle suites;
   commit.

## Task 5: Cross-platform evidence, traceability, and delivery gates

**Create/modify:** integration coverage, CI configuration if necessary, UC-06
verification document, README backlog, and architecture tests.

1. Map FR-PR-07, FR-EX-01..09, BR-06..08, NFR-01..04, NFR-06, NFR-08,
   NFR-10, NFR-12, IR-01..06, IR-08, IR-09, main flow, and AF-01..05 to named
   evidence, including real Git isolation, fixture-process concurrency, bounded
   buffering, and responsiveness.
2. Run formatter, analyzer, migration checks, focused Windows/platform suites,
   the complete pinned Flutter suite, and repository verification; fix root
   causes until every local gate is green.
3. Obtain independent whole-change review and resolve verified findings.
4. After explicit publication approval, push and open the issue-#7 PR. Treat
   only confirmed GitHub Actions infrastructure/no-start failures under the
   owner's outage exception; do not waive code or test failures. Merge, close
   the issue, update local main, and delete the feature branch/worktree.
