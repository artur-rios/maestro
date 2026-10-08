# Changelog

All notable changes to Maestro are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

No release has been tagged yet. What exists so far is the complete first-release scope, use cases UC-01 through
UC-14:

### Added

- A Windows and Linux desktop application for designing and running AI-agent workflows against local Git projects,
  with local password, Windows credential and Google (through Heimdall) sign-in, and one-use recovery codes.
- Reusable and one-off workflows whose steps each get their own AI CLI (Claude Code, OpenAI Codex or OpenCode) and
  model.
- Concurrent workflow runs on isolated Git branches, with live logs, pause, resume, cancel and retry, and embedded
  PowerShell and Bash terminals.
- Supervised and autonomous model-reviewed pull-request delivery.
- Searchable run history and audit evidence, with retention, compaction and deletion controls.
- Release packages for Windows (setup EXE, ZIP, MSIX) and Linux (AppImage, DEB), and in-application checking,
  verification and installation of signed updates.
- A proprietary `LICENSE` (all rights reserved), and a Legal section in the README.

### Changed

- A run cuts its branch from, and delivers its pull request into, the repository's default branch — the branch its
  remote names as `HEAD`, such as `develop` — instead of always `main`, which remains the fallback when no remote
  names one.
- Run branches are named only `feature/<slug>` or `fix/<slug>`, so their pull requests pass branch policies that
  accept nothing else: a refactor is delivered on a `feature/` branch and a hotfix on a `fix/` branch.

### Fixed

- In-application updates on Windows and Linux. Each package is now built to update as its own kind of package, where
  one build had been shared by every Windows package and by both Linux packages.
  - Windows: an MSIX install now fetches the MSIX and hands it to Windows, which applies it once Maestro is closed,
    instead of fetching the ZIP and trying to replace files in its read-only `WindowsApps` folder — and the MSIX
    update itself no longer fails on an argument Windows does not accept. When Windows refuses the package, Maestro
    says how to install it by hand. The setup EXE and ZIP installs keep updating from the ZIP.
  - Linux: the AppImage now replaces the `.AppImage` file it was started from — in one atomic rename that keeps its
    permissions — instead of trying to write inside its own read-only mount, and no longer refuses the downloaded
    package for lacking the execute bit. The Debian package now updates as a Debian package, handing the new `.deb`
    to the system package manager through `pkexec`, instead of fetching the AppImage and trying to overwrite
    `/opt/maestro` with it; when that is not possible, Maestro says how to install it by hand.
- Autonomous delivery no longer fails forever when a pull request is already open for the run's branch — opened by
  the executing agent, or by an earlier attempt whose review or merge failed. The open pull request is delivered.
- A run that autonomous delivery sends back to its execute or test step (review requested changes, stale tests) is
  driven again, instead of resting in `running` with nothing executing it.
- Cancelling a run while a step was starting, or between two steps, now stops it: the step's agent is terminated as
  soon as it exists and no later step starts. Before, the agent kept working after the run was marked cancelled.
- Retrying a stopped run whose worktree has already been reclaimed says so and suggests a new run, instead of
  launching the agent into a missing folder and reporting the CLI as not found. Retry is also refused for runs that
  are not stopped, such as a paused run, which resume handles.
- The output view follows the attempt that is running now after a workflow restart, not the previous pass's last
  step.
- A recovery code is no longer spent when the system keyring cannot be reached, so retrying after unlocking it still
  works.
- Email sign-in reports a temporary lockout with how long to wait, and a keyring failure as a keyring failure,
  instead of "Check your credentials".
- An unavailable or rate-limited Google token endpoint or Heimdall service is reported as a connection problem rather
  than as a rejected sign-in.
- `PWD` and `OLDPWD` are no longer treated as secrets, so the working directory is no longer blanked out of run
  output and diagnostics.
- One run that cannot be read — for example, one recorded with a value this build no longer knows — no longer
  stops the project's whole run list from loading. That run is left out of the list, and the diagnostics log records
  which run it was and why.
- A run whose isolated worktree could not be created no longer leaves its branch behind. Maestro deletes the branch
  once Git confirms that no worktree holds it. If Git cannot confirm that, the run reports that cleanup is needed.
- A run is no longer stuck as queued when its start is cut short before it gets going. The start fails straight
  away, and a run left queued by a crash or shutdown is marked failed at the next launch, with the reason recorded
  on the run.

### Security

- Run output, diagnostics and review findings now redact prefixed and quoted secret keys (`GITHUB_TOKEN=…`,
  `"access_token": "…"`), GitHub's `Authorization: token …` header, and credentials recognisable by shape — GitHub
  tokens, Anthropic and OpenAI keys, Google access tokens and JWTs — not only values found in Maestro's own
  environment.
- Agent steps no longer search empty or relative `PATH` entries, which resolve inside the run's worktree, so a
  repository cannot supply its own `claude`, `codex` or `opencode` executable. CLI discovery likewise ignores them.
- Autonomous merges are pinned to the reviewed and tested head commit, so a commit pushed after approval is not
  merged unreviewed.
- Startup cleanup refuses an ownership record that names the worktrees or run-results folder itself, rather than
  deleting every run's resources.

[Unreleased]: https://github.com/artur-rios/maestro/commits/main
