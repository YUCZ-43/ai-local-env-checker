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

- Windows packaged installer preview.
- Tauri desktop app package metadata.
- Local-only installer output policy.
- CLI bundling and discovery strategy.
- Packaging validation that blocks generated artifacts and secrets from staging.
- Real third-party installation remains disabled.
- Release publishing remains manual.

## v0.8.0

- Controlled automatic installation MVP.
- CLI `--confirm` required for non-dry-run execution.
- LOW-risk allowlisted demo execution only.
- Audit JSONL logs and local reports for runner attempts.
- GUI confirmation state and run-result display.
- Admin, MEDIUM, HIGH, ADMIN_REQUIRED, and DANGEROUS execution blocked.

## v0.9.0

- Admin permission approval UX local self-test.
- Real installer approval model with real installation disabled by default.
- Command-level approval model and blocked command visibility.
- Rollback strategy review surface.
- Audit/report viewer structure.
- Light/dark theme switching.
- English, Simplified Chinese, and Traditional Chinese UI-level language selector.
- Premium rounded desktop UI design system.
- No automatic UAC, PATH modification, proxy modification, global environment modification, silent install, tag, PR, release, or push.

## v1.0.0

- Stable public release.
- Stable cross-platform report schema.
- Stable package downloads.
- Stable documentation.
- Conservative install helpers gated by explicit user intent.
