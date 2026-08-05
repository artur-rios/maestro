# Latest Stable Dependencies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade every project-managed Maestro dependency to its newest stable release and retain green Windows and Ubuntu delivery gates.

**Architecture:** Treat dependency selection as a reproducible supply-chain audit: authoritative release metadata establishes stable versions, repository manifests pin those versions immutably, and the existing tests/builds prove compatibility. Keep source migrations narrow and preserve the current domain/application boundaries.

**Tech Stack:** Flutter, Dart pub, Drift code generation, GitHub Actions, GitHub API/CLI, AppImage tooling, PowerShell, Bash

## Global Constraints

- Only generally available stable releases qualify; alpha, beta, release candidate, nightly, preview, and mutable development releases are excluded.
- Cover Flutter/Dart, direct and transitive pub packages, GitHub Actions, pinned external packaging tools, workflow references, and development documentation.
- Ubuntu `apt-get` dependencies resolve from the current Ubuntu runner repositories and are not hard-pinned.
- GitHub Actions must use immutable commit SHAs with stable-major comments.
- Downloaded executable tools must use immutable release URLs and verified SHA-256 digests.
- Keep `pubspec.lock` committed and document any stable-version exception with authoritative evidence.
- Preserve Windows ZIP/MSIX and Linux AppImage/DEB support and publisher-signing truthfulness.

---

## File Map

| File | Responsibility |
| --- | --- |
| `docs/development/dependency-inventory.md` | Audited before/after versions, authoritative sources, exceptions, and verification result |
| `.fvmrc` | Repository-local stable Flutter SDK selection |
| `pubspec.yaml` | Dart SDK constraint and direct dependency constraints |
| `pubspec.lock` | Exact complete Dart dependency graph |
| `lib/**`, `test/**`, `integration_test/**` | Narrow compatibility migrations and regression evidence |
| `.github/workflows/ci.yml` | Current stable Flutter and immutable CI action/tool pins |
| `.github/workflows/release.yml` | Current stable Flutter and immutable release action/tool pins |
| `.github/dependabot.yml` | Dependency automation using the current supported configuration |
| `docs/development/building-and-testing.md` | Local toolchain and verification commands |
| `docs/development/releases-and-signing.md` | Current packaging-tool provenance and digest workflow |
| `docs/development/issue-1-verification.md` | Final dependency and artifact verification evidence for PR #16 |

---

### Task 1: Audit Every Managed Dependency

**Files:**
- Create: `docs/development/dependency-inventory.md`
- Read: `pubspec.yaml`
- Read: `pubspec.lock`
- Read: `.github/workflows/ci.yml`
- Read: `.github/workflows/release.yml`
- Read: `.github/dependabot.yml`

**Interfaces:**
- Consumes: official Flutter release metadata, pub.dev package metadata, official GitHub release/tag APIs, and `flutter pub outdated --json`
- Produces: one inventory row per direct package, Flutter/Dart, GitHub Action, and downloaded executable with `Current`, `Latest stable`, `Selected`, `Source`, and `Reason`

- [ ] **Step 1: Capture the resolved pub graph**

Run:

```powershell
& 'C:\Users\Artur\development\flutter\bin\flutter.bat' --version
& 'C:\Users\Artur\development\flutter\bin\flutter.bat' pub outdated --json
& 'C:\Users\Artur\development\flutter\bin\cache\dart-sdk\bin\dart.exe' pub deps --json
```

Expected: JSON output identifies every outdated resolvable package without changing repository files.

- [ ] **Step 2: Resolve authoritative stable versions**

Use official Flutter release metadata, pub.dev package APIs, and each action/tool's official GitHub releases or tags. Reject versions whose release name or semantic version contains `alpha`, `beta`, `dev`, `nightly`, `preview`, or `rc`.

For every GitHub Action stable major used in the workflows, resolve the stable major tag to a full commit SHA with:

Use `gh api repos/OWNER/REPOSITORY/git/ref/tags/VERSION` followed by
`gh api repos/OWNER/REPOSITORY/commits/RESOLVED_SHA --jq .sha`, substituting
the audited repository, stable tag, and returned object SHA in each invocation.

Expected: every selected action revision is a 40-character immutable commit SHA.

- [ ] **Step 3: Write the inventory**

Create `docs/development/dependency-inventory.md` with these exact sections:

```markdown
# Dependency inventory

**Audit date:** 2026-08-05

## Toolchain

| Dependency | Current | Latest stable | Selected | Source | Reason |
| --- | --- | --- | --- | --- | --- |

## Direct Dart packages

| Dependency | Current | Latest stable | Selected | Source | Reason |
| --- | --- | --- | --- | --- | --- |

## GitHub Actions and packaging tools

| Dependency | Current | Latest stable | Selected | Source | Reason |
| --- | --- | --- | --- | --- | --- |

## Exceptions

No exceptions, or one evidence-backed paragraph per dependency that cannot use
its newest stable release.
```

