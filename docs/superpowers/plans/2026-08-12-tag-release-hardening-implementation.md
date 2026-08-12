# Tag Release Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish verified stable and prerelease GitHub releases containing Maestro's Windows ZIP, MSIX, setup installer, Linux AppImage, and Linux DEB whenever a supported version tag is pushed.

**Architecture:** A shared Dart release-version model validates tags and projects semantic versions into Windows and Debian package versions. Native packagers consume those explicit projections, while a hardened final release job enforces the exact artifact contract, optional-but-complete signing, checksums, attestations, and GitHub prerelease metadata before publication.

**Tech Stack:** GitHub Actions YAML, Dart 3.12, Flutter 3.44.8, PowerShell 7, Bash, MSIX tooling, Inno Setup 6.7.1, Debian packaging, Flutter tests.

## Global Constraints

- Preserve all five package artifacts: ZIP, MSIX, setup EXE, AppImage, and DEB.
- Accept only `vX.Y.Z`, `vX.Y.Z-alpha.N`, `vX.Y.Z-beta.N`, and `vX.Y.Z-rc.N` tags.
- Require canonical decimal identifiers with core components in `0..65535` and prerelease sequence numbers in `0..9999`.
- Map Windows revisions to `10000 + N` for alpha, `30000 + N` for beta, `50000 + N` for rc, and `65535` for stable.
- Map Debian prereleases to `X.Y.Z~channel.N` and stable releases to `X.Y.Z`.
- Keep release-manifest signing optional only when both signing secrets are absent.
- Keep all third-party GitHub Actions pinned to immutable 40-character commit SHAs.
- Do not change the five existing package filenames.

---

## File Structure

- `lib/platform/updates/release_version.dart`: shared supported-version parser, comparison, and platform projections.
- `tooling/release/validate_release_tag.dart`: GitHub Actions adapter that writes validated version outputs.
- `tooling/release/release_artifacts.dart`: exact release package allowlist, non-empty-file validation, and checksum parsing/creation.
- `tooling/release/create_manifest.dart`: runtime manifest plus checksums for all five distribution packages.
- `tooling/release/verify_release.dart`: verifies the artifact set, checksums, manifest entries, and optional signature.
- `tooling/packaging/package_windows.ps1`: builds Windows artifacts from explicit semantic/core/native versions.
- `tooling/packaging/windows/build_installer.ps1`: separates installer display version from numeric file version.
- `tooling/packaging/windows/maestro.iss`: consumes separate display and numeric version macros.
- `tooling/packaging/package_linux.sh`: builds Linux artifacts from explicit semantic/core/Debian versions.
- `.github/workflows/release.yml`: validates once, builds on native runners, and publishes atomically.
- `.github/workflows/ci.yml`: exercises the revised packaging interfaces with stable fixture versions.
- `tooling/verify_workflows.dart`: statically enforces hardened release-workflow structure.
- Tests under `test/platform/updates/` and `test/tooling/`: behavior and contract verification.
- `docs/development/releases-and-signing.md` and `README.md`: supported tags, package mapping, and release behavior.

### Task 1: Shared release-version model and tag validator

**Files:**
- Create: `lib/platform/updates/release_version.dart`
- Create: `tooling/release/validate_release_tag.dart`
- Create: `test/platform/updates/release_version_test.dart`
- Modify: `lib/platform/updates/release_manifest.dart`
- Modify: `test/tooling/release_manifest_test.dart`

**Interfaces:**
- Produces: `ReleaseVersion.parseTag(String tag)` and `ReleaseVersion.parse(String version)`.
- Produces: `semanticVersion`, `coreVersion`, `windowsVersion`, `debianVersion`, `isPrerelease`, and `compareTo(ReleaseVersion other)`.
- Produces: `dart tooling/release/validate_release_tag.dart <tag> <github-output-file>`.
- Consumes: no project services or external packages; parsing remains deterministic and side-effect free.

- [ ] **Step 1: Write failing parser and projection tests**

Add table-driven tests that assert these exact projections:

