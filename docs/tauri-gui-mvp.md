# v0.6.0 Tauri GUI MVP

v0.6.0 introduces the first runnable desktop GUI for AI Local Environment Checker. The app lives in `apps/desktop-tauri/` and uses Tauri v2, TypeScript, Vite, and a small vanilla frontend.

## Scope

The GUI is a safe preview interface around the v0.5.0 Go CLI install-plan runner. It includes:

- Dashboard
- Environment Check
- Install Plan Viewer
- Policy / Risk Review
- Dry Run / Simulate
- Logs
- Reports
- Settings

## CLI integration

The Tauri backend exposes safe commands for the frontend:

- `get_app_info`
- `list_example_plans`
- `read_plan`
- `validate_plan`
- `simulate_plan`
- `dry_run_plan`
- `get_report_location`

The backend is designed to call:

- `ai-local-deploy plan show --file <path>`
- `ai-local-deploy plan validate --file <path>`
- `ai-local-deploy plan run --file <path> --dry-run`
- `ai-local-deploy plan simulate --file <path>`
- `ai-local-deploy doctor`
- `ai-local-deploy report`

The GUI does not call `plan run --confirm`.

## Runtime model

Example plans are listed from `examples/install-plans/`. Plan reads are restricted to that directory. Validation can call the CLI. Simulate and dry-run first check the plan risk and admin flags in the GUI/backend adapter, then call only safe CLI modes.

The CLI binary resolution order is:

1. `AI_LOCAL_DEPLOY_BIN` environment variable
2. local `apps/cli-go/ai-local-deploy` or `.exe` if present
3. `go run .` from `apps/cli-go`

This keeps the GUI usable during development without committing generated binaries.

## Local development

```powershell
cd apps/desktop-tauri
npm install
npm test
npm run build
npm run tauri dev
```

Do not commit `node_modules/`, `dist/`, `src-tauri/target/`, generated installers, generated binaries, logs, reports, `.env` files, keys, or tokens.
