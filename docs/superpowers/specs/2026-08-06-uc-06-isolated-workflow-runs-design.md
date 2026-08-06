# UC-06 Isolated Workflow Runs Design

## Scope and boundaries

UC-06 turns a saved workflow into a durable, immutable run, creates a typed
branch and isolated application-data worktree, and executes the snapshotted
steps in order. It owns start validation, work-item resolution, snapshot and
attempt persistence, process output capture, declared context handoff, terminal
outcomes, concurrent isolation, and startup interruption reconciliation.

UC-07 will add the full active-run topology and bounded observation UI. UC-08
will add pause, cancel, resume, and retry commands. UC-10 and UC-11 will own
GitHub delivery. UC-06 therefore exposes typed run summaries, output events,
and interruption recovery offers but does not execute the later retry/control
transitions.
Maestro never discards source changes: a dirty source worktree is a blocking
preflight result with commit-or-explicitly-discard guidance.

## Run domain and immutable snapshot

`StartRunRequest` identifies one available project, one executable workflow,
the work item matching the workflow's `WorkItemType`, a delivery mode, and one
of the approved branch work types: feature, fix, refactor, or hotfix. Work-item
resolution is behind a `WorkItemResolver` port. Use-case references resolve to
one documented identifier, GitHub issues must be accessible and unambiguous,
and free-form tasks must contain bounded non-blank text. Tests use hand-written
resolvers and never require a network session.

The service validates everything before creating Git resources: authenticated
actor, project availability, clean Git status, work item, workflow invariants,
fresh agent readiness, and a safe application-data destination. It then creates
one immutable schema-versioned snapshot containing normalized work-item content,
delivery mode, project identity and canonical source path, source revision,
workflow identity/revision, and deep copies of every ordered step, assignment,
and non-secret configuration. Execution reads only that snapshot. Later
workflow edits or deletion cannot affect an active or historical run.

Stable statuses are queued, starting, running, succeeded, failed, and
interrupted for this use case. The schema retains the broader pause/cancel
states required by later use cases without exposing unsupported transitions.
Each snapshotted step receives a stable snapshot-step ID. Every execution is a
separate attempt with attempt number, start/completion timestamps, status, exit
code, typed failure code, and declared output context. Existing evidence is
append-only.

## Persistence and interruption recovery

Schema v5 adds run, snapshot-step, execution-attempt, and run-log tables. The
run stores its project/workflow references, status, branch, worktree, current
position, timestamps, and soft-deletion marker. The run snapshot stores a
canonical JSON payload and schema version exactly once. Attempts and log
segments reference the run and snapshotted step, not a mutable workflow step.
Log segments have a stable per-attempt sequence, stdout/stderr/system category,
raw bytes, compression metadata, and timestamp. UC-06 writes uncompressed bytes;
later lossless compaction may replace the representation without changing the
content.

Repository methods make lifecycle transitions transactional and conditional on
the expected prior state. Run creation, immutable snapshot, and snapshot steps
commit together. Attempt completion and run advancement commit together so a
successful step cannot be repeated accidentally after a durable transition.
The repository implements the active-project-run reader already used by project
lifecycle deletion safeguards.

At application startup, a `RunInterruptionReconciler` changes persisted
starting/running attempts and runs to interrupted, records a system event, and
preserves logs and the isolated worktree. It also derives and presents the
typed valid action set from retained evidence: retry the affected step with
preserved context when a valid context envelope exists, rerun the affected step
fresh, or restart the complete workflow. Selecting an offered action validates
it again and durably records a recovery request without rewriting prior
evidence; an unavailable or stale selection is rejected. UC-08 will execute
those persisted requests and add general run controls. The existing
owned-resource reconciliation recognizes retained interrupted-run resources
instead of deleting them as abandoned.

## Git isolation and ownership

`RunGitPort` uses executable-plus-argument requests only. It checks porcelain
status including untracked files, resolves the mandated main/base revision and
verifies it against the advertised remote revision when a remote applies,
failing with typed sync/access guidance rather than branching from an arbitrary
clean source HEAD. It detects branch
or worktree conflicts, creates `feature/`, `fix/`, `refactor/`, or `hotfix/`
branches, and adds worktrees below the configured application-data worktree
root. A branch name uses a sanitized work-item slug plus a run-ID suffix, so two
runs for the same project remain distinct.

