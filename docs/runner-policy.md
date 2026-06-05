# Runner Policy

The v0.8.0 Go CLI runner is policy-gated before any command execution.

## Risk Levels

| Risk level | v0.8.0 behavior |
|------------|------------------|
| LOW | May execute only when explicitly confirmed and allowlisted |
| MEDIUM | Blocked |
| HIGH | Blocked |
| ADMIN_REQUIRED | Blocked |
| DANGEROUS | Always blocked |

## Allowlisted Commands

The allowlist is intentionally small and exists for harmless demo and validation behavior:

- `Write-Output`
- `whoami`
- `$PSVersionTable.PSVersion`
- `git --version`

These commands do not install software, modify PATH, change proxy settings, elevate permissions, or delete user files.

## Blocked Command Patterns

The runner refuses commands outside the allowlist, including:

- `winget install`
- `npm install -g`
- `rustup install`
- Docker installers
- downloaded PowerShell scripts
- `irm | iex`
- `Invoke-WebRequest` piped to execution
- registry writes
- PATH or environment mutation
- proxy mutation
- deletion commands
- UAC elevation attempts
- credential, token, or SSH key access

The policy is intentionally conservative. New commands must be added with tests and documentation.
