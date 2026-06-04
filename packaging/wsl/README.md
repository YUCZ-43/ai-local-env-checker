# WSL Package

The WSL release package is designed as:

`dist/ai-local-env-checker-wsl-vVERSION.tar.gz`

Expected contents:

- README files
- `LICENSE`
- `SECURITY.md`
- `docs/`
- `locales/`
- `scripts/wsl/`
- `scripts/linux/` when shared
- `logs/.gitkeep`
- `reports/.gitkeep`

Run in check-only mode:

```bash
bash scripts/wsl/check-wsl.sh --check-only --language en-US --timeout 10 --skip-network
```
