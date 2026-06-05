# CHANGELOG

## v0.9.0-admin-permission-approval-ux

Added:

- Added v0.9.0-alpha.1 product-grade desktop UI refinement and static website preview.
- Added platform package plan documenting Windows alpha package scope and macOS/Linux planned package requirements.
- Added GitHub Pages, Vercel, and Cloudflare Pages preview-hosting guidance without production domain or DNS changes.
- Added desktop admin permission review UX.
- Added real installer approval model with real execution disabled.
- Added command-level approval model and command approval screen.
- Added rollback strategy screen and audit/report viewer structure.
- Added light/dark/system theme control.
- Added English and Simplified Chinese active UI-level language selector, with Traditional Chinese locale files preserved for future work.
- Added premium rounded desktop UI design tokens and racing-blue-inspired custom palette.
- Added v0.9.0 install-plan schema fields and dry-run-only approval preview example.
- Added v0.9.0 documentation set and safe validation script.

Safety:

- Real third-party installation remains disabled.
- No automatic UAC elevation is enabled.
- No PATH, proxy, or global environment modification is enabled.
- No silent installer or real installer command is executed by the desktop UI.

## v0.8.0-controlled-automatic-installation

Added:

- Added controlled Go CLI execution for explicitly confirmed LOW-risk allowlisted demo commands.
- Added audit JSONL logging for controlled runner attempts.
- Added report next recommended action.
- Added install-plan schema metadata for `toolId`, expected result, rollback notes, and `ADMIN_REQUIRED` risk.
- Added GUI confirmation and run-result sections.
- Added controlled installation, runner policy, audit log, rollback, and roadmap docs.

Safety:

- Dry-run remains the default.
- GUI real installation remains disabled by default.
- MEDIUM, HIGH, ADMIN_REQUIRED, DANGEROUS, and admin-required execution is blocked.
- No automatic UAC elevation, PATH modification, proxy modification, global environment modification, or silent install is enabled.

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
