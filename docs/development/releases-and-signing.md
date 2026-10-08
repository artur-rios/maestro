# Releases and Signing

Pushing a supported release tag starts the GitHub release workflow. The tag
must point at a commit on `main` — the merge commit of a `release/x.y.z` pull
request, as described under *Releasing* in
[CONTRIBUTING.md](../../CONTRIBUTING.md#releasing) — or the workflow fails
before anything is built. The validator accepts exactly these forms:

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

The setup EXE is a distribution artifact only and is not included in the
runtime update manifest. It installs the same files as the ZIP, so an installed
copy updates itself from the ZIP (see [Windows packages](#windows-packages)).
The uninstaller lives beside the install folder, in `Maestro-uninstall`, so an
in-application update keeps it. Installed apps keeps showing the version the
setup EXE installed until the next setup EXE runs.

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
| `MAESTRO_RELEASE_PACKAGE_TYPE` | set by the packaging script for each package: `zip` for the ZIP and the setup EXE, `msix` for the MSIX, `appimage` for the AppImage, and `deb` for the Debian package | Which artifact this build may install into itself, and how. |

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

The package type is compiled into the build, so when updates are configured
each packaging script builds its bundle once per package type and reports
`runtime-update-package-type:` for each. Without update configuration the
bundles would be identical, and one build serves every package — which is what
CI packages. A build configured for updates cannot be packaged with
`-SkipBuild`, because one prebuilt bundle cannot carry two package types.

### Windows packages

`package_windows.ps1` builds the Windows bundle twice when updates are
configured: once with `zip` for the ZIP and the setup EXE, and once with `msix`
for the MSIX.

- **ZIP and setup EXE.** Maestro launches the bundled
  `replace_windows_zip.ps1`, which waits for Maestro to exit, extracts the
  verified ZIP beside the install folder, swaps the folders, starts the new
  version, and restores the previous folder if it does not start. The folder
  must be writable by the user: a ZIP extracted anywhere the user owns, or the
  setup EXE's `%LocalAppData%\Programs\Maestro`.
- **MSIX.** An MSIX install lives under `WindowsApps`, which Windows keeps
  read-only, so Maestro never writes to it. It hands the verified `.msix` to
  `Add-AppxPackage -Path ... -DeferRegistrationWhenPackagesAreInUse`: Windows
  stages the new version and registers it once Maestro is no longer running, so
  restart Maestro to run it (this needs Windows 10 version 2004 or later).
  Windows accepts the package as an update only when it has the installed
  package's identity (`dev.artur-rios.maestro`) and publisher and a signature
  the machine already trusts. Releases are signed with the `msix` tool's test
  certificate, whose publisher is `CN=Msix Testing, O=Msix Testing Corporation,
  S=Some-State, C=US`; moving to a real certificate changes the publisher, and
  Windows then treats the new package as a different app rather than an update.
  When Windows refuses the package, Maestro says so and how to install it by
  hand: open `maestro-windows-x64.msix` from the release with App Installer.
  A ZIP update offered to a copy running from `WindowsApps` is refused before
  anything is launched.

### Linux packages

`package_linux.sh` builds the Linux bundle twice when updates are configured:
once for the AppImage and once for the Debian package.

- **AppImage.** Maestro replaces the `.AppImage` file it was started from,
  which the AppImage runtime names in `APPIMAGE`. The running executable cannot
  be the target: inside an AppImage it lives in a read-only squashfs mount (or,
  with `APPIMAGE_EXTRACT_AND_RUN`, a temporary extraction the runtime deletes on
  exit). The bundled `replace_linux_appimage.sh` waits for Maestro to exit,
  copies the verified download beside the installed file with that file's
  permissions, makes sure it stays executable, renames it over the installed
  file in one step, and starts the new version. A failure before the rename
  leaves the installed AppImage unchanged. The folder holding the AppImage must
  be writable by the user. A copy that was not started from an AppImage file
  refuses the update rather than guess a target.
- **Debian package.** An install under `/opt/maestro` belongs to the system
  package manager. Maestro hands the verified `.deb` to
  `pkexec dpkg --install`, which asks for the user's password through polkit,
  just as an MSIX update is handed to Windows; the package recommends `pkexec`.
  Restart Maestro to run the new version. When elevation is refused or
  unavailable, Maestro says so and how to install the package by hand:
  `sudo apt install ./maestro-linux-amd64.deb`.
