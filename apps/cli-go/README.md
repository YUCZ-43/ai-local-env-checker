# ai-local-deploy Go CLI MVP

This is the first Go CLI skeleton for AI Local Environment Checker v0.4.x.

It is intentionally check-first and non-installing. The commands only print placeholders or an example install plan.

## Commands

```powershell
go run . check
go run . doctor
go run . report
go run . plan
```

- `check` prints that existing PowerShell and Bash detection scripts will be called later.
- `doctor` prints the current Go platform and a diagnostic placeholder.
- `report` prints the expected local reports directory.
- `plan` prints example install plan JSON with `confirmationRequired: true` and `autoExecute: false`.

## Safety

This CLI skeleton does not install software, modify PATH, change proxy settings, delete files, or run repair commands.
