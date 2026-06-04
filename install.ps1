<#
.SYNOPSIS
    AI Local Environment Checker & Installer (Beta)
.DESCRIPTION
    自动检测并安装本地 AI 编程开发环境。
    支持检测：系统信息、Node.js、npm、Git、VS Code、Claude Code、Codex CLI、WSL。
    支持安装：通过 winget 和 npm 安装缺失组件。
    支持修复：用户级 PATH 环境变量。
.NOTES
    版本: 0.2.0-beta
    平台: Windows (PowerShell 5.1+)
    作者: YUCZ-43
.EXAMPLE
    .\install.ps1 -CheckOnly
    .\install.ps1 -CheckOnly -CommandTimeoutSec 10
    .\install.ps1 -CheckOnly -Language en-US
    .\install.ps1 -Install
    .\install.ps1 -Install -FixPath
    .\install.ps1 -Install -FixPath -SkipCodex -VerboseLog
#>

[CmdletBinding(DefaultParameterSetName = "CheckOnly")]
param(
    [Parameter(ParameterSetName = "CheckOnly")]
    [switch]$CheckOnly,

    [Parameter(ParameterSetName = "Install")]
    [switch]$Install,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$FixPath,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$VerboseLog,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$SkipCodex,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$SkipClaude,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$SkipVSCode,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$SkipWSL,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$SkipNetwork,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [int]$CommandTimeoutSec = 10,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [ValidateSet("zh-CN", "en-US")]
    [string]$Language = "zh-CN"
)

# ============================================
# 全局变量
# ============================================
$Script:ScriptVersion = "v0.2.0-cross-platform-i18n-proxy-detect"
$Script:Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Script:RunDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:LogDir = Join-Path $Script:ScriptDir "logs"
$Script:ReportDir = Join-Path $Script:ScriptDir "reports"
$Script:LogFile = Join-Path $Script:LogDir "run-$Script:Timestamp.log"
$Script:PathBackupFile = Join-Path $Script:LogDir "path-backup-$Script:Timestamp.txt"
$Script:JsonReportFile = Join-Path $Script:ReportDir "report-$Script:Timestamp.json"
$Script:MarkdownReportFile = Join-Path $Script:ReportDir "report-$Script:Timestamp.md"

$Script:Results = [ordered]@{}
$Script:InstallResults = [ordered]@{}
$Script:ErrorList = [System.Collections.ArrayList]::new()
$Script:WarningList = [System.Collections.ArrayList]::new()
$Script:FixSuggestionList = [System.Collections.ArrayList]::new()
$Script:CommandResults = @()
$Script:Language = $Language
$Script:Messages = @{}

$null = New-Item -ItemType Directory -Force -Path $Script:LogDir
$null = New-Item -ItemType Directory -Force -Path $Script:ReportDir

if (-not $Install -and -not $CheckOnly) { $CheckOnly = $true }

# ============================================
# 本地化与报告脱敏函数
# ============================================

function Initialize-Localization {
    param([string]$RequestedLanguage)

    $fallbackLanguage = "zh-CN"
    $localeDir = Join-Path $Script:ScriptDir "locales"
    $localePath = Join-Path $localeDir "$RequestedLanguage.json"
    if (-not (Test-Path -LiteralPath $localePath)) {
        $Script:Language = $fallbackLanguage
        $localePath = Join-Path $localeDir "$fallbackLanguage.json"
    }

    try {
        if (Test-Path -LiteralPath $localePath) {
            $json = Get-Content -Raw -Path $localePath -Encoding UTF8 | ConvertFrom-Json
            $messages = @{}
            foreach ($prop in $json.PSObject.Properties) {
                $messages[$prop.Name] = [string]$prop.Value
            }
            return $messages
        }
    } catch { }

    $Script:Language = $fallbackLanguage
    return @{}
}

function Get-LocalizedText {
    param([string]$Key)

    if ($Script:Messages -and $Script:Messages.ContainsKey($Key)) {
        return $Script:Messages[$Key]
    }
    return $Key
}

function ConvertTo-MaskedProxyValue {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return $null
    }

    return [regex]::Replace([string]$Value, '(?i)\b([a-z][a-z0-9+.-]*://)([^/@\s:]+):([^/@\s]+)@', '$1***:***@')
}

function ConvertTo-SafeReportObject {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string]) {
        return (ConvertTo-MaskedProxyValue $Value)
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $copy[$key] = ConvertTo-SafeReportObject $Value[$key]
        }
        return $copy
    }

    if (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string])) {
        $items = @()
        foreach ($item in $Value) {
            $items += ConvertTo-SafeReportObject $item
        }
        return $items
    }

    return $Value
}

function Import-ProxyDetectorModule {
    $modulePath = Join-Path $Script:ScriptDir "scripts\windows\modules\ProxyDetector.psm1"
    if (Test-Path -LiteralPath $modulePath) {
        Import-Module $modulePath -Force
        return $true
    }
    return $false
}

# ============================================
# 日志与状态输出函数
# ============================================

<#
.SYNOPSIS
    写入日志文件（并可选输出到控制台详细模式）
#>
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$Level] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $Script:LogFile -Value $line -Encoding UTF8
    if ($VerboseLog) {
        switch ($Level) {
            "ERROR"   { Write-Host $line -ForegroundColor Red }
            "WARN"    { Write-Host $line -ForegroundColor Yellow }
            "OK"      { Write-Host $line -ForegroundColor Green }
            "TIMEOUT" { Write-Host $line -ForegroundColor Yellow }
            default   { Write-Host $line -ForegroundColor Gray }
        }
    }
}

<#
.SYNOPSIS
    向控制台输出带颜色状态标签的行
#>
function Write-Status {
    param([string]$Status, [string]$Message)
    $label = Get-LocalizedText $Status
    $prefix = "[ {0,-7}] " -f $label
    switch ($Status) {
        "OK"       { Write-Host $prefix -ForegroundColor Green -NoNewline; Write-Host $Message }
        "MISSING"  { Write-Host $prefix -ForegroundColor Red -NoNewline; Write-Host $Message }
        "WARNING"  { Write-Host $prefix -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "ERROR"    { Write-Host $prefix -ForegroundColor DarkRed -NoNewline; Write-Host $Message }
        "SKIPPED"  { Write-Host $prefix -ForegroundColor DarkGray -NoNewline; Write-Host $Message }
        "INSTALL"  { Write-Host $prefix -ForegroundColor Cyan -NoNewline; Write-Host $Message }
        "FIX"      { Write-Host $prefix -ForegroundColor Magenta -NoNewline; Write-Host $Message }
        "TIMEOUT"  { Write-Host $prefix -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        default    { Write-Host "[ INFO   ] " -ForegroundColor Gray -NoNewline; Write-Host $Message }
    }
}

# ============================================
# Invoke-ExternalCommand - 带超时的外部命令执行
# 兼容 Windows PowerShell 5.1
# 使用 System.Diagnostics.Process 避免卡住
# ============================================

function Resolve-WindowsCommandPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CommandName,

        [Parameter(Mandatory=$false)]
        [string[]]$PreferredExtensions = @(".cmd", ".bat", ".exe", "")
    )

    if (-not $CommandName) {
        return $null
    }

    $candidateSet = New-Object System.Collections.ArrayList

    function Add-CommandCandidate {
        param([string]$Path)
        if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf) -and -not $candidateSet.Contains($Path)) {
            [void]$candidateSet.Add($Path)
        }
    }

    $hasDirectory = ($CommandName -match '[\\/]') -or [System.IO.Path]::IsPathRooted($CommandName)
    $extension = [System.IO.Path]::GetExtension($CommandName)

    if ($hasDirectory) {
        if ($extension) {
            Add-CommandCandidate $CommandName
        } else {
            foreach ($ext in $PreferredExtensions) {
                Add-CommandCandidate "$CommandName$ext"
            }
            Add-CommandCandidate $CommandName
        }
    } else {
        $names = @()
        if ($extension) {
            $names += $CommandName
        } else {
            foreach ($ext in $PreferredExtensions) {
                $names += "$CommandName$ext"
            }
            $names += $CommandName
        }

        $pathEntries = @()
        if ($env:PATH) {
            $pathEntries = $env:PATH -split ';' | Where-Object { $_ -and $_.Trim() -ne "" }
        }

        foreach ($dir in $pathEntries) {
            foreach ($name in $names) {
                Add-CommandCandidate (Join-Path $dir.Trim() $name)
            }
        }

        try {
            $commands = Get-Command $CommandName -CommandType Application -ErrorAction SilentlyContinue
            foreach ($cmd in $commands) {
                if ($cmd.Path) {
                    Add-CommandCandidate $cmd.Path
                } elseif ($cmd.Source) {
                    Add-CommandCandidate $cmd.Source
                }
            }
        } catch { }
    }

    foreach ($ext in $PreferredExtensions) {
        $match = $candidateSet | Where-Object {
            if ($ext -eq "") {
                [System.IO.Path]::GetExtension($_) -eq ""
            } else {
                [System.IO.Path]::GetExtension($_).Equals($ext, [System.StringComparison]::OrdinalIgnoreCase)
            }
        } | Select-Object -First 1
        if ($match) {
            return $match
        }
    }

    return ($candidateSet | Select-Object -First 1)
}

<#
.SYNOPSIS
    使用 System.Diagnostics.Process 执行外部命令，带超时保护。
.DESCRIPTION
    每个外部命令最多等待 TimeoutSec 秒。
    超时后强制终止进程并返回 TIMEOUT 状态。
    命令不存在时返回 ERROR 状态并注明 command not found。
    所有调用都会写入 $Script:CommandResults 和日志文件。
.PARAMETER FileName
    要执行的程序路径或名称。
.PARAMETER Arguments
    传递给程序的参数字符串。
.PARAMETER TimeoutSec
    最大等待秒数。默认使用全局 $CommandTimeoutSec。
.EXAMPLE
    $r = Invoke-ExternalCommand -FileName "node" -Arguments "-v" -TimeoutSec 10
#>
function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,

        [Parameter(Mandatory=$false)]
        [string]$Arguments = "",

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSec = -1
    )

    # 使用默认超时
    if ($TimeoutSec -le 0) {
        $TimeoutSec = $CommandTimeoutSec
    }

    $startTime = Get-Date
    $executionFile = Resolve-WindowsCommandPath -CommandName $FileName
    if (-not $executionFile) {
        $executionFile = $FileName
    }

    # .cmd / .bat 文件必须通过 cmd.exe 包装执行，否则在 PowerShell 5.1 下
    # System.Diagnostics.Process 会错误解析工作目录，导致 npm.cmd 去当前
    # 项目目录下查找 .\node_modules\npm\bin\npm-prefix.js
    $isCmdBat = $executionFile -match '\.(cmd|bat)$'
    $argumentSuffix = if ($Arguments) { " $Arguments" } else { "" }

    if ($isCmdBat) {
        $commandStr = "cmd.exe /d /s /c `"`"$executionFile`"$argumentSuffix`""
    } else {
        $commandStr = $executionFile
        if ($Arguments) {
            $commandStr = "$executionFile $Arguments"
        }
    }

    # 构建 ProcessStartInfo
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($isCmdBat) {
        $psi.FileName = "cmd.exe"
        $psi.Arguments = "/d /s /c `"`"$executionFile`"$argumentSuffix`""
    } else {
        $psi.FileName = $executionFile
        $psi.Arguments = $Arguments
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    $stdOut = ""
    $stdErr = ""
    $exitCode = $null
    $status = "OK"

    try {
        $process.Start() | Out-Null

        $completed = $process.WaitForExit($TimeoutSec * 1000)

        if (-not $completed) {
            # 超时 - 强制终止进程
            try { $process.Kill() } catch { }
            $process.WaitForExit(2000) | Out-Null
            $status = "TIMEOUT"
            $exitCode = $null
        }

        # 读取输出（进程已退出或被终止）
        try {
            $stdOut = $process.StandardOutput.ReadToEnd()
            if ($stdOut) { $stdOut = $stdOut.Trim() }
        } catch {
            $stdOut = ""
        }

        try {
            $stdErr = $process.StandardError.ReadToEnd()
            if ($stdErr) { $stdErr = $stdErr.Trim() }
        } catch {
            $stdErr = ""
        }

        if ($status -ne "TIMEOUT") {
            $exitCode = $process.ExitCode
            if ($exitCode -eq 0) {
                $status = "OK"
            } else {
                $status = "ERROR"
            }
        }
    } catch [System.ComponentModel.Win32Exception] {
        # 命令不存在
        $status = "ERROR"
        $exitCode = $null
        $stdErr = "command not found: $FileName"
    } catch {
        $status = "ERROR"
        $exitCode = $null
        $stdErr = $_.Exception.Message
    } finally {
        if ($process) {
            try {
                if (-not $process.HasExited) {
                    $process.Kill()
                }
            } catch { }
        }
    }

    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 1)

    $result = @{
        Command    = $commandStr
        FileName   = $FileName
        ResolvedFileName = $executionFile
        Arguments  = $Arguments
        ExitCode   = $exitCode
        StdOut     = $stdOut
        StdErr     = $stdErr
        Status     = $status
        ElapsedMs  = $elapsed
    }

    # 记录到全局命令结果列表
    $Script:CommandResults += $result

    # 写入日志
    Write-Log "CMD [$status] $commandStr (${elapsed}ms)" -Level $status

    return $result
}