```dart
final cases = <String, (String, String, String, bool)>{
  'v1.2.3-alpha.4': ('1.2.3', '1.2.3.10004', '1.2.3~alpha.4', true),
  'v1.2.3-beta.4': ('1.2.3', '1.2.3.30004', '1.2.3~beta.4', true),
  'v1.2.3-rc.4': ('1.2.3', '1.2.3.50004', '1.2.3~rc.4', true),
  'v1.2.3': ('1.2.3', '1.2.3.65535', '1.2.3', false),
};
for (final MapEntry(key: tag, value: expected) in cases.entries) {
  final version = ReleaseVersion.parseTag(tag);
  expect(version.coreVersion, expected.$1);
  expect(version.windowsVersion, expected.$2);
  expect(version.debianVersion, expected.$3);
  expect(version.isPrerelease, expected.$4);
}
```

Add rejection cases for `1.2.3`, `v01.2.3`, `v1.2`, `v1.2.3-preview.1`,
`v1.2.3-beta`, `v1.2.3-beta.10000`, `v65536.0.0`, and
`v1.2.3+build.1`. Add ordering assertions for
`alpha.1 < alpha.2 < beta.0 < rc.0 < stable < 1.2.4-alpha.0`.

- [ ] **Step 2: Run the tests and confirm the model is absent**

Run: `flutter test test/platform/updates/release_version_test.dart`

Expected: FAIL because `release_version.dart` and `ReleaseVersion` do not exist.

- [ ] **Step 3: Implement the supported release-version value object**

Use one anchored regular expression:

```dart
static final RegExp _pattern = RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
  r'(?:-(alpha|beta|rc)\.(0|[1-9]\d*))?$',
);
```

`parseTag` must require and remove exactly one leading `v`; `parse` handles the
unprefixed manifest/application form. Validate core components at `65535` and
sequence at `9999`. Derive the fourth Windows component from the approved
channel bases. Implement SemVer precedence for the supported subset in
`compareTo` without comparing projected strings.

- [ ] **Step 4: Add the GitHub output adapter and manifest validation**

Write these exact newline-delimited outputs in append mode:

```dart
final values = <String, String>{
  'semantic_version': version.semanticVersion,
  'core_version': version.coreVersion,
  'windows_version': version.windowsVersion,
  'debian_version': version.debianVersion,
  'is_prerelease': version.isPrerelease.toString(),
};
await output.writeAsString(
  values.entries.map((entry) => '${entry.key}=${entry.value}').join('\n') + '\n',
  mode: FileMode.append,
);
```

Replace the permissive manifest version regular expression with
`ReleaseVersion.parse(version)` so runtime manifests accept exactly the same
stable/prerelease subset as the release pipeline.

- [ ] **Step 5: Verify parser, manifest, formatting, and analysis**

Run:

```powershell
flutter test test/platform/updates/release_version_test.dart test/tooling/release_manifest_test.dart
dart format --output=none --set-exit-if-changed lib/platform/updates/release_version.dart lib/platform/updates/release_manifest.dart tooling/release/validate_release_tag.dart test/platform/updates/release_version_test.dart test/tooling/release_manifest_test.dart
flutter analyze
```

Expected: all commands exit `0`; the validator writes the five exact outputs
for stable and prerelease fixture tags.

- [ ] **Step 6: Commit the version model**

```powershell
git add lib/platform/updates/release_version.dart lib/platform/updates/release_manifest.dart tooling/release/validate_release_tag.dart test/platform/updates/release_version_test.dart test/tooling/release_manifest_test.dart
git commit -m "feat: add release version projections"
```

### Task 2: Prerelease-aware updates and native packagers

**Files:**
- Modify: `lib/platform/updates/update_service.dart`
- Modify: `test/platform/updates/update_service_test.dart`
- Modify: `tooling/packaging/package_windows.ps1`
- Modify: `tooling/packaging/windows/build_installer.ps1`
- Modify: `tooling/packaging/windows/maestro.iss`
- Modify: `tooling/packaging/package_linux.sh`
- Modify: `.github/workflows/ci.yml`
- Modify: `test/tooling/windows_installer_assets_test.dart`
- Modify: `test/tooling/update_helper_assets_test.dart`

**Interfaces:**
- Consumes: `ReleaseVersion.parse(String)` and `compareTo` from Task 1.
- Produces: `package_windows.ps1 -SemanticVersion <semver> -CoreVersion <X.Y.Z> -WindowsVersion <X.Y.Z.R> [-SkipBuild]`.
- Produces: `build_installer.ps1 -DisplayVersion <semver> -WindowsVersion <X.Y.Z.R> ...`.
- Produces: `package_linux.sh <semantic-version> <core-version> <debian-version>`.

