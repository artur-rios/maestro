# UC-05 Step Agent Configuration Implementation Plan

> Execute task-by-task with test-driven development and independent review at
> each boundary. Preserve the typed layered architecture and issue #6 trace.

## Task 1: Assignment domain and save preservation

**Modify:** workflow domain models, design service, and their tests.

1. Add failing Given/When/Then tests for typed CLI values, paired assignments,
   repeated assignments, draft mutation, and assignment preservation across a
   structural revision.
2. Implement the smallest immutable assignment model and draft operations.
3. Prove incomplete assignments and new/changed unverified assignments are
   rejected, while an exact persisted pair can survive a metadata-only revision;
   execution remains blocked without mutating the assignment.
4. Run focused workflow domain/application tests and commit.

## Task 2: Three CLI discovery adapters

**Create/modify:** `lib/platform/agents/`, bounded command transport, adapter
tests, and shared fakes.

1. Write contract tests shared by Claude Code, Codex, and OpenCode for missing,
   inaccessible, unauthenticated, malformed, timeout, provider failure, and
   normalized success outcomes. Include credential/PII non-propagation,
   oversized output, invalid model identifiers, OpenCode provider intersection,
   and Claude's documented-alias/product-policy outcome.
2. Add safe Windows executable/PowerShell-wrapper resolution plus bounded
   stdin/output support needed for Codex JSON-RPC without changing existing
   command-runner behavior. Test Codex IDs, notifications, partial/out-of-order
   frames, protocol errors, EOF, output limits, timeout, and process cleanup.
3. Implement each non-mutating adapter and parsers with sanitized diagnostics.
4. Run all platform tests and commit.

## Task 3: Agent configuration application service

**Create:** workflow application agent-configuration service and tests.

1. Test catalog refresh ordering/deduplication, saved-model disappearance,
   retained-unverified selection, repeated assignment, whole-draft validation,
   atomic save, mandatory fresh execution preflight, and typed blockers.
2. Implement catalog aggregation and assignment/readiness policy; keep
   `WorkflowDesignService` as the sole revision/persistence owner.
3. Integrate agent blockers with existing project readiness while preserving
   optimistic revisions and storage-failure behavior.
4. Run focused application/data tests and commit.

## Task 4: Controller and workflow editor UI

**Modify:** workflow providers/controller/editor and widget/controller tests.

1. Add failing tests for catalog loading/refresh, CLI/model selection, cleared
   incompatible models, repeated choices, all four alternative-flow messages,
   save/reload preservation, stale completion, and accessible controls.
2. Implement responsive per-step controls and typed status/remediation text.
3. Wire production composition with all three adapters.
4. Run workflow presentation and app composition tests and commit.

## Task 5: Cross-platform integration, traceability, and delivery gates

**Create/modify:** fixture-based integration test, Windows/Linux CI jobs,
UC-05 verification document, README backlog, and relevant architecture tests.

1. Exercise the real process boundary with deterministic fixture CLIs on both
   supported desktop systems, including a Windows PowerShell launcher; never
   query a user's live sessions in tests. Extend the existing platform jobs.
2. Map FR-AG-01..07 and BR-03/04/05/22 to named evidence, including AF-01..04.
3. Run formatter, analyzer, focused integration, complete Flutter suite, and
   repository verification; fix root causes until all gates are green.
4. Obtain independent whole-change review, resolve verified findings, create
   the traceable PR for issue #6, wait for all CI checks, merge, close the issue,
   update local main, and delete the feature branch/worktree.
