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

function Test-PowerShellSyntax {
    param([string[]]$RelativePaths)

    Write-Check "PowerShell parser checks"
    foreach ($relative in $RelativePaths) {
        $path = Join-Path $script:RepoRoot $relative
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $files = Get-ChildItem -LiteralPath $path -File -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
        if ((Get-Item -LiteralPath $path) -is [System.IO.FileInfo]) {
            $files = @(Get-Item -LiteralPath $path)
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

function Test-JsonFiles {
    param([string[]]$RelativeDirectories)

    Write-Check "JSON parse checks"
    foreach ($relative in $RelativeDirectories) {
        $directory = Join-Path $script:RepoRoot $relative
        if (-not (Test-Path -LiteralPath $directory)) {
            throw "Missing JSON directory: $relative"
        }
        foreach ($file in Get-ChildItem -LiteralPath $directory -File -Filter "*.json") {
            Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json | Out-Null
            Write-Host "  OK $($file.FullName)"
        }
    }
}

function Test-GoCli {
    Write-Check "Go CLI tests and build"
    $cliDir = Join-Path $script:RepoRoot "apps\cli-go"
    Push-Location $cliDir
    try {
        & go test ./...
        if ($LASTEXITCODE -ne 0) {
            throw "go test ./... failed"
        }
        & go build ./...
        if ($LASTEXITCODE -ne 0) {
            throw "go build ./... failed"
        }
    }
    finally {
        Pop-Location
    }
}

function Test-DesktopMetadata {
    Write-Check "Desktop app metadata"
    $desktopDir = Join-Path $script:RepoRoot "apps\desktop-tauri"
    $packagePath = Join-Path $desktopDir "package.json"
    $tauriConfigPath = Join-Path $desktopDir "src-tauri\tauri.conf.json"
    $cargoPath = Join-Path $desktopDir "src-tauri\Cargo.toml"

    foreach ($path in @($packagePath, $tauriConfigPath, $cargoPath)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Missing desktop metadata: $path"
        }
        Write-Host "  OK $path"
    }

    $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
    foreach ($scriptName in @("dev", "build", "test", "tauri")) {
        if (-not $package.scripts.PSObject.Properties.Name.Contains($scriptName)) {
            throw "package.json missing script: $scriptName"
        }
        Write-Host "  OK package script: $scriptName"
    }

    Get-Content -LiteralPath $tauriConfigPath -Raw | ConvertFrom-Json | Out-Null
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

$script:RepoRoot = Resolve-RepoRoot
Write-Host "v0.6.0 GUI validation root: $script:RepoRoot"
Write-Host "This script runs safe checks only. It does not install software, require admin, change PATH, or modify system settings."

Test-PowerShellSyntax -RelativePaths @(
    "install.ps1",
    "verify.ps1",
    "scripts\windows",
    "scripts\dev"
)

Test-JsonFiles -RelativeDirectories @(
    "core\schema",
    "examples\install-plans",
    "examples\reports"
)

Test-GoCli
Test-DesktopMetadata

Test-BashSyntax -RelativeFiles @(
    "scripts\wsl\check-wsl.sh",
    "scripts\linux\check-linux.sh",
    "scripts\macos\check-macos.sh",
    "scripts\release\build-release.sh"
)

Write-Host "v0.6.0 GUI safe validation completed."
