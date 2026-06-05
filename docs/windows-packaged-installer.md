# Windows Packaged Installer Preview

v0.7.0 prepares AI Local Environment Checker as a Windows desktop software package preview. The package target is the Tauri desktop app under `apps/desktop-tauri/`.

## What v0.7.0 Includes

- Tauri package metadata updated to version `0.7.0`.
- A Windows-focused installer preview configuration using a local NSIS bundle target.
- Safe CLI discovery design for future packaged app layouts.
- Documentation for app data, logs, reports, temporary files, and generated installer handling.
- A safe validation script for packaging readiness.

## What v0.7.0 Does Not Include

- No third-party tool installation.
- No `winget install`, global npm install, rustup installer, Docker installer, Claude Code installer, Codex CLI installer, Hermes Agent installer, or OpenClaw installer.
- No PATH modification, proxy modification, global environment modification, admin elevation, UAC trigger, or system repair.
- No release publishing, tags, GitHub Releases, SLSA provenance, or uploaded installers.
- No `plan run --confirm` from the desktop GUI.

## Local App Data

Packaged app configuration should live in the per-user application config directory selected by Tauri or the operating system. Future config should store only local preferences such as selected CLI path, language, UI state, and safe preview settings.

Do not store secrets, API keys, tokens, or private keys in app config.

## Logs, Reports, and Temporary Files

Runtime artifacts should stay local:

| Type | Intended location |
|------|-------------------|
| App config | Per-user app config directory |
| Logs | Per-user app log directory or repository `logs/` during development |
| Reports | Per-user app data/report directory or repository `reports/` during development |
| Temporary files | OS temp directory or Tauri app cache/temp directory |
| Installer outputs | `apps/desktop-tauri/src-tauri/target/` during local Tauri builds |

Generated logs and reports may contain local paths, usernames, proxy details, command output, and system details. They must remain ignored unless they are sanitized examples under `examples/`.

## Installer Output

Local package builds may create `.exe`, `.msi`, `.zip`, `.tar.gz`, `.tgz`, `dist/`, and `target/` outputs. These are generated artifacts and must not be committed.

The installer preview exists to prove local packaging readiness. Release publishing remains manual and out of scope for v0.7.0.

## Manual Local Package Check

Only run this when local dependencies are already present:

```powershell
cd apps\desktop-tauri
npm test
npm run build
cd src-tauri
cargo test
cd ..
npm run tauri build
```

If `npm run tauri build` fails because a local bundler prerequisite is missing, do not install anything from this workflow. Record the blocker and keep source validation passing.
