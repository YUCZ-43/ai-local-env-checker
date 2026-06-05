# Runner safety

The v0.5.0 runner is designed to prove the execution pipeline without turning the project into an automatic installer.

## Hard defaults

- Dry-run and check-first behavior remain the default.
- `plan run` requires either `--dry-run` or `--confirm`.
- `--dry-run` prints command details and never executes commands.
- `--confirm` still passes through policy gates and the safe command allowlist.
- MEDIUM, HIGH, and DANGEROUS execution is refused.
- Administrator elevation is never auto-launched.

## What the runner must not do

- Run `winget install`.
- Run `npm install -g`.
- Run Claude Code, Codex CLI, rustup, or installer bootstrap scripts.
- Modify system PATH.
- Delete user files.
- Create or modify system-wide environment variables.
- Change global PowerShell execution policy.
- Run system repair commands.

Generated logs and reports stay local under ignored directories.
