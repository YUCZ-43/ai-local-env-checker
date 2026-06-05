# AI Local Environment Checker

## 1. Project purpose

AI Local Environment Checker is a safe, check-first diagnostic toolkit for local AI development environments. It helps users check whether a computer is ready before installing or using tools such as Node.js, npm, Git, VS Code, Claude Code, Codex CLI, WSL, proxy networking, and related development dependencies.

The project is not intended to blindly install software or change system settings. Its first job is to diagnose, report, and recommend.

## v0.4.0 software product MVP direction

The project is moving from the v0.3.x script/package-focused line toward the v0.4.x software product MVP architecture.

v0.4.x introduces:

- Future Go CLI in `apps/cli-go`
- Future Tauri desktop GUI in `apps/desktop-tauri`
- Install plan schemas and examples
- Detector, install-plan, runner, report, proxy, and policy boundaries
- A check-first, plan-first, confirm-before-install design

Current PowerShell and Bash scripts remain the platform execution layer and stay safe by default. The future desktop GUI will be based on Tauri. The future CLI will be based on Go.

## 2. Why it exists

Many users get blocked while setting up local AI development tools because the required system pieces are spread across terminals, package managers, PATH, proxy settings, permissions, and operating-system features. A user may not know whether the failure comes from Node.js, npm, Git, VS Code CLI, WSL, a proxy, a missing package manager, or a terminal permission issue.

This repository provides a safer preflight step. It helps users and support providers understand the current machine state before making changes.

## 3. Who it helps

- Users preparing a personal computer for local AI development
- Technicians diagnosing customer machines
- Deployment service providers checking readiness before installation
- Teams standardizing workstation setup
- Maintainers who need local reports before troubleshooting

## 4. Supported platforms

| Platform | Current stability |
|----------|-------------------|
| Windows 10/11 | beta usable |
| WSL | detection preview |
| Linux | detection preview |
| macOS | detection preview |

Windows currently has the most complete detection flow. WSL, Linux, and macOS checkers are detection previews and will continue to improve.

## 5. Quick start

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

## 6. Detection scope

Current checks include:

- Windows system information
- PowerShell version
- Administrator permission
- Execution Policy
- Proxy environment variables
- Automatic proxy port detection
- WinHTTP proxy
- Windows Internet Settings proxy
- npm proxy
- Git proxy
- winget
- Node.js
- npm
- Git
- VS Code CLI
- Claude Code CLI
- Codex CLI
- WSL
- PATH
- TCP 443 network connectivity
- Logs and reports

## 7. Automatic proxy detection

Different users and client machines may use different local proxy ports. The tool must not assume one fixed port.

Proxy detection reads from several sources where available:

- Process, user, and machine proxy environment variables
- npm proxy configuration
- Git proxy configuration
- WinHTTP proxy
- Windows Internet Settings
- macOS `networksetup`
- Linux `gsettings`
- Common loopback ports

The tool detects and recommends proxy candidates. It does not change proxy settings, write npm or Git proxy configuration, or clear existing proxy settings.

## 8. Safety-first behavior

- Default mode is check-only.
- Software is not installed unless an explicit install mode is enabled.
- PATH is not changed unless an explicit path-fix mode is enabled.
- System-level PATH is not modified by default.
- User files are not deleted.
- Logs and reports are not uploaded.
- Generated logs, reports, and packages are ignored by Git.

## 9. Logs and reports

Generated diagnostic files stay local:

| Type | Path |
|------|------|
| Logs | `logs/` |
| JSON reports | `reports/` |
| Markdown reports | `reports/` |

Reports may include usernames, local paths, computer names, proxy information, command output, and system details. Review and sanitize reports before sharing them publicly.

Do not commit API keys, tokens, cookies, passwords, account credentials, private keys, or other secrets.

## 10. Software product and package plan

The v0.3.x line prepared downloadable packages for:

- Windows ZIP package
- WSL tar.gz package
- Linux tar.gz package
- macOS tar.gz package
- Source code package

Local release builds are generated under `dist/`. Generated archives are not committed.

The v0.4.x line starts the transition to an installable software product. Package does not only mean zip or tar release files; the long-term product direction includes a Windows GUI installer / setup.exe, cross-platform CLI, desktop GUI, script-based detection and installation engine, install plans, user confirmation, logs, and reports.

## 11. Future software architecture

The current detection layer uses PowerShell on Windows and Bash on WSL/Linux/macOS. v0.4.x starts adding:

- Go CLI
- Tauri desktop GUI
- Install plan engine
- Policy-controlled runner
- JSON schemas

Future versions may also add:

- Membership or license backend
- Device authorization
- Remote diagnostic report upload, only with explicit user consent

Any backend, membership, license, device authorization, or report-upload feature must remain optional. Offline local checks should continue to work without a backend.

See [docs/architecture.md](docs/architecture.md), [docs/software-product-design.md](docs/software-product-design.md), [docs/cli-plan.md](docs/cli-plan.md), and [docs/desktop-gui-plan.md](docs/desktop-gui-plan.md).

## 12. Roadmap

See [ROADMAP.md](ROADMAP.md).

## 13. Security

See [SECURITY.md](SECURITY.md).

## 14. License

See [LICENSE](LICENSE).
