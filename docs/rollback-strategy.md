# Rollback Strategy

Rollback is represented as a review model in v0.9.0. The desktop app displays rollback availability and warnings, but it does not execute rollback commands.

Fields:

- `rollbackAvailable`: whether a rollback path exists.
- `rollbackPlan`: operator-facing plan summary.
- `rollbackWarning`: risk or limitation.
- `rollbackNote`: command-level note.

Rollback available means the operator has a documented recovery path. It does not mean rollback is automatic, guaranteed, or safe for every machine.

Rollback unavailable must be visible before approval. If rollback is unavailable for a risky command, real execution remains blocked in this milestone.
