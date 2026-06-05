# Windows install-plan runner

v0.5.0 adds the CLI/core foundation for a controlled Windows install-plan pipeline:

```text
detect
-> generate install plan
-> validate schema
-> review risk/admin requirements
-> require explicit confirmation
-> run through a logged runner
-> run verification commands
-> generate report output
```

This version does not implement the desktop GUI and does not perform real package installation. The Go CLI exposes the engine that the future Tauri GUI will call.

## CLI commands

```powershell
ai-local-deploy plan show --file examples/install-plans/windows-safe-demo-plan.json
ai-local-deploy plan validate --file examples/install-plans/windows-safe-demo-plan.json
ai-local-deploy plan run --file examples/install-plans/windows-safe-demo-plan.json --dry-run
ai-local-deploy plan run --file examples/install-plans/windows-safe-demo-plan.json --confirm
ai-local-deploy plan simulate --file examples/install-plans/windows-safe-demo-plan.json
ai-local-deploy doctor
ai-local-deploy report
```

`plan simulate` runs the full load, validate, policy review, dry-run runner, fake verification, and report generation flow without executing commands.

## Future elevation model

The future Windows administrator flow is:

```text
GUI / CLI
-> generate install plan
-> user reviews
-> user confirms
-> UAC prompt
-> elevated PowerShell runner
-> logs
-> verification
-> report
```

The future PowerShell concept is:

```powershell
Start-Process powershell.exe -Verb RunAs
```

v0.5.0 documents this concept only. It does not auto-elevate, does not require administrator elevation for validation, and does not launch elevated PowerShell during tests.
