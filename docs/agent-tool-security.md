# Agent Tool Security

Agent tools such as Hermes Agent and OpenClaw can execute code, read local project files, call CLIs, or depend on third-party repositories. v0.6.1 treats these tools as template-only or manual-review items.

Before any future installation flow is enabled, users should review:

- Repository ownership and official source
- Release signatures or checksums where available
- Install scripts and post-install hooks
- Requested credentials, API keys, tokens, and file permissions
- Network endpoints and proxy behavior
- Whether WSL2 is the safer Windows execution environment

The catalog must not store secrets, tokens, private URLs, or local user paths.
