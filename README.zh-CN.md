# AI Local Environment Checker

## 项目定位

`ai-local-env-checker` 是一个默认只检测的本地 AI 开发环境检查工具。它用于客户电脑环境检测、AI 本地部署前置检查、开发机初始化验收，以及远程支持前的信息收集。

核心原则：

- 默认只检测，不安装。
- 安装逻辑只允许在用户显式传入 `-Install` 时执行。
- PATH 修复只允许在用户显式传入 `-FixPath` 时执行。
- 日志和报告只写入本项目内的 `logs/` 与 `reports/`。
- 代理只检测、只报告、只建议，不自动修改。

## 当前版本

建议版本：`v0.2.0-cross-platform-i18n-proxy-detect`

## 支持系统

| 平台 | 状态 |
|------|------|
| Windows PowerShell 5.1+ | 支持，保留根目录 `install.ps1` / `verify.ps1` |
| WSL | 新增检测版 |
| Linux | 新增检测版 |
| macOS | 新增检测版 |

## 快速开始

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

## Windows 用法

根目录脚本继续可用：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly -Language zh-CN
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly -Language en-US
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Language zh-CN
```

可选参数：

| 参数 | 说明 |
|------|------|
| `-CheckOnly` | 只检测，不安装，默认模式 |
| `-Install` | 显式安装模式 |
| `-FixPath` | 显式用户级 PATH 修复 |
| `-SkipNetwork` | 跳过网络连通性检测 |
| `-CommandTimeoutSec 10` | 设置外部命令超时 |
| `-Language zh-CN` / `-Language en-US` | 选择输出语言 |

## WSL 用法

```bash
bash scripts/wsl/check-wsl.sh --check-only --language zh-CN --timeout 10 --skip-network
bash scripts/wsl/verify-wsl.sh --language en-US --timeout 10
```

检测项包括 WSL 识别、发行版、Kernel、shell、Node.js、npm、Git、curl、VS Code CLI、Claude Code、Codex CLI、Docker、PATH、代理、`/mnt/c` 可访问性，以及 Windows/WSL 路径混用提示。

## Linux 用法

```bash
bash scripts/linux/check-linux.sh --check-only --language en-US --timeout 10
bash scripts/linux/verify-linux.sh --language zh-CN --timeout 10 --skip-network
```

检测项包括发行版、包管理器、shell、基础工具、AI 开发工具、Docker、权限、PATH、代理和 TCP 443 网络检测。

## macOS 用法

```bash
bash scripts/macos/check-macos.sh --check-only --language en-US --timeout 10
bash scripts/macos/verify-macos.sh --language zh-CN --timeout 10 --skip-network
```

检测项包括 macOS 版本、芯片架构、Rosetta 2、Xcode Command Line Tools、Homebrew、Node.js、npm、Git、VS Code CLI、Claude Code、Codex CLI、Docker、shell、PATH、代理和 TCP 443 网络检测。

## 自动代理端口检测说明

Windows 会检测：

- 当前进程、用户级、系统级代理环境变量。
- npm 和 Git 代理配置。
- WinHTTP 代理。
- Windows 用户代理设置。
- 常见本地代理端口，仅检测 `localhost` / loopback 地址。
- 如果 `curl.exe` 可用且未跳过网络，会尝试识别 HTTP proxy 或 SOCKS5 proxy。

WSL / Linux / macOS 会检测：

- 代理环境变量。
- npm 和 Git 代理配置。
- 常见本地 loopback 端口。
- Linux 上的 GNOME proxy 设置（如果 `gsettings` 存在）。
- macOS 上的 `networksetup` 代理设置，逐个网络服务检测。

所有代理 URL 写入日志或报告前都会脱敏。例如包含用户名密码的代理会显示为 `http://***:***@host:port`。

## 安全说明

- 默认只检测，不安装。
- 不收集用户隐私。
- 不上传日志或报告。
- 不自动修改代理。
- 不自动写入 npm / Git 代理。
- 不修改系统级 PATH。
- 不要提交 API key、token、cookie、账号密码或私钥。

更多内容见 [SECURITY.md](SECURITY.md)。

## 日志和报告

生成文件位于：

| 类型 | 路径 |
|------|------|
| 日志 | `logs/` |
| JSON 报告 | `reports/` |
| Markdown 报告 | `reports/` |

`.gitignore` 会排除生成的日志和报告，只保留 `.gitkeep`。

## 常见问题

故障排查见 [docs/troubleshooting.md](docs/troubleshooting.md)。

代理检测说明见 [docs/proxy-detection.md](docs/proxy-detection.md)。

## 版本路线图

路线图见 [ROADMAP.md](ROADMAP.md)。
