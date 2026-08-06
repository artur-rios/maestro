# Maestro

Maestro is a Windows and Linux desktop application for designing and running AI-agent workflows against
local software projects. A user selects a project folder, describes a task, chooses an ordered set of workflow
steps, assigns an AI CLI and model to each step, and lets Maestro execute the workflow on an isolated Git
branch in the background.

> **Status:** the M-01 desktop foundation is implemented on the `feature/issue-1-foundation` branch and is under review.

## What It Does

- Registers local Git projects without taking ownership of their source folders.
- Creates reusable workflow definitions and one-off task workflows.
- Accepts a documented use case, GitHub issue, or free-form task as the unit of work.
- Assigns Claude Code, OpenAI Codex, or OpenCode and a model independently to every step.
- Runs at least two isolated workflows concurrently while keeping the desktop interface responsive.
- Shows current steps and streaming logs through a visual run workspace.
- Pauses between steps, resumes, cancels complete process trees, and retries with user-selected scope.
- Embeds PowerShell on Windows and Bash on Linux at the selected project folder.
- Supports supervised pull-request delivery and autonomous model-reviewed delivery.
- Preserves immutable run snapshots, attempts, audit evidence, and configurable compacted history.
- Checks, verifies, and installs signed updates published through GitHub Releases.

## What It Doesn't Do

- The first release does not connect to an external authentication service. It provides the boundary needed
  to add one later.
- Removing a project record from Maestro never modifies or deletes its source folder.

No other product capability has been declared out of scope for the first release.

## Specifications

Start with the `initial/` documents for context, then use the `requirements/` documents as the normative source.

| Document | What's in it |
| --- | --- |
| [Brainstorm](docs/initial/Brainstorm.md) | Original free-form project notes. |
| [Project Overview](docs/initial/Project%20Overview.md) | Product, audience, capabilities, non-goals, and success criteria. |
| [Technology Stack](docs/initial/Technology%20Stack.md) | Informal architecture and technology decisions. |
| [Workflow](docs/initial/Workflow.md) | Operational delivery flow for one unit of work. |
| [Business Rules](docs/initial/Business%20Rules.md) | Domain entities, relationships, lifecycle, permissions, and `BR-xx` rules. |
| [Vision Document](docs/requirements/Vision%20Document.md) | Product positioning, stakeholder, architecture, and `F-xx` features. |
| [System Requirements Document](docs/requirements/System%20Requirements%20Document.md) | Functional and non-functional requirements, data model, authorization, and traceability. |
| [Use Case Specification Document](docs/requirements/Use%20Case%20Specification%20Document.md) | `UC-xx` interactions, main flows, `AF-xx` alternatives, and requirement mappings. |
| [Development Workflow Document](docs/requirements/Development%20Workflow%20Document.md) | Branch patterns, delivery modes, testing gate, and Definition of Done. |
| [Testing Specification Document](docs/requirements/Testing%20Specification%20Document.md) | Test philosophy, layout, naming, categories, commands, and evidence rules. |
| [Technology Stack Document](docs/requirements/Technology%20Stack%20Document.md) | Single source of truth for technologies and version policy. |
| [Operations & Infrastructure Document](docs/requirements/Operations%20%26%20Infrastructure%20Document.md) | Repository layout, configuration, logging, diagnostics, packaging, delivery, and `IR-xx` requirements. |

## Installation

Prerequisites are Git, the Flutter SDK, the platform desktop build toolchain, and any AI CLIs a workflow will
use. PowerShell is required on Windows and Bash on Linux. The exact technology and version policy is defined in
the [Technology Stack Document](docs/requirements/Technology%20Stack%20Document.md).

```bash
git clone https://github.com/artur-rios/maestro.git
cd maestro
flutter pub get
```

Start the application on Windows:

```bash
flutter run -d windows
```

Start the application on Linux:

```bash
flutter run -d linux
```

Operational prerequisites and clean-clone commands are documented in [Building and Testing](docs/development/building-and-testing.md). Release packaging and the current publisher-signing limitation are documented in [Releases and Signing](docs/development/releases-and-signing.md). Application data ownership and recovery are documented in [Application Data and Recovery](docs/development/application-data.md).

## Testing

Run the complete default suite described in the
[Testing Specification Document](docs/requirements/Testing%20Specification%20Document.md):

```bash
flutter test
```

The testing strategy covers unit, widget, persistence integration, platform contract, desktop integration,
and concurrency/performance evidence. Every unit of work ships with tests for its main flow, applicable
alternative flows, traced requirements, and meaningful resilience boundaries before delivery.

