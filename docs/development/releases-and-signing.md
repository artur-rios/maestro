# Releases and Signing

Release tags use `v<major>.<minor>.<patch>`. Matching GitHub runners build two Windows packages and two Linux packages:

- `maestro-windows-x64.zip`
- `maestro-windows-x64.msix`
- `maestro-linux-x64.AppImage`
- `maestro-linux-amd64.deb`

## Local packaging

On Windows:

```powershell
$env:FLUTTER_ROOT = 'C:\path\to\flutter'
tooling/packaging/package_windows.ps1 -Version 0.1.0
```

On Ubuntu, download the official `appimagetool-x86_64.AppImage`, verify the SHA-256 pinned in `.github/workflows/ci.yml`, and run:

```bash
export APPIMAGETOOL_PATH=/verified/path/appimagetool
bash tooling/packaging/package_linux.sh 0.1.0
```

Create and verify release metadata after all four artifacts are together:

```bash
dart run tooling/release/create_manifest.dart dist 0.1.0 \
  https://github.com/artur-rios/maestro/releases/download/v0.1.0/
dart run tooling/release/verify_release.dart dist
```

## Manifest signing

Update manifests use detached Ed25519 signatures. Configure these GitHub secrets as base64-encoded libsodium keys:

- `MAESTRO_RELEASE_SECRET_KEY_BASE64`: 64-byte secret key; release job only.
- `MAESTRO_RELEASE_PUBLIC_KEY_BASE64`: 32-byte verification key.

With the secret configured, run `dart run tooling/release/sign_manifest.dart dist`. Invalid or incomplete signing material fails the release closed. GitHub artifact attestations are produced independently with OIDC provenance.

There is currently no trusted Windows publisher certificate. Local MSIX files are test-signed and must not be described as publisher-trusted. Unsigned manifest verification prints `publisher-signing: unconfigured`; it never implies trust.

Maestro downloads only the artifact matching its platform, architecture, and installed package type. It enforces the signed size and SHA-256, stages under the application data root, and requires approval tied to that exact digest before invoking an installer.
