# Audit Log Model

v0.8.0 writes local audit records for controlled runner attempts.

## Location

Audit logs are written under ignored local output directories:

- `logs/audit-YYYYMMDD-HHMMSS.jsonl`

Generated audit logs must not be committed.

## Record Fields

Each JSONL record includes:

- `timestamp`
- `platform`
- `toolId`
- `planFile`
- `commandPreview`
- `mode`
- `riskLevel`
- `allowed`
- `reason`
- `exitCode`
- `stdoutSummary`
- `stderrSummary`
- `reportPath`

Output summaries are trimmed and intended for local diagnosis. Users should still review logs before sharing them because local paths, usernames, and command output may appear.

## Safety

Audit logging does not upload data. It does not write secrets intentionally. It does not modify system settings.
