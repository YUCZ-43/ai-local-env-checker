# Windows 使用说明

## 系统要求

- Windows 10 1809+ 或 Windows 11
- PowerShell 5.1+ (推荐 PowerShell 7+)
- 网络连接
- 建议管理员权限（仅安装模式需要）

## 快速开始

### 1. 只检测环境（默认模式，安全）

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly
```

或简写：

```powershell
.\install.ps1
```

（不传参数默认等同 `-CheckOnly`）

### 2. 检测并安装缺失组件

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Install
```

### 3. 检测、安装并修复 PATH

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Install -FixPath
```

### 4. 跳过某些组件

```powershell
# 跳过 Codex CLI
.\install.ps1 -Install -SkipCodex

# 跳过 Claude Code
.\install.ps1 -Install -SkipClaude

# 跳过 VS Code
.\install.ps1 -Install -SkipVSCode

# 跳过 WSL 检测
.\install.ps1 -CheckOnly -SkipWSL

# 组合使用
.\install.ps1 -Install -FixPath -SkipCodex -SkipWSL
```

### 5. 详细日志模式

```powershell
.\install.ps1 -CheckOnly -VerboseLog
.\install.ps1 -Install -VerboseLog
```

### 6. 快速验证环境

```powershell
powershell -ExecutionPolicy Bypass -File .\verify.ps1
```

## 参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `-CheckOnly` | Switch | 只检测，不安装任何东西（默认模式） |
| `-Install` | Switch | 自动安装缺失的组件 |
| `-FixPath` | Switch | 修复用户 PATH 环境变量 |
| `-VerboseLog` | Switch | 输出详细日志到控制台 |
| `-SkipCodex` | Switch | 跳过 Codex CLI 检测/安装 |
| `-SkipClaude` | Switch | 跳过 Claude Code 检测/安装 |
| `-SkipVSCode` | Switch | 跳过 VS Code 检测/安装 |
| `-SkipWSL` | Switch | 跳过 WSL 检测 |

## 输出状态说明

| 状态 | 含义 |
|------|------|
| `OK` | 组件已安装且可用 |
| `MISSING` | 组件未安装 |
| `WARNING` | 组件存在但可能有配置问题 |
| `ERROR` | 检测或安装过程出错 |
| `SKIPPED` | 用户选择跳过此组件 |

## 日志和报告

所有运行记录保存在：

- **日志：** `logs/run-yyyyMMdd-HHmmss.log`
- **JSON 报告：** `reports/report-yyyyMMdd-HHmmss.json`
- **Markdown 报告：** `reports/report-yyyyMMdd-HHmmss.md`
- **PATH 备份：** `logs/path-backup-yyyyMMdd-HHmmss.txt`

## 执行策略

如果遇到执行策略限制，使用以下方式运行：

```powershell
# 仅为当前进程设置
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 或永久为当前用户设置
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# 或在运行命令中指定
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly
```

## 典型工作流

### 新电脑初始化

```powershell
# 第一步：检测当前环境
.\install.ps1 -CheckOnly -VerboseLog

# 第二步：查看报告
# 打开 reports/ 目录查看最新报告

# 第三步：安装缺失组件
.\install.ps1 -Install

# 第四步：修复 PATH
.\install.ps1 -FixPath

# 第五步：重启 PowerShell，验证
.\verify.ps1
```

### 仅检查特定工具

```powershell
# 只关心 AI 工具
.\install.ps1 -CheckOnly -SkipWSL

# 只关心基础环境
.\install.ps1 -CheckOnly -SkipCodex -SkipClaude -SkipVSCode -SkipWSL
```

## 注意事项

1. 安装模式建议以管理员权限运行（部分软件需要）。
2. 安装完成后建议重启 PowerShell 或终端。
3. PATH 修复后需要重启 PowerShell 才能生效。
4. WSL 在测试版中只检测，不自动安装。
5. 所有安装操作都会记录日志，可随时回溯。
