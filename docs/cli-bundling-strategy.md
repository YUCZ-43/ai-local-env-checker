# CLI Bundling Strategy

The desktop app is designed to call the Go CLI runner without enabling real installation.

## Discovery Order

The v0.7.0 backend adapter uses this safe discovery order:

1. Bundled CLI path for a future packaged app.
2. Configured CLI path from `AI_LOCAL_DEPLOY_BIN`.
3. Local development CLI binary under `apps/cli-go`.
4. `go run .` under `apps/cli-go` for development only.

The bundled CLI path is a packaging target, not a real third-party installer. It refers to this project's own `ai-local-deploy` binary when packaged later.

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

Do not bundle third-party installers or scripts that install third-party tools in v0.7.0.
