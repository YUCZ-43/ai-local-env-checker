# ai-local-env-checker

本地 AI 开发环境自动检测与安装工具（测试版）

## 项目说明

`ai-local-env-checker` 是一个命令行工具，用于自动检测并安装本地 AI 编程所需的开发环境，包括：

- **系统环境：** 系统信息、管理员权限、执行策略
- **基础工具：** Node.js、npm、Git
- **编辑器：** VS Code、VS Code CLI (`code`)
- **AI 编程工具：** Claude Code CLI (`claude`)、Codex CLI (`codex`)
- **虚拟化：** WSL (Windows Subsystem for Linux)
- **包管理：** winget
- **网络连通性：** GitHub、npm registry、Claude API、ChatGPT API
- **环境变量：** PATH 完整性、npm 全局目录

## 支持系统

| 系统 | 状态 |
|------|------|
| Windows 10/11 (PowerShell) | ✅ 第一阶段 MVP |
| macOS | 🔜 计划中 |
| Linux (Ubuntu/Debian) | 🔜 计划中 |
| WSL | 🔜 计划中 |

## 当前版本限制

本版本为 **测试版 (v0.1.0-beta)**，仅支持 Windows PowerShell。

- 默认运行模式为**只检测**（CheckOnly），不会安装任何软件。
- 安装模式只使用 `winget` 作为包管理器。
- WSL 只检测，不自动安装。
- 只修改**用户级** PATH，不修改系统级 PATH。

## 快速开始

### 只检测模式（安全，推荐首次使用）

```powershell
# 使用 ExecutionPolicy Bypass
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly

# 或先设置执行策略
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1 -CheckOnly
```

### 安装模式

```powershell
# 以管理员权限运行
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Install
```

### 安装并修复 PATH

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Install -FixPath
```

### 快速验证

```powershell
powershell -ExecutionPolicy Bypass -File .\verify.ps1
```

## 命令示例

### 检测模式

```powershell
# 基本检测
.\install.ps1 -CheckOnly

# 详细日志
.\install.ps1 -CheckOnly -VerboseLog

# 跳过某些组件
.\install.ps1 -CheckOnly -SkipCodex -SkipWSL
```

### 安装模式

```powershell
# 安装所有缺失组件
.\install.ps1 -Install

# 安装但跳过 Codex
.\install.ps1 -Install -SkipCodex

# 安装并修复 PATH
.\install.ps1 -Install -FixPath

# 完整安装（跳过 WSL，保持简洁）
.\install.ps1 -Install -FixPath -SkipWSL
```

## 日志位置

| 内容 | 路径 |
|------|------|
| 运行日志 | `logs/run-yyyyMMdd-HHmmss.log` |
| PATH 备份 | `logs/path-backup-yyyyMMdd-HHmmss.txt` |

## 报告位置

| 格式 | 路径 |
|------|------|
| JSON 报告 | `reports/report-yyyyMMdd-HHmmss.json` |
| Markdown 报告 | `reports/report-yyyyMMdd-HHmmss.md` |

## 常见问题

请查看 [`docs/troubleshooting.md`](docs/troubleshooting.md) 获取详细的故障排查指南。

常见问题列表：
1. winget 不存在
2. Node.js 安装后 `node -v` 仍不可用
3. `npm install -g` 失败
4. `claude` 命令找不到
5. `codex` 命令找不到
6. `code` 命令找不到
7. PATH 修改后仍不生效
8. PowerShell 执行策略报错
9. 网络连接 npmjs.org 失败
10. Windows 中文路径问题
11. WSL 和 Windows 环境混用问题

## 安全说明

本工具遵循以下安全原则：

1. ✅ **默认只检测，不安装** — 只有显式指定 `-Install` 才安装。
2. ✅ **不删除任何用户文件** — 只添加，不删除。
3. ✅ **不修改系统级 PATH** — 只修改用户级 PATH。
4. ✅ **修改 PATH 前自动备份** — 备份到 `logs/` 目录。
5. ✅ **所有操作有日志** — 可追溯每一步。
6. ✅ **不安装非官方包** — 所有安装源均来自官方渠道。
7. ✅ **不上传任何数据** — 完全本地运行。
8. ✅ **不保存用户密码或 API Key** — 不涉及任何凭据操作。
9. ✅ **不使用不明来源安装脚本** — 除官方 Codex 安装脚本外，其他均通过 winget/npm 安装。

## 项目结构

```
ai-local-env-checker-test/
├── README.md                    # 本文件
├── install.ps1                  # 主脚本（检测 + 安装）
├── verify.ps1                   # 快速验证脚本
├── config.example.json          # 配置文件示例
├── logs/                        # 日志目录
│   └── .gitkeep
├── reports/                     # 报告目录
│   └── .gitkeep
└── docs/
    ├── windows-usage.md         # Windows 详细使用说明
    └── troubleshooting.md       # 故障排查指南
```

## License

MIT
