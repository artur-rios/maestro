# UC-08 Control and Recover a Run Design

## Scope and boundaries

UC-08 owns the four run transitions a user can request — pause, resume, cancel,
and retry — and the evidence each one leaves behind. It adds no observation
behavior (UC-07 owns the topology, the categorized output, and the durability
report) and no delivery behavior.

UC-06 built half of recovery already: startup reconciliation marks orphaned runs
`interrupted`, offers the three recovery scopes, and records the user's choice as
a `run_recovery_requests` row. Nothing ever executes that choice, so an
interrupted run stays interrupted. UC-08 makes the recorded selection actually
re-drive the orchestrator, and generalizes recovery to every terminal run —
`failed` and `canceled` as well as `interrupted` — so there is one retry path
rather than two.

## Run lifecycle

`RunStatus` gains `pauseRequested`. The System Requirements data model already
lists "pause-requested" among a run's statuses; the enum omitted it because
nothing needed it before. New legal transitions:

- `running → pauseRequested`
- `pauseRequested → paused | succeeded | failed | interrupted | canceled`
- `queued → canceled` and `starting → canceled`, so a run can be cancelled
  before its first step produces anything
- `failed | canceled | interrupted → running`, for recovery re-entry

`running → canceled` and `paused → canceled` are already legal and unchanged.

`pauseRequested` is an active status, so startup reconciliation sweeps it
alongside `running` and `starting`. `paused` is deliberately **not** swept: BR-14
requires a paused run to stay continuable rather than be converted into a
failure, so a run paused before a restart is still `paused` afterwards and
resumes normally.

`lib/features/runs/domain/run_control.dart` holds the pure control policy:

- `RunControlAction { pause, resume, cancel, retry }`
- `availableControls(RunStatus)`:

| Status | Offered |
| --- | --- |
| `queued`, `starting` | cancel |
| `running` | pause, cancel |
| `pauseRequested` | cancel |
| `paused` | resume, cancel |
| `failed`, `canceled`, `interrupted` | retry |
| `succeeded` | — |

AF-01 is then not a special case. A request for an action outside this set is
rejected with the typed code `run.control.invalid_transition`, and the view
refreshes its state from storage rather than trusting what it last rendered.

- `CancellationOutcome { cancelled, incomplete }` reports whether a cancelled
  run's process tree is actually gone (AF-03).

## Orchestrator

Three narrow changes to `RunOrchestrator`, which already owns the execute loop
and the live process handle.

### Pause (FR-RC-01, FR-RC-02)

`requestPause(runId)` sets an in-memory flag. The loop checks it *between* steps
— after `completeAttemptAndAdvance`, before the next `beginAttempt` — and on
finding it, transitions `pauseRequested → paused` and returns. The active step
always finishes.

The repository's `completeAttemptAndAdvance` and `failAttemptAndRun` guards widen
to accept `pauseRequested` wherever they accept `running`. `beginAttempt`
deliberately does not, so no new step can start while a pause is pending, even if
the flag were lost.

AF-02 falls out of this ordering: if the active step *fails* after pause was
requested, `failAttemptAndRun` runs first and the run ends `failed` rather than
`paused` — and `failed` is a status that offers retry.

### Cancel (FR-RC-04)

The orchestrator tracks the live `StepProcess` per run. `requestCancel(runId)`
sets a cancel flag and terminates the tree. `StepProcess` gains
`Future<StepTermination> terminate()`, returning `cancelled` or `incomplete`; the
owned implementation maps `ProcessTerminalState.failed` and `terminationFailed`
to `incomplete`.

Platform escalation already lives inside `terminateTree()` — SIGTERM then SIGKILL
on Linux, `TerminateJobObject` plus a wait-for-empty poll on Windows. UC-08
invokes it and reports the outcome rather than reimplementing it.

The cancel flag matters for evidence. When the killed step's `exitCode` comes
back non-zero, the loop sees the flag and returns **without** writing
`run.step.nonzero_exit`, leaving the terminal state to the cancel transaction.
Without this, a cancelled run would land as `failed`, which is both wrong and
untraceable back to the user's action.

### Fresh-context retry (FR-RC-06)

`execute(runId, {contextPolicy})`. `RecoveryContextPolicy.fresh` skips
`_resumedContext` for the first step of that call, so rerunning a step from
scratch does not silently inherit the prior step's declared context.
`preserved` is the default and is what resume and FR-RC-05 use.

## Application service

