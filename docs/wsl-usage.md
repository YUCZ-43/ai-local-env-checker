# WSL Usage

Run the WSL checker from the repository root:

```bash
bash scripts/wsl/check-wsl.sh --check-only --language zh-CN --timeout 10 --skip-network
```

The script is detection-only. It writes logs to `logs/` and reports to `reports/`.

It checks WSL identity, distro, kernel, shell tools, Node.js, npm, Git, curl, VS Code CLI, Claude Code, Codex CLI, Docker, PATH, proxy settings, `/mnt/c`, and Windows/WSL path mixing signals.
