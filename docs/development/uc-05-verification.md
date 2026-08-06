# UC-05 verification evidence

This record traces [issue #6](https://github.com/artur-rios/maestro/issues/6)
and [UC-05](../requirements/Use%20Case%20Specification%20Document.md#uc-05-configure-step-agents)
to implementation and review evidence.

## Requirement traceability

| Requirement | Implementation | Named automated evidence |
| --- | --- | --- |
| FR-AG-01 / BR-03 | A step stores one paired `AgentAssignment`; complete configuration validates every row before `WorkflowDesignService` atomically saves the revision. | `GivenCompletedConfiguration_WhenDesignServiceSaves_ThenOneCompleteRevisionIsPersisted`; `GivenAssignmentPair_WhenStored_ThenBothOrNeitherAreAtomic`; `GivenFixtureAgentClis_WhenDiscoveringSavingAndPreflighting_ThenRealProcessBoundariesStayDeterministic` |
| FR-AG-02 / BR-04 | `ClaudeCodeAdapter` verifies installation and authentication without prompting, then offers the versioned documented alias catalog. | `GivenAuthenticatedClaude_WhenDiscovered_ThenVersionedAliasesAreCliOnly`; `GivenClaudeCliOnlyAlias_WhenCompleting_ThenItIsValidWithoutAccountVerifiedClaim`; desktop fixture integration |
| FR-AG-03 / BR-04 | `CodexAdapter` verifies login and performs bounded JSON-RPC initialize plus paged `model/list` over a managed child process. | `GivenPagedNotifications_WhenDiscovered_ThenHandshakePrecedesEveryPage`; `GivenUntrustedCodexResponseIds_WhenDiscovered_ThenNoCatalogIsTrusted`; `GivenExactCodexLoginOnStdoutWithHostNoise_WhenDiscovered_ThenAuthenticationIsAccepted`; desktop fixture integration |
| FR-AG-04 / BR-04 | `OpenCodeAdapter` intersects `models` output with providers from `auth list` and strips terminal decoration. | `GivenAuthenticatedProviders_WhenDiscovered_ThenOnlyTheirSafeModelsRemain`; desktop fixture integration |
| FR-AG-05 / BR-05 | Assignment equality and configuration policy deliberately permit the same CLI/model pair on any number of rows. | `GivenRepeatedAssignments_WhenCompletingConfiguration_ThenEveryRowIsValidated`; `GivenRepeatedAssignments_WhenSaved_ThenEveryRowPersists`; desktop fixture integration persists and reloads two identical Codex assignments |
| FR-AG-06 / BR-22 | Production uses installed launchers and read-only status/catalog commands. It never starts login, reads credential files, refreshes provider state, or sends an AI prompt. | Shared `GivenVersionTimeoutFor<CLI>_WhenDiscovered_ThenTransientFailureIsTyped` cases, command/session cleanup tests, `GivenCredentialPathTokens_WhenParsed_ThenTheyCannotAuthorizeModels`, and desktop fixture command-boundary evidence |
| FR-AG-07 | Fresh execution preflight returns typed row blockers for missing, inaccessible, unauthenticated, unverified, and withdrawn selections. | `GivenUnavailableUnauthenticatedAndUnassignedRows_WhenCompleting_ThenTypedRowGuidanceIsReturned`; `GivenMissingUnassignedUnverifiedAndWithdrawnRows_WhenPreflightRuns_ThenItFailsClosedWithBoundedTypedBlockers`; desktop fixture integration |

## Use-case flow evidence

| Flow | Evidence and outcome |
| --- | --- |
| Main flow 1: detect supported installations and choices | All three production adapters have shared missing/inaccessible/version-failure contracts and adapter-specific parsing contracts. The Windows/Linux desktop integration resolves temporary fixture launchers with the real resolver and process runner; it never consults the user's PATH entries ahead of the fixture directory. |
| Main flow 2: assign a CLI and model to every step | Domain, application, controller, and widget tests cover selection, incompatible-model clearing, repeated choices, per-row state, and accessible controls. |
| Main flow 3: validate and save non-secret configuration | Completion refreshes selected adapters, validates the whole draft, and delegates one optimistic atomic revision to `WorkflowDesignService`. Drift round-trips only CLI/model identifiers plus the existing non-secret `{}` configuration. |
| Main flow 4: use existing CLI sessions | The adapters run status/catalog operations only. Contract tests reject secret-shaped, PII-bearing, malformed, oversized, and failed output without propagating raw text. |
| AF-01: CLI missing or inaccessible | `GivenMissingClaudeCode_WhenDiscovered_ThenMissingIsSanitized`, `GivenCmdOnlyWrapper_WhenResolved_ThenInstallationIsInaccessible`, application/controller/widget status tests, and the desktop fixture's empty-PATH lookup produce typed installation guidance. |
| AF-02: unauthenticated session | Adapter contracts do not start app-server/model discovery after negative auth. The desktop fixture switches OpenCode to an unauthenticated response through the real process boundary; application/UI evidence directs authentication in the project terminal. |
| AF-03: saved model withdrawn | `GivenSavedModelWithdrawn_WhenCompleting_ThenExplicitReplacementIsRequired` and controller/widget equivalents retain the exact saved pair, mark `modelWithdrawn`, and require explicit replacement before readiness. |
| AF-04: discovery/network/provider failure | `GivenDiscoveryFailureForSavedSelection_WhenEvaluated_ThenExactSelectionIsRetainedUnverified`, controller/widget equivalents, and the real OpenCode fixture failure retain the persisted model, mark it unverified, and fail closed. |

## Product decision and execution boundary

The product owner explicitly selected documented Claude Code model aliases as
the stock Claude catalog. The aliases are therefore marked `cliOnly`, never
account-verified. Installation and the existing Claude session are refreshed
before execution, but stock Claude exposes no safe non-interactive account
catalog. Provider entitlement remains unknown until a step starts. UC-06 must
turn provider rejection at that boundary into a typed step-start failure; it
must not silently substitute a model, retry with another alias, or claim that
the alias was account-accessible during configuration.

This decision does not weaken Codex or OpenCode account verification: both use
their local authenticated catalog surfaces and fail closed when discovery
cannot be refreshed.

## Real process and platform evidence

`step_agent_process_integration_test.dart` creates all fixtures under a
disposable same-drive directory and deletes it in teardown. Windows resolves
actual `.ps1` launchers as an explicit PowerShell executable plus argv; Linux
creates equivalent executable shell scripts. Codex performs a bidirectional
initialize handshake, registers each request before sending it, ignores ID-less
notifications before the current matching response, follows a cursor, and
closes the owned child. The test then saves and reloads repeated assignments
through real Drift persistence, performs a fresh execution preflight, and
covers missing, unauthenticated, and discovery-failure states without any live
CLI, provider network, credential, prompt, or login.

The Windows fixture exposed three real boundary defects before passing:

1. local `.ps1` wrappers were rejected by the machine execution policy; the
   resolver now supplies process-scoped `-ExecutionPolicy Bypass` as explicit
   argv, not a shell command string;
2. Windows PowerShell can serialize harmless host progress to stderr as CLIXML
   while Codex writes its exact positive login status to stdout. Codex accepts
   positive stdout only with empty stderr or the exact `PSCustomObject` progress
   envelope (without embedded login-status markers), and accepts positive
   stderr only with empty stdout. Conflicting statuses, arbitrary noise, and
   raw CLIXML/status text are rejected without becoming user guidance;
3. JSON-RPC responses are trusted only for a positive, currently outstanding
   request ID registered before send. Null, zero, negative, future,
   unsolicited/conflicting, and duplicate IDs fail closed instead of being
   queued; frames without an `id` remain ignorable notifications.

The existing `windows-platform` and `linux-platform` CI jobs run this one file
on their native devices; Linux uses the repository's established `xvfb-run`
pattern. No new CI job or live-credential smoke path was added.

## Local verification commands

All commands below use Flutter 3.44.8 / Dart 3.12.2. Native commands set
`TEMP` and `TMP` to `build/native-temp` on the worktree drive.

```text
flutter test test/platform/agents/executable_resolver_test.dart
# Exit 0; 5 tests passed after the execution-policy regression was observed RED.

flutter test test/platform/agents/agent_cli_adapters_test.dart --plain-name GivenExactCodexLoginOnStdoutWithHostNoise_WhenDiscovered_ThenAuthenticationIsAccepted
# Exit 0; 1 test passed after the exact-status-with-host-noise regression was observed RED.

flutter test integration_test/workflows/step_agent_process_integration_test.dart -d windows
# Exit 0; 1 desktop integration test passed using only disposable fixture CLIs.

flutter test test/platform/agents test/platform/common/command_runner_test.dart test/platform/common/command_session_test.dart test/features/workflows
# Exit 0; 134 focused adapter, transport, workflow domain, application,
# persistence, controller, and widget tests passed.

flutter test test/platform/agents/agent_cli_adapters_test.dart
# Exit 0; 35 adapter contracts passed, including outstanding-ID enforcement,
# both stream-polarity conflicts, exact stderr positive status, the exact benign
# PowerShell progress envelope, arbitrary noise, and status-bearing CLIXML.

flutter test test/features/projects/presentation/project_workspace_page_test.dart
# Exit 0; 17 workspace composition tests passed with bounded lazy-list
# scrolling for the taller UC-05 rows.

dart run tooling/verify_architecture.dart
# Exit 0; architecture-verification: passed. The discovery port and typed
# catalog are owned by the workflow application layer, not platform.

dart run tooling/verify_workflows.dart
# Exit 0; workflow-verification: passed.

flutter test --reporter compact
# Exit 0; clean default-concurrency suite passed 386/386 in 33 seconds.

flutter analyze
# Exit 0; No issues found. Generated listener files from an earlier timed-out
# runner were removed first and subsequent TEMP used analyzer-excluded
# .dart_tool/native-temp.

dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
# Exit 0; 150 files, 0 changed.
```

## Platform and delivery status

- Windows: the fixture integration compiles and runs on the Windows desktop
  target. No manual UI result or live CLI session is claimed.
- An earlier default-parallel rerun hit its outer watchdog and left three
  task-owned `flutter_tester` processes; those exact PIDs were inspected and
  terminated. The final clean default-concurrency suite passed 386/386 in 33
  seconds. CI remains the default-parallel gate.
- Linux: equivalent executable fixtures and an `xvfb-run` CI invocation are
  committed; this Windows host cannot execute the Linux desktop target, so the
  Ubuntu job remains the platform gate.
- Pull-request CI and merge evidence are added by the batch delivery step after
  local verification and independent review.