- [ ] **Step 1: Write failing update-order and packaging-contract tests**

Add update checks using manifests at `1.2.3-alpha.2`, `1.2.3-beta.0`,
`1.2.3-rc.0`, and `1.2.3`, proving each later channel is offered over the
earlier installed version and that a downgrade is not offered.

Extend asset tests to require:

```dart
expect(packageScript, contains('SemanticVersion'));
expect(packageScript, contains('CoreVersion'));
expect(packageScript, contains('WindowsVersion'));
expect(packageScript, contains('MAESTRO_INSTALLED_VERSION'));
expect(installerScript, contains('/DDisplayVersion='));
expect(installerScript, contains('/DWindowsVersion='));
expect(definition, contains('AppVersion={#DisplayVersion}'));
expect(definition, contains('VersionInfoVersion={#WindowsVersion}'));
```

Require the Linux script to use three distinct inputs and the Debian input in
the generated control file.

- [ ] **Step 2: Run focused tests and confirm old behavior fails**

Run:

```powershell
flutter test test/platform/updates/update_service_test.dart
flutter test test/tooling/windows_installer_assets_test.dart test/tooling/update_helper_assets_test.dart
```

Expected: FAIL because updates compare only the three core numbers and the
packagers expose only one stable-version input.

- [ ] **Step 3: Use supported SemVer ordering in the update service**

Replace `_versionParts` and the three-integer loop with:

```dart
static bool _isNewer(String candidate, String installed) =>
    ReleaseVersion.parse(candidate).compareTo(
      ReleaseVersion.parse(installed),
    ) > 0;
```

Keep malformed installed or candidate versions fail-closed by preserving the
parser's `FormatException` rather than silently treating them as newer.

- [ ] **Step 4: Split Windows display, build, and package versions**

Change `package_windows.ps1` to validate all three explicit parameters. Pass
`CoreVersion` to `flutter build --build-name`, `WindowsVersion` to
`msix:create --version`, and both `SemanticVersion` and `WindowsVersion` to the
installer builder. In `maestro.iss`, replace `AppVersion` with
`DisplayVersion` and use `WindowsVersion` directly for `VersionInfoVersion`.
Pass
`--dart-define=MAESTRO_INSTALLED_VERSION=$SemanticVersion` to the Flutter
build so the packaged application compares updates against its full
prerelease version rather than the numeric core alone.

Update the installer verification to compare the generated file's normalized
product version with `WindowsVersion`, while leaving the uninstall display
version equal to `SemanticVersion`.

- [ ] **Step 5: Split Linux semantic, build, and Debian versions**

Validate all three inputs in `package_linux.sh`. Use `CoreVersion` for
`flutter build --build-name`, export `VERSION=$SemanticVersion` while invoking
AppImageTool, and substitute `DebianVersion` into the control template. Keep
all filenames unchanged. Pass the same
`--dart-define=MAESTRO_INSTALLED_VERSION=$SemanticVersion` used by the Windows
build. Add an asset test that asserts both release packaging scripts supply
the define consumed by the existing `lib/main.dart` environment lookup.

- [ ] **Step 6: Update CI packaging fixtures and verify**

Use these stable fixture projections in `.github/workflows/ci.yml`:

```text
semantic: 0.1.0
core:     0.1.0
windows:  0.1.0.65535
debian:   0.1.0
```

For the second smoke installer use semantic/core `0.1.1` and Windows
`0.1.1.65535`. Run the focused tests, PowerShell parser checks for both Windows
scripts, `bash -n tooling/packaging/package_linux.sh`, `dart format`, and
`flutter analyze`. Expected: all commands exit `0`.

- [ ] **Step 7: Commit native prerelease support**

```powershell
git add lib/platform/updates/update_service.dart test/platform/updates/update_service_test.dart tooling/packaging/package_windows.ps1 tooling/packaging/windows/build_installer.ps1 tooling/packaging/windows/maestro.iss tooling/packaging/package_linux.sh .github/workflows/ci.yml test/tooling/windows_installer_assets_test.dart test/tooling/update_helper_assets_test.dart
git commit -m "feat: package native prerelease versions"
```

### Task 3: Exact artifact, checksum, and signing verification

**Files:**
- Create: `tooling/release/release_artifacts.dart`
- Create: `test/tooling/release_artifacts_test.dart`
- Modify: `tooling/release/create_manifest.dart`
- Modify: `tooling/release/verify_release.dart`
- Modify: `test/tooling/release_manifest_test.dart`

