[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Write-Check {
    param([string]$Message)
    Write-Host "[check] $Message"
}

function Resolve-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Test-JsonDirectory {
    param([string]$RelativeDirectory)
    $directory = Join-Path $script:RepoRoot $RelativeDirectory
    if (-not (Test-Path -LiteralPath $directory)) {
        throw "Missing JSON directory: $RelativeDirectory"
    }
    foreach ($file in Get-ChildItem -LiteralPath $directory -File -Filter "*.json") {
        Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json | Out-Null
        Write-Host "  OK $($file.FullName)"
    }
}

function Test-PowerShellSyntax {
    param([string[]]$RelativePaths)
    Write-Check "PowerShell parser checks"
    foreach ($relative in $RelativePaths) {
        $path = Join-Path $script:RepoRoot $relative
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }
        $item = Get-Item -LiteralPath $path
        $files = if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $path -File -Filter "*.ps1" -Recurse
        } else {
            @($item)
        }
        foreach ($file in $files) {
            $tokens = $null
            $parseErrors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
            if ($parseErrors.Count -gt 0) {
                foreach ($parseError in $parseErrors) {
                    Write-Error "$($file.FullName): $($parseError.Message)"
                }
                throw "PowerShell parser check failed"
            }
            Write-Host "  OK $($file.FullName)"
        }
    }
}

function Test-GoCli {
    Write-Check "Go tests, build, and safe catalog commands"
    $cliDir = Join-Path $script:RepoRoot "apps\cli-go"
    Push-Location $cliDir
    try {
        & go test ./...
        if ($LASTEXITCODE -ne 0) { throw "go test ./... failed" }
        & go build ./...
        if ($LASTEXITCODE -ne 0) { throw "go build ./... failed" }
        foreach ($args in @(
            @("tools", "list"),
            @("tools", "validate"),
            @("tools", "show", "--id", "claude-code"),
            @("tools", "detect", "--dry-run"),
            @("tools", "plan", "--id", "claude-code", "--dry-run")
        )) {
            & go run . @args | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "go run . $($args -join ' ') failed" }
        }
    }
    finally {
        Pop-Location
    }
}

function Test-BashSyntax {
    param([string[]]$RelativeFiles)
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bash) {
        Write-Host "[skip] bash not found; skipping Bash syntax checks"
        return
    }
    Write-Check "Bash syntax checks"
    foreach ($relative in $RelativeFiles) {
        $path = Join-Path $script:RepoRoot $relative
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Missing Bash script: $relative"
        }
        Get-Content -LiteralPath $path -Raw | & bash -n
        if ($LASTEXITCODE -ne 0) {
            throw "bash -n failed: $relative"
        }
        Write-Host "  OK $path"
    }
}

function Test-ForbiddenValues {
    Write-Check "Forbidden local path and proxy-port scan"
    $localUserPathPattern = "C:" + "\Users\" + "huang"
    $fixedProxyPortPattern = "108" + "70"
    $patterns = @($localUserPathPattern, $fixedProxyPortPattern)
    $include = @(
        "README.md",
        "README.en-US.md",
        "README.zh-CN.md",
        "apps",
        "core",
        "docs",
        "examples",
        "scripts"
    )
    foreach ($pattern in $patterns) {
        foreach ($relative in $include) {
            $path = Join-Path $script:RepoRoot $relative
            if (-not (Test-Path -LiteralPath $path)) { continue }
            $item = Get-Item -LiteralPath $path
            $files = if ($item.PSIsContainer) {
                Get-ChildItem -LiteralPath $path -File -Recurse |
                    Where-Object {
                        $_.FullName -notmatch "\\node_modules\\" -and
                        $_.FullName -notmatch "\\dist\\" -and
                        $_.FullName -notmatch "\\target\\" -and
                        $_.FullName -notmatch "\\gen\\" -and
                        $_.FullName -notmatch "\\logs\\" -and
                        $_.FullName -notmatch "\\reports\\"
                    }
            } else {
                @($item)
            }
            $matches = $files | Select-String -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue
            if ($matches) {
                $matches | ForEach-Object { Write-Error "$($_.Path):$($_.LineNumber): forbidden value '$pattern'" }
                throw "Forbidden value scan failed"
            }
        }
    }
    Write-Host "  OK no forbidden values found"
}

function Test-StagedArtifacts {
    Write-Check "Staged artifact guard"
    $staged = & git -C $script:RepoRoot diff --cached --name-only
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --cached failed"
    }
    $blocked = $staged | Where-Object {
        $_ -match '(^|/)(logs|reports|dist|node_modules|target)(/|$)' -or
        $_ -match '\.(exe|msi|zip|tar\.gz|tgz|7z)$' -or
        $_ -match '(^|/)\.env($|\.)' -or
        $_ -match '(token|tokens|key|keys|pem|pfx|p12)$'
    }
    if ($blocked) {
        $blocked | ForEach-Object { Write-Error "blocked staged artifact: $_" }
        throw "Generated or secret-like artifacts are staged"
    }
    Write-Host "  OK staged artifact guard"
}

$script:RepoRoot = Resolve-RepoRoot
Write-Host "v0.6.1 tool catalog validation root: $script:RepoRoot"
Write-Host "This script runs safe checks only. It does not install software, require admin, change PATH, or modify system settings."

Write-Check "JSON parse checks"
Test-JsonDirectory "core\schema"
Test-JsonDirectory "core\tool-catalog"
Test-JsonDirectory "examples\tool-catalog"
Test-JsonDirectory "examples\install-plans"

Test-GoCli

Test-PowerShellSyntax @(
    "install.ps1",
    "verify.ps1",
    "scripts\dev",
    "scripts\windows"
)

Test-BashSyntax @(
    "scripts\wsl\check-wsl.sh",
    "scripts\linux\check-linux.sh",
    "scripts\macos\check-macos.sh",
    "scripts\release\build-release.sh"
)

Test-ForbiddenValues
Test-StagedArtifacts

Write-Host "v0.6.1 tool catalog safe validation completed."
