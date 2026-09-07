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

## Application icon

Every platform's icon is generated from one geometry definition in
`tooling/packaging/icons/generate_icons.py`, so the Windows `.ico`, the scalable
SVG and the hicolor PNGs cannot drift apart:

```bash
python3 tooling/packaging/icons/generate_icons.py
```

It writes `windows/runner/resources/app_icon.ico` (16 through 256),
`tooling/packaging/maestro.svg`, `tooling/packaging/icons/maestro-N.png`
(16 through 1024), and `assets/icons/maestro.png`. The generated files are
committed, so no build or CI job depends on Python being present; regenerate
and commit whenever the mark changes.
`flutter test test/tooling/update_helper_assets_test.dart` fails if a size goes
missing or the MSIX logo stops pointing at the 1024px source.

Each platform picks the icon up differently:

| Where | How it resolves |
| --- | --- |
| Windows executable, taskbar, installer | `app_icon.ico`, linked into the runner |
| MSIX tile | `logo_path` in `msix_config`, scaled from the 1024px source |
| Debian package | the hicolor theme, which the package installs |
| AppImage | the desktop entry names it, and the window falls back to the bundled copy |
| `flutter run -d linux` | the bundled copy |

The last two matter: `gtk_window_set_icon_name` only resolves a name an
installed icon theme carries, so a build nobody installed — a development run,
or the AppImage, which ships its own hicolor tree without joining it to the
icon search path — had no window icon at all. The Linux runner therefore falls
back to `assets/icons/maestro.png`, which the Flutter bundle places beside the
executable in every build.

## Manifest signing

Update manifests use detached Ed25519 signatures. Configure these GitHub secrets as base64-encoded libsodium keys:

- `MAESTRO_RELEASE_SECRET_KEY_BASE64`: 64-byte secret key; release job only.
- `MAESTRO_RELEASE_PUBLIC_KEY_BASE64`: 32-byte verification key.

With both secrets configured, run `dart run tooling/release/sign_manifest.dart dist`.
Manifest signing is optional only when both secrets are absent. If exactly one
secret is configured, or signing or verification fails, the release fails
closed. GitHub artifact attestations are produced independently with OIDC
provenance.

## Enabling the in-application updater

Signing a manifest is only half of it. A packaged build can check, verify and
install updates only when the packaging step stamps four values into it, and a
build missing any of them composes no update service at all and reports
`Updates are unavailable in this build`:

| Define | Source | Meaning |
| --- | --- | --- |
| `MAESTRO_RELEASE_PUBLIC_KEY_BASE64` | secret `MAESTRO_RELEASE_PUBLIC_KEY_BASE64` | The key every manifest signature is checked against. |
| `MAESTRO_RELEASE_MANIFEST_URL` | repository variable | Where a running Maestro looks for the current manifest. |
| `MAESTRO_RELEASE_SIGNATURE_URL` | repository variable | The detached signature beside it. |
| `MAESTRO_RELEASE_PACKAGE_TYPE` | packaging default (`zip` on Windows, `appimage` on Linux) | Which artifact this build may install into itself. |

The two URLs must be stable across releases, because a build published today
has to find the manifest published months later. GitHub's redirect for the most
recent release is the intended shape:

```
https://github.com/artur-rios/maestro/releases/latest/download/release-manifest.json
https://github.com/artur-rios/maestro/releases/latest/download/release-manifest.json.sig
```

The packaging scripts treat the three published inputs as all-or-nothing and
report which case applied — `runtime-updates: configured` or
`runtime-updates: unconfigured`. Supplying some but not all of them fails the
packaging step rather than shipping a build that cannot verify what it
downloads. `dart run tooling/verify_workflows.dart` checks that both packaging
jobs still forward them.

There is currently no trusted Windows publisher certificate. Local MSIX files are test-signed and must not be described as publisher-trusted. Unsigned manifest verification prints `publisher-signing: unconfigured`; it never implies trust.

Maestro downloads only the artifact matching its platform, architecture, and installed package type. It enforces the signed size and SHA-256, stages under the application data root, and requires approval tied to that exact digest before invoking an installer.