**Interfaces:**
- Produces: `const distributionPackageNames` containing exactly five names.
- Produces: `const runtimePackageNames` containing ZIP, MSIX, AppImage, and DEB.
- Produces: `validateDistributionPackages(Directory)` returning the five non-empty files in deterministic filename order.
- Produces: `createSha256Sums(Iterable<File>)` and `parseSha256Sums(String)`.
- Consumes: the full semantic version from Task 1.

- [ ] **Step 1: Write failing artifact-contract tests**

Create five non-empty fixture packages and assert successful deterministic
validation. Add separate tests for a missing installer, an empty package, and
an unexpected `surprise.msix`; each must throw before manifest generation.

Assert that `release-manifest.json` includes four runtime artifacts while
`SHA256SUMS` includes all five distribution packages, including
`maestro-windows-x64-setup.exe`.

- [ ] **Step 2: Run artifact tests and confirm incomplete enforcement**

Run:

```powershell
flutter test test/tooling/release_artifacts_test.dart test/tooling/release_manifest_test.dart
```

Expected: FAIL because the exact artifact contract and setup-installer checksum
do not exist.

- [ ] **Step 3: Implement the shared package allowlist and checksums**

Define the exact lists:

```dart
const runtimePackageNames = <String>{
  'maestro-windows-x64.zip',
  'maestro-windows-x64.msix',
  'maestro-linux-x64.AppImage',
  'maestro-linux-amd64.deb',
};
const distributionPackageNames = <String>{
  ...runtimePackageNames,
  'maestro-windows-x64-setup.exe',
};
```

Reject missing, empty, or extra managed package extensions
`.zip`, `.msix`, `.exe`, `.AppImage`, and `.deb`. Generate lowercase SHA-256
entries sorted by filename and require parser input to contain exactly one
valid digest for every distribution package.

- [ ] **Step 4: Harden manifest creation and verification**

`create_manifest.dart` must validate all five files, pass only
`runtimePackageNames` into `createReleaseManifest`, and create `SHA256SUMS`
from all five files. `verify_release.dart` must:

1. Validate the exact package set and checksum file.
2. Recompute all five digests and sizes where represented.
3. Require the manifest's four filenames to equal `runtimePackageNames`.
4. Verify each manifest digest and size against its file.
5. Apply the existing signature rule: both signature and public key absent is
   unconfigured; either one alone fails; both present must verify.

Normalize a missing or empty public-key environment value to the same
unconfigured state. This matches GitHub's empty secret expansion while still
failing when a signature exists without a usable public key.

- [ ] **Step 5: Verify release tooling**

Run:

```powershell
flutter test test/tooling/release_artifacts_test.dart test/tooling/release_manifest_test.dart
dart format --output=none --set-exit-if-changed tooling/release test/tooling/release_artifacts_test.dart test/tooling/release_manifest_test.dart
flutter analyze
```

Also invoke `create_manifest.dart` and `verify_release.dart` against a temporary
five-package fixture. Expected output contains `release-verification: passed`
and `publisher-signing: unconfigured`.

- [ ] **Step 6: Commit release artifact enforcement**

```powershell
git add tooling/release/release_artifacts.dart tooling/release/create_manifest.dart tooling/release/verify_release.dart test/tooling/release_artifacts_test.dart test/tooling/release_manifest_test.dart
git commit -m "fix: enforce exact release artifacts"
```

### Task 4: Harden tag-triggered GitHub release orchestration

**Files:**
- Modify: `.github/workflows/release.yml`
- Modify: `tooling/verify_workflows.dart`
- Modify: `test/tooling/windows_installer_assets_test.dart`
- Modify: `test/tooling/release_artifacts_test.dart`

**Interfaces:**
- Consumes: validator outputs and packaging commands from Tasks 1-3.
- Produces: one published GitHub release for each valid supported tag.
- Produces: normal releases for stable tags and prereleases for alpha, beta, and rc tags.

- [ ] **Step 1: Write failing workflow-structure assertions**

Extend workflow verification to require:

- A `validate-release` job exposing all five version outputs.
- Both package jobs depending on validation and consuming its outputs.
- The final job depending on validation plus both package jobs.
- Exact artifact upload paths and `if-no-files-found: error`.
- Tag-scoped concurrency with `cancel-in-progress: false`.
- `generate_release_notes: true` and prerelease wired to validator output.
- Explicit detection of incomplete signing material.
- Top-level `contents: read` plus write, OIDC, and attestation permissions only
  on the final publication job.

