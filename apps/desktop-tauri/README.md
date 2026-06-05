# AI Local Environment Checker Desktop

This is the v0.6.0 Tauri GUI MVP for AI Local Environment Checker.

The desktop app is a safe preview interface around the v0.5.0 Go CLI install-plan runner. It can load example install plans, show commands and policy fields, validate plans, simulate safe plans, dry-run safe plans, show logs, and show report locations.

## Safety limits

- Real installation is disabled.
- `plan run --confirm` is not wired.
- Admin elevation is not implemented.
- MEDIUM, HIGH, and DANGEROUS plans are blocked for simulate and dry-run.
- PATH, proxy, global environment variables, and PowerShell execution policy are not modified.

## Development

```powershell
npm install
npm test
npm run build
npm run tauri dev
```

`npm install` is a local development step only. Do not commit `node_modules/`, `dist/`, `src-tauri/target/`, generated installers, generated binaries, logs, reports, `.env` files, keys, or tokens.

## Adapter layout

- `src/services/planClient.ts`: plan parsing, summary, command display, GUI risk gates
- `src/services/runnerClient.ts`: Tauri invoke adapter for safe backend commands
- `src/services/reportClient.ts`: report location and preview adapter
- `src-tauri/src/lib.rs`: Tauri commands and safe CLI invocation

The CLI call layer is ready for `ai-local-deploy` and currently resolves the binary from `AI_LOCAL_DEPLOY_BIN`, a local CLI binary, or `go run .` under `apps/cli-go`.
