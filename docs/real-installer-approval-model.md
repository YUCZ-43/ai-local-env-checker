# Real Installer Approval Model

v0.9.0 adds the real installer approval model as UI and schema structure only. It does not enable real installer execution.

Required state:

- `realRunDisabled`: true by default.
- `dryRunDefault`: true by default.
- `approvalRequired`: true for install-plan approval surfaces.
- `userConfirmed`: false unless the user explicitly checks a review control.
- `blockedReason`: visible reason when real run is unavailable.

Real installation must require explicit operator approval in a future version. Approval must be command-specific, risk-aware, auditable, and separate from theme or language preferences.

The desktop UI must not:

- Run installer commands silently.
- Convert dry-run into real-run automatically.
- Auto-trigger UAC.
- Modify PATH, proxy settings, or global environment variables.
- Treat a visual checkbox as sufficient for dangerous commands.
