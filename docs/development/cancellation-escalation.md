# Cancellation escalation

How Maestro escalates when a run's process tree resists termination, and why a
repeated Cancel is meaningful rather than a replayed answer.

This closes the limitation recorded during
[UC-08](uc-08-verification.md): a cancellation that reported survivors could not
be retried, because both the supervisor and the Windows job wrapper cached that
failure for the life of the process.

## The rule

**Only a settled outcome is cached.** `ProcessTerminalState.completed` and
`cancelled` mean the tree is gone, so a later request returns the cached result
and never kills anything twice. `failed` and `terminationFailed` mean
descendants are still running — a verdict that is true only at the moment it was
taken, and must not be frozen.

Caching a failure produced the user-visible defect UC-08's AF-03 exposed: the
run correctly stayed out of `canceled`, Cancel correctly stayed enabled, and
clicking it achieved nothing, because the cached failure short-circuited the
call before it reached the platform.

## What each layer does now

| Layer | Behavior on a resisted termination |
| --- | --- |
| `ProcessSupervisor.cancel` | Clears its cached attempt, so the next call re-invokes `terminateTree` on the owned process. |
| `LinuxGroupProcessTree` | Was never memoized. A retry genuinely re-runs SIGTERM, then SIGKILL, against the process group. |
| `WindowsJobTermination` | Reassesses instead of re-terminating: the job handle is closed at most once, because closing it *is* the last-resort kill. |

## Why Windows reassesses rather than re-terminates

The job object is created with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`. Closing the
handle therefore kills every process still in the job, which makes the close the
final escalation rather than mere cleanup — the pre-existing test
`failed job termination still closes the kill-on-close handle` exists to protect
exactly that.

That kill lands *after* `waitForEmpty` has already polled and reported
survivors, so the first attempt can report failure about a tree that is about to
die. Two changes follow:

1. A failed attempt now confirms against the root process's exit before
   reporting, rather than trusting a poll taken before the last-resort kill.
2. A later attempt, with the handle already closed, re-checks that exit instead
   of reusing a destroyed handle. With the job gone its accounting can no longer
   be queried, so the root's exit is the strongest remaining evidence.

The result is that a user who clicks Cancel again gets the current truth. On
Linux they also get a genuine second escalation.

## What has not changed

- A run is still never recorded as `canceled` while its tree is alive (AF-03).
- Cancel stays enabled while a cancellation is incomplete.
- Processes that outlive every escalation are still reclaimed by owned-resource
  reconciliation at the next startup.

## Evidence

```text
test/platform/process/run_execution_context_test.dart
  GivenResistedTermination_WhenCancelledAgain_ThenTerminationIsReattempted
  GivenResistedThenSuccessfulTermination_WhenCancelledAgain_ThenSuccessIsCached
  GivenAttachedProcess_WhenCancelledTwice_ThenTreeTerminatesOnce

test/platform/process/windows_gated_process_launcher_test.dart
  GivenResistedTermination_WhenTerminatedAgain_ThenTheOutcomeIsReassessed
  GivenKillOnJobCloseLandsLate_WhenTerminatedAgain_ThenCancelledIsReported
  GivenSettledTermination_WhenTerminatedAgain_ThenTheTreeIsNotKilledTwice
  failed job termination still closes the kill-on-close handle

test/features/runs/data/production_step_executor_test.dart
  GivenResistedTermination_WhenCancellingAgain_ThenTerminationIsReattempted
```
