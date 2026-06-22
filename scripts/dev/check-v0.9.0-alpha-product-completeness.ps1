[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..\..")).Path
}

function Write-Check {
    param([string]$Message)
    Write-Host "[check] $Message"
}

function Assert-FileExists {
    param([string]$RelativePath)
    $path = Join-Path $script:RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required file: $RelativePath"
    }
    Write-Host "  OK file $RelativePath"
}

function Assert-Contains {
    param(
        [string]$RelativePath,
        [string[]]$RequiredText
    )
    $path = Join-Path $script:RepoRoot $RelativePath
    $content = Get-Content -LiteralPath $path -Raw
    foreach ($text in $RequiredText) {
        if (-not $content.Contains($text)) {
            throw "$RelativePath is missing required text: $text"
        }
    }
    Write-Host "  OK content $RelativePath"
}

function Assert-DoesNotContain {
    param(
        [string]$RelativePath,
        [string[]]$ForbiddenText
    )
    $path = Join-Path $script:RepoRoot $RelativePath
    $content = Get-Content -LiteralPath $path -Raw
    foreach ($text in $ForbiddenText) {
        if ($content.Contains($text)) {
            throw "$RelativePath contains forbidden text: $text"
        }
    }
    Write-Host "  OK forbidden-content guard $RelativePath"
}

$script:RepoRoot = Resolve-RepoRoot
Write-Host "v0.9.0-alpha.1 product completeness root: $script:RepoRoot"
Write-Host "This check is read-only. It does not install software, elevate, modify PATH/proxy/global environment settings, push, tag, release, or deploy."

Write-Check "Required standalone previews"
Assert-FileExists "preview\software-ui-preview.html"
Assert-FileExists "preview\website-preview.html"
Assert-FileExists "preview\README.md"

Write-Check "Software UI preview content"
Assert-Contains "preview\software-ui-preview.html" @(
    "Dashboard",
    "Command Approval",
    "Admin Permission Review",
    "Real installation disabled",
    "English",
    "简体中文",
    "prefers-reduced-motion",
    "data-theme-option",
    "data-language-option"
)
Assert-DoesNotContain "preview\software-ui-preview.html" @(
    "<script src=",
    "<link rel=""stylesheet"""
)

Write-Check "Website preview content"
Assert-Contains "preview\website-preview.html" @(
    "AI Local Environment Checker",
    "Windows Alpha Preview",
    "macOS Planned",
    "Linux Planned",
    "WSL Detection Preview",
    "Safety-first by design",
    "How it works",
    "v0.9.0-alpha.1",
    "prefers-reduced-motion"
)
Assert-DoesNotContain "preview\website-preview.html" @(
    "<script src=",
    "<link rel=""stylesheet"""
)

Write-Check "Desktop and website release accuracy"
Assert-Contains "apps\desktop-tauri\src\main.ts" @(
    "releases/tag/v0.9.0-alpha.1",
    "Alpha preview",
    "English",
    "简体中文"
)
Assert-DoesNotContain "apps\desktop-tauri\src\main.ts" @(
    "data-language-option=""zh-TW"""
)
Assert-Contains "website\index.html" @(
    "https://github.com/YUCZ-43/ai-local-env-checker/releases/tag/v0.9.0-alpha.1",
    "View prerelease"
)
Assert-DoesNotContain "website\index.html" @(
    "View prerelease placeholder"
)

Write-Check "Documentation references"
Assert-Contains "README.md" @(
    "preview/software-ui-preview.html",
    "preview/website-preview.html"
)
Assert-Contains "README.en-US.md" @(
    "preview/software-ui-preview.html",
    "preview/website-preview.html"
)
Assert-Contains "README.zh-CN.md" @(
    "preview/software-ui-preview.html",
    "preview/website-preview.html"
)
Assert-Contains "website\README.md" @(
    "GitHub Pages",
    "Vercel",
    "Cloudflare Pages"
)
Assert-FileExists "locales\zh-TW.json"

Write-Host "v0.9.0-alpha.1 product completeness checks passed."
