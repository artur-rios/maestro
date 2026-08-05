# Latest Stable Dependencies Design

**Date:** 2026-08-05
**Pull request:** [#16](https://github.com/artur-rios/maestro/pull/16)

## Goal

Bring every project-managed dependency in Maestro's foundation to the newest
stable release available at implementation time, migrate narrow compatibility
breaks, and preserve the existing Windows and Ubuntu delivery guarantees.

## Scope

The audit covers:

- Flutter and the Dart SDK constraint;
- direct and transitive packages resolved through `pubspec.yaml` and
  `pubspec.lock`;
- GitHub Actions used by CI, release, and dependency automation;
- pinned external packaging tools and their integrity digests;
- version references in workflows and development documentation.

Ubuntu packages installed with `apt-get` are not hard-pinned. GitHub-hosted
Ubuntu runners resolve those packages from their current stable distribution
repositories, which avoids coupling Maestro to obsolete distro patch versions.
Operating-system libraries bundled by Flutter or the runner image are outside
the repository's dependency authority.

## Stability and Selection Rules

Only generally available stable releases qualify. Alpha, beta, release
candidate, nightly, preview, and mutable development releases are excluded.
Versions are established from authoritative release metadata and package-manager
output. A dependency remains unchanged only when its newest stable release is
incompatible with the newest stable Flutter/Dart toolchain or with a required
supported platform; such an exception must be documented with evidence.

GitHub Actions remain pinned to immutable commit SHAs, with the corresponding
stable major version recorded in comments. Downloaded executable tools remain
protected by SHA-256 verification. `pubspec.lock` remains committed so release
builds use the exact audited dependency graph.

## Upgrade Flow

1. Record the current Flutter, Dart, package, action, and external-tool versions.
2. Query authoritative stable release sources and `flutter pub outdated`.
3. Upgrade Flutter/Dart constraints first, then direct packages and the complete
   lockfile.
4. Update immutable GitHub Action SHAs and external-tool URLs/digests.
5. Regenerate source files and make only compatibility changes required by the
   upgrades.
6. Re-run architecture, formatting, analysis, tests, native builds, packaging,
   smoke tests, and release-artifact verification.
7. Update PR #16 with the version inventory and verification evidence.

## Compatibility and Failure Handling

Breaking major upgrades are accepted when they are the newest stable releases.
Source migrations should preserve existing domain and application contracts and
stay confined to the affected adapters or generated code. If a latest release
causes a platform failure, the failure is diagnosed before deciding whether the
project code, packaging configuration, or dependency selection must change.

The upgrade fails closed: unresolved packages, stale generated output, mutable
action references, unverified executable downloads, analyzer findings, test
failures, or failed Windows/Linux delivery gates prevent completion.

## Verification

Completion requires:

- `flutter pub outdated` reports no newer resolvable stable direct or transitive
  packages;
- generated Drift code produces no unexplained diff;
- formatting, architecture validation, workflow validation, and analysis pass;
- unit, widget, migration, Windows integration, and Ubuntu integration suites
  pass;
- Windows ZIP/MSIX and Linux AppImage/DEB release builds and smoke tests pass;
- downloaded artifacts pass manifest size and SHA-256 verification;
- every check on PR #16's final head commit is green.

Publisher signing remains an explicit release-credential concern and is not
weakened or represented as configured by this dependency upgrade.
