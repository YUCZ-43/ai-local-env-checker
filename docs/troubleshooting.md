# 常见问题排查 (Troubleshooting)

## 1. winget 不存在

**症状：** 运行脚本提示 `winget` 命令找不到。

**原因：** Windows 10 1809 以下版本不自带 winget，或 App Installer 被卸载。

**解决方案：**
1. 打开 Microsoft Store，搜索 "App Installer"，安装或更新。
2. 或者从 GitHub 手动安装：
   ```
   https://github.com/microsoft/winget-cli/releases
   ```
   下载 `.msixbundle` 文件，双击安装。
3. 安装后重启 PowerShell。

---

## 2. Node.js 安装后 `node -v` 仍不可用

**症状：** winget 提示安装成功，但运行 `node -v` 报 "command not found"。

**原因：** 当前 PowerShell 进程没有刷新 PATH 环境变量。

**解决方案：**
1. 关闭当前 PowerShell，重新打开一个新的 PowerShell 窗口。
2. 或者在当前窗口运行：
   ```powershell
   $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
   ```
3. 如果仍不行，检查 Node.js 是否真的安装到了：
   ```
   C:\Program Files\nodejs\
   ```

---

## 3. `npm install -g` 失败（权限问题）

**症状：** 运行 `npm install -g xxx` 报 EACCES 或 EPERM 权限错误。

**原因：**
- Windows 上 npm 全局目录默认在 `%APPDATA%\npm`，通常不需要管理员权限。
- 但如果 npm 全局 prefix 被设置为系统目录，则需要管理员权限。

**解决方案：**
1. 检查 npm 全局 prefix：
   ```powershell
   npm config get prefix
   ```
2. 如果 prefix 指向 `C:\Program Files\nodejs\`，修改为用户目录：
   ```powershell
   npm config set prefix "$env:APPDATA\npm"
   ```
3. 确保 `%APPDATA%\npm` 在用户 PATH 中。
4. 使用本脚本的 `-FixPath` 功能自动修复。

---

## 4. `claude` 命令找不到

**症状：** 安装 @anthropic-ai/claude-code 后，`claude --version` 找不到。

**原因：**
- npm 全局 bin 目录不在 PATH 中。
- 安装时使用了管理员 PowerShell，导致 prefix 不一致。

**解决方案：**
1. 检查安装位置：
   ```powershell
   npm list -g @anthropic-ai/claude-code
   ```
2. 找到全局 bin 目录：
   ```powershell
   npm bin -g
   ```
3. 将该目录加入 PATH，或运行本脚本的 `-FixPath`：
   ```powershell
   .\install.ps1 -Install -FixPath
   ```
4. 重启 PowerShell。

---

## 5. `codex` 命令找不到

**症状：** 安装 Codex CLI 后，`codex --version` 找不到。

**原因：**
- Windows 安装脚本可能安装到了非标准位置。
- npm 安装的 codex 在 npm 全局 bin 目录，不在 PATH。

**解决方案：**
1. 检查 npm 全局安装：
   ```powershell
   npm list -g @openai/codex
   ```
2. 如果通过官方安装脚本安装，检查路径：
   ```powershell
   Get-Command codex -ErrorAction SilentlyContinue
   where codex
   ```
3. 确保 npm 全局 bin 目录在 PATH 中。
4. 运行 `.\install.ps1 -FixPath` 自动修复。

---

## 6. `code` 命令找不到（VS Code CLI）

**症状：** VS Code 已安装，但 `code` 命令不可用。

**原因：** VS Code 安装时没有将 `code` 命令添加到 PATH。

**解决方案：**
1. 手动添加 VS Code bin 目录到 PATH：
   ```
   %LOCALAPPDATA%\Programs\Microsoft VS Code\bin
   ```
2. 或者从 VS Code 内部：打开命令面板 (Ctrl+Shift+P)，搜索 "Shell Command: Install 'code' command in PATH"。
3. 运行 `.\install.ps1 -FixPath` 自动修复。

---

## 7. PATH 修改后仍不生效

**症状：** 运行 `-FixPath` 后，命令仍然找不到。

**原因：** 当前 PowerShell 会话使用旧的 PATH 缓存。

**解决方案：**
1. 完全关闭 PowerShell，重新打开。
2. 检查环境变量是否真的被修改：
   ```powershell
   [System.Environment]::GetEnvironmentVariable("Path", "User")
   ```
3. 检查系统级 PATH（本脚本不修改系统 PATH）：
   ```powershell
   [System.Environment]::GetEnvironmentVariable("Path", "Machine")
   ```

---

## 8. PowerShell 执行策略报错

**症状：** 运行脚本报 `cannot be loaded because running scripts is disabled`。

**原因：** PowerShell 默认执行策略为 Restricted。

**解决方案：**
1. 临时绕过（仅当前会话）：
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
2. 永久修改当前用户：
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```
3. 或运行时加参数：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

---

## 9. 网络连接 npmjs.org 失败

**症状：** `Test-NetConnection npmjs.org` 失败或超时。

**原因：**
- 公司防火墙或代理阻止。
- DNS 解析问题。
- 网络不稳定。

**解决方案：**
1. 检查是否需要配置代理：
   ```powershell
   npm config set proxy http://proxy.company.com:8080
   npm config set https-proxy http://proxy.company.com:8080
   ```
2. 检查 DNS：
   ```powershell
   Resolve-DnsName npmjs.org
   ```
3. 尝试使用 nrm 切换镜像源（仅限中国地区）：
   ```powershell
   npm install -g nrm
   nrm use taobao
   ```

---

## 10. Windows 中文路径问题

**症状：** npm 全局安装到中文用户名下的路径，某些包无法正常工作。

**原因：** 部分 Node.js 工具对非 ASCII 路径支持不完善。

**解决方案：**
1. 检查用户名是否为中文：
   ```powershell
   $env:USERNAME
   ```
2. 如果 npm 全局路径包含中文，可修改 prefix：
   ```powershell
   npm config set prefix "C:\npm-global"
   ```
3. 确保新 prefix 目录有写入权限，并加入 PATH。
4. 运行 `.\install.ps1 -FixPath` 更新 PATH。

---

## 11. WSL 和 Windows 环境混用问题

**症状：** 在 WSL 中运行 Windows 版工具报错，或反之。

**原因：** WSL 和 Windows 是两套独立的环境，PATH 和可执行文件不互通（WSL 可调用 Windows 程序，反之不可）。

**解决方案：**
1. 明确各工具的使用场景：
   - Windows 工具：在 PowerShell / CMD 中使用
   - Linux 工具：在 WSL 中使用
2. 在 WSL 中，Windows 路径下的可执行文件可以调用（通过 interop），但不推荐混用。
3. 建议在 WSL 中单独安装 Node.js、npm、Git 等工具（使用 apt 或 nvm）。
4. 运行 `wsl -l -v` 确认 WSL 版本，WSL2 推荐使用。

---

## 通用排查步骤

如果以上方案不生效，请：

1. 运行完整检测并保存日志：
   ```powershell
   .\install.ps1 -CheckOnly -VerboseLog
   ```
2. 查看日志文件：`logs\run-yyyyMMdd-HHmmss.log`
3. 查看报告：`reports\report-yyyyMMdd-HHmmss.md`
4. 将日志和报告提交到项目 Issues。
