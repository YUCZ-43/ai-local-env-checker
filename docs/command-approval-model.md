# Command Approval Model

Command approval is the per-command review layer. Each command should show:

- Command ID and description.
- Shell and command preview.
- Risk level.
- Whether admin is required.
- Whether approval is required.
- Approval state.
- Blocked reason.
- Rollback note.

Risk handling in v0.9.0:

- LOW: eligible for dry-run approval review.
- MEDIUM: blocked for real execution.
- HIGH: blocked for real execution and shown with high-risk styling.
- ADMIN_REQUIRED: blocked and routed to admin permission review.
- DANGEROUS: blocked and shown as dangerous.

The UI must not hide dangerous command previews. The operator needs to see what was blocked and why.
