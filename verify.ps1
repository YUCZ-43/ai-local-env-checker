<#
.SYNOPSIS
    AI Local Environment Quick Verifier
.DESCRIPTION
    快速验证本地 AI 开发环境是否就绪。
    检测所有关键命令是否可用，输出最终状态。
    所有外部命令都有超时保护，超时后继续检测后续项目。
.NOTES
    版本: 0.2.0-beta
    平台: Windows (PowerShell 5.1+)
.EXAMPLE
    .\verify.ps1
    .\verify.ps1 -JsonOutput
    .\verify.ps1 -CommandTimeoutSec 10
#>

param(
    [switch]$JsonOutput,
    [int]$CommandTimeoutSec = 10
)

# ============================================
# Invoke-ExternalCommand - 带超时的外部命令执行
# 兼容 Windows PowerShell 5.1
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

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,

        [Parameter(Mandatory=$false)]
        [string]$Arguments = "",

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSec = -1
    )

    if ($TimeoutSec -le 0) {
        $TimeoutSec = $CommandTimeoutSec
    }

    $startTime = Get-Date
    $executionFile = Resolve-WindowsCommandPath -CommandName $FileName
    if (-not $executionFile) {
        $executionFile = $FileName
    }

    # .cmd / .bat 文件必须通过 cmd.exe 包装执行，否则在 PowerShell 5.1 下
    # System.Diagnostics.Process 会错误解析工作目录
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
            try { $process.Kill() } catch { }
            $process.WaitForExit(2000) | Out-Null
            $status = "TIMEOUT"
            $exitCode = $null
        }

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

    return @{
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
}

# ============================================
# 颜色函数
# ============================================
function Write-OK { Write-Host "[  OK    ] $args" -ForegroundColor Green }
function Write-FAIL { Write-Host "[  FAIL  ] $args" -ForegroundColor Red }
function Write-INFO { Write-Host "[  INFO  ] $args" -ForegroundColor Cyan }
function Write-WARN { Write-Host "[ WARN   ] $args" -ForegroundColor Yellow }
function Write-TIMEOUT { Write-Host "[ TIMEOUT] $args" -ForegroundColor Yellow }

function Normalize-CommandOutput {
    param([string]$Text)

    if (-not $Text) {
        return ""
    }

    return ($Text -replace "`0", "" -replace "^\uFEFF", "").Trim()
}

# ============================================
# 检测函数（使用 Invoke-ExternalCommand 带超时）
# ============================================
function Test-Cmd {
    param(
        [string]$Name,
        [string]$Command,
        [string]$Args = "--version"
    )

    $r = Invoke-ExternalCommand -FileName $Command -Arguments $Args

    if ($r.Status -eq "OK") {
        Write-OK "$Name : $($r.StdOut)"
        return $true
    } elseif ($r.Status -eq "TIMEOUT") {
        Write-TIMEOUT "$Name : exceeded ${CommandTimeoutSec}s, skipped"
        return $false
    } else {
        Write-FAIL "$Name : $($r.StdErr)"
        return $false
    }
}

function Test-WhereCmd {
    param(
        [string]$Name,
        [string]$Command
    )

    $r = Invoke-ExternalCommand -FileName "where.exe" -Arguments $Command

    if ($r.Status -eq "OK") {
        $location = $r.StdOut -split "`r`n" | Select-Object -First 1
        Write-OK "$Name location : $location"
        return $true
    } elseif ($r.Status -eq "TIMEOUT") {
        Write-TIMEOUT "$Name location : exceeded ${CommandTimeoutSec}s, skipped"
        return $false
    } else {
        Write-FAIL "$Name : location not found"
        return $false
    }
}

# ============================================
# 主检测流程
# ============================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  AI Local Environment Quick Verifier" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Timeout: ${CommandTimeoutSec}s per command" -ForegroundColor Gray
Write-Host ""

$results = @{}
$total = 0
$passed = 0
$commandDetails = @()

# ---- Node.js ----
$total++
$nodeResult = Invoke-ExternalCommand -FileName "node" -Arguments "-v"
if ($nodeResult.Status -eq "OK") {
    Write-OK "Node.js : $($nodeResult.StdOut)"
    $results["node"] = $true
    $passed++
} elseif ($nodeResult.Status -eq "TIMEOUT") {
    Write-TIMEOUT "Node.js : exceeded ${CommandTimeoutSec}s, skipped"
    $results["node"] = $false
} else {
    Write-FAIL "Node.js : $($nodeResult.StdErr)"
    $results["node"] = $false
}
$commandDetails += $nodeResult

