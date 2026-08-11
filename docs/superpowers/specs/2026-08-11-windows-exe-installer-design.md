# Windows EXE Installer Design

## Goal

Add a conventional Windows setup executable to Maestro's existing Windows
release outputs and produce a local version `0.1.0` installer from the same
repeatable packaging path.

The installer is unsigned until a trusted publisher certificate is available.
Windows may therefore show a SmartScreen or unknown-publisher warning. The
packaging workflow must not describe the installer as publisher-trusted.

## Scope

This work will:

- produce `maestro-windows-x64-setup.exe` alongside the existing ZIP and MSIX;
- install Maestro per user without administrator rights;
- install under `%LocalAppData%\Programs\Maestro`;
- add a Start Menu shortcut and an Add/Remove Programs uninstall entry;
- support in-place upgrades without deleting Maestro application data;
- add the EXE artifact to Windows CI and tagged GitHub releases;
- smoke-test installation, upgrade, launch layout, and uninstallation; and
- build and verify a local `0.1.0` setup executable.

This work will not add machine-wide installation, elevation, a publisher
certificate, automatic certificate acquisition, or enterprise MSI deployment.

## Packaging Approach

Use Inno Setup 6.7.1 because it directly supports a conventional setup
executable, per-user installation, version-aware upgrades, shortcuts, and
uninstallation with substantially less custom installer code than NSIS or WiX.
Maestro is non-commercial, so automated use does not require a commercial Inno
Setup license under the publisher's current licensing guidance.

Automation will download the official immutable release asset from:

```text
https://github.com/jrsoftware/issrc/releases/download/is-6_7_1/innosetup-6.7.1.exe
```

Before executing it, automation must verify this SHA-256 digest from the
official GitHub release metadata:

```text
4d11e8050b6185e0d49bd9e8cc661a7a59f44959a621d31d11033124c4e8a7b0
```

A locally installed Inno Setup 6.7.1 compiler may be used for developer
packaging, but CI will install and use the verified pinned compiler.

The installer script will be stored under `tooling/packaging/windows/`. It will
consume the already-built Flutter release bundle rather than invoking Flutter
itself. `tooling/packaging/package_windows.ps1` remains the Windows packaging
entry point and orchestrates the release build, ZIP, MSIX, and setup EXE.

## Installation Model

The setup executable will use these stable settings:

- application name: `Maestro`;
- architecture: Windows x64;
- default directory: `{localappdata}\Programs\Maestro`;
- privilege mode: lowest/per-user, with no administrative elevation;
- stable application identifier: `{225850DC-6179-46A0-962C-88F3BBA6D41D}`,
  retained across releases;
- executable: `maestro.exe`;
- Start Menu shortcut: `Maestro`;
- desktop shortcut: not created by default;
- uninstall entry: visible in the current user's installed-app list; and
- upgrade behavior: close or prompt to close a running Maestro instance before
  replacing application files.

The installer copies the complete Flutter Windows release directory, including
DLLs, assets, plugins, and `replace_windows_zip.ps1`. It must not install files
outside its application directory except for the normal per-user shortcuts and
uninstall metadata managed by Inno Setup.

Maestro application data remains in the existing application-data location and
is not part of the installer payload. Upgrade and uninstall operations therefore
leave projects, workflows, run history, audit evidence, settings, and protected
credential material untouched. The uninstaller removes only files and metadata
owned by the installer.

## Update Compatibility

An EXE installation retains the same on-disk application layout as the portable
Windows ZIP. Maestro will therefore continue to select and apply the verified
`zip` update artifact for this installation type. The existing ZIP replacement
helper performs staged replacement and rollback inside the install directory.

The initial setup executable is a distribution mechanism, not a new runtime
update package type. Release manifests will continue to expose Windows `zip`
and `msix` update artifacts. The setup EXE is published as an additional release
asset but is excluded from update-manifest artifact selection unless a future
design explicitly adds an `exe` update type.

Because `%LocalAppData%\Programs\Maestro` is user-writable, ZIP-based replacement
does not require elevation. The packaged replacement helper must remain inside
the installed application directory so the current update composition can find
and invoke it.

## Build and Release Flow

The Windows packaging flow is:

1. Validate a semantic `major.minor.patch` version.
2. Build the Flutter Windows x64 release bundle when `-SkipBuild` is absent.
3. Copy the ZIP update helper into the bundle.
4. Generate the existing ZIP and MSIX packages.
5. Resolve the Inno Setup 6.7.1 compiler.
6. Compile the installer script with the version, source bundle, output path,
   application icon, and deterministic output filename supplied as parameters.
7. Verify that all three Windows artifacts exist and are non-empty.

The CI Windows packaging job uploads the setup executable with the ZIP and MSIX.
The tagged release workflow likewise publishes it, while the release-manifest
generator continues to include only supported runtime update types.

The local command remains:

```powershell
tooling/packaging/package_windows.ps1 -Version 0.1.0
```

On success it creates:

```text
dist/maestro-windows-x64.zip
dist/maestro-windows-x64.msix
dist/maestro-windows-x64-setup.exe
```

## Error Handling

Packaging fails closed when:

- the Flutter release bundle or `maestro.exe` is missing;
- the Inno Setup 6.7.1 compiler cannot be resolved;
- a downloaded compiler does not match the pinned SHA-256 digest;
- installer compilation exits unsuccessfully;
- the setup executable is missing or empty after compilation; or
- the generated installer metadata does not identify the requested version.

The packaging script must return a nonzero exit code and must not report the EXE
as created after any of these failures. Existing valid artifacts may remain for
diagnosis, but release publication cannot proceed from a partially successful
Windows packaging job.

Installation failures are handled by Inno Setup's transactional file-copy
behavior. A failed upgrade must preserve the prior usable installation where
the installer platform permits rollback. The smoke test must demonstrate that
application data outside the install directory remains unchanged.

## Verification Strategy

### Static and script tests

Repository tests will verify that:

- the packaging entry point invokes the Inno Setup compiler;
- the installer uses per-user privilege mode and the required install path;
- the stable application identifier is present;
- the complete release bundle and ZIP update helper are included;
- the output filename is exact;
- application data is not declared for deletion; and
- CI and release workflows upload the setup executable.

### Windows installer smoke test

A Windows-only smoke test will:

1. install the setup executable silently into an isolated per-user location;
2. verify `maestro.exe`, runtime DLLs, assets, plugins, and the update helper;
3. verify the Start Menu/uninstall metadata where the test environment exposes
   it;
4. install a `0.1.1` test build over a `0.1.0` test build as an in-place
   upgrade;
5. verify a sentinel in a separate application-data directory is unchanged;
6. uninstall silently; and
7. verify installer-owned files are removed while the data sentinel remains.

The test uses only paths created for that test and validates their resolved
locations before cleanup.

### Completion gate

Completion requires:

- architecture and workflow verifiers;
- `flutter analyze`;
- the complete default Flutter test suite;
- Windows platform integration tests;
- a successful Windows release build;
- successful ZIP, MSIX, and setup EXE packaging;
- a passing installer smoke test; and
- inspection of the local `0.1.0` setup executable's size, SHA-256 digest,
  version metadata, and unsigned signature state.

## Documentation

The release documentation will list the setup executable, describe per-user
installation and uninstallation, and state that the artifact is unsigned.
Developer instructions will explain the pinned compiler requirement and the
local packaging command. The README installation section will link to the
release asset without implying publisher trust.
