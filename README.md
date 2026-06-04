# AI Local Environment Checker

AI Local Environment Checker is a safe, check-first environment diagnostic toolkit for local AI development. It helps users verify whether a computer is ready for tools such as Node.js, npm, Git, VS Code, Claude Code, Codex CLI, WSL, proxy networking, and related development dependencies.

- 中文文档: [README.zh-CN.md](README.zh-CN.md)
- English Documentation: [README.en-US.md](README.en-US.md)

## 1. What this project does

This project runs local readiness checks and writes local reports. It is intended to show what is installed, what is missing, and what may need manual review before local AI development tools are installed.

## 2. Why this project exists

Local AI tooling often depends on several system components. Users can get blocked by PATH issues, terminal permissions, proxy configuration, package managers, WSL setup, or missing command line tools. This repository provides a safer diagnostic step before installation.

## 3. Supported platforms

- Windows 10/11: beta usable
- WSL: detection preview
- Linux: detection preview
- macOS: detection preview

## 4. Safe-by-default policy

- Default mode is check-only.
- Software is not installed unless an explicit install mode is enabled.
- PATH is not modified unless an explicit path-fix mode is enabled.
- Reports and logs stay local.
- Generated logs, reports, and release packages are ignored by Git.

## 5. Quick start

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly -SkipNetwork -CommandTimeoutSec 10 -Language en-US
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Language en-US
```

WSL/Linux/macOS:

```bash
bash scripts/wsl/check-wsl.sh --check-only --language en-US --timeout 10 --skip-network
bash scripts/linux/check-linux.sh --check-only --language en-US --timeout 10
bash scripts/macos/check-macos.sh --check-only --language en-US --timeout 10
```

## 6. Package downloads and release plan

The v0.3.0 release line prepares downloadable packages for Windows, WSL, Linux, macOS, and source code. Release archives are generated under `dist/` for local testing and are not committed.

## 7. Current status

Windows detection is usable as a beta. Cross-platform Bash checkers are available as detection previews. Release packaging is being prepared for GitHub Releases.

## 8. Roadmap

See [ROADMAP.md](ROADMAP.md).

## 9. Security and privacy

See [SECURITY.md](SECURITY.md). Review generated reports before sharing them because local paths, usernames, proxy details, and system information may appear in diagnostic output.

## 10. License

See [LICENSE](LICENSE).
