[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

function Write-CheckResult {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Path,
        [string]$Version
    )

    [PSCustomObject]@{
        Name = $Name
        Status = $Status
        Path = $Path
        Version = $Version
    }
}

function Get-FirstLine {
    param([string[]]$Value)

    if ($null -eq $Value -or $Value.Count -eq 0) {
        return ""
    }

    return (($Value | Where-Object { $_ } | Select-Object -First 1) -as [string]).Trim()
}

function Test-CommandVersion {
    param(
        [string]$Name,
        [string]$Command,
        [string[]]$Arguments = @("--version")
    )

    $found = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $found) {
        return Write-CheckResult -Name $Name -Status "MISSING" -Path "" -Version "command not found"
    }

    try {
        $job = Start-Job -ScriptBlock {
            param([string]$Executable, [string[]]$Args)
            & $Executable @Args 2>&1
        } -ArgumentList $found.Source, $Arguments

        $completed = Wait-Job -Job $job -Timeout 10
        if (-not $completed) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            return Write-CheckResult -Name $Name -Status "TIMEOUT" -Path $found.Source -Version "version command timed out"
        }

        $output = Receive-Job -Job $job
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        $version = Get-FirstLine -Value ($output | ForEach-Object { $_.ToString() })
        return Write-CheckResult -Name $Name -Status "OK" -Path $found.Source -Version $version
    }
    catch {
        return Write-CheckResult -Name $Name -Status "ERROR" -Path $found.Source -Version $_.Exception.Message
    }
}

function Find-Vcvars64 {
    $programFilesX86 = ${env:ProgramFiles(x86)}
    if (-not $programFilesX86) {
        return $null
    }

    $root = Join-Path $programFilesX86 "Microsoft Visual Studio"
    if (-not (Test-Path -LiteralPath $root)) {
        return $null
    }

    return Get-ChildItem -Path $root -Recurse -Filter "vcvars64.bat" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}

function Test-ClCompiler {
    $cl = Get-Command "cl.exe" -ErrorAction SilentlyContinue
    if ($cl) {
        $job = Start-Job -ScriptBlock {
            param([string]$Executable)
            & $Executable 2>&1
        } -ArgumentList $cl.Source

        $completed = Wait-Job -Job $job -Timeout 10
        if (-not $completed) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            return Write-CheckResult -Name "cl" -Status "TIMEOUT" -Path $cl.Source -Version "version command timed out"
        }

        $output = Receive-Job -Job $job
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return Write-CheckResult -Name "cl" -Status "OK" -Path $cl.Source -Version (Get-FirstLine -Value ($output | ForEach-Object { $_.ToString() }))
    }

    $vcvars = Find-Vcvars64
    if (-not $vcvars) {
        return Write-CheckResult -Name "cl" -Status "MISSING" -Path "" -Version "cl.exe and vcvars64.bat not found"
    }

    $cmd = "`"$vcvars`" >nul && where cl && cl"
    $job = Start-Job -ScriptBlock {
        param([string]$CommandLine)
        cmd.exe /d /s /c $CommandLine 2>&1
    } -ArgumentList $cmd

    $completed = Wait-Job -Job $job -Timeout 20
    if (-not $completed) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return Write-CheckResult -Name "cl" -Status "TIMEOUT" -Path $vcvars -Version "vcvars64.bat check timed out"
    }

    $output = Receive-Job -Job $job
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    $lines = $output | ForEach-Object { $_.ToString() }
    $path = Get-FirstLine -Value $lines
    $version = Get-FirstLine -Value ($lines | Select-Object -Skip 1)
    return Write-CheckResult -Name "cl" -Status "OK" -Path $path -Version $version
}

$results = @(
    Test-CommandVersion -Name "git" -Command "git"
    Test-CommandVersion -Name "gh" -Command "gh"
    Test-CommandVersion -Name "node" -Command "node"
    Test-CommandVersion -Name "npm" -Command "npm"
    Test-CommandVersion -Name "go" -Command "go" -Arguments @("version")
    Test-CommandVersion -Name "rustc" -Command "rustc"
    Test-CommandVersion -Name "cargo" -Command "cargo"
    Test-CommandVersion -Name "code" -Command "code"
    Test-CommandVersion -Name "claude" -Command "claude"
    Test-CommandVersion -Name "codex" -Command "codex"
    Test-CommandVersion -Name "tauri" -Command "tauri"
    Test-CommandVersion -Name "makensis" -Command "makensis" -Arguments @("/VERSION")
    Test-ClCompiler
    Test-CommandVersion -Name "wsl" -Command "wsl"
)

$results | Format-Table -AutoSize

if ($results.Status -contains "ERROR") {
    exit 1
}

exit 0