Keep the immutable action-reference scan unchanged.

- [ ] **Step 2: Run workflow checks and confirm missing hardening**

Run:

```powershell
dart run tooling/verify_workflows.dart
flutter test test/tooling/windows_installer_assets_test.dart test/tooling/release_artifacts_test.dart
```

Expected: FAIL because the current workflow parses tags independently, has no
validation job or concurrency policy, and does not configure generated notes
or the prerelease flag.

- [ ] **Step 3: Add validation and concurrency to the workflow**

Add top-level configuration:

```yaml
concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false
```

Create `validate-release` on `ubuntu-24.04`, checkout the tag, install the same
pinned Flutter toolchain, and run:

```yaml
- id: version
  run: dart tooling/release/validate_release_tag.dart "$GITHUB_REF_NAME" "$GITHUB_OUTPUT"
```

Expose all five step outputs at job level. Make each native package job depend
on validation and pass the projected versions explicitly to its packager. Use
bracket access such as
`${{ needs['validate-release'].outputs.semantic_version }}` because the job ID
contains a hyphen.

- [ ] **Step 4: Harden final verification and optional signing**

Make the final job depend on all three preceding jobs. After downloading the
two artifact groups, create the manifest using `semantic_version`. Use one
shell branch that signs only when both key variables are non-empty, proceeds
unsigned only when both are empty, and exits nonzero when exactly one is set.
Always run `verify_release.dart` before attestation or publication.

Set top-level permissions to `contents: read`. Grant `contents: write`,
`id-token: write`, and `attestations: write` only on the final `release` job.

- [ ] **Step 5: Publish release metadata explicitly**

Configure the pinned release action with:

```yaml
with:
  name: ${{ github.ref_name }}
  generate_release_notes: true
  prerelease: ${{ needs['validate-release'].outputs.is_prerelease }}
  files: dist/*
  fail_on_unmatched_files: true
```

Keep the attestation step before release publication.

- [ ] **Step 6: Verify and commit the workflow**

Run:

```powershell
dart run tooling/verify_workflows.dart
flutter test test/tooling/windows_installer_assets_test.dart test/tooling/release_artifacts_test.dart
git diff --check
```

Expected: all commands exit `0`, and every `uses:` reference remains a
40-character SHA.

```powershell
git add .github/workflows/release.yml tooling/verify_workflows.dart test/tooling/windows_installer_assets_test.dart test/tooling/release_artifacts_test.dart
git commit -m "ci: harden tag release publication"
```

### Task 5: Documentation and complete verification

**Files:**
- Modify: `docs/development/releases-and-signing.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: final commands, accepted tag forms, package mappings, and signing policy from Tasks 1-4.
- Produces: operator instructions for stable and prerelease publication.

- [ ] **Step 1: Update release operator documentation**

Document the four accepted tag forms, alpha/beta/rc sequence range, Windows
revision mapping, Debian `~` mapping, GitHub prerelease behavior, exact five
packages, generated notes, and optional signing rule. Update local packaging
examples to pass the explicit semantic/core/native version arguments.

- [ ] **Step 2: Run the complete repository verification**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
dart run tooling/verify_architecture.dart
dart run tooling/verify_workflows.dart
flutter analyze
flutter test
git diff --check
git status --short
```

On Windows, also run the packaging verification used by CI with stable fixture
versions and `-SkipBuild` after ensuring the release bundle and pinned Inno
compiler exist. On Ubuntu, rely on the unchanged native CI job for AppImage and
DEB build/smoke execution unless an Ubuntu runner is locally available.

Expected: every available command exits `0`; Windows creates non-empty ZIP,
MSIX, and setup EXE artifacts with `0.1.0.65535` numeric metadata; the working
tree lists only the intended documentation changes before the final commit.

- [ ] **Step 3: Commit documentation**

```powershell
git add docs/development/releases-and-signing.md README.md
git commit -m "docs: explain tag release versions"
```

- [ ] **Step 4: Record final evidence**

Capture the exact successful command outputs, the five artifact names, their
positive sizes, the unsigned or verified signing status, and `git status
--short`. Do not push a test tag from the implementation workspace; after the
change is reviewed and merged, validate publication with the next intended
release tag.
