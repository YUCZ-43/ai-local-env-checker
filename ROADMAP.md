# Roadmap

## v0.1.x Windows beta

- Windows PowerShell detection baseline.
- Safe check-only mode.
- Logs and reports.

## v0.2.x i18n + proxy auto detection

- Chinese and English docs.
- Locale files for user-facing status text.
- Automatic proxy detection across environment variables, npm, Git, Windows settings, and loopback ports.
- Detection-only WSL, Linux, and macOS scripts.

## v0.3.x WSL/Linux stable

- Harden WSL and Linux reports.
- Add more distro-specific checks.
- Improve shell and package-manager recommendations.

## v0.4.x macOS stable

- Harden macOS checks.
- Improve Homebrew, Rosetta, Xcode Command Line Tools, and network service handling.

## v0.5.x unified CLI launcher

- Add a single launcher that routes to Windows, WSL, Linux, or macOS checks.
- Normalize report schemas across platforms.

## v1.0.0 stable release

- Stable cross-platform report schema.
- Stable docs.
- Conservative install helpers with explicit user intent.
