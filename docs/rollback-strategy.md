# Rollback Strategy

v0.8.0 does not implement real third-party installer rollback.

## Current Scope

The only confirmed execution allowed in v0.8.0 is LOW-risk allowlisted demo behavior. These commands are read-only or harmless and do not require rollback.

Example:

- `Write-Output`
- `whoami`
- PowerShell version display
- `git --version`

## Blocked Scope

Rollback is not implemented for:

- package manager installs
- npm global installs
- PATH edits
- proxy edits
- registry changes
- downloaded scripts
- admin-required commands

Those actions remain blocked.

## Future Requirements

Before real installation is enabled, rollback design must define:

- per-tool uninstall strategy
- files and directories owned by the installer
- user data that must never be deleted
- audit records for rollback attempts
- failure handling when rollback partially succeeds
- explicit user confirmation before rollback
