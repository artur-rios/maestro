## Linked issue

Closes #1

## Requirement traceability

- Evidence: `docs/development/issue-1-verification.md`
- Requirements covered: IR-01 through IR-15

## Verification

- [ ] Formatting, architecture, analysis, and unit/widget tests pass
- [ ] Windows integration test and release build pass
- [ ] Ubuntu integration test and release build pass
- [ ] Windows ZIP/MSIX artifacts verify
- [ ] Linux AppImage/DEB artifacts verify

## Security and data safety

- [ ] Secrets are redacted and protected by OS credential storage
- [ ] Source project directories are never cleanup targets
- [ ] Update approval is tied to the verified artifact digest
- [ ] Publisher-signing status is recorded accurately

## Review notes

Maestro stops at this pull request for stakeholder review and does not merge it.
