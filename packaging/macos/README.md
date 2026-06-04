# macOS Package

The macOS release package is designed as:

`dist/ai-local-env-checker-macos-vVERSION.tar.gz`

Expected contents:

- README files
- `LICENSE`
- `SECURITY.md`
- `docs/`
- `locales/`
- `scripts/macos/`
- `logs/.gitkeep`
- `reports/.gitkeep`

Run in check-only mode:

```bash
bash scripts/macos/check-macos.sh --check-only --language en-US --timeout 10
```
