# Audit and Report Viewer

v0.9.0 improves the audit/report viewer structure in the desktop UI. Generated logs and reports remain local artifacts and must not be committed unless sanitized as examples.

Log and report entries should include:

- Timestamp.
- Plan ID.
- Command ID where applicable.
- Mode: dry-run, simulate, controlled-run preview, blocked.
- Risk level.
- Approval state.
- Admin requirement.
- Rollback state.
- Result or blocked reason.
- Local report path.

The app must never log:

- API keys, tokens, passwords, cookies, or private keys.
- Raw proxy credentials.
- Private file contents.
- Unredacted secrets from environment variables.
- Generated installers or binary contents.

Reports may still contain local paths, usernames, hostnames, command output, and proxy metadata. Users must review reports before sharing them.
