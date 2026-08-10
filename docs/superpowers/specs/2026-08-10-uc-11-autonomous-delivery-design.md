# UC-11 Complete Autonomous Delivery — Design

## Scope

UC-11 completes delivery for a run whose immutable snapshot selected autonomous mode. It covers FR-DE-05 through FR-DE-11, BR-11, BR-12, NFR-10, and the autonomous-agent authorization condition. The slice includes domain orchestration, a production GitHub CLI adapter, durable delivery/audit evidence, and visible delivery state in the active-runs workspace.

## Architecture

`features/delivery` gains an `AutonomousDelivery` application service behind a dedicated `AutonomousDeliveryPort`; the existing supervised port remains restricted to opening a pull request. The autonomous port provides distinct operations to open the pull request, record an independent review result, approve and merge an approved PR, close its tracked issue, and delete the merged branch. The service accepts only autonomous requests and requires a fresh green-test attestation plus an approving review result before it invokes the privileged operations.

The domain uses typed outcomes for the successful delivery record and the four safe-stop paths. Rejected review returns the execution findings without attempting approval or merge. Failed or stale test evidence blocks privileged calls and requires a return through the delivery test gate. An unavailable reviewer fails the run with actionable recovery guidance. GitHub policy, conflict, or network failures preserve the existing pull request and all collected evidence as a retryable failure; retry never bypasses a failed test or rejected review.

The production adapter follows the existing `CommandRunner` pattern and invokes `gh` with prompt suppression. It parses only the fields needed for pull-request URL/number, review result, merge commit, and issue/branch cleanup confirmation. It exposes no raw command output to presentation or domain code. Storage extends the existing delivery record so the run retains pull-request identifiers and URL, review outcome and findings, merge commit, cleanup/issue-closure result, failures, and timestamps; an append-oriented audit event records autonomous delivery actions.

`RunOrchestrator` remains responsible for completing the configured Execute and Test steps. When autonomous delivery reaches review, it invokes the separately configured Review step, so its model identity is distinct from the executing model. The delivery service is called only after that step reports approval and the test evidence still matches the delivered head commit. Returned findings restart the same branch at Execute; unavailable review marks the run failed. Success records all delivery evidence and completes the run after GitHub merge, issue closure, and branch cleanup.

## Presentation

The selected run in `ActiveRunsPanel` gains a delivery section driven by a `DeliveryController`. It shows the PR link, review model/outcome, merge commit, and retained completion/audit state. Before the autonomous gate has passed it states which condition is outstanding. Rejected review displays findings and that the run has returned to execution. Unavailable review, stale tests, and GitHub rejection show redacted actionable recovery guidance; GitHub rejection also keeps the PR link visible for retry context. The UI has no user approval or merge control because autonomous approval is executed only by the guarded service.

## Testing

Tests use the repository’s Given-When-Then convention and hand-written fakes. Unit tests cover the approving-and-green path, non-autonomous denial, rejected review, stale/failed tests, unavailable reviewer, and GitHub policy/conflict/network failure. Adapter contract tests assert `gh` command construction, prompt suppression, response parsing, and redaction. Drift migration/repository tests verify all delivery and audit evidence survives reload. Controller and widget tests assert visible PR/review/merge evidence, findings, retry guidance, semantics, and no privileged UI escape hatch. The full required suite is `flutter test`.

## Explicit Decisions

- A "fresh" test gate means the recorded successful test head commit exactly equals the pull-request head commit supplied to delivery.
- Review findings are retained as structured, redacted text associated with the run and review step.
- Cleanup proceeds only after a recorded successful merge; failure to close the issue or delete the branch is persisted as retryable post-merge work rather than silently discarded.
