# UC-07 Observe Active Runs Design

## Scope and boundaries

UC-07 owns observation only: the active-run topology, per-step status, live
categorized output, durable output paging, and the degraded-durability report.
It adds no control transitions — pause, resume, cancel, and retry stay with
UC-08 — and no delivery behavior.

UC-06 already persists runs, immutable snapshots, ordered attempts, and
channel-tagged log segments, and already publishes coalesced summary events with
a bounded live tail. UC-07 therefore adds the reader side plus three gaps UC-06
left open: the live tail loses the stdout/stderr/system distinction that
FR-OB-05 requires, there is no view of a run's ordered steps and their status
(FR-OB-01, FR-OB-02), and a durable-write failure currently fails the attempt
immediately rather than reporting degraded durability with bounded buffering
(AF-03).

## Observation domain

A new `lib/features/runs/domain/run_observation.dart` holds pure derivation:

- `RunStepStatus { pending, running, succeeded, failed, interrupted }` is derived
  per snapshot step from that step's attempts, never stored.
- `ObservedStep` carries the snapshot-step ID, position, name, kind, CLI, model,
  derived status, attempt count, and latest attempt ID.
- `RunTopology` carries run identity, label, branch, worktree, run status,
  current step position, and the ordered `ObservedStep` list.
- `RunOutputChunk` pairs a `RunLogChannel` with raw bytes and exposes
  `text`, decoded as UTF-8 with malformed sequences replaced (AF-02). Durable
  bytes are never rewritten; replacement happens only at the display boundary.
- `OutputDurability { durable, degraded }` reports whether durable log writes are
  currently succeeding.

`deriveTopology(run, snapshot, attempts)` is a pure function: the latest attempt
per snapshot step decides its status, positions before the current step with no
attempt are `succeeded` only when an attempt proves it, and everything after the
current position is `pending`. This keeps FR-OB-02 out of the widget layer and
testable at the domain level.

## Reader surface

`RunObservationRepository` is a typed inward port implemented by
`DriftRunRepository`:

- `listObservable(projectId)` returns every non-deleted run for the project,
  newest first, active runs before terminal ones, with its snapshot and attempts
  so the topology derives without a second round trip.
- `topologyFor(runId)` refreshes one run.
- `readOutputTail({runId, attemptId, limit})` and
  `readOutputPage({runId, attemptId, afterSequenceExclusive, limit})` reuse the
  existing `readLogTail` and `readLogPage` queries, so paging older output stays
  an explicit storage read rather than an unbounded in-memory subscription
  (NFR-03).

The existing `listActiveForProject` stays as-is; it serves project-deletion
safeguards and returns a deliberately narrower projection.

## Orchestrator changes

Two narrow changes to `RunOrchestrator`, both required by UC-07 requirements:

1. **Categorized live tail.** The per-run tail becomes a bounded queue of
   `RunOutputChunk` rather than raw bytes, exposed as
   `outputTailFor(runId)`. The 64 KiB cap, the eight-run retention cap, and the
   trimming behavior are unchanged; only the channel is now preserved
   (FR-OB-05). `tailFor` is removed and its single caller updated.

2. **Degraded durability (AF-03).** `appendLog` failures no longer escape into
   `run.step.stream_failed`. A failed batch moves into a bounded pending-durable
   buffer, the run's durability flips to `degraded`, and the next flush retries
   the buffered batches before new ones so ordering is preserved. Streaming
   continues while the buffer stays under `maximumDegradedBufferBytes`
   (256 KiB). Crossing that cap fails the attempt and run with the typed code
   `run.step.log_persist` — bounded memory, no silent byte loss, and a durable
   typed failure. Every summary event carries the current durability so the UI
   can report it.

`RunLogSummary` gains `durability` and an announcement form
(`lastSequence < 0`, empty attempt ID) published once when a run transitions to
running. That lets the observation view pick up a newly started run before its
first byte arrives, without the run-start controller and the observation
controller knowing about each other.

## Application service

`ObserveRuns` composes the repository reads into what the presentation layer
needs: the project's run topologies, and for a selected run an output window
built from the durable tail of the latest attempt plus, when the user asks for
it, an earlier page. It performs no rendering and holds no timers.

## Presentation

`RunObservationController` (`ChangeNotifier`, mirroring `RunStartController`'s
shape — generation guards, disposal guards, typed failures) owns:

- loading and refreshing the project's run list, and selecting one run;
- a subscription to `RunSummaryEvents` that appends the live categorized tail
  for the selected run, reloads the run list when an unknown run announces
  itself, and refreshes the selected run's topology;
- a bounded display buffer capped at 32 KiB of chunks, coalescing bursts into at
  most one publish per animation-frame-sized interval so a flooding run cannot
  drive one rebuild per frame (AF-01, NFR-01, NFR-02) while durable bytes stay
  complete in storage;
- `loadEarlier()`, which pages backwards through durable segments;
- a typed `failure` for read errors and a `durability` flag surfaced as a live
  region when the orchestrator reports degradation.

`ActiveRunsPanel` renders: a loading state, an empty state, the run list with
status and branch, the selected run's ordered steps with the current one
highlighted and each step's derived status announced through semantics, the
categorized output view (stdout, stderr, and system visually and semantically
distinguished), a "Load earlier output" action, and a degraded-durability live
region. Keyboard traversal and semantics follow the existing panels.

The inline tail currently rendered by `RunStartPanel` moves here; the start
panel keeps the start form and the identity of runs it started. Observation is
one view, in one place, for runs from this session and earlier ones alike.

`ProjectWorkspacePage` gains an optional `runObservationBuilder` alongside
`runStartBuilder`, and `main.dart` composes the controller from the existing
`DriftRunRepository` and `RunOrchestrator`.

## Verification strategy

Domain tests cover topology derivation and undecodable-byte replacement.
Application tests cover ordering, selection, and paging. Orchestrator tests cover
categorized tails, degraded durability, retry ordering, and the bounded-buffer
failure boundary. Drift tests cover the observable-run query against a real
temporary database. Controller and widget tests cover loading, empty, populated,
degraded, and error states, batching under flood, paging, and semantics.
A performance integration test streams two concurrent fixture runs while
navigating, asserting bounded display buffers and preserved durable ordering
(NFR-01..03, §7.4 of the Testing Specification).