The start transaction records run intent and a pending owned-resource record
before each individual external Git mutation. It marks that record active only
after the matching branch or worktree creation succeeds.
If Git creation fails, compensation removes only resources proved to have been
created by that attempt, marks ownership records resolved, and records a typed
Git failure. It never resets, cleans, checks out, or writes the source worktree.
Real-Git integration tests use disposable repositories and cover dirty status,
conflicts, partial failure cleanup, and two simultaneous same-project worktrees.

## Ordered execution, logs, and context

`RunOrchestrator` schedules each accepted run asynchronously, allowing at least
two independent runs to progress without blocking Flutter. A per-run serial
loop reads snapshotted steps only. It creates a `RunExecutionContext` rooted in
that run's worktree and asks the selected production agent executor to start an
owned process session. Executors map typed assignments to argument arrays for
Claude Code, Codex, and OpenCode; no prompt or user value is interpolated into
a shell string.

The process boundary emits ordered stdout/stderr byte frames and a terminal
result. Every frame is secret-redacted before either persistence or
publication. The child environment is constructed from the documented minimal
platform allowlist plus explicit CLI-required variables; Maestro does not copy
the ambient environment wholesale. A bounded ingestion queue coalesces frames
into capped persistence batches and pauses the source subscription at its high
watermark. Durable writes therefore apply backpressure without dropping output.
The UI receives batched invalidation/summaries and maintains a fixed-size tail;
it reads older bytes from storage instead of subscribing to an unbounded
broadcast queue.

Declared context never comes from ordinary stdout. Each attempt gets a
Maestro-owned result-file path outside the worktree plus a cryptographically
random nonce supplied in the executor instruction. On exit zero Maestro opens
that exact non-symlink file and accepts one UTF-8 JSON object using result
schema v1 with exact `schema`, `attemptId`, `nonce`, `outcome`, and `context`
fields. The file is capped at 256 KiB, the IDs and nonce must match the active
attempt, and `context` is a bounded string. Missing, duplicate, malformed,
oversized, wrong-attempt, wrong-nonce, unknown-field, or non-regular results are
typed step failures. The result file is registered as owned before process
start and consumed once. A nonzero exit, spawn error, or crash completes the
attempt and run as failed while preserving prior redacted output. The next step
receives only the original immutable task/repository context plus the prior
successful step's validated declared context.

The three production executors use each CLI's non-interactive invocation and
explicit model argument. Their prompts instruct the agent to write the shared
versioned result-file protocol; CLI parsers handle only process framing and
never interpret ordinary diagnostic output as control data.
Fixture executables verify command shapes, streaming, nonzero exits, process
ownership, and context handoff on Windows and Linux without consuming user
tokens or touching live CLI sessions.

## Application and presentation behavior

A run-start controller loads available projects and executable workflows,
collects the work-item form dictated by the workflow, defaults delivery to
supervised, and requires a branch work type. Starting displays typed preflight
or Git failures without losing entered values. Success yields the stable run ID,
branch, worktree identity, current step, status, and a small live output tail;
the durable event stream and repository remain the authority. Busy-generation
guards prevent late starts or events publishing after disposal or sign-out.

Production use-case resolution reads the repository's documented use-case
specification; production GitHub-issue resolution uses the typed GitHub port and
fails closed on missing, ambiguous, inaccessible, or authorization outcomes.
Production composition shares the existing database, workflow repository,
fresh agent preflight, bounded process infrastructure, application paths, and
Git adapter. It replaces `NoActiveProjectRuns` with the durable run reader and
runs interruption reconciliation before ordinary orphan-resource cleanup.

## Verification strategy

TDD evidence covers FR-PR-07, FR-EX-01..09, BR-06..08, UC-06 main flow, and
AF-01..05. Unit tests prove validation ordering, immutable copies, deterministic
branch naming, state transitions, context rules, failures, and controller
behavior. Drift tests prove schema-v4-to-v5 migration, atomic creation,
append-only evidence, restart interruption, and active-project queries.
Integration tests use disposable Git repositories, temporary application data,
fixture agent processes, and two concurrent runs. They measure navigation/event
latency under sustained output, prove queue and UI-tail bounds, verify
backpressure without byte loss, and trace NFR-01..03 and IR-03..06. Completion
gates are format, analyze, focused platform suites, the complete pinned Flutter
suite, repository verification, and independent whole-change review.