`lib/features/runs/application/control_run.dart` holds `ControlRun` behind a
`RunControlRepository` port implemented by `DriftRunRepository`. Every command
reads the run's persisted status first and checks `availableControls`, so AF-01
is enforced in exactly one place.

- **pause** — `running → pauseRequested`, then the orchestrator flag.
- **resume** — verifies the worktree still exists through a `RunWorktreeProbe`
  port, rejecting with `run.control.worktree_missing` when it is gone; then
  `paused → running`; then re-drives `execute` from the run's persisted position.
  No in-process state is consulted, so a run paused in an earlier session resumes
  in a later one.
- **cancel** — asks the orchestrator to terminate, then:
  - `cancelled` → one transaction: the active attempt becomes `interrupted` with
    the failure code `run.canceled.user_request`, a `system` log segment records
    the cancellation, and the run becomes `canceled`.
  - `incomplete` → **no status change** (AF-03). A `system` segment records the
    failed termination, and the call returns `CancellationOutcome.incomplete`.
    Cancel stays offered so the user can escalate again, and surviving trees are
    swept by the existing owned-resource reconciliation at next startup. A run
    whose agent is still writing files is not a cancelled run, and the record
    must not claim otherwise.

  A run cancelled before its first step has no active attempt and no attempt to
  hang a log segment from, so the transaction records only the status change.

  Between terminating and writing the transaction, `ControlRun` awaits the run's
  execution future under a bounded timeout, so the execute loop has already
  bailed out before the evidence is finalized.
- **recoveryScopes(runId)** — AF-04. `restartWorkflow` is always available.
  `rerunStepFresh` requires an affected attempt at the run's current step.
  `retryWithPreservedContext` additionally requires the *preceding* step to have
  a succeeded attempt whose declared context is present **and parses**; a context
  that fails to parse counts as unavailable, which is the corrupt case AF-04
  names. Unavailable scopes are returned with a reason rather than silently
  omitted, so the user can see why a scope is disabled.
- **retry(runId, action)** — validates that the scope is offered, then one
  transaction: insert the `run_recovery_requests` row, set the run to `running`
  at position `0` for `restartWorkflow` or at the affected step's position
  otherwise, and clear `completedAt`. Prior attempts and the immutable snapshot
  are never modified, which is FR-RC-08 and BR-17. Attempt numbering continues
  from the existing per-step maximum, so each retry is a new attempt. Then
  `execute` runs with `fresh` context for `rerunStepFresh` and `preserved`
  otherwise.

The startup interruption offers route through this same `retry`, so
`RunStartController.selectRecovery` stops being record-only. `listInterrupted`
keeps its narrower job of deciding what the startup panel shows; the unification
is about execution, not about promoting every failed run into a startup offer.

## Presentation

`RunControlController` is a separate `ChangeNotifier` in
`lib/features/runs/presentation/run_control_controller.dart`, not an extension of
`RunObservationController` — that file is already large and owns a different
concern. It follows the same shape as the existing controllers: generation
guards, disposal guards, typed failures. It holds the offered actions, the
pending recovery-scope choice, the `cancellationIncomplete` flag, and a typed
failure.

`ActiveRunsPanel` hosts both controllers. Observation owns selection and output
and feeds the selected run into a control bar, which renders:

- Pause, Resume, and Cancel, each enabled per `availableControls`;
- a Retry action opening the three-scope chooser, with unavailable scopes
  disabled and their reason shown (AF-04);
- a live region reporting an incomplete cancellation (AF-03);
- a live region reporting a rejected transition, which also refreshes the run
  list from storage (AF-01).

Keyboard traversal and semantics follow the existing panels.

## Verification strategy

Following the Testing Specification, at the lowest correct layer:

- **Domain** — the transition table and `availableControls` for every status.
- **Application** — `ControlRun` against hand-written fakes: each command's main
  path, every rejection, an incomplete cancellation, recovery-scope availability
  including the unparseable declared context, and retry positioning for all three
  scopes.
- **Orchestrator** — pause honored between steps and never mid-step, AF-02's
  failure-after-pause, cancel suppressing the non-zero-exit failure, and fresh
  versus preserved context.
- **Data** — the cancel and recovery transactions and the evidence queries
  against a real temporary database.
- **Presentation** — controller states, and widget loading, populated, degraded,
  error, keyboard, and semantics states.
- **Performance integration** — §7.4 requires controls issued while concurrent
  runs stream, so the existing UC-07 performance test grows a pause and a cancel
  against two live fixture runs.
