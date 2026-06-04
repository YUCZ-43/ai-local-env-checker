# Roadmap

## v0.1.0-beta

- Windows beta.
- Windows PowerShell detection baseline.
- Safe check-only mode.
- Local logs and reports.
- Initial checks for Node.js, npm, Git, VS Code CLI, Claude Code CLI, Codex CLI, WSL, PATH, permissions, and network readiness.

## v0.2.0

- Cross-platform repository structure.
- i18n foundation for Chinese and English users.
- Proxy detection across environment variables, npm, Git, Windows settings, and loopback ports.
- Detection-preview scripts for WSL, Linux, and macOS.
- Safer timeout handling for external commands.

## v0.3.0

- Release packaging.
- Downloadable package structure.
- GitHub Release workflow preparation.
- Windows ZIP package design.
- WSL/Linux/macOS tar.gz package design.
- Source package design.
- Documentation for architecture and packaging.

## v0.4.0

- Unified CLI launcher.
- Recommended language: Go first.
- Optional Rust implementation later for selected components.
- Shared report schema across platforms.
- Shared command runner and proxy detection interface.

## v0.5.0

- Desktop GUI.
- Recommended stack: Tauri.
- Local-first UI for running checks and viewing results.
- GUI wrappers around script or CLI backends.

## v0.6.0

- Report viewer.
- Environment scoring.
- Customer diagnostic mode.
- Better remediation guidance.
- Safer export flow with sanitization reminders.

## v0.7.0

- Optional backend.
- Membership.
- License key.
- Device authorization.
- Report upload with explicit user consent only.
- Offline local checks must remain available without backend login.

## v1.0.0

- Stable public release.
- Stable cross-platform report schema.
- Stable package downloads.
- Stable documentation.
- Conservative install helpers gated by explicit user intent.
