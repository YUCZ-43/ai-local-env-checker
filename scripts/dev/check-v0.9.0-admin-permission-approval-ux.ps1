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
        if (-not (Test-Path -LiteralPath $path)) { continue }
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

function Test-WorkflowYaml {
    Write-Check "YAML parse checks"
    $workflowDir = Join-Path $script:RepoRoot ".github\workflows"
    if (-not (Test-Path -LiteralPath $workflowDir)) {
        Write-Host "  SKIP no workflow directory"
        return
    }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        Write-Host "  SKIP python not found; YAML parser unavailable"
        return
    }
    $script = @"
import sys
try:
    import yaml
except Exception as exc:
    print(f"SKIP yaml parser unavailable: {exc}")
    sys.exit(2)
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    yaml.safe_load(handle)
"@
    foreach ($file in Get-ChildItem -LiteralPath $workflowDir -File | Where-Object { $_.Name -like "*.yml" -or $_.Name -like "*.yaml" }) {
        $script | & python - $file.FullName
        if ($LASTEXITCODE -eq 2) {
            Write-Host "  SKIP $($file.FullName)"
            return
        }
        if ($LASTEXITCODE -ne 0) { throw "YAML parse failed: $($file.FullName)" }
        Write-Host "  OK $($file.FullName)"
    }
}

function Test-GoCli {
    Write-Check "Go tests and build"
    $cliDir = Join-Path $script:RepoRoot "apps\cli-go"
    Push-Location $cliDir
    try {
        & go test ./...
        if ($LASTEXITCODE -ne 0) { throw "go test ./... failed" }
        & go build ./...
        if ($LASTEXITCODE -ne 0) { throw "go build ./... failed" }
    }
    finally {
        Pop-Location
    }
}

function Test-DesktopApp {
    Write-Check "Desktop npm and cargo checks"
    $desktopDir = Join-Path $script:RepoRoot "apps\desktop-tauri"
    if (Test-Path -LiteralPath (Join-Path $desktopDir "node_modules")) {
        Push-Location $desktopDir
        try {
            & npm test
            if ($LASTEXITCODE -ne 0) { throw "npm test failed" }
            & npm run build
            if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
        }
        finally {
            Pop-Location
        }
    } else {
        Write-Host "  SKIP npm checks; local node_modules not present"
    }

    $tauriDir = Join-Path $desktopDir "src-tauri"
    if (Test-Path -LiteralPath (Join-Path $tauriDir "Cargo.toml")) {
        Push-Location $tauriDir
        try {
            & cargo test
            if ($LASTEXITCODE -ne 0) { throw "cargo test failed" }
        }
        finally {
            Pop-Location
        }
    }
}

function Test-GeneratedOutputsIgnored {
    Write-Check "Generated outputs are ignored"
    $paths = @(
        "node_modules\package.json",
        "dist\preview-installer.exe",
        "target\debug\preview.exe",
        "logs\audit-preview.jsonl",
        "reports\generated.json",
        "apps\desktop-tauri\node_modules\package.json",
        "apps\desktop-tauri\dist\index.html",
        "apps\desktop-tauri\src-tauri\target\release\preview.exe",
        "apps\desktop-tauri\src-tauri\binaries\ai-local-deploy-x86_64-pc-windows-msvc.exe",
        "apps\cli-go\ai-local-deploy.exe"
    )
    foreach ($relative in $paths) {
        & git -C $script:RepoRoot check-ignore -q -- $relative
        if ($LASTEXITCODE -ne 0) { throw "Generated output is not ignored: $relative" }
        Write-Host "  OK ignored $relative"
    }
}

function Test-StagedArtifacts {
    Write-Check "Staged artifact guard"
    $staged = & git -C $script:RepoRoot diff --cached --name-only
    if ($LASTEXITCODE -ne 0) { throw "git diff --cached failed" }
    $blocked = $staged | Where-Object {
        $allowedPlaceholder = $_ -match '^(logs|reports|dist)/\.gitkeep$'
        $allowedExampleReport = $_ -match '^examples/reports/[^/]+\.json$'
        if ($allowedPlaceholder -or $allowedExampleReport) { return $false }
        $_ -match '^(logs|reports|dist)/' -or
        $_ -match '(^|/)(dist|node_modules|target|gen)(/|$)' -or
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

function Test-ForbiddenValues {
    Write-Check "Forbidden local path and proxy-port scan"
    $localUserPathPattern = "C:" + "\Users\" + "huang"
    $fixedProxyPortPattern = "108" + "70"
    $include = @(
        ".github",
        "README.md",
        "README.en-US.md",
        "README.zh-CN.md",
        "CHANGELOG.md",
        "ROADMAP.md",
        "SECURITY.md",
        "apps",
        "core",
        "docs",
        "examples",
        "locales",
        "packaging",
        "scripts"
    )
    foreach ($pattern in @($localUserPathPattern, $fixedProxyPortPattern)) {
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
                $matches | ForEach-Object { Write-Error "$($_.Path):$($_.LineNumber): forbidden value found" }
                throw "Forbidden value scan failed"
            }
        }
    }
    Write-Host "  OK no forbidden values found"
}

$script:RepoRoot = Resolve-RepoRoot
Write-Host "v0.9.0 admin permission approval UX validation root: $script:RepoRoot"
Write-Host "This script runs safe checks only. It does not install software, require admin, change PATH, modify proxy settings, trigger UAC, create tags, push, or create releases."

Test-PowerShellSyntax @(
    "install.ps1",
    "verify.ps1",
    "scripts\dev",
    "scripts\packaging",
    "scripts\windows",
    "scripts\release"
)

Write-Check "JSON parse checks"
Test-JsonDirectory "core\schema"
Test-JsonDirectory "core\tool-catalog"
Test-JsonDirectory "examples\tool-catalog"
Test-JsonDirectory "examples\install-plans"
Test-JsonDirectory "examples\reports"
Test-JsonDirectory "locales"

Test-WorkflowYaml
Test-GoCli
Test-DesktopApp
Test-GeneratedOutputsIgnored
Test-StagedArtifacts
Test-ForbiddenValues

Write-Host "v0.9.0 admin permission approval UX safe validation completed."
