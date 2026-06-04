[CmdletBinding()]
param(
    [string]$Version = "0.3.0-preview"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$distDir = Join-Path $repoRoot "dist"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-local-env-checker-release-" + [System.Guid]::NewGuid().ToString("N"))

function Write-Info {
    param([string]$Message)
    Write-Host "[release] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[release][WARN] $Message" -ForegroundColor Yellow
}

function New-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-RepoItem {
    param(
        [string]$RelativePath,
        [string]$DestinationRoot
    )

    $source = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $source)) {
        return
    }

    $destination = Join-Path $DestinationRoot $RelativePath
    $parent = Split-Path -Parent $destination
    if ($parent) {
        New-Directory -Path $parent
    }

    Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
}

function Initialize-PackageOutputDirs {
    param([string]$PackageRoot)

    foreach ($name in @("logs", "reports")) {
        $dir = Join-Path $PackageRoot $name
        New-Directory -Path $dir
        $keep = Join-Path $dir ".gitkeep"
        if (-not (Test-Path -LiteralPath $keep)) {
            New-Item -ItemType File -Path $keep -Force | Out-Null
        }
    }
}

function New-PackageRoot {
    param([string]$Name)

    $path = Join-Path $tempRoot $Name
    New-Directory -Path $path
    return $path
}

function New-ZipPackage {
    param(
        [string]$PackageRoot,
        [string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath) {
        Remove-Item -LiteralPath $DestinationPath -Force
    }

    $items = Join-Path $PackageRoot "*"
    Compress-Archive -Path $items -DestinationPath $DestinationPath -CompressionLevel Optimal
}

function New-TarGzPackage {
    param(
        [string]$PackageRoot,
        [string]$DestinationPath
    )

    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tar) {
        return $false
    }

    if (Test-Path -LiteralPath $DestinationPath) {
        Remove-Item -LiteralPath $DestinationPath -Force
    }

    & $tar.Source -czf $DestinationPath -C $PackageRoot .
    if ($LASTEXITCODE -ne 0) {
        throw "tar failed while creating $DestinationPath"
    }

    return $true
}

function Copy-CommonPackageFiles {
    param([string]$PackageRoot)

    foreach ($file in @("README.md", "README.zh-CN.md", "README.en-US.md", "LICENSE", "SECURITY.md", "CHANGELOG.md")) {
        Copy-RepoItem -RelativePath $file -DestinationRoot $PackageRoot
    }

    foreach ($dir in @("docs", "locales")) {
        Copy-RepoItem -RelativePath $dir -DestinationRoot $PackageRoot
    }
}

function New-WindowsPackageRoot {
    $packageRoot = New-PackageRoot -Name "windows"
    Copy-CommonPackageFiles -PackageRoot $packageRoot

    foreach ($item in @("install.ps1", "verify.ps1", "config.example.json", "scripts/windows")) {
        Copy-RepoItem -RelativePath $item -DestinationRoot $packageRoot
    }

    Initialize-PackageOutputDirs -PackageRoot $packageRoot
    return $packageRoot
}

function New-PlatformPackageRoot {
    param(
        [string]$Name,
        [string[]]$ScriptDirs
    )

    $packageRoot = New-PackageRoot -Name $Name
    Copy-CommonPackageFiles -PackageRoot $packageRoot

    foreach ($scriptDir in $ScriptDirs) {
        Copy-RepoItem -RelativePath $scriptDir -DestinationRoot $packageRoot
    }

    Initialize-PackageOutputDirs -PackageRoot $packageRoot
    return $packageRoot
}

