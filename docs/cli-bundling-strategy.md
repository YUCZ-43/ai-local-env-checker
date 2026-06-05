# CLI Bundling Strategy

The desktop app is designed to call the Go CLI runner without enabling real installation.

## Discovery Order

The v0.8.0 backend adapter uses this safe discovery order:

1. Bundled CLI sidecar path for the packaged app.
2. Configured CLI path from `AI_LOCAL_DEPLOY_BIN`.
3. Local development CLI binary under `apps/cli-go`.
4. `go run .` under `apps/cli-go` for development only.

The bundled CLI is this project's own `ai-local-deploy` binary. The Tauri build prepares it with `scripts/packaging/build-bundled-cli.ps1` and includes it through `bundle.externalBin`.

The packaged app also bundles read-only runtime data through `bundle.resources`:

- `core/schema`
- `core/tool-catalog`
- `examples/install-plans`
- `examples/reports`

This lets an installed app launched outside the source checkout list example plans, load the tool catalog, validate plans, simulate plans, and run dry-run previews.

## Safety Boundary

The GUI only wires safe commands:

- `plan validate`
- `plan simulate`
- `plan run --dry-run`
- `tools detect --dry-run`
- `tools plan --dry-run`

The GUI does not call `plan run --confirm`. It blocks MEDIUM, HIGH, and DANGEROUS plans and blocks admin-required plans.

## Future Packaging Work

Future packaging may place the CLI next to the desktop executable or inside a `resources/bin/` directory. The CLI must be built from this repository and treated as part of the app package.

Do not bundle third-party installers or scripts that install third-party tools in v0.8.0.

## Runtime Roots

The desktop backend passes two process-local environment variables to the CLI:

- `AI_LOCAL_DEPLOY_CONTENT_ROOT`: read-only packaged content root containing `core/` and `examples/`
- `AI_LOCAL_DEPLOY_OUTPUT_ROOT`: writable per-user output root for generated `logs/` and `reports/`

These are set only for the child CLI process. They do not modify global environment variables or system PATH.
