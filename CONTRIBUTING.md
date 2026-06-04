# Contributing

Thanks for improving `ai-local-env-checker`.

## Safety Rules

- Keep default behavior check-only.
- Do not add install behavior unless it is gated behind explicit user intent.
- Do not modify system-level PATH.
- Do not write proxy settings into npm, Git, operating system settings, or shell startup files.
- Keep external commands timeout-protected.
- Continue after individual check failures and record the failure in logs/reports.
- Do not commit generated logs or reports.
- Do not commit secrets.

## Development Workflow

1. Run PowerShell syntax checks for Windows scripts.
2. Run check-only Windows detection.
3. Run Bash syntax checks when Bash is available.
4. Run WSL/Linux/macOS scripts only on platforms where they are available.
5. Check `git status --short --ignored` before opening a pull request.

## Documentation

Keep `README.zh-CN.md` and `README.en-US.md` aligned when changing user-facing behavior.

Do not write personal local paths or fixed user-specific proxy ports in documentation.
