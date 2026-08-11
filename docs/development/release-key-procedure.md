# Release Signing Key Procedure

Generate the Ed25519 signing key on an offline, access-controlled machine. Do
not run this procedure in CI and do not save its terminal output to a file.

```powershell
dart run tooling/release/generate_keypair.dart
```

The command prints two base64 values. Store the secret value only in GitHub as
the `MAESTRO_RELEASE_SECRET_KEY_BASE64` repository secret. Pass the public
value into each release build:

```powershell
flutter build windows --release --dart-define=MAESTRO_RELEASE_PUBLIC_KEY_BASE64=<public-value>
```

Use the same public value for Linux builds. Rotate keys by releasing a build
that trusts both the old and new public key, then signing future manifests only
with the new secret after existing installations have updated.

Never commit, print in CI logs, or add the secret key to a release artifact.
