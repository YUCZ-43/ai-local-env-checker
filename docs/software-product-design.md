# Software Product Design

AI Local Environment Checker is moving from a script/package checker toward an installable desktop and CLI product.

## Product shape

- Windows GUI installer / setup.exe in a future release
- Cross-platform Go CLI
- Tauri desktop GUI
- PowerShell and Bash detection and execution layer
- Install plan before execution
- User confirmation before repair or install
- Local logs and reports

## MVP boundaries

v0.4.x introduces product architecture, schemas, examples, a Go CLI skeleton, and desktop placeholders. It does not install software or modify system settings.

## Core flow

1. Detect the local environment.
2. Generate a report.
3. Generate an install or repair plan when problems are found.
4. Show risk level, commands, admin requirements, rollback availability, and verification steps.
5. Require explicit user confirmation.
6. Execute only through a policy-checked runner in a future release.
7. Verify results and export logs/reports.

## Runtime layers

- `apps/cli-go`: future cross-platform CLI entrypoint.
- `apps/desktop-tauri`: future desktop GUI.
- `core/schema`: JSON schemas for plans and reports.
- `core/detector`: read-only detection contracts.
- `core/install-plan`: plan generation.
- `core/runner`: future controlled execution.
- `core/report`: report generation and export.
- `core/proxy`: proxy detection and recommendation.
- `core/policy`: permission, confirmation, and risk controls.
