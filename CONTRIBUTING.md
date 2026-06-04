# Contributing

Thanks for improving `ai-local-env-checker`.

## Where contributors can help

- Windows detection
- WSL detection
- Linux detection
- macOS detection
- Proxy detection
- i18n
- Packaging
- Go CLI
- Tauri GUI
- Documentation

## Contribution rules

- Do not commit logs or reports.
- Do not commit secrets.
- Keep the check-only default safe.
- Keep Windows PowerShell 5.1 compatibility.
- Keep Bash scripts portable where possible.
- Do not hard-code personal paths.
- Do not hard-code one fixed proxy port.
- Do not add installation behavior unless it is gated behind explicit user intent.
- Do not modify system-level PATH by default.
- Do not write proxy settings into npm, Git, operating-system settings, or shell startup files.
- Keep external commands timeout-protected.
- Continue after individual check failures and record the failure in logs/reports.

## Development workflow

1. Run PowerShell syntax checks for Windows scripts.
2. Run check-only Windows detection.
3. Run Windows verification.
4. Run Bash syntax checks when Bash is available.
5. Run release package build checks when packaging files change.
6. Check `git status --short` and `git status --ignored --short` before opening a pull request.

## Documentation

Keep `README.md`, `README.zh-CN.md`, and `README.en-US.md` aligned when changing user-facing behavior.

Use clear language for both Chinese and English users. Avoid marketing exaggeration. Explain what the tool checks, what it does not change, and how users should handle generated reports.
