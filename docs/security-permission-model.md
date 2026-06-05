# Security and Permission Model

AI Local Environment Checker must preserve user control.

## Principles

- Check first.
- Plan first.
- Confirm before install or repair.
- Log actions locally.
- Avoid collecting secrets.
- Do not upload reports without explicit user consent.

## Permission levels

- Read-only detection: default.
- User-level repair: future explicit confirmation required.
- Admin-level repair: future explicit confirmation and elevation required.
- Dangerous actions: blocked by default.

## Sensitive data

Reports may contain usernames, local paths, proxy settings, hostnames, command output, and tool versions. Export and upload flows must support review and redaction before sharing.
