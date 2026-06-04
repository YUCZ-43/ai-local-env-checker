# macOS Usage

Run the macOS checker from the repository root:

```bash
bash scripts/macos/check-macos.sh --check-only --language en-US --timeout 10
```

The script is detection-only. It checks macOS version, architecture, Rosetta 2, Xcode Command Line Tools, Homebrew, Node.js, npm, Git, VS Code CLI, Claude Code, Codex CLI, Docker, shells, PATH, proxy settings, and TCP 443 network reachability.

Proxy settings are read with `networksetup` across all available network services.
