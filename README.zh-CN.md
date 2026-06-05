# AI Local Environment Checker

## v0.4.0 软件产品 MVP 方向

本项目正在从 v0.3.x 的脚本检测和下载包形态，转向 v0.4.x 的真实软件产品 MVP 架构。

v0.4.x 引入：

- 未来 Go CLI：`apps/cli-go`
- 未来 Tauri 桌面 GUI：`apps/desktop-tauri`
- 安装计划 schema 和示例
- detector、install-plan、runner、report、proxy、policy 等核心边界
- 先检测、先生成计划、用户确认后才安装或修复的设计

当前 PowerShell/Bash 脚本仍然是平台检测和执行层，并且默认保持只检测、安全优先。未来桌面 GUI 会基于 Tauri，未来 CLI 会基于 Go。

## v0.4.1 报告 schema 对齐

v0.4.1 将 `core/schema/report.schema.json` 与当前 PowerShell/Bash 执行层生成的报告格式对齐。本项目同时支持当前脚本报告格式和未来面向产品的报告模型。

详见 [docs/report-schema.md](docs/report-schema.md) 和 `examples/reports/` 中的脱敏示例。

## v0.5.0 Windows 安装计划 runner 基础

v0.5.0 在 Go CLI 中加入第一版受控安装计划执行管线：

- `ai-local-deploy plan show --file <path>`
- `ai-local-deploy plan validate --file <path>`
- `ai-local-deploy plan run --file <path> --dry-run`
- `ai-local-deploy plan run --file <path> --confirm`
- `ai-local-deploy plan simulate --file <path>`
- `ai-local-deploy doctor`
- `ai-local-deploy report`

默认行为仍然是 dry-run / check-first。安装计划必须先验证，再进行风险和管理员权限审查；非 dry-run 执行必须显式确认。v0.5.0 会拒绝 MEDIUM、HIGH 和 DANGEROUS 风险命令，只允许安全示例计划中的 LOW 风险无害命令。真实软件安装不会自动发生。未来 Tauri GUI 会调用这套 CLI/core engine。

详见 [docs/windows-install-plan-runner.md](docs/windows-install-plan-runner.md)、[docs/install-plan-policy.md](docs/install-plan-policy.md)、[docs/runner-safety.md](docs/runner-safety.md) 和 [docs/v0.5.0-roadmap.md](docs/v0.5.0-roadmap.md)。

## v0.6.0 Tauri GUI MVP

v0.6.0 在 `apps/desktop-tauri/` 中加入第一版可运行的 Tauri 桌面 GUI MVP。

GUI 基于 v0.5.0 Go CLI runner，支持：

- 加载示例安装计划
- 展示计划摘要、命令、`riskLevel`、`requiresAdmin` 和 `confirmationRequired`
- 通过安全 CLI adapter 验证安装计划
- 对 LOW 风险且不需要管理员权限的计划进行 simulate
- 对 LOW 风险且不需要管理员权限的计划进行 dry-run 展示
- 在日志面板展示输出
- 展示本地报告路径

真实安装仍然禁用。GUI 不会修改 PATH，不会修改全局环境变量，不会修改代理设置，不会修改 PowerShell Execution Policy，不会自动提权，也不会调用 `plan run --confirm`。

详见 [docs/tauri-gui-mvp.md](docs/tauri-gui-mvp.md)、[docs/gui-safety-model.md](docs/gui-safety-model.md) 和 [docs/v0.6.0-roadmap.md](docs/v0.6.0-roadmap.md)。

## v0.6.1 工具目录

v0.6.1 增加数据驱动的工具目录，用于描述 AI 和本地开发工具。它包含 manifest、示例、dry-run-only 安装计划模板、安全 Go CLI `tools` 命令、验证脚本，以及桌面 GUI 的 Tool Catalog 区域。

工具目录用于让 GUI 展示支持的工具、检测预览命令、风险等级、管理员权限要求、推荐安装模式和关联 dry-run 计划。真实安装仍然禁用。

详见 [docs/tool-catalog.md](docs/tool-catalog.md)、[docs/supported-tools.md](docs/supported-tools.md)、[docs/tool-manifest-schema.md](docs/tool-manifest-schema.md) 和 [docs/agent-tool-security.md](docs/agent-tool-security.md)。

## v0.6.2 GitHub Actions CI

v0.6.2 增加 GitHub Actions CI，用于 pull request 和 push 验证。CI 会验证 schema、工具目录 manifest、示例、Go CLI 测试和构建、桌面 npm 测试和构建、Tauri backend cargo test、脚本语法和安全护栏。

