# Linux Package

The Linux release package is designed as:

`dist/ai-local-env-checker-linux-vVERSION.tar.gz`

Expected contents:

- README files
- `LICENSE`
- `SECURITY.md`
- `docs/`
- `locales/`
- `scripts/linux/`
- `logs/.gitkeep`
- `reports/.gitkeep`

Run in check-only mode:

```bash
bash scripts/linux/check-linux.sh --check-only --language en-US --timeout 10
```