## Roadmap

| Milestone | Delivers | Depends on | Issues | Status |
| --- | --- | --- | --- | --- |
| [M-01 — Foundation](https://github.com/artur-rios/maestro/milestone/1) | Layered scaffold, persistence, adapters, configuration, tests, CI, packaging, and signed-release foundation covering IR-01 through IR-15 | — | 1 | 0 / 1 closed |
| [M-02 — Secure Project Workspace](https://github.com/artur-rios/maestro/milestone/2) | Local authentication plus safe project registration, selection, restoration, and metadata deletion | M-01 | 3 | 3 / 3 closed |
| [M-03 — Workflow Authoring](https://github.com/artur-rios/maestro/milestone/3) | Reusable and one-off workflow design with validated CLI and model assignments | M-02 | 2 | 2 / 2 closed |
| [M-04 — Execution and Control](https://github.com/artur-rios/maestro/milestone/4) | Isolated concurrent execution, live observation, run recovery, and embedded terminals | M-03 | 4 | 0 / 4 closed |
| [M-05 — Governed Delivery](https://github.com/artur-rios/maestro/milestone/5) | Supervised human-controlled and autonomous model-reviewed GitHub delivery | M-04 | 2 | 0 / 2 closed |
| [M-06 — History, Maintenance, and Updates](https://github.com/artur-rios/maestro/milestone/6) | Searchable evidence, auditing, retention, compaction, safe deletion, and verified application updates | M-05 | 3 | 0 / 3 closed |

## Backlog

### M-01 — Foundation

| Issue | Work | Specification |
| --- | --- | --- |
| [#1](https://github.com/artur-rios/maestro/issues/1) | Project scaffold and initial infrastructure | [Operations & Infrastructure](docs/requirements/Operations%20%26%20Infrastructure%20Document.md), [Technology Stack](docs/requirements/Technology%20Stack%20Document.md) |

### M-02 — Secure Project Workspace

| Issue | Work | Specification |
| --- | --- | --- |
| ✅ [#2](https://github.com/artur-rios/maestro/issues/2) | UC-01 — Authenticate locally | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |
| ✅ [#3](https://github.com/artur-rios/maestro/issues/3) | UC-02 — Register and select a project | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |
| ✅ [#4](https://github.com/artur-rios/maestro/issues/4) | UC-03 — Manage a project record's lifecycle | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |

### M-03 — Workflow Authoring

| Issue | Work | Specification |
| --- | --- | --- |
| ✅ [#5](https://github.com/artur-rios/maestro/issues/5) | UC-04 — Design a workflow | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |
| ✅ [#6](https://github.com/artur-rios/maestro/issues/6) | UC-05 — Configure step agents | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |

### M-04 — Execution and Control

| Issue | Work | Specification |
| --- | --- | --- |
| [#7](https://github.com/artur-rios/maestro/issues/7) | UC-06 — Start isolated workflow runs | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |
| [#8](https://github.com/artur-rios/maestro/issues/8) | UC-07 — Observe active runs | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |
| [#9](https://github.com/artur-rios/maestro/issues/9) | UC-08 — Control and recover a run | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |
| [#10](https://github.com/artur-rios/maestro/issues/10) | UC-09 — Use the embedded terminal | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |

### M-05 — Governed Delivery

| Issue | Work | Specification |
| --- | --- | --- |
| [#11](https://github.com/artur-rios/maestro/issues/11) | UC-10 — Complete supervised delivery | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |
| [#12](https://github.com/artur-rios/maestro/issues/12) | UC-11 — Complete autonomous delivery | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |

### M-06 — History, Maintenance, and Updates

| Issue | Work | Specification |
| --- | --- | --- |
| [#13](https://github.com/artur-rios/maestro/issues/13) | UC-12 — Inspect run history and audit evidence | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |
| [#14](https://github.com/artur-rios/maestro/issues/14) | UC-13 — Manage retention and record deletion | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |
| [#15](https://github.com/artur-rios/maestro/issues/15) | UC-14 — Check and install an application update | [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) |

The counts above reflect creation time. GitHub milestone pages are the live source for completion counts.

## Contributing

One unit of work equals one workflow run, one branch, one GitHub issue when issue tracking applies, and one
pull request. Branches use `feature/`, `fix/`, `refactor/`, or `hotfix/` prefixes. The full supervised and
autonomous process is defined in the
[Development Workflow Document](docs/requirements/Development%20Workflow%20Document.md).