<#
.SYNOPSIS
    清理外部命令输出中的特殊字符（NUL、BOM、异常空白等）
.DESCRIPTION
    Windows 中文系统下 wsl 等命令可能输出 NUL 字符、BOM 标记或特殊编码内容。
    此函数移除这些干扰字符，同时保留原始输出用于日志记录。
#>
function Normalize-CommandOutput {
    param([string]$Raw)

    if (-not $Raw) { return "" }

    $cleaned = $Raw

    # 移除 NUL 字符 (0x00)
    $cleaned = $cleaned -replace "`0", ""

    # 移除 BOM (0xFEFF, 0xFFFE) - Windows PowerShell 5.1 compatible
    $cleaned = $cleaned.Replace([string][char]0xFEFF, "")
    $cleaned = $cleaned.Replace([string][char]0xFFFE, "")

    # 移除其他不可打印控制字符（保留常见空白和换行）
    # 0x00-0x08, 0x0B, 0x0C, 0x0E-0x1F, 0x7F-0x9F
    $cleaned = $cleaned -replace "[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]", ""

    # 规范化行尾
    $cleaned = $cleaned -replace "`r`n", "`n"
    $cleaned = $cleaned -replace "`r", "`n"

    # Trim 首尾空白
    $cleaned = $cleaned.Trim()

    return $cleaned
}

# ============================================
# 基础检测函数
# ============================================

<#
.SYNOPSIS
    检测当前是否以管理员权限运行
#>
function Test-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        Write-Log "Admin check: $isAdmin"
        return $isAdmin
    } catch {
        Write-Log "Admin check failed: $_" -Level "ERROR"
        return $false
    }
}

<#
.SYNOPSIS
    获取系统信息
