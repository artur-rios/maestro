# Contributing

## Prerequisites and building

Operational prerequisites and clean-clone commands are documented in
[Building and Testing](docs/development/building-and-testing.md). The exact technology and version policy is defined
in the [Technology Stack Document](docs/requirements/Technology%20Stack%20Document.md).

## Testing

Run the complete default suite described in the
[Testing Specification Document](docs/requirements/Testing%20Specification%20Document.md):

```bash
flutter test
```

The testing strategy covers unit, widget, persistence integration, platform contract, desktop integration,
and concurrency/performance evidence. Every unit of work ships with tests for its main flow, applicable
alternative flows, traced requirements, and meaningful resilience boundaries before delivery.

The formatting, architecture, workflow and analyzer gates CI runs, the Windows test wrapper, and the desktop
integration suites are listed under *Local gates* in [Building and Testing](docs/development/building-and-testing.md).

## Developing Google sign-in

A mock Heimdall endpoint for development must implement `POST /api/auth/google` and return the standard
successful `DataOutput` envelope with `token`, future `expiresAt`, and `emailVerified`. The Heimdall API base is set
at build time with `--dart-define=HEIMDALL_API_BASE_URL=...` and defaults to `http://localhost:8080`, as described
under [Authentication and recovery](README.md#authentication-and-recovery) in the README.

## Branching and pull requests

```
feature/<name> ─┐
fix/<name> ─────┴─▶ develop ──▶ release/x.y.z ──▶ main  (tag vx.y.z)
```

| Branch | Cut from | Merges into | How |
| --- | --- | --- | --- |
| `feature/<name>`, `fix/<name>` | `develop` | `develop` | Pull request, squash or merge. The branch is deleted on merge. |
| `release/x.y.z` | `develop` | `main` | Pull request, merge commit. Carries no commits of its own. |
| `develop`, `main` | — | — | Protected: no direct pushes, no force pushes, no deletion. |

`develop` is the default branch. One unit of work equals one branch, one GitHub issue when issue tracking applies,
and one pull request into `develop`. Branches are created from an up-to-date `develop` and named `feature/<name>`,
or `fix/<name>` for a defect; names are lowercase: letters, digits, `.`, `_` and `-`. Dependabot's own
`dependabot/` branches are accepted as well. A `release/` branch is a snapshot of `develop`: a fix for a release
lands on `develop` through a `fix/` branch and a new release branch is cut.

The **Branch Policy** workflow (`.github/workflows/branch-policy.yml`) checks all of this on every pull request into
`develop` or `main`. It and the three CI jobs — `analyze-test / analyze-test`, `windows-platform` and
`linux-platform` — are required checks on both branches. The repository owner can bypass these rules; that is for
emergencies, not for routine work.

The [Development Workflow Document](docs/requirements/Development%20Workflow%20Document.md) specifies how a Maestro
run delivers a unit of work — its supervised and autonomous modes, issue status, testing gate and Definition of
Done — and its last section records how that applies to this repository.

No pull request may be opened as ready for delivery while required tests fail. The CI workflow runs on every pull
request into `develop` or `main`, and on every push to them.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) with a lowercase subject, e.g.
`feat: manage concurrent terminals` or `fix: kill a linux terminal's whole session`.

Record every change a user would notice under `## [Unreleased]` in [CHANGELOG.md](./CHANGELOG.md), in the same
pull request that makes it.

## Versioning

Maestro follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). For an application, what a version
number promises is about the person who installed it: the workflows, runs and delivery behaviour they rely on, the
data Maestro keeps — its application-data root (settings, workflows, run history, audit evidence) and the secrets in
the system's protected storage — its configuration, and what it works with — the supported AI CLIs, Git and GitHub, and the Heimdall
API behind Google sign-in.

- **Major** — a release that breaks something a user relies on. A capability is removed, or works so differently
  that it has to be relearned; data a previous version wrote is no longer read, or an upgrade cannot migrate it; a
  setting or build-time `--dart-define` is renamed, removed or becomes required; support for an AI CLI, a platform
  or a Heimdall API release the previous version worked with is dropped; or an installed copy can no longer update
  itself to it. Its entry in [CHANGELOG.md](./CHANGELOG.md) carries an `### Upgrading from <X>.x to <Y>.0` section
  saying what to do.
- **Minor** — new capabilities that leave existing ones working as before: a new feature or use case, a newly
  supported AI CLI, a new setting whose default keeps the previous behaviour.
- **Patch** — fixes with no new capability.

No release has been tagged yet. While a version is `0.x`, SemVer itself allows anything to change at any time; the
rules above still say which number to move.

Release tags take the Semantic Versioning forms `tooling/release/validate_release_tag.dart` accepts:
`v<major>.<minor>.<patch>`, or a pre-release suffixed `-alpha.<sequence>`, `-beta.<sequence>` or `-rc.<sequence>` —
SemVer pre-release identifiers, ordered `alpha < beta < rc <` the release itself. The tag, not `pubspec.yaml`, sets
the version a release is built with: the workflow passes it to Flutter as the build name, to the MSIX and the
installer as the Windows version, and into the application as its installed version, so the `version:` in
`pubspec.yaml` (`0.1.0+1`) is not bumped for a release. The complete tag ranges and the native version mappings are
in [Releases and Signing](docs/development/releases-and-signing.md).

## Releasing

A release branch carries no commits of its own, so the changelog for a release is finalized on `develop` first,
through a normal `feature/` or `fix/` pull request: rename `## [Unreleased]` in [CHANGELOG.md](./CHANGELOG.md) to
`## [<version>] - <yyyy-mm-dd>` above a fresh, empty `## [Unreleased]`, and update the compare links at the bottom.
There is no version to bump in the source — the tag sets it.

1. Cut the release branch from `develop` and push it:

   ```bash
   git switch develop && git pull
   git switch -c release/1.0.0
   git push -u origin release/1.0.0
   ```

2. Open a pull request `release/1.0.0 → main`. The Branch Policy check refuses it if the branch carries a commit that
   is not on `develop`, or if `v1.0.0` is already tagged.
3. When the checks pass, merge it with a merge commit, and delete the release branch.
4. Tag the merge commit on `main` and push the tag — only the repository owner can create a `v*` tag:

   ```bash
   git switch main && git pull
   git tag v1.0.0 && git push origin v1.0.0
   ```

A pre-release goes the same way and is tagged `v1.0.0-rc.1` (or `-alpha.<n>`, `-beta.<n>`) on the merge commit
instead; the release that follows it is tagged on the same commit, or on the merge of a later `release/1.0.0` cut
after fixes have landed on `develop`.

Pushing a supported `v<major>.<minor>.<patch>` stable, `-alpha.<sequence>`,
`-beta.<sequence>`, or `-rc.<sequence>` tag publishes the five release
packages (Windows ZIP, MSIX, and setup EXE; Linux AppImage and DEB). The
release workflow first refuses a tag whose commit is not on `main`. Stable
tags create normal GitHub Releases; prerelease tags create GitHub prereleases;
both receive generated release notes. The release workflow runs the same
analyze-and-test gate as CI before anything is packaged. The complete tag
ranges, native version mappings, local packaging commands, and signing policy
are in [Releases and Signing](docs/development/releases-and-signing.md), and the
release signing key is generated following the
[Release Signing Key Procedure](docs/development/release-key-procedure.md).