# ---- npm ----
$total++
$npmResult = Invoke-ExternalCommand -FileName "npm.cmd" -Arguments "-v"
if ($npmResult.Status -eq "OK") {
    Write-OK "npm : $($npmResult.StdOut)"
    $results["npm"] = $true
    $passed++
} elseif ($npmResult.Status -eq "TIMEOUT") {
    Write-TIMEOUT "npm : exceeded ${CommandTimeoutSec}s, skipped"
    $results["npm"] = $false
} else {
    Write-FAIL "npm : $($npmResult.StdErr)"
    $results["npm"] = $false
}
$commandDetails += $npmResult

# ---- npm prefix ----
$total++
$prefixResult = Invoke-ExternalCommand -FileName "npm.cmd" -Arguments "config get prefix"
if ($prefixResult.Status -eq "OK") {
    Write-OK "npm global prefix : $($prefixResult.StdOut)"
    $results["npm-prefix"] = $true
    $passed++
} elseif ($prefixResult.Status -eq "TIMEOUT") {
    Write-TIMEOUT "npm global prefix : exceeded ${CommandTimeoutSec}s, skipped"
    $results["npm-prefix"] = $false
} else {
    Write-FAIL "npm global prefix : error ($($prefixResult.StdErr))"
    $results["npm-prefix"] = $false
}
$commandDetails += $prefixResult

# ---- npm root -g ----
$total++
$npmRootResult = Invoke-ExternalCommand -FileName "npm.cmd" -Arguments "root -g"
if ($npmRootResult.Status -eq "OK") {
    Write-OK "npm root -g : $($npmRootResult.StdOut)"
    $results["npm-root-g"] = $true
    $passed++
} elseif ($npmRootResult.Status -eq "TIMEOUT") {
    Write-TIMEOUT "npm root -g : exceeded ${CommandTimeoutSec}s, skipped"
    $results["npm-root-g"] = $false
} else {
    Write-FAIL "npm root -g : error ($($npmRootResult.StdErr))"
    $results["npm-root-g"] = $false
}
$commandDetails += $npmRootResult

# ---- Git ----
$total++
$gitResult = Invoke-ExternalCommand -FileName "git" -Arguments "--version"
if ($gitResult.Status -eq "OK") {
    Write-OK "Git : $($gitResult.StdOut)"
    $results["git"] = $true
    $passed++
} elseif ($gitResult.Status -eq "TIMEOUT") {
    Write-TIMEOUT "Git : exceeded ${CommandTimeoutSec}s, skipped"
    $results["git"] = $false
} else {
    Write-FAIL "Git : $($gitResult.StdErr)"
    $results["git"] = $false
}
$commandDetails += $gitResult

# ---- VS Code ----
$total++
$codeResult = Invoke-ExternalCommand -FileName "code" -Arguments "--version"
if ($codeResult.Status -eq "OK") {
    $firstLine = $codeResult.StdOut -split "`r`n" | Select-Object -First 1
    Write-OK "VS Code : $firstLine"
    $results["code"] = $true
    $passed++
} elseif ($codeResult.Status -eq "TIMEOUT") {
    Write-TIMEOUT "VS Code : exceeded ${CommandTimeoutSec}s, skipped"
    $results["code"] = $false
} else {
    Write-FAIL "VS Code : $($codeResult.StdErr)"
    $results["code"] = $false
}
$commandDetails += $codeResult

# ---- Claude Code ----
$total++
$claudeResult = Invoke-ExternalCommand -FileName "claude" -Arguments "--version"
if ($claudeResult.Status -eq "OK") {
    Write-OK "Claude Code : $($claudeResult.StdOut)"
    $results["claude"] = $true
    $passed++
} elseif ($claudeResult.Status -eq "TIMEOUT") {
    Write-TIMEOUT "Claude Code : exceeded ${CommandTimeoutSec}s, skipped"
    $results["claude"] = $false
} else {
    Write-FAIL "Claude Code : $($claudeResult.StdErr)"
    $results["claude"] = $false
}
$commandDetails += $claudeResult

# ---- Codex CLI ----
$total++
$codexResult = Invoke-ExternalCommand -FileName "codex" -Arguments "--version"
if ($codexResult.Status -eq "OK") {
    Write-OK "Codex CLI : $(Normalize-CommandOutput $codexResult.StdOut)"
    $results["codex"] = $true
    $passed++
} elseif ($codexResult.Status -eq "TIMEOUT") {
    Write-TIMEOUT "Codex CLI : exceeded ${CommandTimeoutSec}s, skipped"
    $results["codex"] = $false
} else {
    Write-FAIL "Codex CLI : $($codexResult.StdErr)"
    $results["codex"] = $false
}
$commandDetails += $codexResult

