# Admin Permission Model

Admin permission is treated as a blocking safety state in v0.9.0. The desktop app may display why a plan or command requires admin privileges, but it must not request elevation, trigger UAC, or start an elevated child process.

The UI model:

- `requiresAdmin`: whether a plan or command needs administrator rights.
- `adminReason`: human-readable reason for the request.
- `permissionReview`: operator-facing review text.
- `approvalState`: `preview-only` or `blocked` in this milestone.

Admin-required plans are shown as blocked for real execution. They may still be visible in dry-run and approval review so technicians can understand what would be needed later.

The app must never hide an admin command preview. A hidden privileged action would make the tool feel like a dangerous installer instead of a professional approval dashboard.
