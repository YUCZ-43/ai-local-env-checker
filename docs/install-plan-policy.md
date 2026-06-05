# Install-plan policy

Install plans are reviewed before any command can run. The policy engine evaluates plan risk, command risk, confirmation, dry-run-only flags, and administrator requirements.

## Gates

- No confirmation: only dry-run is allowed.
- `confirmationRequired=true` without `--confirm`: execution is refused.
- `requiresAdmin=true` without elevation: real execution is refused.
- `riskLevel=LOW`: may run only with `--confirm` and only if the command is on the safe demo allowlist.
- `riskLevel=MEDIUM`: real execution is refused in v0.5.0.
- `riskLevel=HIGH`: real execution is refused in v0.5.0.
- `riskLevel=DANGEROUS`: execution is always refused.
- `dryRunOnly=true`: execution is refused.

## Safe command allowlist

v0.5.0 only allows harmless demo commands, such as:

- `Write-Output`
- `whoami`
- `$PSVersionTable.PSVersion`
- `git --version`

Installation commands, repair commands, PATH mutation, registry mutation, service mutation, and deletion commands are not allowed.