# ---- WSL ----
$total++
$wslResult = Invoke-ExternalCommand -FileName "wsl.exe" -Arguments "-l -v"
if ($wslResult.Status -eq "OK") {
    Write-OK "WSL : available"
    $wslOutput = Normalize-CommandOutput $wslResult.StdOut
    $lines = $wslOutput -split "(`r`n|`n)"
    foreach ($line in $lines) {
        if ($line.Trim()) {
            Write-Host "  $line"
        }
    }
    $results["wsl"] = $true
    $passed++
} elseif ($wslResult.Status -eq "TIMEOUT") {
    Write-TIMEOUT "WSL : exceeded ${CommandTimeoutSec}s, skipped"
    $results["wsl"] = $false
} else {
    Write-WARN "WSL : not installed or no distros"
    $results["wsl"] = $false
}
$commandDetails += $wslResult

# ---- Location checks ----
Write-Host ""
Write-Host "--- Command Locations ---" -ForegroundColor Cyan
Write-Host ""

$locationResults = @{}
$locTotal = 0
$locPassed = 0

$locCommands = @(
    @{ Name = "node";   Exe = "node" },
    @{ Name = "npm";    Exe = "npm.cmd" },
    @{ Name = "git";    Exe = "git" },
    @{ Name = "code";   Exe = "code" },
    @{ Name = "claude"; Exe = "claude" },
    @{ Name = "codex";  Exe = "codex.cmd" },
    @{ Name = "wsl";    Exe = "wsl.exe" }
)

foreach ($cmd in $locCommands) {
    $locTotal++
    $locResult = Invoke-ExternalCommand -FileName "where.exe" -Arguments $cmd.Exe
    if ($locResult.Status -eq "OK") {
        $location = $locResult.StdOut -split "`r`n" | Select-Object -First 1
        Write-OK "$($cmd.Name) location : $location"
        $locationResults[$cmd.Name] = $true
        $locPassed++
    } elseif ($locResult.Status -eq "TIMEOUT") {
        Write-TIMEOUT "$($cmd.Name) location : exceeded ${CommandTimeoutSec}s, skipped"
        $locationResults[$cmd.Name] = $false
    } else {
        Write-FAIL "$($cmd.Name) : location not found"
        $locationResults[$cmd.Name] = $false
    }
    $commandDetails += $locResult
}

# ============================================
# 最终结论
# ============================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  VERIFICATION RESULT" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta

$allPassed = ($passed -eq $total) -and ($locPassed -eq $locTotal)

if ($allPassed) {
    Write-Host ""
    Write-Host "  STATUS: READY" -ForegroundColor Green
    Write-Host ""
    Write-Host "  所有组件已就绪，可以开始 AI 编程开发。" -ForegroundColor Green
    Write-Host ""
    $finalStatus = "READY"
} elseif ($passed -ge ($total * 0.6)) {
    Write-Host ""
    Write-Host "  STATUS: PARTIAL_READY" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  大部分组件已就绪，但仍有 $($total - $passed) 项缺失。" -ForegroundColor Yellow
    Write-Host "  建议运行: .\install.ps1 -Install -FixPath" -ForegroundColor Yellow
    Write-Host ""
    $finalStatus = "PARTIAL_READY"
} else {
    Write-Host ""
    Write-Host "  STATUS: NOT_READY" -ForegroundColor Red
    Write-Host ""
    Write-Host "  多个组件缺失 ($($total - $passed)/$total)，建议运行完整安装:" -ForegroundColor Red
    Write-Host "  .\install.ps1 -Install -FixPath" -ForegroundColor Red
    Write-Host ""
    $finalStatus = "NOT_READY"
}

$timeoutCount = ($commandDetails | Where-Object { $_.Status -eq 'TIMEOUT' }).Count
Write-Host "  Commands: $passed/$total passed | Locations: $locPassed/$locTotal passed | Timeouts: $timeoutCount" -ForegroundColor Cyan
Write-Host ""

# ============================================
# JSON 输出
# ============================================
if ($JsonOutput) {
    $output = @{
        status = $finalStatus
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        timeoutSec = $CommandTimeoutSec
        commands = @{
            passed = $passed
            total = $total
            timeouts = $timeoutCount
            details = $results
        }
        locations = @{
            passed = $locPassed
            total = $locTotal
            details = $locationResults
        }
        commandDetails = $commandDetails | ForEach-Object {
            @{
                command = $_.Command
                status = $_.Status
                exitCode = $_.ExitCode
                stdout = $_.StdOut
                stderr = $_.StdErr
                elapsedMs = $_.ElapsedMs
            }
        }
    }
    $output | ConvertTo-Json -Depth 4 | Write-Output
}

# ============================================
# 退出码（PowerShell 5.1 兼容）
# ============================================
if ($allPassed) {
    exit 0
} else {
    exit 1
}