当前还没有启用 release automation。SLSA provenance workflow 和 Datadog Synthetics 也会推迟到后续阶段。

详见 [docs/github-actions-ci.md](docs/github-actions-ci.md)。

## v0.7.0 Windows 打包安装器预览

v0.7.0 将 Tauri 桌面应用准备为 AI Local Environment Checker 自身的 Windows 打包安装器预览。

- 生成的安装器只作为本地构建产物。
- 生成的安装器、二进制、日志、报告、`dist/`、`target/` 和 `node_modules/` 不会提交。
- 真实第三方软件安装仍然禁用。
- 发布仍然保持手动流程。
- v0.8.0 应聚焦在带明确用户意图的受控自动安装。

详见 [docs/windows-packaged-installer.md](docs/windows-packaged-installer.md)、[docs/installer-output-policy.md](docs/installer-output-policy.md)、[docs/cli-bundling-strategy.md](docs/cli-bundling-strategy.md) 和 [docs/v0.7.0-roadmap.md](docs/v0.7.0-roadmap.md)。

## v0.8.0 受控自动安装 MVP

v0.8.0 在 Go CLI 中加入受控执行层：

- 默认仍然是 dry-run。
- 非 dry-run 执行必须显式传入 `--confirm`。
- 只允许 LOW 风险且在安全 allowlist 中的演示命令执行。
- 管理员权限、MEDIUM、HIGH、ADMIN_REQUIRED 和 DANGEROUS 风险执行都会被阻止。
- 每次受控 runner 尝试都会写入本地 audit log 和 report。

GUI 会展示已选择工具、目标平台、计划步骤、命令预览、风险标签、管理员权限要求、dry-run 状态、确认状态和运行结果。GUI 不会静默安装软件，也不会自动提权。

详见 [docs/controlled-installation-model.md](docs/controlled-installation-model.md)、[docs/runner-policy.md](docs/runner-policy.md)、[docs/audit-log-model.md](docs/audit-log-model.md)、[docs/rollback-strategy.md](docs/rollback-strategy.md) 和 [docs/v0.8.0-roadmap.md](docs/v0.8.0-roadmap.md)。

## v0.9.0 管理员权限审批 UX

v0.9.0 增加本地自测版审批仪表盘，用于展示管理员权限复核、真实安装审批模型、命令级审批、回滚策略、审计/报告查看结构、主题切换、语言选择，以及更高质感的圆角桌面 UI 设计系统。

真实第三方安装仍然禁用。桌面应用不会自动触发 UAC，不会修改 PATH，不会修改代理设置，不会修改全局环境变量，也不会运行真实安装器命令。

详见 [docs/v0.9.0-admin-permission-approval-ux.md](docs/v0.9.0-admin-permission-approval-ux.md)、[docs/admin-permission-model.md](docs/admin-permission-model.md)、[docs/real-installer-approval-model.md](docs/real-installer-approval-model.md)、[docs/command-approval-model.md](docs/command-approval-model.md)、[docs/audit-report-viewer.md](docs/audit-report-viewer.md)、[docs/ux-ui-design-system.md](docs/ux-ui-design-system.md) 和 [docs/theme-and-language-model.md](docs/theme-and-language-model.md)。

## 1. 项目名称

AI Local Environment Checker

## 2. 项目定位

AI Local Environment Checker 是一个安全优先、默认只检测的本地 AI 开发环境诊断工具。它用于在安装或使用本地 AI 开发工具之前，检查当前电脑是否具备基础运行条件。

本项目适合普通用户、技术支持人员、电脑维护人员、部署服务提供者，以及需要批量确认开发环境状态的团队使用。

## 3. 项目初衷

本项目的目的，是帮助用户在安装和使用本地 AI 开发工具之前，先检查电脑环境是否已经准备好。

许多用户并不熟悉 Node.js、npm、Git、VS Code、Claude Code、Codex CLI、WSL、代理端口、PATH、终端权限、包管理器和系统配置。因此，他们经常在安装 AI 工具时卡住，无法判断问题到底来自网络、代理、权限、PATH、包管理器，还是某个命令行工具缺失。

本项目提供安全的检测脚本和本地报告，帮助用户、技术人员和部署服务提供者快速了解当前电脑环境。它的目标是先诊断、先记录、先给出建议，而不是盲目安装或修改系统。

## 4. 检测范围

当前检测范围包括：

