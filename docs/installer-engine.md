# Installer Engine

The installer engine is a future execution layer. It must not run commands directly from UI input.

## Required sequence

1. Detection creates a machine-state report.
2. Planner creates an install plan.
3. Policy validates the plan.
4. User reviews the exact commands and risk level.
5. User confirms.
6. Runner executes approved commands with logging and timeouts.
7. Verifier checks the result.
8. Reporter saves the final report.

## Non-goals for v0.4.x

- No software installation.
- No PATH modification.
- No system repair.
- No background auto-fix.

## Execution requirements

- Default behavior remains check-only.
- `confirmationRequired` must be true for install or repair plans.
- `autoExecute` must remain false by default.
- DANGEROUS plans should be blocked unless a future policy explicitly allows them.
