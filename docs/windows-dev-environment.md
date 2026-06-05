# Windows Development Environment

This document lists prerequisites for building the future Windows desktop and CLI product.

## Prerequisites

- Git
- GitHub CLI
- Node.js/npm
- Go
- Rust/Cargo
- Microsoft C++ Build Tools
- WebView2 Runtime
- NSIS
- Tauri CLI
- WSL
- Claude Code
- Codex CLI

## Validation commands

```powershell
git --version
gh --version
node --version
npm --version
go version
rustc --version
cargo --version
code --version
claude --version
codex --version
tauri --version
makensis /VERSION
wsl --version
```

For Microsoft C++ Build Tools, open a Developer PowerShell or run `vcvars64.bat`, then validate:

```powershell
cl
```

## Automated check

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\check-windows-dev-env.ps1
```

The script only checks versions and paths. It does not install software, modify PATH, repair tools, or delete files.
