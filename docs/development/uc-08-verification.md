# UC-08 verification evidence

This record traces [issue #9](https://github.com/artur-rios/maestro/issues/9)
and [UC-08](../requirements/Use%20Case%20Specification%20Document.md#uc-08-control-and-recover-a-run)
to implementation and local verification evidence prepared for review.

- Toolchain: Flutter 3.44.9 and Dart 3.12.2.
- Local full-suite result: 678 tests passed on Windows, up from 644.
- Static analysis and architecture/workflow verification: passed.
- New evidence: 34 net tests across the run lifecycle, the control policy, the
  orchestrator's pause and cancel paths, the cancel and recovery transactions,
  the control service, the presentation controller, the panel widget,
  production composition, and a controls-under-load performance test.

## Requirement traceability

| Requirement | Implementation | Named evidence and verified outcome |
| --- | --- | --- |
| FR-RC-01 / BR-14 | `ControlRun.pause` checks the run's persisted status against `availableControls`, records `running → pauseRequested`, and flags the orchestrator. The request is durable before the flag is set, so a restart cannot lose it silently. | `control_run_test.dart` proves the durable request and the flag; `drift_run_repository_test.dart` proves the transition; `run_control_controller_test.dart` and `active_runs_panel_test.dart` prove Pause is offered only for a running run. |
| FR-RC-02 / BR-14 | The orchestrator checks the pause flag only after `completeAttemptAndAdvance` and before the next `beginAttempt`, then transitions `pauseRequested → paused`. `beginAttempt` still requires a running run, so no step can start under a pending pause even if the flag were lost. | `run_orchestrator_test.dart` proves the second step never launches, the active step still completes, and a pause on the final step lets the run succeed instead of parking. |
| FR-RC-03 / BR-14 | `ControlRun.resume` verifies the worktree through `RunWorktreeProbe`, transitions `paused → running`, and re-drives `execute` from the run's persisted position. No in-process state is consulted, so a run paused in an earlier session resumes in a later one. Startup reconciliation deliberately does not sweep `paused`. | `control_run_test.dart` proves the restart and the `run.control.worktree_missing` rejection; `drift_run_repository_test.dart` proves a paused run survives startup reconciliation; `local_run_worktree_probe_test.dart` covers present, removed, and blank paths. |
| FR-RC-04 / BR-15 | `RunOrchestrator.requestCancel` terminates the live tree through `StepProcess.terminate()`, which drives the platform escalation already in `terminateTree` — SIGTERM then SIGKILL on Linux, `TerminateJobObject` plus a wait-for-empty poll on Windows. `cancelRun` then terminates the active attempt, records a `system` segment, and marks the run cancelled in one transaction. | `run_orchestrator_test.dart` proves termination and that no live process still reports cancelled; `production_step_executor_test.dart` proves the owned process maps its terminal state; `drift_run_repository_test.dart` proves the attempt, run, and log evidence. |
| FR-RC-05 / BR-16 | `retryWithPreservedContext` re-enters at the affected step with `RecoveryContextPolicy.preserved`, so the step receives the context the preceding step declared. | `run_orchestrator_test.dart` proves the prior context reaches the resumed step; `control_run_test.dart` and `drift_run_repository_test.dart` prove the scope resumes at the affected position. |
| FR-RC-06 / BR-16 | `rerunStepFresh` re-enters at the same position with `RecoveryContextPolicy.fresh`, which skips `_resumedContext` for the first step of that call, so a rerun does not silently inherit context. | `run_orchestrator_test.dart` proves the prompt carries `(none)` rather than the prior context; `control_run_test.dart` proves the scope selects the fresh policy. |
| FR-RC-07 / BR-16 | `restartWorkflow` re-enters at position 0 with no attempt reference. It needs no prior evidence, which is why it is the scope that always remains when the others are ruled out. | `control_run_test.dart` proves position 0 and a null attempt reference; `drift_run_repository_test.dart` proves the run restarts at its first step. |
| FR-RC-08 / BR-17 | `beginRecovery` inserts the `run_recovery_requests` row and re-opens the run in one transaction, touching neither prior attempts, their logs, nor the immutable snapshot. Attempt numbering continues from the existing per-step maximum, so each recovery is a new attempt. | `drift_run_repository_test.dart` compares every attempt's id, status, and failure code plus the canonical snapshot before and after recovery, and asserts the recovery row was recorded. |
| NFR-12 | Every refusal crosses the UI boundary as a typed code with remediation: `run.control.invalid_transition`, `run.control.not_found`, `run.control.worktree_missing`, `run.control.cancel_incomplete`, `run.recovery.unavailable_scope`, `run.recovery.stale`, `run.control.read`, `run.control.failed`. | `control_run_test.dart` asserts each code; `run_control_controller_test.dart` and `active_runs_panel_test.dart` prove message plus remediation reach a live region. |
| NFR-01 / NFR-03 | Controls are issued while two runs flood output; the display window stays capped and durable ordering holds. | `run_observation_integration_test.dart` pauses one fixture run and cancels the other mid-flood, asserting the bounded display buffer, sorted ordering, and complete durable segment counts. |
| NFR-08 / IR-01 | Control flows through typed inward ports — `RunControlRepository`, `RunExecutionControl`, `RunWorktreeProbe` — with the policy pure in the domain. Drift, `dart:io`, and Flutter stay outside the domain and application layers. | `tooling/verify_architecture.dart` passes with the new domain, application, data, platform, and presentation files. |
| IR-08 | Every control test uses hand-written state-based fakes; repository tests use a real temporary SQLite database and the process contract test a fake owned process. | No control test requires a live CLI, network, or GitHub session. |

## Use-case flow evidence

| Flow | Evidence and outcome |
| --- | --- |
| Main flow 1: the user selects pause, resume, cancel, or retry | The control bar offers exactly the actions the run's persisted status accepts, derived once by `availableControls` and reused by service, controller, and widget. Panel tests cover running, paused, and terminal runs. |
| Main flow 2: pause records pause-requested, finishes the step, pauses before the next | The request is durable first, the active step completes and writes its evidence, and only then does the run become paused. The next step never launches. |
| Main flow 3: resume starts the next pending step | Resume re-drives execution from the persisted position after confirming the worktree still exists, so a run paused in an earlier session continues rather than being treated as a failure. |
| Main flow 4: cancel terminates the full process tree immediately | The tree is killed before any terminal evidence is written, and the execute loop stands down first so the two writers cannot race over the same attempt. |
| Main flow 5: retry asks for the recovery scope | All three scopes are always presented; the choice is the user's and is never guessed. An unavailable scope is disabled with its reason rather than hidden. |
| Main flow 6: a new attempt is created and prior evidence preserved | Recovery re-opens the run and records its selection without rewriting a single prior attempt, log segment, or snapshot byte. |
| AF-01: the requested transition is invalid for the current state | The service re-reads the run's persisted status before acting, so a view showing a stale status is refused with `run.control.invalid_transition`. The controller then re-reads the controls and the panel reloads the run list, which is the refresh the flow requires. |
| AF-02: the active step fails after pause was requested | `failAttemptAndRun` runs before the loop reaches its pause check, so the run ends `failed` rather than `paused`, and `failed` is a status that offers retry. The repository accepts a failing attempt under `pauseRequested` for exactly this reason. |
| AF-03: a descendant process resists termination | `StepTermination.incomplete` propagates as `CancellationOutcome.incomplete`. The run's status is left untouched — a run whose agent is still writing files is not a cancelled run — a `system` segment records the failed termination, Cancel stays offered so the user can escalate again, and surviving trees are reclaimed by the existing owned-resource reconciliation at next startup. |
| AF-04: preserved context is unavailable or corrupt | `recoveryEvidenceFor` treats a declared context that fails to parse exactly as an absent one, so a corrupt context disables its scope instead of failing the read. The scope is returned disabled with its reason, and the remaining safe scopes stay available. |

## Behaviour changed in earlier use-case code

- `RunStatus` gained `pauseRequested`, which the System Requirements data model
  already named. It counts as active, so startup reconciliation sweeps it;
  `paused` is deliberately not swept, because BR-14 requires a paused run to
  stay continuable rather than become an interruption the user never caused.
- `completeAttemptAndAdvance` and `failAttemptAndRun` accept `pauseRequested`
  wherever they accepted `running`, since a pause request does not stop the
  active step. `beginAttempt` still requires `running`.
- UC-06 recorded a startup recovery selection but never acted on it, so an
  interrupted run stayed interrupted forever. `RunInterruptionReconciler.select`
  and `DriftRunRepository.recordRecoverySelection` are removed;
  `ProductionFoundation` now delegates a selection to the run control service,
  which records it and drives the run as one operation. Recovery also applies to
  `failed` and `canceled` runs, not only interrupted ones.
- The orchestrator no longer writes `run.step.nonzero_exit` when a step's
  non-zero exit was caused by a cancellation. Without this a cancelled run would
  land as `failed`, which is both wrong and untraceable to the user's action.

## Local verification commands

```text
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
Formatted 209 files (0 changed)

flutter analyze
No issues found!

dart run tooling/verify_architecture.dart
architecture-verification: passed

dart run tooling/verify_workflows.dart
workflow-verification: passed

flutter test
678 tests passed

flutter test integration_test/performance/run_observation_integration_test.dart -d windows
2 tests passed
```

Focused suites:

```text
flutter test test/features/runs/domain/run_models_test.dart                          # 15 passed
flutter test test/features/runs/domain/run_control_test.dart                         #  8 passed
flutter test test/features/runs/application/run_orchestrator_test.dart               # 44 passed
flutter test test/features/runs/application/control_run_test.dart                    # 16 passed
flutter test test/features/runs/application/run_interruption_reconciler_test.dart    #  4 passed
flutter test test/features/runs/data/drift_run_repository_test.dart                  # 39 passed
flutter test test/features/runs/data/production_step_executor_test.dart              # 10 passed
flutter test test/features/runs/presentation/run_control_controller_test.dart        #  9 passed
flutter test test/features/runs/presentation/active_runs_panel_test.dart             # 18 passed
flutter test test/platform/git/local_run_worktree_probe_test.dart                    #  2 passed
flutter test test/features/foundation/data/production_foundation_test.dart           #  3 passed
flutter test test/app/production_run_observation_composition_test.dart               #  2 passed
```

## Platform coverage

- Windows: full suite and the desktop performance integration suite run locally.
- Linux: not run locally. The Ubuntu `flutter test --coverage` job on the pull
  request covers it.

## Known limitation

On Windows, `WindowsJobTermination` memoizes its result and closes the job
handle, so a second Cancel on a tree that survived the first reports
`incomplete` again rather than re-escalating. The escalation inside
`TerminateJobObject` plus `KILL_ON_JOB_CLOSE` has already fired by then, and any
surviving process is reclaimed by owned-resource reconciliation at next startup.
Changing that memoization is platform work outside this use case.
