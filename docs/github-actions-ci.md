# GitHub Actions CI

v0.6.2 adds safe GitHub Actions validation workflows under `.github/workflows/`.

## Workflows

- `ci.yml`: runs on pull requests, pushes to `main`, pushes to `dev/**`, and manual dispatch.
- `desktop-build-check.yml`: manual-only desktop build readiness check.

Both workflows use Windows runners first because Windows is the most complete current target for the project.

## What CI Checks

The main CI workflow checks:

- PowerShell parser validity for root, Windows, and development scripts
- JSON parsing for schemas, tool catalog manifests, examples, install plans, and report examples
- Go tests and Go build under `apps/cli-go`
- Desktop npm tests and Vite/TypeScript build under `apps/desktop-tauri`
- Cargo tests under `apps/desktop-tauri/src-tauri`
- Bash syntax for WSL, Linux, macOS, and release shell scripts
- Latest safe local validation script when present
- Tracked-file artifact guard for generated outputs and secret-like files
- Forbidden source scan for local machine paths and fixed proxy-port values

The Actions workflow runs safe validation scripts under PowerShell 7 (`pwsh`) for consistent parsing on GitHub-hosted Windows runners. Local validation may still use Windows PowerShell when checking Windows 5.1 compatibility.

## What CI Does Not Do

CI does not:

- Install user-facing software
- Run `winget install`
- Run global npm installs
- Run Claude Code, Codex CLI, Hermes Agent, OpenClaw, Docker, rustup, or repair installers
- Modify PATH
- Modify global environment variables
- Change global PowerShell execution policy
- Trigger UAC or elevation
- Upload installers
- Create tags
- Create GitHub Releases
- Publish packages

`npm ci` is used only inside the temporary GitHub Actions workspace to restore project-local desktop dependencies for tests and build checks. It is not a global install step.

## Why Generated Artifacts Are Ignored

Generated files such as top-level logs, top-level reports, `dist/`, `target/`, `node_modules/`, binaries, installers, and archives can contain machine-specific paths, timestamps, build products, or sensitive diagnostic data. They are not source and should not be committed.

Committed fixtures under `examples/reports/` are allowed because they are stable schema examples used by validation and documentation. They are not generated runtime reports.

## Local Validation Before PR

Run the latest safe validation script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\check-v0.6.1-tool-catalog.ps1
```

For desktop changes, also run when dependencies are already present:

```powershell
cd apps\desktop-tauri
npm test
npm run build
cd src-tauri
cargo test
```

## SLSA and Datadog

SLSA Go releaser and SLSA Generic generator are intentionally deferred until release packaging is stable and the project has a defined release artifact model. They should be added when the project is ready to produce provenance for signed release artifacts.

Datadog Synthetics is intentionally skipped at this stage. AI Local Environment Checker is currently a local desktop diagnostic tool, not a hosted web service with synthetic browser journeys. Custom CI validation is the right first step.
