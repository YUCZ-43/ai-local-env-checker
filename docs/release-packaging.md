# Release Packaging

## 1. Package types

The v0.3.0 release plan prepares these package types:

- Windows ZIP package
- WSL tar.gz package
- Linux tar.gz package
- macOS tar.gz package
- Source package

## 2. What each package includes

Windows package:

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

WSL package:

- README files
- `LICENSE`
- `SECURITY.md`
- `CHANGELOG.md`
- `docs/`
- `locales/`
- `scripts/wsl/`
- `scripts/linux/` when shared
- `logs/.gitkeep`
- `reports/.gitkeep`

Linux package:

- README files
- `LICENSE`
- `SECURITY.md`
- `CHANGELOG.md`
- `docs/`
- `locales/`
- `scripts/linux/`
- `logs/.gitkeep`
- `reports/.gitkeep`

macOS package:

- README files
- `LICENSE`
- `SECURITY.md`
- `CHANGELOG.md`
- `docs/`
- `locales/`
- `scripts/macos/`
- `logs/.gitkeep`
- `reports/.gitkeep`

Source package:

- Full repository source
- Excludes `.git`, generated logs, generated reports, generated packages, `.env`, token/key files, and local AI tool folders

## 3. Build packages on Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build-release.ps1 -Version 0.3.0-preview
```

The Windows build script always creates the Windows ZIP and source ZIP packages. If `tar` is available, it also creates WSL, Linux, and macOS tar.gz packages.

## 4. Build packages on Linux/macOS

```bash
bash scripts/release/build-release.sh --version 0.3.0-preview
```

The Bash build script creates WSL, Linux, macOS, and source tar.gz packages. If `zip` is available, it also creates a source ZIP package.

## 5. Upload packages to GitHub Release

1. Run the validation checks.
2. Build release packages locally.
3. Confirm `dist/` contains the expected archive names.
4. Confirm generated archives are ignored by Git.
5. Draft a GitHub Release manually.
6. Upload the package archives from `dist/`.
7. Paste and edit release notes from `scripts/release/RELEASE_NOTES_TEMPLATE.md`.

Do not create a GitHub Release automatically from the local build scripts.

## 6. Why dist/ is ignored

`dist/` contains generated release artifacts. These archives can be recreated from source and should not be committed to the repository.

## 7. Why logs/reports are not included

Generated logs and reports may contain usernames, local paths, proxy information, system details, and other machine-specific diagnostic data. Platform packages include only `logs/.gitkeep` and `reports/.gitkeep`.

## 8. Safety checklist before publishing

- Confirm default mode is still check-only.
- Confirm no generated logs or reports are staged.
- Confirm no `.env`, token, key, cookie, password, or account credential files are staged.
- Confirm package archives do not include `.git`.
- Confirm package archives do not include generated logs or generated reports.
- Confirm proxy URLs are masked where possible.
- Confirm README and release notes explain that reports should be reviewed before sharing.
