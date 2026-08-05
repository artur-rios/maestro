# Business Rules — Maestro

## Domain Entities

| Entity | Meaning |
| --- | --- |
| **Local User** | A person authenticated through operating-system credentials or a local email and password. |
| **Project** | Maestro's registration of a local folder containing a Git project. Maestro owns only the registration metadata. |
| **Workflow Definition** | An ordered, reusable or one-off description of how agents process a unit of work. |
| **Workflow Step** | A named stage in a workflow with an assigned AI CLI and model. |
| **Workflow Run** | One background execution of a workflow against a project and unit of work. |
| **Run Snapshot** | The immutable workflow, task, mode, project reference, and step configuration captured when a run starts. |
| **Step Execution** | One attempt to execute a snapshotted workflow step, including status, timing, logs, and outcome. |
| **Terminal Session** | An interactive PowerShell 7 or Bash session embedded for a project or used to run an agent CLI. |
| **Work Item** | The selected input to a workflow: a documented use case, GitHub issue, or free-form task. |
| **Pull Request** | The GitHub delivery artifact created from the run's Git branch. |

## Relationships

| Relationship | Cardinality and rule |
| --- | --- |
| Local User → Maestro data | Every authenticated local user may access and control all locally stored Maestro data. |
| Project → Workflow Run | One project has zero or many runs; every run belongs to exactly one registered project. |
| Project ↔ Workflow Definition | A project may use many workflows; a reusable workflow may be used by many projects. |
| Workflow Definition → Workflow Step | One workflow has one or many ordered steps; every step belongs to exactly one workflow definition. |
| Workflow Run → Run Snapshot | Every run has exactly one immutable snapshot. |
| Run Snapshot → Workflow Step | A snapshot contains one or many copied step configurations in a fixed order. |
| Workflow Run → Step Execution | One run has one or many step executions and may have multiple attempts for a step. |
| Workflow Run → Work Item | Every run has exactly one selected unit-of-work source. |
| Workflow Run → Pull Request | A delivery run creates at most one pull request. |
| Project → Terminal Session | One project may have multiple terminal sessions; every session opens at that project's folder. |

## Rules

| ID | Rule | Rationale |
| --- | --- | --- |
| BR-01 | Every workflow shall contain an Execute step. | Execution is the only universally required workflow stage. |
| BR-02 | A newly created workflow shall default to ordered Plan, Execute, and Review steps. | The default provides preparation, implementation, and independent review. |
| BR-03 | Each workflow step shall name exactly one supported AI CLI and one model. | A step must have an unambiguous executor. |
| BR-04 | Claude Code, OpenAI Codex, and OpenCode shall be supported in the first release. | These are the required agent integrations. |
| BR-05 | A workflow may assign the same CLI and model to any number of steps. | A single agent configuration may perform the complete workflow. |
| BR-06 | A workflow shall select a use case, GitHub issue, or free-form task as its unit-of-work approach before it runs. | The execution source must be explicit. |
| BR-07 | Every run shall preserve an immutable snapshot of its workflow and task inputs at start time. | Editing a reusable workflow must not rewrite history or alter an active run. |
| BR-08 | Multiple runs may execute concurrently, including runs for the same project. | Parallel agent work is a core product capability. |
| BR-09 | Supervised mode shall be the default delivery mode. | Human review and merge are the safe default. |
| BR-10 | In supervised mode, agents may work through pull-request creation without intermediate approval, but only a user may review, approve, merge, close the work item, or delete the branch. | Supervision occurs at delivery rather than between implementation stages. |
| BR-11 | In autonomous mode, agents may push, open, review, approve, merge, close the work item, and clean up the branch without user intervention. | Autonomous mode is intended for unattended delivery. |
| BR-12 | An autonomous pull request shall not merge unless a model Review step approves it and required tests pass. | Autonomous delivery still requires independent review and green verification. |
| BR-13 | Run logs and the active step shall be available in real time and retained in run history. | Users need both live observability and later auditability. |
| BR-14 | Pausing a run shall preserve state needed for resumption. | A paused run must be continuable rather than converted into a failure. |
| BR-15 | Cancelling a run shall immediately terminate every process Maestro started for that run. | Cancellation must stop agent work and prevent orphan processes. |
| BR-16 | Retrying a failed or cancelled run shall ask the user whether to resume the affected step from preserved context, rerun that step from scratch, or restart the complete workflow. | Recovery scope is a user decision and must not be guessed. |
| BR-17 | Each retry shall create a new attempt while retaining the original run snapshot and prior attempt evidence. | Recovery must not destroy historical evidence. |
| BR-18 | A project registration shall reference a local Git project folder without giving Maestro ownership of that folder. | Maestro orchestrates work in a project but does not manage its source storage. |
| BR-19 | Removing a project from Maestro, including permanent removal, shall never modify or delete its source folder or files. | Project-record deletion must be safe for user-owned source code. |
| BR-20 | Project records, workflows, and run history shall support both soft deletion and permanent deletion of Maestro-managed data. | Users require reversible cleanup and explicit irreversible removal. |
| BR-21 | Every authenticated local user shall have full control over all local Maestro capabilities and data. | The first release has no differentiated local roles. |
| BR-22 | Maestro shall rely on the installed AI CLIs and their existing authenticated sessions. | Maestro does not duplicate provider login or credential ownership. |

