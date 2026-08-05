# Project Overview — Maestro

## What This Is

Maestro is a Windows and Linux desktop application for designing and running AI-agent workflows against
local software projects. A user selects a project folder, describes a task, chooses an ordered set of
workflow steps, assigns an AI CLI and model to each step, and lets Maestro execute the workflow on a Git
branch in the background.

## The Problem

Implementing a software task with AI agents currently requires developers to coordinate multiple command-line
tools, pass context between planning, implementation, and review stages, monitor several terminals, and manage
branches and pull requests manually. Maestro gives developers one place to define that coordination, observe
it in real time, and retain its execution history.

## Who It's For

- Developers and technical teams who orchestrate AI coding agents against local Git projects.
- Users who want human control over pull-request review and merge through supervised workflows.
- Users who want model-reviewed, model-merged delivery through autonomous workflows.
- Locally authenticated users; every authenticated local user has full access to Maestro's capabilities.

## What It Does

- Opens local project folders and lists registered projects in a left-side panel.
- Creates reusable workflow definitions and one-off task workflows.
- Lets the user choose whether a workflow is driven by a use case, a GitHub issue, or a free-form task.
- Supports ordered workflow steps, with Execute required and Plan, Execute, and Review supplied by default.
- Assigns Claude Code, OpenAI Codex, or OpenCode and a selected model independently to each step.
- Runs workflows on Git branches in the background, including multiple concurrent runs.
- Displays a live visual representation of each run, its current step, and streaming logs.
- Embeds PowerShell 7 on Windows and Bash on Linux at the selected project's folder.
- Pauses, resumes, cancels, and retries runs with user-selected recovery scope.
- Preserves an immutable workflow snapshot and execution history for every run.
- Supports supervised delivery, where the user reviews and merges the pull request.
- Supports autonomous delivery, where agents push, open, review, approve, and merge the pull request.
- Authenticates locally through operating-system credentials or local email and password.
- Soft-deletes or permanently deletes Maestro-managed project records, workflows, and run history.

## What It Doesn't Do

- The first release does not connect to an external authentication service. It provides an authentication
  boundary and provider structure so that external authentication can be added in a later release.
- Maestro never modifies, deletes, or otherwise manages a registered project's source folder as a consequence
  of removing the project from Maestro.

No other product capability has been declared out of scope for the first release.

## How Success Is Measured

The first release is successful when every capability listed in this overview is delivered and verified on
supported Windows and Linux systems, including successful end-to-end workflows through Claude Code, OpenAI
Codex, and OpenCode in both supervised and autonomous modes.
