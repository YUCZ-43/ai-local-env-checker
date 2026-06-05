# Tauri Backend

The v0.8.0 backend is implemented in Rust under `src-tauri/src/`.

It exposes safe Tauri commands for listing and reading example plans, validating plans, simulating safe plans, dry-running safe plans, and returning the local report directory.

The CLI discovery order is bundled packaged CLI path, configured `AI_LOCAL_DEPLOY_BIN`, local development CLI binary, then `go run .` for development only.
