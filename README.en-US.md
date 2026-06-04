# AI Local Environment Checker

## Project Positioning

`ai-local-env-checker` is a check-first local environment checker for AI development. It is designed for customer machine diagnostics, preflight checks before local AI deployment, workstation readiness validation, and support handoff reports.

Core rules:

- Check-only by default.
- Installation logic can run only when the user explicitly passes `-Install`.
- PATH repair can run only when the user explicitly passes `-FixPath`.
- Logs and reports stay inside this project under `logs/` and `reports/`.
- Proxy settings are detected, reported, and recommended only. They are never modified automatically.

## Current Version

Suggested version: `v0.2.0-cross-platform-i18n-proxy-detect`

## Supported Systems

| Platform | Status |
|----------|--------|
| Windows PowerShell 5.1+ | Supported, root `install.ps1` / `verify.ps1` preserved |
| WSL | Detection-only checker added |
| Linux | Detection-only checker added |
| macOS | Detection-only checker added |

## Quick Start

Windows check-only:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly -SkipNetwork -CommandTimeoutSec 10 -Language en-US
```

Windows quick verify:

```powershell
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Language en-US
```

WSL:

```bash
bash scripts/wsl/check-wsl.sh --check-only --language en-US --timeout 10 --skip-network
```

Linux:

```bash
bash scripts/linux/check-linux.sh --check-only --language en-US --timeout 10
```

macOS:

```bash
bash scripts/macos/check-macos.sh --check-only --language en-US --timeout 10
```

## Windows Usage

Root scripts remain available:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly -Language zh-CN
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly -Language en-US
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Language en-US
```

Common options:

| Option | Description |
|--------|-------------|
| `-CheckOnly` | Check only, no installation, default mode |
| `-Install` | Explicit install mode |
| `-FixPath` | Explicit user PATH repair |
| `-SkipNetwork` | Skip network reachability checks |
| `-CommandTimeoutSec 10` | Set per-command timeout |
| `-Language zh-CN` / `-Language en-US` | Select output language |

## WSL Usage

```bash
bash scripts/wsl/check-wsl.sh --check-only --language en-US --timeout 10 --skip-network
bash scripts/wsl/verify-wsl.sh --language zh-CN --timeout 10
```

The WSL checker detects WSL status, distro, kernel, shells, Node.js, npm, Git, curl, VS Code CLI, Claude Code, Codex CLI, Docker, PATH, proxy settings, `/mnt/c` access, and Windows/WSL path mixing signals.

## Linux Usage

```bash
bash scripts/linux/check-linux.sh --check-only --language en-US --timeout 10
bash scripts/linux/verify-linux.sh --language zh-CN --timeout 10 --skip-network
```

The Linux checker detects distro, package managers, shells, base tools, AI development tools, Docker, permissions, PATH, proxy settings, and TCP 443 network reachability.

## macOS Usage

```bash
bash scripts/macos/check-macos.sh --check-only --language en-US --timeout 10
bash scripts/macos/verify-macos.sh --language zh-CN --timeout 10 --skip-network
```

The macOS checker detects macOS version, CPU architecture, Rosetta 2, Xcode Command Line Tools, Homebrew, Node.js, npm, Git, VS Code CLI, Claude Code, Codex CLI, Docker, shells, PATH, proxy settings, and TCP 443 network reachability.

## Automatic Proxy Detection

Windows checks:

- Process, user, and machine proxy environment variables.
- npm and Git proxy configuration.
- WinHTTP proxy.
- Windows user internet settings.
- Common loopback proxy ports only.
- HTTP proxy and SOCKS5 proxy protocol checks when `curl.exe` is available and network checks are not skipped.

WSL / Linux / macOS check:

- Proxy environment variables.
- npm and Git proxy configuration.
- Common loopback ports.
- GNOME proxy settings on Linux when `gsettings` exists.
- macOS `networksetup` proxy settings across all network services.

Proxy URLs are masked before they are written to logs or reports. Credentials are shown as `http://***:***@host:port`.

## Security

- Check-only by default.
- No privacy collection.
- No log or report uploads.
- No automatic proxy modification.
- No npm / Git proxy writes.
- No system PATH changes.
- Do not commit API keys, tokens, cookies, passwords, or private keys.

See [SECURITY.md](SECURITY.md).

## Logs and Reports

Generated files are written to:

| Type | Path |
|------|------|
| Logs | `logs/` |
| JSON reports | `reports/` |
| Markdown reports | `reports/` |

Generated logs and reports are ignored by Git. Only `.gitkeep` files should remain tracked.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md).

Proxy detection details: [docs/proxy-detection.md](docs/proxy-detection.md).

## Roadmap

See [ROADMAP.md](ROADMAP.md).
