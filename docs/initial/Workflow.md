# Workflow — Maestro

How a single unit of work is delivered, from selecting its source to closing it out. The formal, normative
version of this process lives in the
[Development Workflow Document](../requirements/Development%20Workflow%20Document.md); this document is the
operational form an implementer follows step by step.

> **One unit of work = one workflow run = one branch = one GitHub issue when issue tracking applies = one pull
> request.**

## Invocation

Before a workflow is saved or started, Maestro asks which unit-of-work approach it uses:

- A documented use case, identified by its use-case identifier.
- A GitHub issue, identified by its issue number.
- A free-form task entered by the user.

The selected source and its content become part of the immutable snapshot created for the run. If a use-case
identifier or issue number is missing or ambiguous, Maestro asks the user to resolve it before execution.

## Delivery mode

Every workflow selects one of two modes. Supervised is the default.

### Supervised

Agents may plan, create the branch, implement, test, commit, push, and open the pull request without
intermediate approval. Maestro then stops and hands the pull request to the user. Only the user may review,
approve, merge, close the work item, or delete the branch.

### Autonomous

Agents may perform every stage without intermediate approval, including pushing the branch, opening the pull
request, reviewing it with a model, approving it, merging it, closing the work item, and completing branch
cleanup. The model performing review must be represented as a distinct Review step; a workflow cannot silently
skip model review before an autonomous merge.

## Workflow overview

```text
Choose unit of work and delivery mode
  → Snapshot workflow and task
  → Plan when configured
  → Create typed branch
  → Execute
  → Test until green
  → Review when configured or required by autonomous mode
  → Open pull request
  → Supervised: hand off to user
  → Autonomous: model review, approval, merge, close, and cleanup
```

## Step 1 — Load the source material

Load the selected use case, GitHub issue, or free-form task. Read relevant repository instructions and project
documentation before designing or changing code. Do not work from remembered context when current files and
issue content are available.

## Step 2 — Materialize the workflow

Use the selected reusable workflow or create a one-off workflow. Execute is the only mandatory step. A new
workflow defaults to Plan, Execute, and Review. Each ordered step specifies one supported AI CLI and a model;
the same CLI and model may be used for every step.

Before execution, validate the workflow and save an immutable snapshot containing its steps, order, CLI/model
assignments, delivery mode, project reference, unit-of-work source, and task content.

## Step 3 — Plan when configured

When a Plan step exists, the assigned agent refines the task into a repository-specific design and a testable,
sequenced implementation plan. The plan becomes run output and feeds the next step automatically in both
delivery modes.

## Step 4 — Create the branch and begin work

Create the branch from an up-to-date main branch. Its prefix reflects the work type:

- `feature/<descriptive-slug>` for new behavior.
- `fix/<descriptive-slug>` for defects.
- `refactor/<descriptive-slug>` for internal restructuring without intended behavior change.
- `hotfix/<descriptive-slug>` for urgent production corrections.

When the unit of work is a GitHub issue, move it to In Progress if the repository's project configuration
supports that status.

## Step 5 — Execute

Run the mandatory Execute step on the branch using its assigned CLI and model. Stream logs to the run view and
persist them in run history. The agent implements the requested behavior and its tests, following repository
instructions and the materialized plan when one exists.

## Step 6 — Test until green

Run the applicable test suites, with `flutter test` as the intended full project test command. Fix failures and
rerun until the required suites pass. A failing test blocks pull-request creation and autonomous merge.

## Step 7 — Review and deliver

When a Review step exists, its assigned CLI and model inspect the completed change and test evidence. Review is
mandatory before an autonomous merge, even if a customized workflow originally omitted it.

- In supervised mode, agents push and open the pull request, then stop. The user reviews and merges it.
- In autonomous mode, the review model records its decision. Only an approved, green pull request may be
  merged by an agent. The workflow then closes the associated issue when applicable and performs branch cleanup.

## Step 8 — Pause, cancel, resume, and retry

- Pausing suspends the active run and preserves enough state to resume it.
- Resuming continues a paused run from its preserved state.
- Cancelling immediately terminates the active CLI, shell, and every process Maestro started for that run.
- Retrying a failed or cancelled run asks the user to choose one of three scopes: resume the affected step from
  preserved context, rerun the affected step from scratch, or restart the complete workflow.
- Every retry is recorded as a new attempt without changing the run's immutable workflow snapshot.

## Definition of Done

- [ ] The selected unit of work and delivery mode are recorded in the run snapshot.
- [ ] Work was performed on a branch with the correct `feature/`, `fix/`, `refactor/`, or `hotfix/` prefix.
- [ ] Every configured workflow step completed successfully.
- [ ] Required tests pass and their results are retained with the run.
- [ ] A pull request was opened with traceable run and work-item context.
- [ ] In supervised mode, the pull request was handed to the user for review and merge.
- [ ] In autonomous mode, a model approved the pull request before an agent merged it.
- [ ] The final run, issue, pull-request, and branch states are recorded in history.
