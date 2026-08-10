# Windows Flutter Native-Temp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** Make Windows Flutter tests reliable from long `D:` worktree paths without global environment changes.

**Architecture:** A PowerShell wrapper owns a short same-drive temporary directory and invokes `flutter test` with child-only `TEMP`/`TMP`; documentation routes Windows local gates through it.

**Tech Stack:** PowerShell 7 and Flutter.

## Global Constraints

- Preserve the caller environment after the child process exits.
- Propagate arbitrary Flutter test arguments and the exact child exit code.
- Do not change Linux or CI command behavior.

### Task 1: Add and verify the Windows wrapper

**Files:**
- Create: `tooling/test_windows.ps1`
- Modify: `docs/development/building-and-testing.md`

- [ ] **Step 1: Write a failing wrapper verification command.** Invoke `tooling/test_windows.ps1 test/features/delivery/application/supervised_delivery_test.dart`; it initially fails because the script is absent.
- [ ] **Step 2: Implement the wrapper.** Resolve the repository drive, build the short path `<drive>:\mt`, create it, save `TEMP`/`TMP`, set both for `& flutter test @args`, restore both in `finally`, and `exit $LASTEXITCODE`.
- [ ] **Step 3: Update documentation.** Replace Windows local Flutter test commands with `pwsh -File tooling/test_windows.ps1` and explain the native-asset path workaround.
- [ ] **Step 4: Verify.** Run the supervised-delivery test through the wrapper and a failing test selector, asserting success and non-zero propagation respectively.
- [ ] **Step 5: Commit.** Use `fix: stabilize windows flutter tests`.

## Plan Self-Review

- Scope is confined to the confirmed Windows native-asset failure.
- The wrapper is testable through real child-process exit behavior and preserves environment state.
