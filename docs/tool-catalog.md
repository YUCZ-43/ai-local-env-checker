# Tool Catalog

v0.6.1 adds a data-driven tool catalog under `core/tool-catalog/`.

The catalog lets the CLI and future GUI describe supported AI/local-development tools without hard-coding tool behavior in the UI. Each manifest describes detection commands, verification commands, supported platforms, risk, admin requirements, security warnings, docs, and dry-run-only install-plan templates.

## Safety model

The catalog is metadata. It does not install software.

- Detection commands are printed as previews unless an explicit future safe detector executes them.
- Install-plan templates are dry-run-only.
- Tools with install-like templates are MEDIUM risk or higher.
- Admin-required tools are shown as requiring admin, but v0.6.1 does not elevate.
- Proxy settings are read-only and must not use fixed local proxy ports.

## CLI commands

```powershell
ai-local-deploy tools list
ai-local-deploy tools show --id claude-code
ai-local-deploy tools validate
ai-local-deploy tools detect --dry-run
ai-local-deploy tools plan --id claude-code --dry-run
```

These commands read local manifests and print previews. They do not run installers.