#>
function Get-SystemInfo {
    Write-Log "Collecting system information..."
    $info = @{}
    try {
        $info.PSVersion = $PSVersionTable.PSVersion.ToString()
        $info.PSEdition = $PSVersionTable.PSEdition
        $info.OSVersion = [Environment]::OSVersion.VersionString
        try {
            $cs = Get-ComputerInfo -Property WindowsProductName, WindowsVersion, OsArchitecture -ErrorAction Stop
            $info.WindowsProductName = $cs.WindowsProductName
            $info.WindowsVersion = $cs.WindowsVersion
            $info.OsArchitecture = $cs.OsArchitecture
        } catch {
            $info.WindowsProductName = [Environment]::OSVersion.VersionString
            $info.WindowsVersion = [Environment]::OSVersion.Version.ToString()
            $info.OsArchitecture = [Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
        }
        $info.ComputerName = $env:COMPUTERNAME
        $info.UserName = $env:USERNAME
        $info.UserDomain = $env:USERDOMAIN
        $info.ExecutionPolicy = (Get-ExecutionPolicy -List | Select-Object Scope, ExecutionPolicy)
        Write-Log "System info collected: $($info.WindowsProductName) $($info.WindowsVersion)"
    } catch {
        Write-Log "System info error: $_" -Level "ERROR"
        $Script:ErrorList.Add("获取系统信息失败: $_") > $null
    }
    return $info
}

<#
.SYNOPSIS
    使用 TCP 连接检测网络连通性（不依赖 ICMP/Ping）
#>
function Test-Network {
    param([string]$HostName, [int]$Port = 443, [string]$Label = $HostName)
    Write-Log "Testing network (TCP): $HostName`:$Port"
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($HostName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
        if ($wait) {
            $tcp.EndConnect($connect)
            $tcp.Close()
            Write-Status "OK" "$Label : reachable"
            Write-Log "$Label reachable" -Level "OK"
            return @{ Host = $HostName; Port = $Port; Reachable = $true }
        } else {
            $tcp.Close()
            Write-Status "WARNING" "$Label : unreachable"
            Write-Log "$Label unreachable" -Level "WARN"
            $Script:WarningList.Add("$Label 不可达，可能影响安装") > $null
            return @{ Host = $HostName; Port = $Port; Reachable = $false }
        }
    } catch {
        Write-Status "WARNING" "$Label : test failed ($_)"
        Write-Log "$Label test failed: $_" -Level "WARN"
        return @{ Host = $HostName; Port = $Port; Reachable = $false }
    }
}

<#
.SYNOPSIS
    批量检测网络连通性
#>
function Test-AllNetwork {
    if ($SkipNetwork) {
        Write-Host ""
        Write-Host "--- $(Get-LocalizedText 'section.network') ---" -ForegroundColor Cyan
        Write-Host ""
        Write-Status "SKIPPED" "Network check skipped by user (-SkipNetwork)"
        Write-Log "Network check skipped by -SkipNetwork"
        $Script:Results.Network = @{ AllReachable = $null; Targets = @(); Skipped = $true }
        return
    }
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.network') ---" -ForegroundColor Cyan
    Write-Host ""
    $targets = @(
        @{ HostName = "github.com"; Port = 443; Label = "GitHub" },
        @{ HostName = "registry.npmjs.org"; Port = 443; Label = "NPM Registry" },
        @{ HostName = "npmjs.com"; Port = 443; Label = "npmjs.com" },
        @{ HostName = "claude.ai"; Port = 443; Label = "Claude AI" },
        @{ HostName = "chatgpt.com"; Port = 443; Label = "ChatGPT" }
    )
    $allReachable = $true
    $netResults = @()
    foreach ($t in $targets) {
        $r = Test-Network -HostName $t.HostName -Port $t.Port -Label $t.Label
        $netResults += $r
        if (-not $r.Reachable) { $allReachable = $false }
    }
    $Script:Results.Network = @{
        AllReachable = $allReachable
        Targets = $netResults
    }
    if (-not $allReachable) {
        $Script:FixSuggestionList.Add("网络部分不可达，请检查防火墙/代理设置") > $null
    }
}

# ============================================
# 代理检测函数
# ============================================

<#
.SYNOPSIS
    检测系统代理设置（只读，不修改）
#>
function Test-ProxySettings {
    Write-Host ""
    Write-Host "--- Proxy Settings ---" -ForegroundColor Cyan
    Write-Host ""
    Write-Log "Collecting proxy settings..."

    $proxyInfo = @{}

    # 1. 环境变量代理
    $envVars = @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")
    $envProxies = @{}
    foreach ($var in $envVars) {
        $val = $null
        $val = [Environment]::GetEnvironmentVariable($var)
        if (-not $val) {
            $val = [Environment]::GetEnvironmentVariable($var, "User")
        }
        if (-not $val) {
            $val = [Environment]::GetEnvironmentVariable($var, "Machine")
        }
        if ($val) {
            $envProxies[$var] = $val
        }
    }
    if ($envProxies.Count -gt 0) {
        Write-Status "OK" "环境变量代理已设置"
        foreach ($k in $envProxies.Keys) {
            Write-Host "    $k = $($envProxies[$k])" -ForegroundColor Gray
            Write-Log "Proxy env: $k = $($envProxies[$k])"
        }
    } else {
        Write-Status "OK" "环境变量代理: 未设置"
        Write-Log "No environment proxy variables set"
    }
    $proxyInfo.Environment = $envProxies

    # 2. npm 代理 (使用 Invoke-ExternalCommand 带超时)
    $npmProxies = @{}
    $npmProxyResult = Invoke-ExternalCommand -FileName "npm.cmd" -Arguments "config get proxy"
    if ($npmProxyResult.Status -eq "OK" -and $npmProxyResult.StdOut) {
        $val = $npmProxyResult.StdOut.Trim()
        if ($val -ne "null" -and $val -ne "undefined" -and $val.Length -gt 0) {
            $npmProxies["proxy"] = $val
        }
    }
    $npmHttpsResult = Invoke-ExternalCommand -FileName "npm.cmd" -Arguments "config get https-proxy"
    if ($npmHttpsResult.Status -eq "OK" -and $npmHttpsResult.StdOut) {
        $val = $npmHttpsResult.StdOut.Trim()
        if ($val -ne "null" -and $val -ne "undefined" -and $val.Length -gt 0) {
            $npmProxies["https-proxy"] = $val
        }
    }
    if ($npmProxies.Count -gt 0) {
        Write-Status "OK" "npm 代理已配置"
        foreach ($k in $npmProxies.Keys) {
            Write-Host "    npm $k = $($npmProxies[$k])" -ForegroundColor Gray
            Write-Log "npm proxy: $k = $($npmProxies[$k])"
        }
    } else {
        Write-Status "OK" "npm 代理: 未配置"
        Write-Log "No npm proxy configured"
    }
    $proxyInfo.Npm = $npmProxies

    # 3. Git 代理 (使用 Invoke-ExternalCommand 带超时)
    $gitProxies = @{}
    $gitHttpResult = Invoke-ExternalCommand -FileName "git" -Arguments "config --global --get http.proxy"
    if ($gitHttpResult.Status -eq "OK" -and $gitHttpResult.StdOut) {
        $gitProxies["http.proxy"] = $gitHttpResult.StdOut.Trim()
    }
    $gitHttpsResult = Invoke-ExternalCommand -FileName "git" -Arguments "config --global --get https.proxy"
    if ($gitHttpsResult.Status -eq "OK" -and $gitHttpsResult.StdOut) {
        $gitProxies["https.proxy"] = $gitHttpsResult.StdOut.Trim()
    }
    if ($gitProxies.Count -gt 0) {
        Write-Status "OK" "Git 代理已配置"
        foreach ($k in $gitProxies.Keys) {
            Write-Host "    git $k = $($gitProxies[$k])" -ForegroundColor Gray
            Write-Log "git proxy: $k = $($gitProxies[$k])"
        }
    } else {
        Write-Status "OK" "Git 代理: 未配置"
        Write-Log "No git proxy configured"
    }
    $proxyInfo.Git = $gitProxies

    # 4. WinHTTP 代理 (使用 Invoke-ExternalCommand 带超时)
    $winhttpResult = Invoke-ExternalCommand -FileName "netsh" -Arguments "winhttp show proxy"
    if ($winhttpResult.Status -eq "OK" -or $winhttpResult.Status -eq "ERROR") {
        $winhttpText = $winhttpResult.StdOut
        if (-not $winhttpText) { $winhttpText = $winhttpResult.StdErr }
        if ($winhttpText -match "Proxy Server") {
            Write-Status "OK" "WinHTTP 代理已设置"
            $lines = $winhttpText -split "`r`n" | Where-Object { $_ -match '\S' }
            foreach ($line in $lines) {
                Write-Host "    $($line.Trim())" -ForegroundColor Gray
            }
            Write-Log "WinHTTP proxy: $winhttpText"
        } else {
            Write-Status "OK" "WinHTTP 代理: 直接连接（无代理）"
            Write-Log "WinHTTP proxy: direct (no proxy)"
        }
        $proxyInfo.WinHTTP = $winhttpText.Trim()
    } else {
        Write-Status "WARNING" "WinHTTP 代理: 检测超时或失败"
        Write-Log "WinHTTP proxy detection failed: $($winhttpResult.Status)" -Level "WARN"
        $proxyInfo.WinHTTP = "detection $($winhttpResult.Status)"
    }

    $Script:Results.Proxy = $proxyInfo
    Write-Log "Proxy detection completed"
}

# ============================================
# 组件检测函数
# ============================================

<#
.SYNOPSIS
    检测 winget（只执行 winget --version，不刷完整帮助页）
#>
function Test-Winget {
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.packageManager') ---" -ForegroundColor Cyan
    Write-Host ""

    $r = Invoke-ExternalCommand -FileName "winget" -Arguments "--version"

    if ($r.Status -eq "OK") {
        $ver = if ($r.StdOut) { $r.StdOut } else { "unknown" }
        Write-Status "OK" "winget : $ver"
        Write-Log "winget found: $ver" -Level "OK"
        $Script:Results.Winget = @{ Exists = $true; Version = $ver; Path = $r.FileName }
        return @{ Exists = $true; Version = $ver }
    } elseif ($r.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "winget : exceeded $CommandTimeoutSec seconds, skipped"
        Write-Log "winget detection timed out" -Level "WARN"
        $Script:Results.Winget = @{ Exists = $false; Version = $null; Path = $null; TimedOut = $true }
        $Script:WarningList.Add("winget 检测超时") > $null
        return @{ Exists = $false; Version = $null }
    } else {
        Write-Status "MISSING" "winget : not found"
        Write-Log "winget not found: $($r.StdErr)" -Level "ERROR"
        $Script:ErrorList.Add("winget 未安装，部分自动安装功能不可用") > $null
        $Script:FixSuggestionList.Add("从 Microsoft Store 安装 App Installer 以获取 winget") > $null
        $Script:Results.Winget = @{ Exists = $false; Version = $null; Path = $null }
        return @{ Exists = $false; Version = $null }
    }
}

<#
.SYNOPSIS
    检测 Node.js 和 npm（完整 8 步检测，每步都有超时）
#>
function Test-Node {
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.node') ---" -ForegroundColor Cyan
    Write-Host ""

    $nodeResults = @{}

    # Step 1: where.exe node
    $step1 = Invoke-ExternalCommand -FileName "where.exe" -Arguments "node"
    if ($step1.Status -eq "OK") {
        $nodePath = $step1.StdOut -split "`r`n" | Select-Object -First 1
        Write-Status "OK" "node path : $nodePath"
        $nodeResults.NodePath = $nodePath
    } elseif ($step1.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "node path : exceeded $CommandTimeoutSec seconds, skipped"
        $nodeResults.NodePath = $null
    } else {
        Write-Status "MISSING" "node path : $($step1.StdErr)"
        $nodeResults.NodePath = $null
    }

    # Step 2: node -v
    $step2 = Invoke-ExternalCommand -FileName "node" -Arguments "-v"
    if ($step2.Status -eq "OK") {
        $nodeVer = $step2.StdOut
        Write-Status "OK" "node version : $nodeVer"
        $nodeResults.NodeVersion = $nodeVer
        $nodeResults.NodeExists = $true
    } elseif ($step2.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "node version : exceeded $CommandTimeoutSec seconds, skipped"
        $nodeResults.NodeVersion = $null
        $nodeResults.NodeExists = $false
    } else {
        Write-Status "MISSING" "node version : $($step2.StdErr)"
        $nodeResults.NodeVersion = $null
        $nodeResults.NodeExists = $false
    }

    if (-not $nodeResults.NodeExists) {
        $Script:FixSuggestionList.Add("安装 Node.js: winget install -e --id OpenJS.NodeJS.LTS") > $null
    }

    # Step 3: where.exe npm.cmd（Windows 下必须优先查找 .cmd 文件）
    $step3 = Invoke-ExternalCommand -FileName "where.exe" -Arguments "npm.cmd"
    if ($step3.Status -eq "OK") {
        $npmCmdPath = $step3.StdOut -split "`r`n" | Select-Object -First 1
        Write-Status "OK" "npm path : $npmCmdPath"
        $nodeResults.NpmPath = $npmCmdPath
    } elseif ($step3.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "npm path : exceeded $CommandTimeoutSec seconds, skipped"
        $nodeResults.NpmPath = $null
        $npmCmdPath = $null
    } else {
        Write-Status "MISSING" "npm path : $($step3.StdErr)"
        $nodeResults.NpmPath = $null
        $npmCmdPath = $null
    }

    # Step 4: npm.cmd -v（使用绝对路径，避免工作目录干扰）
    $npmCmdFile = if ($npmCmdPath) { $npmCmdPath } else { "npm.cmd" }
    $step4 = Invoke-ExternalCommand -FileName $npmCmdFile -Arguments "-v"
    if ($step4.Status -eq "OK") {
        $npmVer = $step4.StdOut
        Write-Status "OK" "npm version : $npmVer"
        $nodeResults.NpmVersion = $npmVer
        $nodeResults.NpmExists = $true
    } elseif ($step4.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "npm version : exceeded $CommandTimeoutSec seconds, skipped"
        $nodeResults.NpmVersion = $null
        $nodeResults.NpmExists = $false
    } else {
        Write-Status "MISSING" "npm version : $($step4.StdErr)"
        $nodeResults.NpmVersion = $null
        $nodeResults.NpmExists = $false
    }

    # Step 5: npm config get prefix
    $step5 = Invoke-ExternalCommand -FileName $npmCmdFile -Arguments "config get prefix"
    if ($step5.Status -eq "OK") {
        $prefix = $step5.StdOut
        Write-Status "OK" "npm prefix : $prefix"
        $nodeResults.NpmPrefix = $prefix
    } elseif ($step5.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "npm prefix : exceeded $CommandTimeoutSec seconds, skipped"
        $nodeResults.NpmPrefix = $null
    } else {
        Write-Status "WARNING" "npm prefix : unable to determine ($($step5.StdErr))"
        $nodeResults.NpmPrefix = $null
    }

    # Step 6: npm root -g
    $step6 = Invoke-ExternalCommand -FileName $npmCmdFile -Arguments "root -g"
    if ($step6.Status -eq "OK") {
        $globalRoot = $step6.StdOut
        Write-Status "OK" "npm root -g : $globalRoot"
        $nodeResults.NpmGlobalRoot = $globalRoot
    } elseif ($step6.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "npm root -g : exceeded $CommandTimeoutSec seconds, skipped"
        $nodeResults.NpmGlobalRoot = $null
    } else {
        Write-Status "WARNING" "npm root -g : unable to determine ($($step6.StdErr))"
        $nodeResults.NpmGlobalRoot = $null
    }

    # Step 7: npm config get proxy
    $step7 = Invoke-ExternalCommand -FileName $npmCmdFile -Arguments "config get proxy"
    if ($step7.Status -eq "OK") {
        $proxyVal = $step7.StdOut
        if ($proxyVal -and $proxyVal -ne "null" -and $proxyVal -ne "undefined") {
            Write-Status "OK" "npm proxy : $proxyVal"
            $nodeResults.NpmProxy = $proxyVal
        } else {
            Write-Status "OK" "npm proxy : (not set)"
            $nodeResults.NpmProxy = $null
        }
    } elseif ($step7.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "npm proxy : exceeded $CommandTimeoutSec seconds, skipped"
        $nodeResults.NpmProxy = $null
    } else {
        Write-Status "WARNING" "npm proxy : unable to determine"
        $nodeResults.NpmProxy = $null
    }

    # Step 8: npm config get https-proxy
    $step8 = Invoke-ExternalCommand -FileName $npmCmdFile -Arguments "config get https-proxy"
    if ($step8.Status -eq "OK") {
        $httpsProxyVal = $step8.StdOut
        if ($httpsProxyVal -and $httpsProxyVal -ne "null" -and $httpsProxyVal -ne "undefined") {
            Write-Status "OK" "npm https-proxy : $httpsProxyVal"
            $nodeResults.NpmHttpsProxy = $httpsProxyVal
        } else {
            Write-Status "OK" "npm https-proxy : (not set)"
            $nodeResults.NpmHttpsProxy = $null
        }
    } elseif ($step8.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "npm https-proxy : exceeded $CommandTimeoutSec seconds, skipped"
        $nodeResults.NpmHttpsProxy = $null
    } else {
        Write-Status "WARNING" "npm https-proxy : unable to determine"
        $nodeResults.NpmHttpsProxy = $null
    }

    $Script:Results.Node = $nodeResults
    return $nodeResults
}

<#
.SYNOPSIS
    检测 Git
#>
function Test-Git {
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.git') ---" -ForegroundColor Cyan
    Write-Host ""

    $result = @{}

    # where.exe git
    $whereResult = Invoke-ExternalCommand -FileName "where.exe" -Arguments "git"
    if ($whereResult.Status -eq "OK") {
        $gitPath = $whereResult.StdOut -split "`r`n" | Select-Object -First 1
        Write-Status "OK" "git path : $gitPath"
        $result.Path = $gitPath
    } elseif ($whereResult.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "git path : exceeded $CommandTimeoutSec seconds, skipped"
        $result.Path = $null
    } else {
        $result.Path = $null
    }

    # git --version
    $verResult = Invoke-ExternalCommand -FileName "git" -Arguments "--version"
    if ($verResult.Status -eq "OK") {
        Write-Status "OK" "Git : $($verResult.StdOut)"
        Write-Log "Git found: $($verResult.StdOut)" -Level "OK"
        $result.Exists = $true
        $result.Version = $verResult.StdOut
    } elseif ($verResult.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "Git : exceeded $CommandTimeoutSec seconds, skipped"
        Write-Log "Git detection timed out" -Level "WARN"
        $result.Exists = $false
        $result.Version = $null
    } else {
        Write-Status "MISSING" "Git : not found"
        Write-Log "Git not found" -Level "ERROR"
        $Script:FixSuggestionList.Add("安装 Git: winget install -e --id Git.Git") > $null
        $result.Exists = $false
        $result.Version = $null
    }

    $Script:Results.Git = $result
    return $result
}

<#
.SYNOPSIS
    检测 VS Code 和 code 命令
#>
function Test-VSCode {
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.vscode') ---" -ForegroundColor Cyan
    Write-Host ""

    if ($SkipVSCode) {
        Write-Status "SKIPPED" "VS Code : skipped by user"
        Write-Log "VS Code skipped by -SkipVSCode"
        $Script:Results.VSCode = @{ Exists = $false; Skipped = $true }
        return @{ Exists = $false; Skipped = $true }
    }

    $result = @{}

    # where.exe code
    $whereResult = Invoke-ExternalCommand -FileName "where.exe" -Arguments "code"
    if ($whereResult.Status -eq "OK") {
        $codePath = $whereResult.StdOut -split "`r`n" | Select-Object -First 1
        Write-Status "OK" "code path : $codePath"
        $result.Path = $codePath
    } elseif ($whereResult.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "code path : exceeded $CommandTimeoutSec seconds, skipped"
        $result.Path = $null
    } else {
        $result.Path = $null
    }

    # code --version
    $verResult = Invoke-ExternalCommand -FileName "code" -Arguments "--version"
    if ($verResult.Status -eq "OK") {
        $firstLine = $verResult.StdOut -split "`r`n" | Select-Object -First 1
        Write-Status "OK" "VS Code CLI : $firstLine"
        Write-Log "code found: $firstLine" -Level "OK"
        $result.Exists = $true
        $result.Version = $firstLine
    } elseif ($verResult.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "VS Code CLI : exceeded $CommandTimeoutSec seconds, skipped"
        Write-Log "code detection timed out" -Level "WARN"
        $result.Exists = $false
        $result.Version = $null
    } else {
        Write-Status "WARNING" "VS Code CLI : code command not found in PATH"
        Write-Log "code command not found" -Level "WARN"
        $Script:FixSuggestionList.Add("VS Code CLI 不在 PATH 中，运行 -FixPath 修复") > $null
        $result.Exists = $false
        $result.Version = $null
    }

    $result.Skipped = $false
    $Script:Results.VSCode = $result
    return $result
}

<#
.SYNOPSIS
    检测 Claude Code CLI
#>
function Test-ClaudeCode {
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.claude') ---" -ForegroundColor Cyan
    Write-Host ""

    if ($SkipClaude) {
        Write-Status "SKIPPED" "Claude Code : skipped by user"
        Write-Log "Claude Code skipped by -SkipClaude"
        $Script:Results.ClaudeCode = @{ Exists = $false; Skipped = $true }
        return @{ Exists = $false; Skipped = $true }
    }

    $result = @{}

    # where.exe claude
    $whereResult = Invoke-ExternalCommand -FileName "where.exe" -Arguments "claude"
    if ($whereResult.Status -eq "OK") {
        $claudePath = $whereResult.StdOut -split "`r`n" | Select-Object -First 1
        Write-Status "OK" "claude path : $claudePath"
        $result.Path = $claudePath
    } elseif ($whereResult.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "claude path : exceeded $CommandTimeoutSec seconds, skipped"
        $result.Path = $null
    } else {
        $result.Path = $null
    }

    # claude --version
    $verResult = Invoke-ExternalCommand -FileName "claude" -Arguments "--version"
    if ($verResult.Status -eq "OK") {
        Write-Status "OK" "Claude Code : $($verResult.StdOut)"
        Write-Log "claude found: $($verResult.StdOut)" -Level "OK"
        $result.Exists = $true
        $result.Version = $verResult.StdOut
    } elseif ($verResult.Status -eq "TIMEOUT") {
        Write-Status "TIMEOUT" "Claude Code : exceeded $CommandTimeoutSec seconds, skipped"
        Write-Log "claude detection timed out" -Level "WARN"
        $result.Exists = $false
        $result.Version = $null
    } else {
        Write-Status "MISSING" "Claude Code : not found"
        Write-Log "claude not found" -Level "ERROR"
        $Script:FixSuggestionList.Add("安装 Claude Code: npm install -g @anthropic-ai/claude-code") > $null
        $result.Exists = $false
        $result.Version = $null
    }

    $result.Skipped = $false
    $Script:Results.ClaudeCode = $result
    return $result
}

<#
.SYNOPSIS
    检测 Codex CLI
#>
function Test-CodexCLI {
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.codex') ---" -ForegroundColor Cyan
    Write-Host ""

    if ($SkipCodex) {
        Write-Status "SKIPPED" "Codex CLI : skipped by user"
        Write-Log "Codex CLI skipped by -SkipCodex"
        $Script:Results.CodexCLI = @{ Exists = $false; Skipped = $true }
        return @{ Exists = $false; Skipped = $true }
    }

    $result = @{
        Exists    = $false
        Path      = $null
        Version   = $null
        Source    = $null
        Status    = "MISSING"
        Skipped   = $false
        RawOutput = $null
        Error     = $null
    }

    $codexFile = $null
    $codexSource = $null

    # Step 1: where.exe codex
    $whereResult = Invoke-ExternalCommand -FileName "where.exe" -Arguments "codex"
    if ($whereResult.Status -eq "OK" -and $whereResult.StdOut) {
        $foundPath = ($whereResult.StdOut -split "`r`n" | Select-Object -First 1).Trim()
        if ($foundPath -and (Test-Path $foundPath)) {
            $codexFile = $foundPath
            $codexSource = "where.exe"
            Write-Log "codex found via where.exe: $codexFile"
        }
    }

    # Step 2: Get-Command codex（fallback）
    if (-not $codexFile) {
        try {
            $gcm = Get-Command codex -ErrorAction Stop 2>$null
            if ($gcm) {
                $gcmPath = if ($gcm.Source) { $gcm.Source } else { $gcm.Path }
                if ($gcmPath -and (Test-Path $gcmPath)) {
                    $codexFile = $gcmPath
                    $codexSource = "Get-Command"
                    Write-Log "codex found via Get-Command: $codexFile"
                }
            }
        } catch {
            Write-Log "Get-Command codex: not found"
        }
    }

    # Step 3: 常见 npm 全局路径 + 本地安装路径
    if (-not $codexFile) {
        $searchPaths = @(
            "$env:APPDATA\npm\codex.cmd",
            "$env:APPDATA\npm\codex.ps1",
            "$env:APPDATA\npm\codex",
            "$env:LOCALAPPDATA\Programs\codex\codex.exe",
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\codex.exe"
        )
        foreach ($sp in $searchPaths) {
            if (Test-Path $sp) {
                $codexFile = $sp
                $codexSource = "path-search"
                Write-Log "codex found via path search: $codexFile"
                break
            }
        }
    }

    # Step 4: 执行 codex --version 验证
    if ($codexFile) {
        $verResult = Invoke-ExternalCommand -FileName $codexFile -Arguments "--version"
        $verifiedCodexPath = if ($verResult.ResolvedFileName) { $verResult.ResolvedFileName } else { $codexFile }

        if ($verResult.Status -eq "OK") {
            $verOutput = Normalize-CommandOutput $verResult.StdOut
            Write-Status "OK" "codex path : $verifiedCodexPath"
            Write-Status "OK" "codex version : $verOutput"
            Write-Log "codex version: $verOutput" -Level "OK"
            $result.Exists = $true
            $result.Path = $verifiedCodexPath
            $result.Version = $verOutput
            $result.Source = $codexSource
            $result.Status = "OK"
        } elseif ($verResult.Status -eq "TIMEOUT") {
            Write-Status "OK" "codex path : $verifiedCodexPath"
            Write-Status "TIMEOUT" "codex version : exceeded $CommandTimeoutSec seconds, skipped"
            Write-Log "codex --version timed out" -Level "WARN"
            $result.Exists = $true
            $result.Path = $verifiedCodexPath
            $result.Version = $null
            $result.Source = $codexSource
            $result.Status = "PARTIAL"
            $result.Error = "version check timed out"
        } else {
            Write-Status "OK" "codex path : $verifiedCodexPath"
            Write-Status "WARNING" "codex version : failed ($($verResult.StdErr))"
            Write-Log "codex --version failed: $($verResult.StdErr)" -Level "WARN"
            $result.Exists = $true
            $result.Path = $verifiedCodexPath
            $result.Version = $null
            $result.Source = $codexSource
            $result.Status = "PARTIAL"
            $result.Error = $verResult.StdErr
        }
        $result.RawOutput = $verResult.StdOut
    } else {
        # 任何路径都没有找到 codex CLI
        Write-Status "PARTIAL" "Codex app may exist, but codex CLI is not available in PATH."
        Write-Log "codex CLI not found in PATH or common locations" -Level "WARN"
        $Script:FixSuggestionList.Add("Codex CLI 未在 PATH 中找到，请运行官方安装脚本或检查安装") > $null
        $result.Status = "PARTIAL"
        $result.Error = "codex CLI not found in PATH"
    }

    $Script:Results.CodexCLI = $result
    return $result
}

<#
.SYNOPSIS
    检测 WSL
#>
function Test-WSL {
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.wsl') ---" -ForegroundColor Cyan
    Write-Host ""

    if ($SkipWSL) {
        Write-Status "SKIPPED" "WSL : skipped by user"
        Write-Log "WSL skipped by -SkipWSL"
        $Script:Results.WSL = @{ Exists = $false; Skipped = $true }
        return @{ Exists = $false; Skipped = $true }
    }

    $wslResult = @{
        Detected      = $false
        Status        = "MISSING"
        WslPath       = $null
        StatusOutput  = $null
        Distributions = @()
        RawOutput     = $null
        Error         = $null
        Skipped       = $false
    }

    # Step 1: where.exe wsl
    $whereResult = Invoke-ExternalCommand -FileName "where.exe" -Arguments "wsl"
    if ($whereResult.Status -eq "OK" -and $whereResult.StdOut) {
        $wslPath = ($whereResult.StdOut -split "`r`n" | Select-Object -First 1).Trim()
        if ($wslPath -and (Test-Path $wslPath)) {
            Write-Status "OK" "wsl path : $wslPath"
            $wslResult.WslPath = $wslPath
            $wslResult.Detected = $true
            Write-Log "wsl found at: $wslPath"
        }
    }

    # Fallback: 直接检查 System32\wsl.exe
    if (-not $wslResult.Detected) {
        $system32Wsl = "$($env:SystemRoot)\System32\wsl.exe"
        if (Test-Path $system32Wsl) {
            Write-Status "OK" "wsl path : $system32Wsl"
            $wslResult.WslPath = $system32Wsl
            $wslResult.Detected = $true
            Write-Log "wsl found at: $system32Wsl"
        }
    }

    if (-not $wslResult.Detected) {
        Write-Status "MISSING" "wsl : not found"
        Write-Log "wsl not found" -Level "WARN"
        $Script:FixSuggestionList.Add("WSL 未安装: 运行 'wsl --install' (需管理员权限)") > $null
        $wslResult.Status = "MISSING"
        $wslResult.Error = "wsl.exe not found"
        $Script:Results.WSL = $wslResult
        return $wslResult
    }

    $wslExe = $wslResult.WslPath

    # Step 2: wsl --status
    $statusResult = Invoke-ExternalCommand -FileName $wslExe -Arguments "--status"
    $statusOutput = ""
    if ($statusResult.Status -eq "OK") {
        $statusOutput = Normalize-CommandOutput $statusResult.StdOut
        Write-Log "wsl --status: $statusOutput"
    } else {
        Write-Log "wsl --status: $($statusResult.Status) - $($statusResult.StdErr)"
    }
    $wslResult.StatusOutput = $statusOutput

    # Step 3: wsl -l -v（获取发行版列表）
    $listResult = Invoke-ExternalCommand -FileName $wslExe -Arguments "-l -v"
    $rawList = ""
    if ($listResult.Status -eq "OK") {
        $rawList = Normalize-CommandOutput $listResult.StdOut
    }

    # Fallback: wsl --list --verbose
    if (-not $rawList) {
        $listResult2 = Invoke-ExternalCommand -FileName $wslExe -Arguments "--list --verbose"
        if ($listResult2.Status -eq "OK") {
            $rawList = Normalize-CommandOutput $listResult2.StdOut
        }
    }

    $wslResult.RawOutput = $rawList

    # 解析发行版列表（兼容中文系统，不依赖英文固定短语）
    $distros = @()
    if ($rawList) {
        $lines = $rawList -split "`n" | Where-Object { $_ -and $_.Trim() -ne "" }
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            # 跳过 Windows Subsystem for Linux 说明行
            if ($trimmed -match '^Windows Subsystem') { continue }
            # 跳过纯表头行（NAME / STATE / VERSION）
            if ($trimmed -match '^\s*(NAME|STATE|VERSION)\s+(NAME|STATE|VERSION)') { continue }
            # 提取发行版名称：行首可能有 * 标记，后面跟名称
            if ($trimmed -match '^\*?\s*(\S+)') {
                $distroName = $Matches[1]
                # 过滤掉明显不是发行版名称的关键词
                if ($distroName -notmatch '^(NAME|STATE|VERSION|Windows|Linux|适用|默认|Default)$') {
                    $distros += $distroName
                }
            }
        }
    }

    # 确定状态
    if ($distros.Count -gt 0) {
        Write-Status "OK" "wsl status : available"
        $distroList = $distros -join ", "
        Write-Status "OK" "WSL distributions : $distroList"
        # 打印发行版详细列表
        foreach ($line in ($rawList -split "`n" | Where-Object { $_.Trim() -ne "" })) {
            Write-Host "  $($line.Trim())" -ForegroundColor Gray
        }
        Write-Log "WSL distributions: $distroList" -Level "OK"
        $wslResult.Status = "OK"
        $wslResult.Distributions = $distros
    } else {
        Write-Status "OK" "wsl status : available"
        Write-Status "PARTIAL" "WSL installed, but no Linux distributions found."
        Write-Log "WSL installed but no distros found" -Level "WARN"
        $Script:FixSuggestionList.Add("WSL 已安装但没有 Linux 发行版，运行 'wsl --install' 安装") > $null
        $wslResult.Status = "PARTIAL"
        $wslResult.Distributions = @()
        $wslResult.Error = "no distributions found"
    }

    $Script:Results.WSL = $wslResult
    return $wslResult
}

