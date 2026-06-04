# AI Local Environment Checker

AI Local Environment Checker is a safe, check-first environment diagnostic toolkit for local AI development. It helps users verify whether a computer is ready for tools such as Node.js, npm, Git, VS Code, Claude Code, Codex CLI, WSL, proxy networking, PATH, and related development dependencies.

- 中文文档: [README.zh-CN.md](README.zh-CN.md)
- English Documentation: [README.en-US.md](README.en-US.md)

## 1. What this project does

This project runs local readiness checks before users install or troubleshoot local AI development tools. It reports what is installed, what is missing, which settings may need review, and where follow-up action may be needed.

Current checks cover common setup blockers such as command-line tools, package managers, terminal permissions, proxy configuration, PATH, WSL, and network connectivity.

## 2. Why this project exists

Local AI tooling often depends on several system components that are hard for non-specialists to diagnose. A setup failure may come from Node.js, npm, Git, VS Code CLI, Claude Code, Codex CLI, WSL, a local proxy, package-manager configuration, PATH, or terminal permissions.

This repository provides a safer diagnostic step before installation or repair.

## 3. Who this project helps

- Users preparing a personal computer for local AI development
- Technicians diagnosing customer machines
- Deployment service providers checking readiness before installation
- Teams standardizing workstation setup
- Maintainers who need local reports before troubleshooting

## 4. Supported platforms

| Platform | Current status |
|----------|----------------|
| Windows 10/11 | beta usable |
| WSL | detection preview |
| Linux | detection preview |
| macOS | detection preview |

## 5. Safe-by-default policy

- Default mode is check-only.
- Software is not installed unless an explicit install mode is enabled.
- System-level PATH is not modified unless an explicit path-fix mode is enabled.
- User files are not deleted.
- Private data is not collected intentionally.
- Logs and reports are not uploaded.
- Generated logs, reports, and release packages are ignored by Git.

## 6. Quick start

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly -SkipNetwork -CommandTimeoutSec 10 -Language en-US
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

## 7. Package downloads and release plan

The v0.3.0 release line prepares downloadable packages for Windows, WSL, Linux, macOS, and source code. Release archives are generated locally under `dist/` for testing and are not committed.

See [docs/release-packaging.md](docs/release-packaging.md).

## 8. Current status

Windows detection is usable as a beta. WSL, Linux, and macOS checkers are detection previews. Release packaging and public documentation are being prepared for future GitHub Releases.

## 9. Future software architecture

The current detection layer uses PowerShell on Windows and Bash on WSL/Linux/macOS. Future versions may add a Go CLI, Rust components, Python tooling, a Tauri desktop GUI, a web dashboard, and optional backend features for licensing or report upload.

Offline local checks must remain available without a backend. Any report upload must require explicit user consent.

See [docs/architecture.md](docs/architecture.md).

## 10. Roadmap

See [ROADMAP.md](ROADMAP.md).

## 11. Security and privacy

See [SECURITY.md](SECURITY.md). Review generated reports before sharing them because local paths, usernames, proxy details, and system information may appear in diagnostic output.

Do not commit API keys, tokens, cookies, passwords, account credentials, private keys, generated logs, generated reports, or generated package archives.

## 12. License

See [LICENSE](LICENSE).
