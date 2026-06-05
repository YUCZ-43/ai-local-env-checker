# AI Local Environment Checker Desktop

This is the v0.7.0 Tauri Windows installer preview for AI Local Environment Checker.

The desktop app is a safe preview interface around the v0.5.0 Go CLI install-plan runner. It can load example install plans, show commands and policy fields, validate plans, simulate safe plans, dry-run safe plans, show logs, and show report locations.

v0.7.0 prepares local Windows packaging metadata and installer output policy. Generated installers are local-only artifacts and must not be committed.

The package preview includes read-only runtime data (`core/schema`, `core/tool-catalog`, `examples/install-plans`, and `examples/reports`) plus this repository's own `ai-local-deploy` CLI sidecar. It does not bundle third-party installers.

## Safety limits

- Real installation is disabled.
- `plan run --confirm` is not wired.
- Admin elevation is not implemented.
- MEDIUM, HIGH, and DANGEROUS plans are blocked for simulate and dry-run.
- PATH, proxy, global environment variables, and PowerShell execution policy are not modified.
- Tool Catalog entries do not expose real install buttons.
- Packaged installer output is not uploaded or published by this app.

## Development

```powershell
npm install
npm test
npm run build
npm run tauri dev
```

`npm install` is a local development step only. Do not commit `node_modules/`, `dist/`, `src-tauri/target/`, generated installers, generated binaries, logs, reports, `.env` files, keys, or tokens.

## Local package preview

If local dependencies are already present, a developer may run:

```powershell
npm run tauri build
```

This builds a local CLI sidecar under `src-tauri/binaries/` and may create local `.exe` or installer artifacts under `src-tauri/target/`. They are ignored and must not be committed, uploaded, tagged, or released in v0.7.0.

## Adapter layout

- `src/services/planClient.ts`: plan parsing, summary, command display, GUI risk gates
- `src/services/runnerClient.ts`: Tauri invoke adapter for safe backend commands
- `src/services/reportClient.ts`: report location and preview adapter
- `src/services/toolCatalogClient.ts`: tool catalog summary and preview adapter
- `src-tauri/src/lib.rs`: Tauri commands and safe CLI invocation

The CLI call layer resolves `ai-local-deploy` in this order: bundled packaged CLI sidecar, `AI_LOCAL_DEPLOY_BIN`, local development CLI binary, then `go run .` under `apps/cli-go` for development only. The backend passes process-local content and output roots to the CLI; it does not modify global environment variables.
