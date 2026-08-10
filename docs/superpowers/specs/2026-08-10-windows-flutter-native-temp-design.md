# Windows Flutter Native-Asset Test Wrapper — Design

## Scope

Provide a repository-local Windows command for Flutter tests whose native Sodium asset build uses a short temporary directory on the same drive as the checkout. This avoids the Windows cross-volume rename error and Sodium's 218-character extraction limit without changing global environment variables.

## Design

`tooling/test_windows.ps1` accepts remaining Flutter-test arguments, creates a fixed short `D:\mt` directory when the repository is on `D:`, saves the caller's `TEMP` and `TMP`, sets both only for the child `flutter test` process, then restores the caller environment in `finally`. The script forwards the child exit code unchanged.

The development guide uses this wrapper for Windows test commands and explains that it is required when native assets are built from a long worktree path. The wrapper remains Windows-only; Linux and CI continue to call Flutter directly.

## Verification

Run the existing supervised delivery test through the wrapper, verify all four tests pass, and verify a deliberately invalid Flutter test argument returns a non-zero exit code through the wrapper.
