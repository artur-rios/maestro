# UC-10 Complete Supervised Delivery — Design

## Scope

UC-10 completes a supervised workflow after its configured agent steps succeed. Maestro must create a traceable pull request, retain delivery evidence, and hand all review, merge, issue-closing, and branch-deletion authority to the user. It covers FR-DE-01 through FR-DE-04 and FR-DE-11, plus BR-09 and BR-10.

## Architecture

Delivery is a dedicated `features/delivery` slice. Its application service consumes a completed run, verifies that the run used supervised delivery, delegates the safe external actions to a narrow GitHub port, and records an immutable delivery outcome. The port only supports pushing a committed branch and opening a pull request; prohibited actions are deliberately absent from its API. That lets the type boundary enforce the supervised authority rule instead of relying on UI convention.

The run repository owns a one-to-one `DeliveryRecords` table. The record retains the issue reference, branch, head commit, pull-request number and URL, delivery status, failure code, and timestamps. Delivery failures do not destroy the branch or commits. A retry addresses only the external delivery action and reuses that durable context.

The existing run orchestrator remains responsible for configured agent steps. When the final step succeeds, it invokes supervised delivery only when the immutable snapshot selected supervised mode. A delivery success records the pull request and ends the run with a handoff state; a failed test/agent step never reaches delivery (AF-01), external push or PR errors are persisted as retryable failures (AF-02), and merge conflicts are represented as a user-handoff record without any automatic resolution (AF-04).

## Presentation

The active-runs UI receives a delivery summary for the selected run. A successful supervised delivery exposes the PR link and clearly states that the user must review and merge it. Retryable delivery failure displays redacted, actionable guidance and a retry action. Merge conflicts display the PR context and instruct the user to resolve and complete delivery outside the agent’s authority. There are no approve, merge, close-issue, or delete-branch controls.

## Testing

Tests use Given-When-Then names and hand-written fakes. Unit tests cover authorization, happy-path delivery, external failure preservation/retry, and conflict handoff. Drift migration/repository tests prove delivery-record persistence. The GitHub adapter has contract tests for command construction and response parsing. Widget/controller tests cover PR guidance and the absence of prohibited controls. `flutter test` remains the full required suite.
