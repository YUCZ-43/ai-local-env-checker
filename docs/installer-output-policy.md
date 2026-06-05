# Installer Output Policy

Generated installer outputs are local-only artifacts. They are not source files and are not committed to the repository.

## Blocked Generated Outputs

The repository and validation scripts block staging of:

- `node_modules/`
- `dist/`
- `target/`
- `apps/desktop-tauri/dist/`
- `apps/desktop-tauri/src-tauri/target/`
- `apps/desktop-tauri/src-tauri/gen/`
- `apps/desktop-tauri/src-tauri/binaries/`
- generated `.exe`, `.msi`, `.zip`, `.tar.gz`, `.tgz`, and `.7z` files
- generated logs and reports
- `.env` files
- token, key, certificate, and private key files

Top-level `logs/.gitkeep`, `reports/.gitkeep`, and `dist/.gitkeep` are allowed placeholders. Sanitized example reports under `examples/reports/` are allowed fixtures.

## Why Installers Are Not Committed

Installers and build outputs can contain timestamps, local paths, machine-specific metadata, bundled binaries, and unsigned preview artifacts. They can be reproduced from source and should be distributed only through an explicit release process.

v0.8.0 does not create GitHub Releases, tags, uploaded artifacts, or signed installers.

The packaged app may bundle this repository's own CLI sidecar and read-only `core/` and `examples/` data. Those inputs are source-built or source-controlled, but the generated sidecar binary and installer output remain local-only artifacts.

## Safe Review Checklist

Before committing packaging changes:

- Confirm only source, config, docs, scripts, schemas, and workflow-safe files are staged.
- Confirm no generated package output is staged.
- Confirm no local reports or logs are staged.
- Confirm no local user path or fixed proxy port is committed.
- Confirm release publishing remains manual.
