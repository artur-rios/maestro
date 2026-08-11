# Release Signing and Rollback Design

## Goal

Provide an offline Ed25519 key-generation procedure and bundled platform helpers
that replace a verified update only after the running app exits, retain a
rollback copy, and relaunch Maestro after a successful replacement.

## Key Management

`tooling/release/generate_keypair.dart` uses Sodium to generate an Ed25519
keypair. It writes no keys by default. The operator copies the base64 secret
into GitHub Actions as `MAESTRO_RELEASE_SECRET_KEY_BASE64` and compiles the
matching public key into the application through
`MAESTRO_RELEASE_PUBLIC_KEY_BASE64`. The public key is safe to distribute;
the secret is never logged, committed, or passed to the application.

## Replacement Helpers

The Windows ZIP helper and Linux AppImage helper receive explicit paths and a
parent PID. They reject unsafe/missing package paths, wait for the parent to
exit, move the existing installation to a sibling rollback location, install
the staged artifact, restore the rollback on any replacement error, and then
relaunch the installed executable only after a successful swap. Application
data is outside the installation root and is never enumerated or changed.

## Verification

Tests cover emitted key material shape without exposing private material and
assert helper command contracts retain the parent-PID, rollback, and relaunch
arguments. Platform smoke tests remain the authority for replacement behavior.
