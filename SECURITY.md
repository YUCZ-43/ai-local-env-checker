# Security Policy

## Default Behavior

`ai-local-env-checker` is check-only by default. It does not install software unless the user explicitly passes `-Install`.

PATH repair is also explicit. It can run only when the user passes `-FixPath`, and it is limited to user-level PATH handling.

## Privacy

The tool does not collect user privacy data, does not upload logs, and does not send reports to any service.

Logs and reports are generated locally under `logs/` and `reports/`.

## Do Not Commit Sensitive Data

Do not commit:

- API keys, tokens, cookies, passwords, or account credentials.
- SSH private keys, certificates, or secret config files.
- `.env` files or local credential files.
- Generated `logs/` and `reports/` artifacts.

The repository should track only `logs/.gitkeep` and `reports/.gitkeep` for those directories.

## Report Sanitization

Reports may include local paths, usernames, computer names, installed tool paths, proxy configuration, PATH summaries, command output, and environment details.

Proxy URLs containing usernames or passwords are masked before being written, but you should still review reports manually before sharing them publicly.

## Proxy Safety

Proxy detection is read-only:

- It does not modify proxy settings.
- It does not clear proxy settings.
- It does not write proxy values into npm or Git.
- It only reports detected values and a recommended proxy candidate.

## Reporting Security Issues

Please report security issues privately to the repository owner. Do not publish secrets, raw logs, or raw reports in public issues.
