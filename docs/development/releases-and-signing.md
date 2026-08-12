# Releases and Signing

Pushing a supported release tag starts the GitHub release workflow. The
validator accepts exactly these forms:

- Stable: `v<major>.<minor>.<patch>`
- Alpha: `v<major>.<minor>.<patch>-alpha.<sequence>`
- Beta: `v<major>.<minor>.<patch>-beta.<sequence>`
- Release candidate: `v<major>.<minor>.<patch>-rc.<sequence>`

Every numeric identifier is canonical decimal: `0` is allowed, other values
have no leading zeroes, and major, minor, and patch are each `0..65535`.
Prerelease sequences are `0..9999`. Build metadata, other prerelease labels,
missing sequences, noncanonical numbers, and out-of-range values are rejected
before packaging begins.

The tag without the leading `v` is the semantic version used by the release
metadata and update manifest. Its numeric `major.minor.patch` portion is the
core version passed to Flutter. Native package versions are projected as
follows:

| Tag suffix | Windows revision | Debian version |
| --- | --- | --- |
| `-alpha.N` | `10000 + N` | `X.Y.Z~alpha.N` |
| `-beta.N` | `30000 + N` | `X.Y.Z~beta.N` |
| `-rc.N` | `50000 + N` | `X.Y.Z~rc.N` |
| none (stable) | `65535` | `X.Y.Z` |

For example, `v1.2.3-beta.4` maps to semantic version `1.2.3-beta.4`, core
version `1.2.3`, Windows version `1.2.3.30004`, and Debian version
`1.2.3~beta.4`. These mappings preserve `alpha < beta < rc < stable` for the
same core version; Debian's `~` also places every prerelease below its stable
counterpart.

Stable tags publish normal GitHub Releases. Alpha, beta, and release-candidate
tags publish GitHub prereleases. Every release uses its tag as the release name
and has GitHub-generated release notes.

The published release must contain exactly these five non-empty packages:

- `maestro-windows-x64-setup.exe`
- `maestro-windows-x64.zip`
- `maestro-windows-x64.msix`
- `maestro-linux-x64.AppImage`
- `maestro-linux-amd64.deb`

It also contains `release-manifest.json`, `SHA256SUMS`, and, when manifest
signing is configured, `release-manifest.sig`. The runtime-update manifest
contains the ZIP, MSIX, AppImage, and DEB; the setup EXE is a
distribution-only package, though it is still checksummed and attested.

> **Unsigned Windows installer:** `maestro-windows-x64-setup.exe` is currently
> unsigned. Windows may display SmartScreen or unknown-publisher warnings. Do
> not treat the installer as publisher-trusted.

## Windows setup installer

The setup EXE installs Maestro for the current user under
`%LocalAppData%\Programs\Maestro` and does not request administrator rights or
elevation. Launch Maestro from its Start Menu shortcut after installation. To
remove it, open Windows Settings > Apps > Installed apps, select Maestro, and
choose Uninstall.

Installing an upgrade preserves application data. Uninstalling Maestro also
preserves application data so that workflows, history, and settings remain
available for recovery or a later installation. See
[Application Data and Recovery](application-data.md) for data locations and
manual deletion guidance.

The setup EXE is a distribution artifact only. The ZIP package remains the
payload used by Maestro's in-application runtime updater, and the setup EXE is
not included in the runtime update manifest.

## Local packaging

On Windows:

```powershell
$env:FLUTTER_ROOT = 'C:\path\to\flutter'
$compiler = tooling/packaging/windows/install_inno_setup.ps1 `
  -Destination build/tooling/inno-setup
$env:INNO_SETUP_COMPILER = $compiler
tooling/packaging/package_windows.ps1 `
  -SemanticVersion 0.1.0 `
  -CoreVersion 0.1.0 `
  -WindowsVersion 0.1.0.65535
```

`install_inno_setup.ps1` downloads the pinned Inno Setup compiler, verifies its
SHA-256 digest, and installs it for the current user before packaging begins.

On Ubuntu, download the official immutable AppImageTool 1.9.1 asset, verify its pinned SHA-256, and run:

```bash
curl --fail --location --output appimagetool \
  https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage
echo 'ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0  appimagetool' \
  | sha256sum --check --strict
chmod 0755 appimagetool
export APPIMAGETOOL_PATH="$PWD/appimagetool"
bash tooling/packaging/package_linux.sh 0.1.0 0.1.0 0.1.0
```

For a prerelease, pass each distinct projection explicitly. For example,
`v0.1.0-beta.4` uses:

```powershell
tooling/packaging/package_windows.ps1 `
  -SemanticVersion 0.1.0-beta.4 `
  -CoreVersion 0.1.0 `
  -WindowsVersion 0.1.0.30004
```

```bash
bash tooling/packaging/package_linux.sh 0.1.0-beta.4 0.1.0 0.1.0~beta.4
```

Create and verify release metadata after the ZIP, MSIX, AppImage, and DEB
runtime-update artifacts are together:

```bash
dart run tooling/release/create_manifest.dart dist 0.1.0 \
  https://github.com/artur-rios/maestro/releases/download/v0.1.0/
dart run tooling/release/verify_release.dart dist
```

## Manifest signing

Update manifests use detached Ed25519 signatures. Configure these GitHub secrets as base64-encoded libsodium keys:

- `MAESTRO_RELEASE_SECRET_KEY_BASE64`: 64-byte secret key; release job only.
- `MAESTRO_RELEASE_PUBLIC_KEY_BASE64`: 32-byte verification key.

With both secrets configured, run `dart run tooling/release/sign_manifest.dart dist`.
Manifest signing is optional only when both secrets are absent. If exactly one
secret is configured, or signing or verification fails, the release fails
closed. GitHub artifact attestations are produced independently with OIDC
provenance.

There is currently no trusted Windows publisher certificate. Local MSIX files are test-signed and must not be described as publisher-trusted. Unsigned manifest verification prints `publisher-signing: unconfigured`; it never implies trust.

Maestro downloads only the artifact matching its platform, architecture, and installed package type. It enforces the signed size and SHA-256, stages under the application data root, and requires approval tied to that exact digest before invoking an installer.
