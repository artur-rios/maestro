# UC-05 Step Agent Configuration Design

## Scope and boundaries

UC-05 assigns one supported AI CLI and one model to every workflow step. It
detects installations, verifies that the CLI is authenticated through its own
session, discovers selectable models, preserves valid repeated assignments,
and blocks execution when an assignment cannot be verified. It does not own,
copy, display, or persist provider credentials. Terminal-based authentication
is handed to the embedded-terminal capability owned by UC-09; until then the
UI gives the same explicit terminal remediation without attempting login.

The existing schema-v4 paired `cli` and `model` columns are sufficient. No
migration is needed. The existing `configuration` JSON remains `{}` because
UC-05 has no additional per-step settings and must not invent secret storage.

## Domain model

`AgentCliKind` has the stable persisted values `claude-code`, `codex`, and
`opencode`. An `AgentAssignment` contains a kind and trimmed model identifier.
`WorkflowDraftStep` carries an optional paired assignment so structural edits
and revision saves cannot erase previously configured agents.

Discovery produces an `AgentCliCatalog` for each supported CLI with:

- installation state: available, missing, inaccessible, or transient failure;
- session state: authenticated, unauthenticated, or unverified;
- an ordered, deduplicated model list;
- sanitized user guidance that never includes command output or credentials.

An assignment is configuration-valid only when its CLI is installed and
authenticated and its model appears in a freshly obtained CLI-supported
catalog. Cached catalogs are display
hints only. Every execution preflight refreshes the selected adapters and fails
closed if installation, authentication, or discovery cannot be revalidated. A discovery failure
retains an existing selection as unverified but never silently converts it to
another model. A missing saved model requires an explicit replacement. New or
unassigned steps remain editable but cannot be execution-ready.

For CLIs that expose an account-specific catalog, configuration validity also
means account accessibility. For Claude Code, the product owner explicitly
chose documented CLI model aliases as the catalog because stock Claude Code
does not expose a safe non-interactive account model-list command. Provider-side
entitlement or withdrawal can therefore be known only when the step begins; a
rejection is a typed step-start failure, never silently retried with another
model. Installation and authentication are still refreshed before execution.

## Adapter design

`AgentCliAdapter` exposes `kind` and `discover()`. Production adapters use
`CommandRunner` requests constructed from an executable and argument list,
never a shell command string. Commands have bounded timeouts and bounded
captured output; routine installation, authentication, parsing, provider, and
network failures become typed catalog states rather than exceptions.

An `ExecutableResolver` searches PATH entries directly. On Windows it prefers
native `.exe`/`.com` launchers and may represent a `.ps1` wrapper as an explicit
`powershell.exe -NoProfile -NonInteractive -File <resolved-path>` executable and
argument prefix. User values are never interpolated into a command string;
unresolvable or `.cmd`-only installations are reported inaccessible with safe
guidance rather than handed to a shell.

- Claude Code: `claude --version`, `claude auth status --json`, and the stable
  CLI-resolved model-family aliases advertised by the installed CLI. These are
  selectable CLI-valid choices under the product-owner decision for stock
  Claude Code, but the UI and domain do not claim account-level verification.
  A pluggable enterprise catalog may narrow them when available. The adapter
  never issues a prompt, spends tokens, or reads credentials.
- Codex: `codex --version`, `codex login status`, and JSON-RPC `model/list`
  through `codex app-server`. The transport sends only initialize/model-list
  protocol messages, closes stdin, enforces a timeout, and retains only model
  identifiers from matching responses.
- OpenCode: `opencode --version`, `opencode auth list`, and `opencode models`.
  ANSI decoration is stripped before parsing. The selectable catalog is the
  intersection of provider-qualified models and providers reported by `auth
  list`; models from unauthenticated providers are excluded.

No adapter runs a prompt, starts login, refreshes a provider cache, changes CLI
configuration, or reads credential files. Adapter contract tests cover success,
missing/inaccessible executables, unauthenticated sessions, malformed output,
timeouts, discovery failure, and model normalization for all three CLIs. They
also cover oversized output, credential-shaped and PII-bearing auth output,
control characters and overlong model IDs, and prove raw command output never
reaches UI guidance or stored data. Codex protocol tests cover response-ID
matching, notifications, out-of-order and partial frames, protocol errors, EOF,
oversized frames, timeout, and child-process cleanup.

## Application behavior

`AgentConfigurationService` refreshes adapters, applies an assignment by row
key, and evaluates catalog/readiness policy. `WorkflowDesignService` remains the
sole save/revision owner: it validates structure and every agent assignment,
constructs IDs/timestamps once, and writes the complete definition through the
existing optimistic-revision `WorkflowRepository`. Either every row has a
freshly validated assignment and the complete revision is stored, or the prior
revision remains. Repeated assignments are deliberately accepted.

`WorkflowDesignService` preserves draft assignments when constructing the next
revision. Draft editing remains possible while incomplete, but configuration
completion rejects every unassigned or unvalidated row. AF-04 retains the last
persisted selection in the editor as unverified: an unrelated metadata-only
revision may carry that exact unchanged pair forward, but a new or changed
assignment is rejected and execution remains blocked until refresh validates it.
Execution readiness reports every affected row and performs its own fresh,
bounded adapter preflight immediately before a step/run begins.

## Presentation

The workflow editor loads agent catalogs alongside definitions and shows two
controls per step: CLI and model. Changing the CLI clears an incompatible model
selection. A model control is enabled only for an authenticated, successfully
discovered CLI. Per-row status text distinguishes installation guidance,
authentication guidance, unavailable saved models, and temporarily unverified
saved selections. A refresh action retries discovery. Busy-generation guards
prevent late discovery from publishing into a replaced or disposed editor.

Saving validates structural fields, assignment pairing, and fresh catalogs for
new or changed assignments; unchanged persisted pairs survive transient
discovery failures but are marked unverified. The editor reports
unassigned rows but does not discard them. Readiness combines associated-project
availability with agent verification so later execution use cases receive one
typed blocking result.

## Production composition and verification

Production composition creates the three adapters from the shared bounded
command runner, injects the catalog service into workflow application and
presentation, and never probes a real user session in automated tests.
Cross-platform integration uses fixture executables/processes to exercise the
real process boundary on Windows and Linux, including a PowerShell wrapper on
Windows. Existing platform CI jobs are extended to run that suite on both
systems.

Evidence includes domain/application unit tests, three adapter contract suites,
controller and widget tests for every main/alternative flow, Drift round-trip
and atomic-revision tests, production composition tests, cross-platform process
integration, formatting/analyzer checks, and the complete Flutter suite.
