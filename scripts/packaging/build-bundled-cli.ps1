[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

$repoRoot = Resolve-RepoRoot
$cliDir = Join-Path $repoRoot "apps\cli-go"
$outputDir = Join-Path $repoRoot "apps\desktop-tauri\src-tauri\binaries"
$outputFile = Join-Path $outputDir "ai-local-deploy-x86_64-pc-windows-msvc.exe"

if (-not (Test-Path -LiteralPath (Join-Path $cliDir "go.mod"))) {
    throw "Missing Go CLI module: $cliDir"
}

if (-not ($IsWindows -or $env:OS -eq "Windows_NT")) {
    throw "v0.7.0 bundled CLI build currently targets Windows only"
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Push-Location $cliDir
try {
    & go build -o $outputFile .
    if ($LASTEXITCODE -ne 0) {
        throw "go build for bundled CLI failed"
    }
}
finally {
    Pop-Location
}

Write-Host "Bundled CLI written to $outputFile"
