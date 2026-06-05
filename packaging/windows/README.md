# Windows Package

The Windows release package is designed as:

`dist/ai-local-env-checker-windows-vVERSION.zip`

v0.7.0 also prepares a Tauri Windows installer preview for the desktop app. Any generated `.exe` or `.msi` installer output remains local-only and must not be committed, uploaded, tagged, or released automatically.

Real third-party tool installation remains disabled in the packaged preview.

Expected contents:

- `install.ps1`
- `verify.ps1`
- `config.example.json`
- README files
- `LICENSE`
- `SECURITY.md`
- `CHANGELOG.md`
- `docs/`
- `locales/`
- `scripts/windows/`
- `logs/.gitkeep`
- `reports/.gitkeep`

Run in check-only mode by default:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly -SkipNetwork -CommandTimeoutSec 10 -Language en-US
```