function Test-ExcludedSourcePath {
    param(
        [string]$RelativePath,
        [bool]$IsDirectory
    )

    $path = ($RelativePath -replace "\\", "/").TrimStart("/")
    if ([string]::IsNullOrEmpty($path)) {
        return $false
    }

    $parts = $path -split "/"
    $first = $parts[0]
    $leaf = $parts[$parts.Length - 1]

    if ($first -in @(".git", ".codex", ".claude")) {
        return $true
    }

    if ($first -eq "dist" -and $path -ne "dist/.gitkeep") {
        return $true
    }

    if ($path.StartsWith("logs/") -and $path -ne "logs/.gitkeep") {
        return $true
    }

    if ($path.StartsWith("reports/") -and $path -ne "reports/.gitkeep") {
        return $true
    }

    foreach ($pattern in @(".env", ".env.*", "*.env", "*.local", "*.token", "*.tokens", "*.key", "*.keys", "*.pem", "*.pfx", "*.p12", "id_rsa*", "id_ed25519*", "secrets.*", "credentials.*")) {
        if ($leaf -like $pattern) {
            return $true
        }
    }

    return $false
}

function Copy-SourceDirectory {
    param(
        [string]$SourceDir,
        [string]$TargetDir,
        [string]$RelativeBase
    )

    New-Directory -Path $TargetDir

    foreach ($item in Get-ChildItem -LiteralPath $SourceDir -Force) {
        if ([string]::IsNullOrEmpty($RelativeBase)) {
            $relativePath = $item.Name
        } else {
            $relativePath = "$RelativeBase/$($item.Name)"
        }

        if (Test-ExcludedSourcePath -RelativePath $relativePath -IsDirectory:$item.PSIsContainer) {
            continue
        }

        $target = Join-Path $TargetDir $item.Name
        if ($item.PSIsContainer) {
            Copy-SourceDirectory -SourceDir $item.FullName -TargetDir $target -RelativeBase $relativePath
        } else {
            Copy-Item -LiteralPath $item.FullName -Destination $target -Force
        }
    }
}

try {
    Write-Info "Repository root: $repoRoot"
    Write-Info "Version: $Version"

    New-Directory -Path $distDir
    New-Directory -Path $tempRoot

    Write-Info "Cleaning generated archives in dist/"
    foreach ($pattern in @("ai-local-env-checker-*.zip", "ai-local-env-checker-*.tar.gz", "ai-local-env-checker-*.tgz", "ai-local-env-checker-*.7z")) {
        Get-ChildItem -LiteralPath $distDir -File -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }

    $windowsRoot = New-WindowsPackageRoot
    $windowsZip = Join-Path $distDir "ai-local-env-checker-windows-v$Version.zip"
    New-ZipPackage -PackageRoot $windowsRoot -DestinationPath $windowsZip

    $sourceRoot = New-PackageRoot -Name "source"
    Copy-SourceDirectory -SourceDir $repoRoot -TargetDir $sourceRoot -RelativeBase ""
    $sourceZip = Join-Path $distDir "ai-local-env-checker-source-v$Version.zip"
    New-ZipPackage -PackageRoot $sourceRoot -DestinationPath $sourceZip

    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if ($tar) {
        $platforms = @(
            @{ Name = "wsl"; Scripts = @("scripts/wsl", "scripts/linux") },
            @{ Name = "linux"; Scripts = @("scripts/linux") },
            @{ Name = "macos"; Scripts = @("scripts/macos") }
        )

        foreach ($platform in $platforms) {
            $packageRoot = New-PlatformPackageRoot -Name $platform.Name -ScriptDirs $platform.Scripts
            $tarPath = Join-Path $distDir "ai-local-env-checker-$($platform.Name)-v$Version.tar.gz"
            [void](New-TarGzPackage -PackageRoot $packageRoot -DestinationPath $tarPath)
        }
    } else {
        Write-Warn "tar was not found. Skipping optional WSL/Linux/macOS tar.gz packages."
    }

    Write-Info "Package list:"
    Get-ChildItem -LiteralPath $distDir -File | Where-Object {
        $_.Name -like "ai-local-env-checker-*"
    } | Sort-Object Name | ForEach-Object {
        Write-Host ("  {0}" -f $_.Name)
    }
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