- Windows 系统信息
- PowerShell 版本
- 管理员权限
- Execution Policy
- 代理环境变量
- 自动代理端口检测
- WinHTTP 代理
- Windows Internet Settings 代理
- npm 代理
- Git 代理
- winget
- Node.js
- npm
- Git
- VS Code CLI
- Claude Code CLI
- Codex CLI
- WSL
- PATH
- TCP 443 网络连通性
- 日志和报告

## 5. 支持系统

| 系统 | 当前状态 |
|------|----------|
| Windows 10/11 | beta 可用 |
| WSL | 检测预览 |
| Linux | 检测预览 |
| macOS | 检测预览 |

Windows 当前最完整。WSL、Linux 和 macOS 脚本用于只检测场景，后续版本会继续补齐报告结构和平台细节。

## 6. 快速开始

Windows 只检测：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly -SkipNetwork -CommandTimeoutSec 10 -Language zh-CN
```

Windows 快速验证：

```powershell
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Language zh-CN
```

WSL：

```bash
bash scripts/wsl/check-wsl.sh --check-only --language zh-CN --timeout 10 --skip-network
```

Linux：

```bash
bash scripts/linux/check-linux.sh --check-only --language zh-CN --timeout 10
```

macOS：

```bash
bash scripts/macos/check-macos.sh --check-only --language zh-CN --timeout 10
```

## 7. 安全说明

- 默认模式是只检测。
- 不会自动安装软件。
- 不会自动删除文件。
- 不会自动上传报告。
- `logs/` 和 `reports/` 中的生成文件默认被 Git 排除。
- 报告可能包含用户名、本地路径、代理信息或系统细节。公开分享之前应先脱敏。
- 不要提交 API key、token、cookie、密码、账号凭据或私钥。

安装模式和 PATH 修复必须由用户显式启用。默认检测流程不会修改系统级 PATH，也不会修改代理、npm 或 Git 配置。

## 8. 自动代理检测

不同用户、不同电脑、不同代理客户端可能使用不同的本地代理端口。因此，本工具不能假设某一个固定端口。

代理检测会尽量从多个来源读取信息：

- 当前进程、用户级和系统级代理环境变量
- npm 代理配置
- Git 代理配置
- WinHTTP 代理
- Windows Internet Settings
- macOS `networksetup`
- Linux `gsettings`
- 常见本地 loopback 端口

代理检测只负责发现、记录和推荐。它不会修改系统代理，不会写入 npm 或 Git 代理，也不会清空现有代理配置。

## 9. 日志和报告

检测脚本会在本地生成日志和报告：

| 类型 | 路径 |
|------|------|
| 日志 | `logs/` |
| JSON 报告 | `reports/` |
| Markdown 报告 | `reports/` |

这些文件用于本地诊断。提交代码或公开分享前，请检查是否包含本地路径、用户名、电脑名、代理地址或其他敏感信息。

## 10. 软件产品与发布计划

v0.3.x 主要面向脚本检测、本地报告和下载包：

- Windows ZIP package
- WSL tar.gz package
- Linux tar.gz package
- macOS tar.gz package
- Source code package

本地构建的发布包会输出到 `dist/`，该目录中的生成包不会提交到 Git。

v0.4.x 及后续版本开始转向可安装的软件产品，而不是只把 package 理解为 zip/tar 发布文件。长期目标包括 Windows GUI installer / setup.exe、跨平台 CLI、桌面 GUI、脚本执行引擎、安装计划、用户确认、日志和报告。

## 11. 未来软件架构

当前检测层使用 PowerShell 和 Bash：

- Windows：PowerShell
- WSL/Linux/macOS：Bash

当前产品架构已经包括：

- Go CLI
- Tauri desktop GUI
- 安装计划引擎
- 受策略控制的 runner
- JSON schema

未来版本可能继续增加：

- 会员或授权后端
- 设备授权
- 远程诊断报告上传，但必须由用户明确同意

后端、会员、授权和报告上传都应是可选能力，不能成为离线本地检测的前置条件。

相关设计见 [docs/software-product-design.md](docs/software-product-design.md)、[docs/cli-plan.md](docs/cli-plan.md)、[docs/desktop-gui-plan.md](docs/desktop-gui-plan.md)。

## 12. 故障排查与相关链接

见 [docs/troubleshooting.md](docs/troubleshooting.md)。

代理检测说明见 [docs/proxy-detection.md](docs/proxy-detection.md)。

路线图见 [ROADMAP.md](ROADMAP.md)。

安全策略见 [SECURITY.md](SECURITY.md)。

许可证见 [LICENSE](LICENSE)。
