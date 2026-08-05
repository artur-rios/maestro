# Application Data and Recovery

Maestro asks `path_provider` for the current user's application-support directory. All Maestro-owned data is below that resolved root:

| Path | Purpose |
| --- | --- |
| `data/maestro.db` | SQLite settings, ownership records, and diagnostic segment metadata |
| `logs/` | Bounded and compactable diagnostic output |
| `updates/` | Verified staged update artifacts |
| `worktrees/` | Maestro-created isolated Git worktrees |

Secrets do not enter SQLite or logs. They cross the protected-storage adapter as base64 text and are stored through Windows Credential Manager or the Linux Secret Service implementation supplied by `flutter_secure_storage`.

Project source directories are references, never Maestro-owned storage. Removing a project record, reconciliation, retention cleanup, uninstall, and update operations must not delete or modify a registered source directory. Cleanup requires both a path below `updates/` or `worktrees/` and a matching durable ownership record; filesystem roots, source ancestors, source descendants, links that escape an owned root, and unknown records fail closed.

On startup Maestro creates required directories, checks protected storage, opens SQLite off the UI isolate, runs `PRAGMA integrity_check`, probes Git/GitHub and supported agent CLIs, then reconciles stale owned resources. Blocking failures appear in Foundation diagnostics. Optional missing CLIs are degraded checks with remediation.

To recover, preserve the complete application-support root before changing files. Inspect diagnostics, verify disk permissions and free space, then restart. Do not move or delete registered source folders as a recovery action. A failed owned-resource cleanup remains recorded for review.
