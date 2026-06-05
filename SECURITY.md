# Security Policy

## Local-first design

AI Local Environment Checker is local-first. Checks run on the user's machine, and generated logs and reports are written locally under `logs/` and `reports/`.

The default mode is check-only. The project must not install software, modify PATH, change proxy settings, delete user files, or upload reports unless a future feature explicitly asks for and receives user consent.

## Default behavior

- Default mode is check-only.
- Dry-run is the default for install plans.
- Non-dry-run CLI execution requires explicit `--confirm`.
- v0.8.0 confirmed execution is limited to LOW-risk allowlisted demo commands.
- MEDIUM, HIGH, ADMIN_REQUIRED, DANGEROUS, and admin-required execution is blocked.
- PATH repair requires an explicit path-fix mode.
- System-level PATH must not be modified by default.
- Proxy detection is read-only.
- Logs and reports are local.
- v0.9.0 desktop real installation is disabled by default.
- v0.9.0 desktop admin permission review must not auto-trigger UAC.
- Theme and language settings must not change installer policy or approval state.

## Logs and reports

Generated reports may include usernames, local paths, computer names, tool paths, proxy information, PATH summaries, command output, and system details.

Do not publish logs or reports without reviewing and sanitizing them first. Users should review generated reports before sharing them with maintainers, service providers, or public issue trackers.

## Proxy safety

Proxy URLs are masked where possible before being written to logs or reports. Credentials in proxy URLs should not appear in clear text, but users should still review reports manually before sharing.

Proxy detection does not:

- Modify operating-system proxy settings.
- Clear proxy settings.
- Write npm or Git proxy values.
- Assume one fixed local proxy port.

## Secrets

Tokens, API keys, cookies, passwords, account credentials, private keys, certificates, and secret configuration files must never be committed.

Do not commit:

- `.env` files or local credential files.
- API keys, tokens, cookies, passwords, or account credentials.
- SSH private keys, certificates, or private key material.
- Generated `logs/` and `reports/` artifacts.
- Generated release archives under `dist/`.

The repository should track only `logs/.gitkeep`, `reports/.gitkeep`, and `dist/.gitkeep` for those generated-output directories.

## Future backend features

Future backend, membership, license, device authorization, or report-upload features must be optional. They must require explicit user consent and must not be required for offline local checks.

## Reporting security issues

Please report security issues privately to the repository owner. Do not publish secrets, raw logs, or raw reports in public issues.
