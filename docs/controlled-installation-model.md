# Controlled Installation Model

v0.8.0 adds a controlled automatic installation MVP. The default mode remains dry-run.

## Execution Flow

1. Detect environment.
2. Load an install plan.
3. Validate the plan schema.
4. Classify plan and command risk.
5. Show user-facing risk review.
6. Require explicit confirmation for non-dry-run CLI execution.
7. Run dry-run by default.
8. Execute only LOW-risk allowlisted demo commands when `--confirm` is present.
9. Write audit logs and reports.
10. Keep dangerous, admin, and higher-risk commands blocked.

## What v0.8.0 Allows

- `plan show --file <path>`
- `plan validate --file <path>`
- `plan simulate --file <path>`
- `plan run --file <path> --dry-run`
- `plan run --file <path> --confirm` only for LOW-risk allowlisted demo commands
- local audit logs under `logs/`
- local reports under `reports/`

## What v0.8.0 Blocks

- silent installation
- admin-required plans and commands
- automatic UAC elevation
- MEDIUM, HIGH, ADMIN_REQUIRED, and DANGEROUS execution
- PATH modification
- proxy modification
- global environment modification
- registry modification
- downloaded script execution
- credential, token, or SSH key access

The GUI keeps real installation disabled in v0.8.0. It shows confirmation state and controlled execution review, but uses validate, simulate, and dry-run actions.