<#
.SYNOPSIS
    检测 PowerShell 执行策略
#>
function Test-ExecutionPolicy {
    Write-Host ""
    Write-Host "--- PowerShell Execution Policy ---" -ForegroundColor Cyan
    Write-Host ""
    try {
        $policies = Get-ExecutionPolicy -List
        foreach ($p in $policies) {
            $scope = $p.Scope
            $policy = $p.ExecutionPolicy
            if ($policy -eq "Restricted" -or $policy -eq "AllSigned") {
                Write-Status "WARNING" "ExecutionPolicy [$scope] : $policy"
            } else {
                Write-Status "OK" "ExecutionPolicy [$scope] : $policy"
            }
        }
        Write-Log "Execution policies collected"
        $Script:Results.ExecutionPolicy = $policies | ForEach-Object { @{ Scope = $_.Scope; Policy = $_.ExecutionPolicy.ToString() } }
    } catch {
        Write-Status "ERROR" "ExecutionPolicy : unable to read"
        Write-Log "ExecutionPolicy error: $_" -Level "ERROR"
        $Script:Results.ExecutionPolicy = @()
    }
}

<#
.SYNOPSIS
    检测用户 PATH 环境变量
#>
function Test-UserPath {
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.path') ---" -ForegroundColor Cyan
    Write-Host ""
    try {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $processPath = $env:Path

        $pathEntries = @()
        if ($userPath) {
            $userPath -split ';' | Where-Object { $_ } | ForEach-Object { $pathEntries += $_ }
        }
        if ($machinePath) {
            $machinePath -split ';' | Where-Object { $_ } | ForEach-Object { $pathEntries += $_ }
        }

        # 检测关键路径是否在 PATH 中
        $checks = @(
            @{ Name = "npm global bin"; Path = "$env:APPDATA\npm"; Expected = $true },
            @{ Name = "VS Code bin"; Path = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"; Expected = $true },
            @{ Name = "Git cmd"; Path = "C:\Program Files\Git\cmd"; Expected = $true },
            @{ Name = "Node.js"; Path = "C:\Program Files\nodejs"; Expected = $true }
        )

        $pathResults = @()
        foreach ($check in $checks) {
            $found = $false
            if (Test-Path $check.Path) {
                foreach ($entry in $pathEntries) {
                    if ($entry.TrimEnd('\') -eq $check.Path.TrimEnd('\')) {
                        $found = $true
                        break
                    }
                }
                if ($found) {
                    Write-Status "OK" "PATH contains : $($check.Name) ($($check.Path))"
                } else {
                    Write-Status "WARNING" "PATH missing : $($check.Name) ($($check.Path))"
                    $Script:FixSuggestionList.Add("$($check.Path) 不在 PATH 中，运行 -FixPath 修复") > $null
                }
            } else {
                Write-Status "WARNING" "Directory not found: $($check.Path)"
            }
            $pathResults += @{ Name = $check.Name; Path = $check.Path; InPath = $found; DirExists = (Test-Path $check.Path) }
        }

        $Script:Results.PATH = @{
            UserPath = $userPath
            ProcessPath = $processPath
            Checks = $pathResults
        }
        Write-Log "PATH check completed"
    } catch {
        Write-Status "ERROR" "PATH : check failed ($_)"
        Write-Log "PATH check error: $_" -Level "ERROR"
        $Script:Results.PATH = @{ Error = $_.ToString() }
    }
}

<#
.SYNOPSIS
    检查指定路径是否在用户 PATH 中
#>
function Test-PathInUserPath {
    param([string]$PathToCheck)
    try {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $entries = $userPath -split ';' | Where-Object { $_ }
        foreach ($entry in $entries) {
            if ($entry.TrimEnd('\') -eq $PathToCheck.TrimEnd('\')) {
                return $true
            }
        }
        return $false
    } catch {
        return $false
    }
}

# ============================================
# PATH 修复函数
# ============================================

<#
.SYNOPSIS
    备份用户 PATH 到日志目录
#>
function Backup-UserPath {
    Write-Host ""
    Write-Host "--- PATH Backup ---" -ForegroundColor Cyan
    Write-Host ""
    try {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $backupContent = @"
# PATH Backup
# Date: $Script:RunDate
# User: $env:USERNAME
# Computer: $env:COMPUTERNAME

$userPath
"@
        Set-Content -Path $Script:PathBackupFile -Value $backupContent -Encoding UTF8
        Write-Status "OK" "PATH backed up to: $Script:PathBackupFile"
        Write-Log "PATH backed up to $Script:PathBackupFile" -Level "OK"
        return $true
    } catch {
        Write-Status "ERROR" "PATH backup failed: $_"
        Write-Log "PATH backup failed: $_" -Level "ERROR"
        return $false
    }
}

<#
.SYNOPSIS
    添加指定路径到用户 PATH（如不存在且目录存在）
#>
function Add-UserPath {
    param([string]$PathToAdd, [string]$Label = $PathToAdd)

    # 检查目录是否存在
    if (-not (Test-Path $PathToAdd)) {
        Write-Status "WARNING" "Directory does not exist, skipping: $PathToAdd"
        Write-Log "Add-UserPath: directory not found: $PathToAdd" -Level "WARN"
        return $false
    }

    # 检查是否已在 PATH 中
    if (Test-PathInUserPath $PathToAdd) {
        Write-Status "OK" "Already in PATH: $Label ($PathToAdd)"
        Write-Log "Path already exists: $PathToAdd" -Level "OK"
        return $true
    }

    # 添加到用户 PATH
    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $newPath = $PathToAdd
        if ($currentPath) {
            $newPath = "$currentPath;$PathToAdd"
        }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        # 同时更新当前进程 PATH
        $env:Path = "$env:Path;$PathToAdd"
        Write-Status "FIX" "Added to PATH: $Label ($PathToAdd)"
        Write-Log "Added to user PATH: $PathToAdd" -Level "FIX"
        return $true
    } catch {
        Write-Status "ERROR" "Failed to add to PATH: $Label ($_)"
        Write-Log "Add-UserPath failed: $_" -Level "ERROR"
        $Script:ErrorList.Add("添加 $PathToAdd 到 PATH 失败: $_") > $null
        return $false
    }
}

<#
.SYNOPSIS
    修复用户级 PATH（主函数）
#>
function Repair-UserPath {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "  PATH REPAIR MODE" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host ""

    # 1. 备份
    if (-not (Backup-UserPath)) {
        Write-Status "ERROR" "Cannot proceed with PATH repair: backup failed"
        return
    }

    # 2. 收集需要修复的路径
    $pathsToFix = @()

    # npm 全局 bin（使用 Invoke-ExternalCommand 带超时）
    $npmPrefixResult = Invoke-ExternalCommand -FileName "npm.cmd" -Arguments "config get prefix"
    if ($npmPrefixResult.Status -eq "OK" -and $npmPrefixResult.StdOut) {
        $pathsToFix += @{ Path = $npmPrefixResult.StdOut.Trim(); Label = "npm global prefix" }
    }

    # %APPDATA%\npm
    $appDataNpm = "$env:APPDATA\npm"
    $pathsToFix += @{ Path = $appDataNpm; Label = "npm global (AppData)" }

    # VS Code bin
    $vsCodeBin = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
    $pathsToFix += @{ Path = $vsCodeBin; Label = "VS Code CLI" }

    # Git cmd
    $pathsToFix += @{ Path = "C:\Program Files\Git\cmd"; Label = "Git" }
    $pathsToFix += @{ Path = "C:\Program Files\Git\bin"; Label = "Git (bin)" }

    # Node.js
    $pathsToFix += @{ Path = "C:\Program Files\nodejs"; Label = "Node.js" }

    # 3. 逐个添加
    $fixed = 0
    foreach ($item in $pathsToFix) {
        if (Add-UserPath -PathToAdd $item.Path -Label $item.Label) {
            $fixed++
        }
    }

    Write-Host ""
    Write-Status "OK" "PATH repair complete: $fixed path(s) processed"
    Write-Host ""
    Write-Host "  IMPORTANT: 请重启 PowerShell 以使 PATH 修改生效。" -ForegroundColor Yellow
    Write-Host ""

    Write-Log "PATH repair completed: $fixed paths processed" -Level "OK"
}

# ============================================
# 安装函数（仅在 -Install 模式下调用）
# ============================================

<#
.SYNOPSIS
    使用 winget 安装程序（带超时保护）
#>
function Install-WithWinget {
    param([string]$PackageId, [string]$Label, [string]$ExtraArgs = "")
    Write-Status "INSTALL" "Installing $Label ($PackageId) via winget..."
    Write-Log "winget install: $PackageId" -Level "INSTALL"

    $argsList = @(
        "install", "-e", "--id", $PackageId,
        "--accept-source-agreements", "--accept-package-agreements"
    )
    if ($ExtraArgs) { $argsList += $ExtraArgs }
    $argsString = $argsList -join " "

    # 安装命令超时设为 300 秒（5 分钟），因为安装可能较长
    $r = Invoke-ExternalCommand -FileName "winget" -Arguments $argsString -TimeoutSec 300
    if ($r.Status -eq "OK") {
        Write-Status "OK" "$Label installed successfully"
        Write-Log "$Label installed via winget" -Level "OK"
        return @{ Success = $true; Output = $r.StdOut }
    } else {
        Write-Status "ERROR" "$Label installation failed: $($r.Status)"
        Write-Log "$Label winget failed: $($r.StdErr)" -Level "ERROR"
        $Script:ErrorList.Add("$Label 安装失败: $($r.Status)") > $null
        return @{ Success = $false; Output = $r.StdOut + $r.StdErr }
    }
}

<#
.SYNOPSIS
    刷新当前进程 PATH
#>
function Refresh-Path {
    try {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                     [System.Environment]::GetEnvironmentVariable("Path", "User")
        Write-Log "PATH refreshed in current process"
    } catch {
        Write-Log "PATH refresh failed: $_" -Level "WARN"
    }
}

<#
.SYNOPSIS
    安装 Node.js
#>
function Install-Node {
    Write-Host ""
    Write-Host "--- Installing Node.js ---" -ForegroundColor Cyan
    Write-Host ""

    $wingetResult = Invoke-ExternalCommand -FileName "winget" -Arguments "--version"
    if ($wingetResult.Status -ne "OK") {
        Write-Status "ERROR" "Cannot install Node.js: winget not available"
        Write-Log "Node.js install aborted: winget missing" -Level "ERROR"
        return @{ Success = $false; Error = "winget not available" }
    }

    $result = Install-WithWinget -PackageId "OpenJS.NodeJS.LTS" -Label "Node.js (LTS)"
    if ($result.Success) {
        Refresh-Path
        Start-Sleep -Seconds 2
        $verify = Invoke-ExternalCommand -FileName "node" -Arguments "-v"
        if ($verify.Status -eq "OK") {
            Write-Status "OK" "Node.js verified after install: $($verify.StdOut)"
        } else {
            Write-Status "WARNING" "Node.js installed but 'node -v' not available yet. Please restart PowerShell."
            $Script:FixSuggestionList.Add("Node.js 已安装，请重启 PowerShell 后验证 'node -v'") > $null
        }
    } else {
        Write-Status "ERROR" "Node.js installation failed. Try manual install: https://nodejs.org/"
    }
    return $result
}

<#
.SYNOPSIS
    安装 Git
#>
function Install-Git {
    Write-Host ""
    Write-Host "--- Installing Git ---" -ForegroundColor Cyan
    Write-Host ""

    $wingetResult = Invoke-ExternalCommand -FileName "winget" -Arguments "--version"
    if ($wingetResult.Status -ne "OK") {
        Write-Status "ERROR" "Cannot install Git: winget not available"
        Write-Log "Git install aborted: winget missing" -Level "ERROR"
        return @{ Success = $false; Error = "winget not available" }
    }

    $result = Install-WithWinget -PackageId "Git.Git" -Label "Git"
    if ($result.Success) {
        Refresh-Path
        Start-Sleep -Seconds 2
        $verify = Invoke-ExternalCommand -FileName "git" -Arguments "--version"
        if ($verify.Status -eq "OK") {
            Write-Status "OK" "Git verified after install: $($verify.StdOut)"
        } else {
            Write-Status "WARNING" "Git installed but 'git --version' not yet available. Please restart PowerShell."
        }
    }
    return $result
}

<#
.SYNOPSIS
    安装 VS Code
#>
function Install-VSCode {
    Write-Host ""
    Write-Host "--- Installing VS Code ---" -ForegroundColor Cyan
    Write-Host ""

    if ($SkipVSCode) {
        Write-Status "SKIPPED" "VS Code installation skipped"
        return @{ Success = $false; Skipped = $true }
    }

    $wingetResult = Invoke-ExternalCommand -FileName "winget" -Arguments "--version"
    if ($wingetResult.Status -ne "OK") {
        Write-Status "ERROR" "Cannot install VS Code: winget not available"
        return @{ Success = $false; Error = "winget not available" }
    }

    $result = Install-WithWinget -PackageId "Microsoft.VisualStudioCode" -Label "VS Code"
    return $result
}

<#
.SYNOPSIS
    安装 Claude Code CLI
#>
function Install-ClaudeCode {
    Write-Host ""
    Write-Host "--- Installing Claude Code ---" -ForegroundColor Cyan
    Write-Host ""

    if ($SkipClaude) {
        Write-Status "SKIPPED" "Claude Code installation skipped"
        return @{ Success = $false; Skipped = $true }
    }

    $npmResult = Invoke-ExternalCommand -FileName "npm.cmd" -Arguments "-v"
    if ($npmResult.Status -ne "OK") {
        Write-Status "ERROR" "Cannot install Claude Code: npm not available. Install Node.js first."
        Write-Log "Claude Code install aborted: npm missing" -Level "ERROR"
        return @{ Success = $false; Error = "npm not available" }
    }

    Write-Status "INSTALL" "Installing Claude Code via npm..."
    Write-Log "npm install -g @anthropic-ai/claude-code" -Level "INSTALL"

    # 安装超时设为 300 秒
    $r = Invoke-ExternalCommand -FileName "npm.cmd" -Arguments "install -g @anthropic-ai/claude-code" -TimeoutSec 300
    if ($r.Status -eq "OK") {
        Write-Status "OK" "Claude Code installed successfully"
        Write-Log "Claude Code installed" -Level "OK"
        Refresh-Path
        $verify = Invoke-ExternalCommand -FileName "claude" -Arguments "--version"
        if ($verify.Status -eq "OK") {
            Write-Status "OK" "Claude Code verified: $($verify.StdOut)"
        }
        return @{ Success = $true; Output = $r.StdOut }
    } else {
        Write-Status "ERROR" "Claude Code installation failed: $($r.Status)"
        Write-Log "Claude Code npm install failed: $($r.StdErr)" -Level "ERROR"
        $Script:ErrorList.Add("Claude Code 安装失败") > $null
        return @{ Success = $false; Output = $r.StdOut + $r.StdErr }
    }
}

<#
.SYNOPSIS
    安装 Codex CLI
#>
function Install-CodexCLI {
    Write-Host ""
    Write-Host "--- Installing Codex CLI ---" -ForegroundColor Cyan
    Write-Host ""

    if ($SkipCodex) {
        Write-Status "SKIPPED" "Codex CLI installation skipped"
        return @{ Success = $false; Skipped = $true }
    }

    # 尝试官方安装脚本
    Write-Status "INSTALL" "Installing Codex CLI via official Windows install script..."
    Write-Log "Codex CLI: trying official install script" -Level "INSTALL"

    $r = Invoke-ExternalCommand -FileName "powershell" -Arguments "-ExecutionPolicy Bypass -Command `"irm https://chatgpt.com/codex/install.ps1 | iex`"" -TimeoutSec 300
    if ($r.Status -eq "OK") {
        Write-Status "OK" "Codex CLI installed via official script"
        Write-Log "Codex CLI installed via official script" -Level "OK"
        Refresh-Path
        return @{ Success = $true; Output = $r.StdOut; Method = "official_script" }
    }

    Write-Status "WARNING" "Official script failed, trying npm fallback..."
    Write-Log "Official script failed, trying npm" -Level "WARN"

    # npm fallback
    $npmResult = Invoke-ExternalCommand -FileName "npm.cmd" -Arguments "-v"
    if ($npmResult.Status -ne "OK") {
        Write-Status "ERROR" "Cannot install Codex CLI: npm not available"
        return @{ Success = $false; Error = "npm not available"; Method = "none" }
    }

    Write-Status "INSTALL" "Installing Codex CLI via npm (fallback)..."
    $r2 = Invoke-ExternalCommand -FileName "npm.cmd" -Arguments "install -g @openai/codex" -TimeoutSec 300
    if ($r2.Status -eq "OK") {
        Write-Status "OK" "Codex CLI installed via npm"
        Write-Log "Codex CLI installed via npm" -Level "OK"
        Refresh-Path
        return @{ Success = $true; Output = $r2.StdOut; Method = "npm" }
    } else {
        Write-Status "ERROR" "Codex CLI installation failed (both methods)"
        Write-Log "Codex CLI install failed" -Level "ERROR"
        $Script:ErrorList.Add("Codex CLI 安装失败，请手动安装") > $null
        return @{ Success = $false; Output = $r2.StdOut + $r2.StdErr; Method = "failed" }
    }
}

<#
.SYNOPSIS
    执行安装流程主函数（仅在 -Install 模式下调用）
#>
function Invoke-InstallMode {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "  INSTALL MODE" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  WARNING: Installation mode will install" -ForegroundColor Yellow
    Write-Host "  missing components on your system." -ForegroundColor Yellow
    Write-Host "  All operations are logged to: $Script:LogFile" -ForegroundColor Yellow
    Write-Host ""

    # 检测 winget（必须先于任何安装操作）
    $wingetCheck = Invoke-ExternalCommand -FileName "winget" -Arguments "--version"
    if ($wingetCheck.Status -ne "OK") {
        Write-Status "ERROR" "winget is not available. Cannot proceed with automatic installation."
        Write-Status "ERROR" "Please install App Installer from Microsoft Store first."
        Write-Log "Install mode aborted: winget not available" -Level "ERROR"
        $Script:InstallResults.WingetRequired = $false
        return
    }
    $Script:InstallResults.WingetRequired = $true

    # 安装 Node.js（基础依赖）
    $nodeCheck = Invoke-ExternalCommand -FileName "node" -Arguments "-v"
    if ($nodeCheck.Status -ne "OK") {
        $r = Install-Node
        $Script:InstallResults.Node = $r
    } else {
        Write-Status "OK" "Node.js already installed, skipping"
        $Script:InstallResults.Node = @{ Success = $true; AlreadyInstalled = $true }
    }

    # 安装 Git
    $gitCheck = Invoke-ExternalCommand -FileName "git" -Arguments "--version"
    if ($gitCheck.Status -ne "OK") {
        $r = Install-Git
        $Script:InstallResults.Git = $r
    } else {
        Write-Status "OK" "Git already installed, skipping"
        $Script:InstallResults.Git = @{ Success = $true; AlreadyInstalled = $true }
    }

    # 安装 VS Code
    if (-not $SkipVSCode) {
        $codeCheck = Invoke-ExternalCommand -FileName "code" -Arguments "--version"
        if ($codeCheck.Status -ne "OK") {
            $r = Install-VSCode
            $Script:InstallResults.VSCode = $r
        } else {
            Write-Status "OK" "VS Code already installed, skipping"
            $Script:InstallResults.VSCode = @{ Success = $true; AlreadyInstalled = $true }
        }
    }

    # 安装 Claude Code
    if (-not $SkipClaude) {
        $claudeCheck = Invoke-ExternalCommand -FileName "claude" -Arguments "--version"
        if ($claudeCheck.Status -ne "OK") {
            $r = Install-ClaudeCode
            $Script:InstallResults.ClaudeCode = $r
        } else {
            Write-Status "OK" "Claude Code already installed, skipping"
            $Script:InstallResults.ClaudeCode = @{ Success = $true; AlreadyInstalled = $true }
        }
    }

    # 安装 Codex CLI
    if (-not $SkipCodex) {
        $codexCheck = Invoke-ExternalCommand -FileName "codex" -Arguments "--version"
        if ($codexCheck.Status -ne "OK") {
            $r = Install-CodexCLI
            $Script:InstallResults.CodexCLI = $r
        } else {
            Write-Status "OK" "Codex CLI already installed, skipping"
            $Script:InstallResults.CodexCLI = @{ Success = $true; AlreadyInstalled = $true }
        }
    }

    # WSL 提示（测试版不自动安装）
    if (-not $SkipWSL) {
        $wslCheck = Invoke-ExternalCommand -FileName "wsl" -Arguments "-l -v"
        if ($wslCheck.Status -ne "OK") {
            Write-Host ""
            Write-Status "WARNING" "WSL is not installed."
            Write-Host "  To install WSL manually (requires admin): wsl --install" -ForegroundColor Yellow
            Write-Log "WSL not installed - manual install required"
            $Script:InstallResults.WSL = @{ Success = $false; ManualRequired = $true }
        } else {
            $Script:InstallResults.WSL = @{ Success = $true; AlreadyInstalled = $true }
        }
    }
}

# ============================================
# 报告生成函数
# ============================================

<#
.SYNOPSIS
    生成 JSON 格式检测报告
#>
function Save-JsonReport {
    try {
        $report = @{
            Meta = @{
                Version = $Script:ScriptVersion
                Timestamp = $Script:RunDate
                ComputerName = $env:COMPUTERNAME
                UserName = $env:USERNAME
                IsAdmin = Test-IsAdmin
                Mode = if ($Install) { "Install" } else { "CheckOnly" }
                Language = $Script:Language
                FixPath = [bool]$FixPath
                CommandTimeoutSec = $CommandTimeoutSec
                LogFile = $Script:LogFile
            }
            Results = ConvertTo-SafeReportObject $Script:Results
            CommandResults = ConvertTo-SafeReportObject $Script:CommandResults
            InstallResults = ConvertTo-SafeReportObject $Script:InstallResults
            Errors = ConvertTo-SafeReportObject $Script:ErrorList
            Warnings = ConvertTo-SafeReportObject $Script:WarningList
            FixSuggestions = ConvertTo-SafeReportObject $Script:FixSuggestionList
        }
        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $Script:JsonReportFile -Encoding UTF8
        Write-Log "JSON report saved: $Script:JsonReportFile" -Level "OK"
        return $true
    } catch {
        Write-Log "JSON report save failed: $_" -Level "ERROR"
        return $false
    }
}

<#
.SYNOPSIS
    生成 Markdown 格式检测报告
#>
function Convert-ProxyInfoToMarkdown {
    param($Proxy)

    if (-not $Proxy) {
        return "| N/A | No data |"
    }

    $lines = ""
    $lines += "### Environment`n`n"
    foreach ($scope in @("Process", "User", "Machine")) {
        $lines += "#### $scope`n`n"
        if ($Proxy.Environment -and $Proxy.Environment.Contains($scope) -and $Proxy.Environment[$scope].Count -gt 0) {
            $lines += "| Variable | Value |`n|----------|-------|`n"
            foreach ($k in $Proxy.Environment[$scope].Keys) {
                $lines += "| ``$k`` | $(ConvertTo-MaskedProxyValue $Proxy.Environment[$scope][$k]) |`n"
            }
            $lines += "`n"
        } else {
            $lines += "- *(not set)*`n`n"
        }
    }

    foreach ($section in @("Npm", "Git")) {
        $lines += "### $section`n`n"
        if ($Proxy[$section] -and $Proxy[$section].Count -gt 0) {
            $lines += "| Key | Value |`n|-----|-------|`n"
            foreach ($k in $Proxy[$section].Keys) {
                $lines += "| ``$k`` | $(ConvertTo-MaskedProxyValue $Proxy[$section][$k]) |`n"
            }
            $lines += "`n"
        } else {
            $lines += "- *(not configured)*`n`n"
        }
    }

    $lines += "### WinHTTP`n`n"
    $lines += "```````n$(ConvertTo-MaskedProxyValue $Proxy.WinHTTP.Raw)`n```````n`n"

    $lines += "### Windows Internet Settings`n`n"
    $lines += "| Field | Value |`n|-------|-------|`n"
    $lines += "| ProxyEnable | $($Proxy.WindowsInternetSettings.ProxyEnable) |`n"
    $lines += "| ProxyServer | $(ConvertTo-MaskedProxyValue $Proxy.WindowsInternetSettings.ProxyServer) |`n"
    $lines += "| AutoConfigURL | $(ConvertTo-MaskedProxyValue $Proxy.WindowsInternetSettings.AutoConfigURL) |`n`n"

    $reachable = @($Proxy.LocalPortScan | Where-Object { $_.TcpReachable })
    $lines += "### Local Port Scan`n`n"
    if ($reachable.Count -gt 0) {
        $lines += "| Port | Protocol | URL |`n|------|----------|-----|`n"
        foreach ($item in $reachable) {
            $lines += "| $($item.Port) | $($item.Protocol) | $(ConvertTo-MaskedProxyValue $item.Url) |`n"
        }
        $lines += "`n"
    } else {
        $lines += "- No common local proxy ports were reachable.`n`n"
    }

    $r = $Proxy.RecommendedProxy
    $lines += "### RecommendedProxy`n`n"
    $lines += "| Field | Value |`n|-------|-------|`n"
    foreach ($field in @("Url", "Protocol", "Host", "Port", "Source", "Confidence", "IsUsable")) {
        $lines += "| $field | $(ConvertTo-MaskedProxyValue $r[$field]) |`n"
    }
    $lines += "| Notes | $($r.Notes -join '; ') |`n"

    return $lines
}

function Save-MarkdownReport {
    try {
        $okCount = 0; $missingCount = 0; $warnCount = 0; $skipCount = 0; $errorCount = 0
        $timeoutCount = 0

        $md = @"
# AI Local Environment Check Report

## Meta

| Field | Value |
|-------|-------|
| **Version** | $Script:ScriptVersion |
| **Timestamp** | $Script:RunDate |
| **Computer** | $env:COMPUTERNAME |
| **User** | $env:USERNAME |
| **Admin** | $(if (Test-IsAdmin) { "Yes" } else { "No" }) |
| **Mode** | $(if ($Install) { "Install" } else { "CheckOnly" }) |
| **Language** | $Script:Language |
| **FixPath** | $([bool]$FixPath) |
| **Timeout** | ${CommandTimeoutSec}s |
| **Log** | `$Script:LogFile` |

---

## System

| Property | Value |
|----------|-------|
| PowerShell | $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition)) |
| OS | $([Environment]::OSVersion.VersionString) |

## Permission

| Check | Result |
|-------|--------|
| Administrator | $(if (Test-IsAdmin) { "✅ Yes" } else { "⚠️ No" }) |

## Network

$(
    if ($Script:Results.Network.Skipped) {
        "⏭️ **Network check skipped** (-SkipNetwork)`n"
    } elseif ($Script:Results.Network) {
        $lines = "| Target | Status |`n|--------|--------|`n"
        foreach ($t in $Script:Results.Network.Targets) {
            $status = if ($t.Reachable) { "✅" } else { "❌" }
            $lines += "| $($t.Host):$($t.Port) | $status |`n"
        }
        $lines + "`n**All Reachable:** " + $(if ($Script:Results.Network.AllReachable) { "✅ Yes" } else { "❌ No" }) + "`n"
    } else { "| N/A | No data |" }
)

## Proxy

$(Convert-ProxyInfoToMarkdown $Script:Results.Proxy)

## Package Manager

| Tool | Status | Version |
|------|--------|---------|
| winget | $(if ($Script:Results.Winget.Exists) { "✅" } else { "❌" }) | $($Script:Results.Winget.Version) |

## Node.js / npm

| Check | Status | Value |
|-------|--------|-------|
| node path | $(if ($Script:Results.Node.NodePath) { "✅" } else { "❌" }) | $($Script:Results.Node.NodePath) |
| node version | $(if ($Script:Results.Node.NodeExists) { "✅" } else { "❌" }) | $($Script:Results.Node.NodeVersion) |
| npm path | $(if ($Script:Results.Node.NpmPath) { "✅" } else { "❌" }) | $($Script:Results.Node.NpmPath) |
| npm version | $(if ($Script:Results.Node.NpmExists) { "✅" } else { "❌" }) | $($Script:Results.Node.NpmVersion) |
| npm prefix | — | $($Script:Results.Node.NpmPrefix) |
| npm root -g | — | $($Script:Results.Node.NpmGlobalRoot) |
| npm proxy | — | $(ConvertTo-MaskedProxyValue $Script:Results.Node.NpmProxy) |
| npm https-proxy | — | $(ConvertTo-MaskedProxyValue $Script:Results.Node.NpmHttpsProxy) |

## Git

| Tool | Status | Version | Path |
|------|--------|---------|------|
| Git | $(if ($Script:Results.Git.Exists) { "✅" } else { "❌" }) | $($Script:Results.Git.Version) | $($Script:Results.Git.Path) |

## VS Code

| Tool | Status | Version | Path |
|------|--------|---------|------|
| VS Code CLI | $(if ($Script:Results.VSCode.Exists) { "✅" } else { "❌" }) | $($Script:Results.VSCode.Version) | $($Script:Results.VSCode.Path) |

## Claude Code

| Tool | Status | Version | Path |
|------|--------|---------|------|
| Claude Code | $(if ($Script:Results.ClaudeCode.Exists) { "✅" } elseif ($Script:Results.ClaudeCode.Skipped) { "⏭️" } else { "❌" }) | $($Script:Results.ClaudeCode.Version) | $($Script:Results.ClaudeCode.Path) |

## Codex CLI

| Check | Status | Value |
|-------|--------|-------|
| codex path | $(if ($Script:Results.CodexCLI.Path) { "✅" } else { "⚠️" }) | $($Script:Results.CodexCLI.Path) |
| codex version | $(if ($Script:Results.CodexCLI.Status -eq "OK") { "✅" } elseif ($Script:Results.CodexCLI.Status -eq "PARTIAL") { "⚠️" } elseif ($Script:Results.CodexCLI.Skipped) { "⏭️" } else { "❌" }) | $($Script:Results.CodexCLI.Version) |
| source | — | $($Script:Results.CodexCLI.Source) |
| status | $(if ($Script:Results.CodexCLI.Status -eq "OK") { "✅" } elseif ($Script:Results.CodexCLI.Status -eq "PARTIAL") { "⚠️" } else { "❌" }) | $($Script:Results.CodexCLI.Status) |
| error | — | $($Script:Results.CodexCLI.Error) |

## WSL

| Check | Status | Value |
|-------|--------|-------|
| wsl path | $(if ($Script:Results.WSL.WslPath) { "✅" } else { "❌" }) | $($Script:Results.WSL.WslPath) |
| wsl status | $(if ($Script:Results.WSL.Status -eq "OK") { "✅" } elseif ($Script:Results.WSL.Status -eq "PARTIAL") { "⚠️" } elseif ($Script:Results.WSL.Skipped) { "⏭️" } else { "❌" }) | $($Script:Results.WSL.Status) |
| distributions | $(if ($Script:Results.WSL.Distributions.Count -gt 0) { "✅" } else { "⚠️" }) | $($Script:Results.WSL.Distributions -join ", ") |
| error | — | $($Script:Results.WSL.Error) |

## PATH

$(
    if ($Script:Results.PATH.Checks) {
        $lines = ""
        foreach ($c in $Script:Results.PATH.Checks) {
            $s = if ($c.InPath) { "✅" } else { "⚠️" }
            $lines += "| $($c.Name) | $s | $($c.Path) | $($c.DirExists) |`n"
        }
        $lines
    } else { "| N/A | No data | — | — |" }
)

## Command Details

$(
    $lines = "| Command | Status | ExitCode | Elapsed (ms) |`n"
    $lines += "|---------|--------|----------|-------------|`n"
    foreach ($cr in $Script:CommandResults) {
        $statusIcon = switch ($cr.Status) {
            "OK" { "✅" }
            "ERROR" { "❌" }
            "TIMEOUT" { "⏱️" }
            default { $cr.Status }
        }
        $lines += "| ``$($cr.Command)`` | $statusIcon | $($cr.ExitCode) | $($cr.ElapsedMs) |`n"
    }
    $lines
)

## Summary

$(
    # Count statuses
    $allResults = @(
        @{ K = "Winget"; V = $Script:Results.Winget.Exists },
        @{ K = "Node.js"; V = $Script:Results.Node.NodeExists },
        @{ K = "npm"; V = $Script:Results.Node.NpmExists },
        @{ K = "Git"; V = $Script:Results.Git.Exists },
        @{ K = "VS Code"; V = $Script:Results.VSCode.Exists -and -not $Script:Results.VSCode.Skipped },
        @{ K = "Claude Code"; V = $Script:Results.ClaudeCode.Exists -and -not $Script:Results.ClaudeCode.Skipped },
        @{ K = "Codex CLI"; V = ($Script:Results.CodexCLI.Status -eq "OK") -and -not $Script:Results.CodexCLI.Skipped },
        @{ K = "WSL"; V = ($Script:Results.WSL.Status -eq "OK") -and -not $Script:Results.WSL.Skipped }
    )
    $present = ($allResults | Where-Object { $_.V }).Count
    $total = ($allResults | Where-Object {
        $k = $_.K
        if ($k -eq "Claude Code" -and $SkipClaude) { return $false }
        if ($k -eq "Codex CLI" -and $SkipCodex) { return $false }
        if ($k -eq "VS Code" -and $SkipVSCode) { return $false }
        if ($k -eq "WSL" -and $SkipWSL) { return $false }
        return $true
    }).Count

    "- **Present:** $present / $total`n"
    "- **Network:** $(if ($Script:Results.Network.Skipped) { "Skipped" } elseif ($Script:Results.Network.AllReachable) { "All reachable" } else { "Partial issues" })`n"
    "- **Errors:** $($Script:ErrorList.Count)`n"
    "- **Warnings:** $($Script:WarningList.Count)`n"
    "- **Timeouts:** $(($Script:CommandResults | Where-Object { $_.Status -eq 'TIMEOUT' }).Count)`n"
)

## Install Results

$(
    if ($Install -and $Script:InstallResults.Count -gt 0) {
        $lines = "| Component | Result |`n|-----------|--------|`n"
        foreach ($k in $Script:InstallResults.Keys) {
            $v = $Script:InstallResults[$k]
            $s = ""
            if ($v.Success) { $s = "✅ Success" }
            elseif ($v.AlreadyInstalled) { $s = "✅ Already installed" }
            elseif ($v.Skipped) { $s = "⏭️ Skipped" }
            else { $s = "❌ Failed" }
            $lines += "| $k | $s |`n"
        }
        $lines
    } else { "*(CheckOnly mode - no installation performed)*" }
)

## Next Actions

$(
    if ($Script:FixSuggestionList.Count -eq 0) {
        "✅ All checks passed. Your environment is ready!"
    } else {
        $lines = ""
        foreach ($s in $Script:FixSuggestionList) {
            $lines += "- $s`n"
        }
        $lines
    }
)

---

*Report generated by ai-local-env-checker $Script:ScriptVersion*
"@

        Set-Content -Path $Script:MarkdownReportFile -Value $md -Encoding UTF8
        Write-Log "Markdown report saved: $Script:MarkdownReportFile" -Level "OK"
        return $true
    } catch {
        Write-Log "Markdown report save failed: $_" -Level "ERROR"
        return $false
    }
}

