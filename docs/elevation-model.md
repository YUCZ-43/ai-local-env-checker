# Windows elevation model

The install-plan runner separates plan review from elevated execution. Validation, simulation, and dry-run review must work from a normal user shell.

## v0.5.0 behavior

- No automatic elevation.
- No UAC prompt is launched by the runner.
- Plans that require administrator rights are refused for real execution when the current process is not elevated.
- The CLI prints an elevation suggestion instead of starting a privileged process.

## Future behavior

The future GUI or CLI may ask the user to approve an elevated run after plan validation and risk review:

```text
GUI / CLI
-> validated install plan
-> explicit user confirmation
-> UAC prompt
-> elevated PowerShell runner
-> logged command execution
-> verification commands
-> final report
```

The future implementation may use this Windows mechanism:

```powershell
Start-Process powershell.exe -Verb RunAs
```

That command is not used by v0.5.0 validation scripts.