## Validation Constraints

| Field or object | Constraints |
| --- | --- |
| Project name | Required and unique among active and soft-deleted Maestro project records until a permanent deletion releases it. |
| Project folder | Required, existing, and a Git working tree when registered; stored as a reference only. |
| Workflow identifier | Required, globally unique, stable, and generated independently of its display name or project usage. |
| Workflow display name | Required for reusable workflows; optional for one-off workflows when the task supplies an adequate label. |
| Workflow steps | At least one step; ordered; exactly one Execute step is required. |
| Step name | Required within its workflow. |
| Step CLI | Required and limited in the first release to Claude Code, OpenAI Codex, or OpenCode. |
| Step model | Required and must be available to the selected installed CLI. |
| Delivery mode | Required and limited to supervised or autonomous; defaults to supervised. |
| Unit-of-work approach | Required and limited to use case, GitHub issue, or free-form task. |
| Use-case input | Requires an unambiguous use-case identifier. |
| GitHub-issue input | Requires an unambiguous issue reference. |
| Free-form task input | Requires non-empty task text. |
| Local email | Required and unique for email-and-password authentication; normalized before comparison. |
| Local password | Required for email-and-password authentication and stored only as a secure password verifier, never plaintext. |

## Permissions

| Actor | Permission |
| --- | --- |
| Unauthenticated person | May only access authentication and account-bootstrap functions. |
| Authenticated local user | May create, view, change, run, pause, resume, cancel, retry, soft-delete, restore, and permanently delete any Maestro-managed record. |
| Authenticated local user | May select supervised or autonomous delivery and authorize agent actions implied by that mode. |
| Agent in supervised mode | May operate through pull-request creation but may not review, approve, merge, close the work item, or delete the branch. |
| Agent in autonomous mode | May complete the full delivery lifecycle after required model approval and passing tests. |
| Maestro | May operate inside a selected project to perform an authorized workflow, but may never delete or claim ownership of the source folder. |

## Lifecycle

| Entity | Lifecycle |
| --- | --- |
| Project | Registered → active → soft-deleted → restored or permanently removed from Maestro. Source-folder contents are unchanged by every transition. |
| Workflow Definition | Draft → valid → reusable or one-off → soft-deleted → restored or permanently deleted. Snapshots already used by runs remain unchanged. |
| Workflow Run | Queued → running → paused, succeeded, failed, or cancelled. A paused run may return to running; a failed or cancelled run may be retried with a user-selected scope. |
| Step Execution | Pending → running → paused, succeeded, failed, or cancelled. Retry creates another attempt rather than overwriting the prior attempt. |
| Pull Request in supervised mode | Prepared → opened → handed to user; subsequent review, merge, closure, and branch deletion are user actions. |
| Pull Request in autonomous mode | Prepared → opened → model-reviewed → approved or changes requested → merged only after approval and passing tests → closed and branch cleaned up. |
| Run history | Created with the run → appended with attempts, logs, and outcomes → soft-deleted → restored or permanently deleted. |

## Prohibitions

- Maestro must never delete or modify a project's source folder as part of project-record deletion.
- Maestro must never store local passwords in plaintext.
- Maestro must never alter a run snapshot after execution begins.
- Maestro must never leave a known run-related child process active after cancellation completes.
- Maestro must never merge an autonomous pull request without a successful model review and passing required tests.
- An agent must never approve, merge, close, or delete the branch for a supervised run.
- A workflow must never start without an Execute step, assigned CLI/model values, a project, a delivery mode,
  and a resolved unit-of-work source.