<#
.SYNOPSIS
    输出最终总结
#>
function Show-Summary {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "  $(Get-LocalizedText 'section.summary')" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "  Log File  : $Script:LogFile" -ForegroundColor Gray
    Write-Host "  JSON Report: $Script:JsonReportFile" -ForegroundColor Gray
    Write-Host "  MD Report  : $Script:MarkdownReportFile" -ForegroundColor Gray
    Write-Host ""

    if ($Script:ErrorList.Count -gt 0) {
        Write-Host "  Errors ($($Script:ErrorList.Count)):" -ForegroundColor Red
        foreach ($e in $Script:ErrorList) {
            Write-Host "    - $e" -ForegroundColor Red
        }
        Write-Host ""
    }

    if ($Script:WarningList.Count -gt 0) {
        Write-Host "  Warnings ($($Script:WarningList.Count)):" -ForegroundColor Yellow
        foreach ($w in $Script:WarningList) {
            Write-Host "    - $w" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    if ($Script:FixSuggestionList.Count -gt 0) {
        Write-Host "  Next Steps:" -ForegroundColor Cyan
        foreach ($s in $Script:FixSuggestionList) {
            Write-Host "    → $s" -ForegroundColor Cyan
        }
        Write-Host ""
    }

    if ($Script:ErrorList.Count -eq 0 -and $Script:WarningList.Count -eq 0 -and $Script:FixSuggestionList.Count -eq 0) {
        Write-Host "  ALL CHECKS PASSED" -ForegroundColor Green
        Write-Host "  Your local AI development environment is ready!" -ForegroundColor Green
        Write-Host ""
    }

    if ($FixPath -and -not $Install) {
        Write-Host "  💡 PATH has been fixed. Please RESTART PowerShell." -ForegroundColor Yellow
        Write-Host "     Then run: .\verify.ps1" -ForegroundColor Yellow
        Write-Host ""
    }

    if ($Install) {
        Write-Host "  💡 Installation complete. Please RESTART PowerShell." -ForegroundColor Yellow
        Write-Host "     Then run: .\verify.ps1" -ForegroundColor Yellow
        Write-Host ""
    }

    if ($CheckOnly -and -not $Install -and -not $FixPath) {
        Write-Host "  💡 Check mode only. To install missing components:" -ForegroundColor Yellow
        Write-Host "     .\install.ps1 -Install" -ForegroundColor Yellow
        Write-Host "  💡 To fix PATH issues:" -ForegroundColor Yellow
        Write-Host "     .\install.ps1 -FixPath" -ForegroundColor Yellow
        Write-Host ""
    }
}

# ============================================
# 主执行流程
# ============================================

function Test-ProxySettings {
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.proxy') ---" -ForegroundColor Cyan
    Write-Host ""
    Write-Log "$(Get-LocalizedText 'proxy.detecting')..."

    if (-not (Import-ProxyDetectorModule)) {
        Write-Status "WARNING" "ProxyDetector.psm1 not found, proxy detection skipped"
        Write-Log "ProxyDetector module missing" -Level "WARN"
        $Script:Results.Proxy = [ordered]@{
            Environment = [ordered]@{}
            Npm = [ordered]@{}
            Git = [ordered]@{}
            WinHTTP = [ordered]@{}
            WindowsInternetSettings = [ordered]@{}
            LocalPortScan = @()
            RecommendedProxy = [ordered]@{
                Url = $null
                Protocol = $null
                Host = $null
                Port = $null
                Source = $null
                Confidence = "none"
                IsUsable = $false
                Notes = @("ProxyDetector.psm1 not found")
            }
        }
        return
    }

    try {
        $proxyInfo = Invoke-ProxyDetection -TimeoutSec $CommandTimeoutSec -SkipNetwork:$SkipNetwork
        $Script:Results.Proxy = $proxyInfo

        $envCount = 0
        foreach ($scope in @("Process", "User", "Machine")) {
            if ($proxyInfo.Environment.Contains($scope)) {
                $envCount += $proxyInfo.Environment[$scope].Count
            }
        }

        if ($envCount -gt 0) {
            Write-Status "OK" "Environment proxy entries detected: $envCount"
        } else {
            Write-Status "OK" "Environment proxy entries: none"
        }

        Write-Status "OK" "npm proxy entries: $($proxyInfo.Npm.Count)"
        Write-Status "OK" "Git proxy entries: $($proxyInfo.Git.Count)"

        $reachablePorts = @($proxyInfo.LocalPortScan | Where-Object { $_.TcpReachable })
        if ($reachablePorts.Count -gt 0) {
            $ports = ($reachablePorts | ForEach-Object { "$($_.Port)/$($_.Protocol)" }) -join ", "
            Write-Status "OK" "Local proxy-like TCP listeners: $ports"
        } else {
            Write-Status "OK" "Local proxy-like TCP listeners: none"
        }

        if ($proxyInfo.RecommendedProxy -and $proxyInfo.RecommendedProxy.IsUsable) {
            Write-Status "OK" "$(Get-LocalizedText 'proxy.recommended') : $($proxyInfo.RecommendedProxy.Url) [$($proxyInfo.RecommendedProxy.Source), $($proxyInfo.RecommendedProxy.Confidence)]"
            Write-Log "Recommended proxy: $($proxyInfo.RecommendedProxy.Url), protocol=$($proxyInfo.RecommendedProxy.Protocol), source=$($proxyInfo.RecommendedProxy.Source), confidence=$($proxyInfo.RecommendedProxy.Confidence)" -Level "OK"
        } else {
            Write-Status "OK" "$(Get-LocalizedText 'proxy.noRecommended')"
            Write-Log "No recommended proxy generated"
        }

        Write-Log "Proxy detection completed"
    } catch {
        Write-Status "WARNING" "Proxy detection failed: $($_.Exception.Message)"
        Write-Log "Proxy detection failed: $($_.Exception.Message)" -Level "WARN"
        $Script:WarningList.Add("代理检测失败: $($_.Exception.Message)") > $null
        $Script:Results.Proxy = [ordered]@{
            Environment = [ordered]@{}
            Npm = [ordered]@{}
            Git = [ordered]@{}
            WinHTTP = [ordered]@{}
            WindowsInternetSettings = [ordered]@{}
            LocalPortScan = @()
            RecommendedProxy = [ordered]@{
                Url = $null
                Protocol = $null
                Host = $null
                Port = $null
                Source = $null
                Confidence = "none"
                IsUsable = $false
                Notes = @("Proxy detection failed")
            }
        }
    }
}

function Main {
    $Script:Messages = Initialize-Localization -RequestedLanguage $Language
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "  $(Get-LocalizedText 'app.title')" -ForegroundColor Magenta
    Write-Host "  $Script:ScriptVersion" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Mode: $(if ($Install) { 'Install' } else { 'CheckOnly' })  |  Language: $Script:Language  |  SkipNetwork: $([bool]$SkipNetwork)  |  Timeout: ${CommandTimeoutSec}s" -ForegroundColor Cyan
    Write-Host "  Time: $Script:RunDate" -ForegroundColor Cyan
    Write-Host "  User: $env:USERNAME @ $env:COMPUTERNAME" -ForegroundColor Cyan
    $isAdmin = Test-IsAdmin
    if ($isAdmin) {
        Write-Host "  Admin: Yes" -ForegroundColor Cyan
    } else {
        Write-Host "  Admin: No (some features may be limited)" -ForegroundColor Cyan
    }
    Write-Host ""

    Write-Log "=== Session Start ==="
    $modeStr = "CheckOnly"
    if ($Install) { $modeStr = "Install" }
    Write-Log "Mode: $modeStr, FixPath: $([bool]$FixPath), SkipNetwork: $([bool]$SkipNetwork), Timeout: ${CommandTimeoutSec}s"
    Write-Log "User: $env:USERNAME, Computer: $env:COMPUTERNAME, Admin: $isAdmin"

    # 1. 系统信息
    Write-Host ""
    Write-Host "--- $(Get-LocalizedText 'section.system') ---" -ForegroundColor Cyan
    Write-Host ""
    $sysInfo = Get-SystemInfo
    Write-Status "OK" "PowerShell : $($sysInfo.PSVersion) ($($sysInfo.PSEdition))"
    Write-Status "OK" "OS : $($sysInfo.WindowsProductName)"
    Write-Status "OK" "Architecture : $($sysInfo.OsArchitecture)"
    Write-Status "OK" "Computer : $($sysInfo.ComputerName)"
    Write-Status "OK" "User : $($sysInfo.UserName)"
    if ($isAdmin) {
        Write-Status "OK" "Administrator : Yes"
    } else {
        Write-Status "WARNING" "Administrator : No"
    }
    $Script:Results.System = $sysInfo

    if (-not $isAdmin -and $Install) {
        Write-Status "WARNING" "Not running as administrator. Some installations may fail."
        $Script:WarningList.Add("非管理员运行，部分安装可能失败。建议以管理员身份运行 PowerShell") > $null
    }

    # 2. 执行策略
    Test-ExecutionPolicy

    # 3. 代理检测
    Test-ProxySettings

    # 4. 网络检测
    Test-AllNetwork

    # 5. winget
    Test-Winget

    # 6. Node.js & npm
    Test-Node

    # 7. Git
    Test-Git

    # 8. VS Code
    Test-VSCode

    # 9. Claude Code
    Test-ClaudeCode

    # 10. Codex CLI
    Test-CodexCLI

    # 11. WSL
    Test-WSL

    # 12. PATH
    Test-UserPath

    # 13. 安装模式
    if ($Install) {
        Invoke-InstallMode
    }

    # 14. PATH 修复模式
    if ($FixPath) {
        Repair-UserPath
    }

    # 15. 生成报告
    Write-Host ""
    Write-Host "--- Generating Reports ---" -ForegroundColor Cyan
    Write-Host ""
    $jsonSaved = Save-JsonReport
    if (-not $jsonSaved) {
        Write-Status "WARNING" "JSON report may not have been saved correctly"
    }
    Save-MarkdownReport
    Write-Status "OK" "Log saved: $Script:LogFile"
    Write-Status "OK" "JSON report saved: $Script:JsonReportFile"
    Write-Status "OK" "Markdown report saved: $Script:MarkdownReportFile"

    # 16. 总结
    Show-Summary

    Write-Log "=== Session End ==="
}

# 执行
try {
    Main
} catch {
    Write-Host ""
    Write-Host "FATAL ERROR: $_" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Log "FATAL: $_" -Level "ERROR"
    Write-Log "Stack: $($_.ScriptStackTrace)" -Level "ERROR"
    Write-Host ""
    Write-Host "Please check the log file: $Script:LogFile" -ForegroundColor Yellow
    exit 1
}