Every row must use a direct authoritative source URL. Do not link search results.

- [ ] **Step 4: Verify complete inventory coverage**

Run a PowerShell comparison that extracts direct names from `pubspec.yaml`, action repositories from both workflows, and downloaded executable URLs, then fails if any extracted name is absent from the inventory.

Expected: `dependency-inventory: complete` and exit code 0.

- [ ] **Step 5: Commit the audit**

```powershell
git add docs/development/dependency-inventory.md
git commit -m "docs: audit project dependencies"
```

---

### Task 2: Upgrade Flutter, Dart, and Pub Packages

**Files:**
- Create: `.fvmrc`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/**` only where an upgraded API requires compatibility changes
- Modify: `test/**` and `integration_test/**` only where a stable API changes test setup
- Modify: `docs/development/building-and-testing.md`
- Modify: `docs/development/dependency-inventory.md`

**Interfaces:**
- Consumes: selected Flutter/Dart and package versions from Task 1
- Produces: a fully resolved stable pub graph that compiles on the selected Flutter SDK

- [ ] **Step 1: Pin the selected stable Flutter SDK**

Create `.fvmrc` as a JSON object with one `flutter` property whose string value
is the exact numeric stable Flutter version selected in Task 1. Apply the
audited value directly with `apply_patch`; do not commit a symbolic value or
version range. Update `environment.sdk` in `pubspec.yaml` to the Dart version
bundled by that Flutter release.

- [ ] **Step 2: Upgrade all direct package constraints**

Run with the selected stable Flutter SDK:

```powershell
flutter pub upgrade --major-versions
flutter pub get
flutter pub outdated --json
```

Then replace any remaining direct constraint whose `latest` stable version is newer than `resolvable` by diagnosing its constraint conflict. Upgrade the conflicting direct dependency rather than pinning a transitive override.

Expected: every direct dependency's `current`, `upgradable`, `resolvable`, and `latest` stable versions match.

- [ ] **Step 3: Regenerate Drift output**

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Expected: generated files reflect the upgraded generator/runtime pair.

- [ ] **Step 4: Compile to expose compatibility breaks**

```powershell
flutter analyze
flutter test
```

Expected before migrations: either both pass or failures identify exact upgraded API call sites.

- [ ] **Step 5: Apply narrow compatibility migrations**

For each compiler or test failure, consult the dependency's official changelog/API documentation, update only the affected adapter or test, and preserve its public Maestro interface. Do not add `dependency_overrides`, analyzer suppressions, or broad refactors.

- [ ] **Step 6: Prove the pub graph is current**

```powershell
flutter pub outdated --json
flutter analyze
flutter test
git diff --check
```

Expected: no newer resolvable stable package is reported, analyzer exits 0, and all tests pass.

- [ ] **Step 7: Commit toolchain and package upgrades**

```powershell
git add .fvmrc pubspec.yaml pubspec.lock lib test integration_test docs/development/building-and-testing.md docs/development/dependency-inventory.md
git commit -m "build: upgrade flutter dependencies"
```

---

### Task 3: Upgrade CI Actions and Packaging Tools

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/release.yml`
- Modify: `.github/dependabot.yml`
- Modify: `docs/development/releases-and-signing.md`
- Modify: `docs/development/dependency-inventory.md`
- Modify: `tooling/verify_workflows.dart`
- Test: `test/tooling/architecture_test.dart`

**Interfaces:**
- Consumes: immutable action SHAs and stable external-tool release assets from Task 1
- Produces: workflows with current immutable dependencies and fail-closed executable verification

- [ ] **Step 1: Strengthen workflow validation before changing pins**

Extend `tooling/verify_workflows.dart` so it rejects:

```text
uses: owner/repository@vN
uses: owner/repository@main
/releases/download/continuous/
/releases/latest/download/
```

It must accept only 40-character hexadecimal revisions for non-local actions and immutable versioned release asset URLs for downloaded executables.

- [ ] **Step 2: Run validation to prove mutable external tooling fails**

```powershell
dart run tooling/verify_workflows.dart
```

Expected: FAIL because the existing appimagetool URL contains `/continuous/`.

- [ ] **Step 3: Update every action pin**

Replace every action revision in CI and release workflows with the Task 1 selected full SHA. Keep a comment containing the selected stable major, for example `# v5`.

- [ ] **Step 4: Replace mutable executable references**

Replace the appimagetool URL with the selected immutable stable release asset and replace `APPIMAGETOOL_SHA256` with the SHA-256 calculated from that exact asset. If the official project publishes no stable immutable release, select the documented stable replacement from Task 1 and update `tooling/packaging/package_linux.sh` only as required by its official CLI.

- [ ] **Step 5: Validate workflows and automation**

```powershell
dart run tooling/verify_workflows.dart
flutter test test/tooling/architecture_test.dart
git diff --check
```

Expected: workflow verification and architecture test pass with no mutable dependency references.

- [ ] **Step 6: Commit CI dependency upgrades**

```powershell
git add .github tooling/verify_workflows.dart tooling/packaging/package_linux.sh test/tooling/architecture_test.dart docs/development/releases-and-signing.md docs/development/dependency-inventory.md
git commit -m "ci: upgrade workflow dependencies"
```

---

### Task 4: Run Native Compatibility and Packaging Gates

**Files:**
- Modify: platform source or tests only when a reproduced upgraded-dependency failure requires it
- Modify: `docs/development/dependency-inventory.md`

**Interfaces:**
- Consumes: upgraded SDK, package graph, workflows, and packaging tool from Tasks 2 and 3
- Produces: locally verified Windows build/packages and remotely verified Ubuntu build/packages

- [ ] **Step 1: Run clean repository gates**

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
dart run tooling/verify_architecture.dart
dart run tooling/verify_workflows.dart
flutter analyze
flutter test
```

Expected: every command exits 0 and generated output is committed.

- [ ] **Step 2: Run all Windows native integrations**

```powershell
flutter test integration_test/platform/process_tree_integration_test.dart -d windows
flutter test integration_test/foundation_startup_integration_test.dart -d windows
flutter test integration_test/performance/concurrent_streams_integration_test.dart -d windows
```

Expected: process-tree cancellation, production startup, and two concurrent 1 MiB streams pass.

- [ ] **Step 3: Build and smoke Windows packages**

```powershell
flutter build windows --release
tooling/packaging/package_windows.ps1 -Version 0.1.0
tooling/smoke/windows_install_update.ps1 -InitialPackage dist/maestro-windows-x64.zip -UpdatePackage dist/maestro-windows-x64.zip -WorkRoot .artifacts/dependency-upgrade/windows-smoke
```

Expected: release build, ZIP/MSIX creation, and portable update staging pass without changing source or application-data fixtures.

- [ ] **Step 4: Push the implementation commits**

```powershell
git push origin feature/issue-1-foundation
```

Expected: CI starts for the exact implementation SHA.

- [ ] **Step 5: Follow native CI to completion**

```powershell
$run = gh run list --branch feature/issue-1-foundation --limit 1 --json databaseId,headSha,status,conclusion,url | ConvertFrom-Json | Select-Object -First 1
gh run watch $run.databaseId --exit-status
```

Expected: `analyze-test`, `windows-platform`, and `linux-platform` all succeed, including packages and smoke tests.

- [ ] **Step 6: Commit any evidence-backed compatibility correction**

If a native gate fails, reproduce or diagnose from its complete job log, make
the narrowest correction, rerun the affected local gate, and commit with
`fix: adapt upgraded dependencies`. Repeat Step 5 until all jobs are green.

---

### Task 5: Verify Artifacts and Update PR Evidence

**Files:**
- Modify: `docs/development/dependency-inventory.md`
- Modify: `docs/development/issue-1-verification.md`
- Modify: `.artifacts/pr-body.md` (ignored working artifact only)

**Interfaces:**
- Consumes: successful exact-SHA CI run and four uploaded packages from Task 4
- Produces: review-ready PR #16 with current dependency and artifact evidence

- [ ] **Step 1: Download the successful run artifacts**

```powershell
gh run download $run.databaseId --dir .artifacts/dependency-upgrade/download
```

Expected: Windows ZIP/MSIX and Linux AppImage/DEB files are present.

- [ ] **Step 2: Verify all downloaded packages together**

Copy the four packages into `.artifacts/dependency-upgrade/combined`, then run:

```powershell
dart run tooling/release/create_manifest.dart .artifacts/dependency-upgrade/combined 0.1.0 https://github.com/artur-rios/maestro/releases/download/v0.1.0/
dart run tooling/release/verify_release.dart .artifacts/dependency-upgrade/combined
```

Expected: `release-verification: passed`; publisher signing remains either truthfully `verified` or `unconfigured`.

- [ ] **Step 3: Finalize dependency and issue evidence**

Record in both evidence documents:

- exact implementation SHA and successful workflow URL;
- selected Flutter/Dart versions;
- confirmation that `flutter pub outdated --json` has no newer resolvable stable packages;
- all action SHAs and external-tool version/digest;
- SHA-256 for each downloaded desktop package;
- publisher-signing status.

- [ ] **Step 4: Commit and push evidence**

```powershell
git add docs/development/dependency-inventory.md docs/development/issue-1-verification.md
git commit -m "docs: record dependency upgrade evidence"
git push origin feature/issue-1-foundation
```

- [ ] **Step 5: Update PR #16 and verify the final head**

Update the PR body with the dependency inventory and successful run URL, then run:

```powershell
gh pr checks 16 --watch --interval 10
gh pr view 16 --json state,isDraft,mergeStateStatus,headRefOid,statusCheckRollup
git status --short
```

Expected: PR #16 remains open and unmerged, every final-head check succeeds, and the worktree is clean.
