# Tag Release Hardening Design

## Goal

Harden Maestro's existing tag-triggered GitHub Actions release pipeline so
every supported stable or prerelease tag publishes a verified GitHub release
containing the Windows ZIP, MSIX, and setup installer plus the Linux AppImage
and DEB packages.

## Supported release tags

The release workflow continues to trigger for tags beginning with `v`, then a
dedicated validation job accepts only these complete forms:

- Stable: `v<major>.<minor>.<patch>`
- Alpha: `v<major>.<minor>.<patch>-alpha.<sequence>`
- Beta: `v<major>.<minor>.<patch>-beta.<sequence>`
- Release candidate: `v<major>.<minor>.<patch>-rc.<sequence>`

All numeric identifiers use canonical decimal notation: zero is written `0`,
and other values have no leading zero. Major, minor, and patch must each fit
the Windows package-version range `0..65535`. Prerelease sequences must fit
the range selected by the Windows mapping below. Tags with build metadata,
arbitrary prerelease labels, missing sequence numbers, or out-of-range values
fail in validation before packaging starts.

## Release version model

A repository-owned release-version tool is the single source of truth for tag
validation and platform version projection. It emits job outputs consumed by
both packaging jobs and the final release job:

- `semantic_version`: the tag without its `v` prefix, preserved in release
  metadata and the signed release manifest.
- `core_version`: the numeric `major.minor.patch` portion used where Flutter
  requires a numeric build name.
- `windows_version`: a four-part numeric version used by MSIX and executable
  file metadata.
- `debian_version`: the Debian package version.
- `is_prerelease`: `true` for alpha, beta, and release-candidate tags.

Windows package revisions encode ordering within the same core version:

- `alpha.N` maps to revision `10000 + N`, where `N` is `0..9999`.
- `beta.N` maps to revision `30000 + N`, where `N` is `0..9999`.
- `rc.N` maps to revision `50000 + N`, where `N` is `0..9999`.
- A stable release maps to revision `65535`.

This guarantees `alpha < beta < rc < stable` and preserves sequence ordering
inside each supported channel. For example, `v1.2.3-beta.4` has semantic
version `1.2.3-beta.4`, core version `1.2.3`, and Windows version
`1.2.3.30004`.

Debian prereleases replace the semantic-version hyphen with Debian's `~`, so
`v1.2.3-beta.4` maps to `1.2.3~beta.4`; the stable tag maps to `1.2.3`. Debian
therefore also orders every supported prerelease below its stable counterpart.

## Packaging changes

The Windows packager accepts the semantic display version, numeric core
version, and four-part Windows package version separately. Flutter builds with
the numeric core version. MSIX receives the four-part Windows version. The
Inno Setup installer displays the semantic version but writes the numeric
Windows version into executable version resources. Existing ZIP, MSIX, and
setup filenames remain unchanged.

The Linux packager accepts the semantic version, numeric core version, and
Debian version separately. Flutter builds with the numeric core version, the
AppImage bundle exposes the semantic release version where supported, and the
DEB control file receives the Debian version. Existing AppImage and DEB
filenames remain unchanged.

The release manifest records the full semantic version. The application
version comparison must follow the supported prerelease precedence so an
alpha installation can advance through beta and release-candidate versions to
the stable release with the same core version.

## Workflow architecture

The release workflow contains four jobs:

1. `validate-release` parses the tag once and exposes the version projections.
2. `windows-package` builds the ZIP, MSIX, and setup EXE from those outputs.
3. `linux-package` builds the AppImage and DEB from those outputs.
4. `release` downloads both artifact groups, verifies the complete release,
   creates and optionally signs metadata, attests the files, and publishes the
   GitHub release.

The packaging jobs depend on validation and never parse `GITHUB_REF_NAME`
independently. Concurrency is scoped to the complete tag reference and does
not cancel an in-progress release, preventing two runs for the same tag from
publishing concurrently.

GitHub Releases uses the tag as its release name, generates release notes, and
sets its prerelease flag from the validator output. Stable releases are normal
published releases. Alpha, beta, and release-candidate versions are published
as GitHub prereleases.

## Artifact contract

Before publication, the release directory must contain these five non-empty
package files exactly:

- `maestro-windows-x64.zip`
- `maestro-windows-x64.msix`
- `maestro-windows-x64-setup.exe`
- `maestro-linux-x64.AppImage`
- `maestro-linux-amd64.deb`

The manifest generator includes the four runtime-update packages (ZIP, MSIX,
AppImage, and DEB). The setup EXE remains a distribution-only artifact and is
covered by release checksums and provenance without entering the runtime
update manifest. The final published release additionally contains
`release-manifest.json`, `SHA256SUMS`, and, when configured,
`release-manifest.sig`.

An absent required package, an unexpected package with one of the managed
release extensions, an empty file, a size or checksum mismatch, or an invalid
manifest stops the workflow before GitHub release publication.

## Optional signing and provenance

Publisher signing remains optional only when both release signing secrets are
absent. If the secret and public keys are both present, the workflow signs the
manifest and verifies the detached signature. If only one key is present, or
if signing or verification fails, the release fails closed.

GitHub artifact attestations remain required for all files that will be
published. Actions remain pinned to immutable commit SHAs.

## Verification

Automated tests cover:

- Accepted stable, alpha, beta, and release-candidate tags.
- Rejection of malformed, unsupported, noncanonical, and out-of-range tags.
- Exact semantic, core, Windows, Debian, and prerelease outputs.
- Ordering of alpha, beta, release-candidate, and stable projections.
- Prerelease-aware application update comparison.
- Separation of installer display version and executable package version.
- The exact five-package release contract and setup EXE exclusion from the
  runtime update manifest.
- Optional signing when both keys are absent and failure on incomplete signing
  material.
- Workflow dependencies, concurrency, generated notes, prerelease flag, exact
  artifact uploads, and immutable action references.

Existing Windows installer lifecycle smoke tests, Windows portable update
smoke tests, Linux install/update smoke tests, workflow validation, Flutter
analysis, and the unit test suite remain CI gates.

