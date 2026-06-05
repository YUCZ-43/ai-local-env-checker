# CHANGELOG

## v0.7.0-windows-packaged-installer-preview

Added:

- Prepared Tauri desktop package metadata for version `0.7.0`.
- Added Windows packaged installer preview documentation.
- Added installer output policy for local-only generated artifacts.
- Added CLI bundling and discovery strategy documentation.
- Added safe v0.7.0 packaging validation script.

Safety:

- Real third-party installation remains disabled.
- Generated installers, binaries, logs, reports, `dist/`, `target/`, and `node_modules/` remain uncommitted.
- Release publishing remains manual; no tags or GitHub Releases are created by this milestone.

## v0.3.0-packaging-readme-release

Planned / Added:

- Expanded README files for project purpose and public usage.
- Added packaging documentation for Windows, WSL, Linux, and macOS.
- Added release build scripts.
- Added package structure for GitHub Releases.
- Documented future multi-language implementation options such as Go, Rust, Python, and Tauri.
- Preserved safe check-only defaults.

## v0.2.0-cross-platform-i18n-proxy-detect

- Added bilingual docs.
- Added proxy auto-detection design and implementation.
- Added WSL/Linux/macOS checker scripts.
- Added locale files.
- Improved GitHub release readiness.

## v0.1.0-beta

- Initial Windows PowerShell beta.
- Added environment detection for Node.js, npm, Git, VS Code, Claude Code, Codex CLI, WSL.
- Added logs and reports.
- Added safe check-only mode.
