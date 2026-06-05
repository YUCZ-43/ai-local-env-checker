[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$goCliRoot = Join-Path $repoRoot "apps\cli-go"
$safePlan = Join-Path $repoRoot "examples\install-plans\windows-safe-demo-plan.json"

function Invoke-SafeCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string[]]$Arguments,

        [Parameter(Mandatory=$true)]
        [string]$WorkingDirectory
    )

    Write-Host "Running: $FilePath $($Arguments -join ' ')"
    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Command failed with exit code $($process.ExitCode): $FilePath $($Arguments -join ' ')"
    }
}

function Test-PowerShellParser {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RelativePath
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing PowerShell file: $RelativePath"
    }

    Write-Host "Parsing PowerShell: $RelativePath"
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $messages = $errors | ForEach-Object { $_.Message }
        throw "Parser errors in $RelativePath`: $($messages -join '; ')"
    }
}

function Test-JsonFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    Write-Host "Parsing JSON: $Path"
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json | Out-Null
}

Write-Host "v0.5.0 runner validation is safe-only. It does not install, repair, delete, or modify PATH."

$powerShellFiles = @(
    "install.ps1",
    "verify.ps1",
    "scripts\windows\install.ps1",
    "scripts\windows\verify.ps1",
    "scripts\dev\check-windows-dev-env.ps1",
    "scripts\dev\validate-report-schema.ps1",
    "scripts\dev\check-v0.5.0-runner.ps1"
)

foreach ($file in $powerShellFiles) {
    Test-PowerShellParser -RelativePath $file
}

$jsonFiles = @(
    (Join-Path $repoRoot "core\schema\install-plan.schema.json"),
    (Join-Path $repoRoot "core\schema\report.schema.json")
)

$jsonFiles += Get-ChildItem -LiteralPath (Join-Path $repoRoot "examples\install-plans") -Filter "*.json" | Select-Object -ExpandProperty FullName
$jsonFiles += Get-ChildItem -LiteralPath (Join-Path $repoRoot "examples\reports") -Filter "*.json" | Select-Object -ExpandProperty FullName

foreach ($file in $jsonFiles) {
    Test-JsonFile -Path $file
}

Invoke-SafeCommand -FilePath "go" -Arguments @("test", "./...") -WorkingDirectory $goCliRoot
Invoke-SafeCommand -FilePath "go" -Arguments @("build", "./...") -WorkingDirectory $goCliRoot

$relativeSafePlan = "..\..\examples\install-plans\windows-safe-demo-plan.json"
Invoke-SafeCommand -FilePath "go" -Arguments @("run", ".", "plan", "validate", "--file", $relativeSafePlan) -WorkingDirectory $goCliRoot
Invoke-SafeCommand -FilePath "go" -Arguments @("run", ".", "plan", "simulate", "--file", $relativeSafePlan) -WorkingDirectory $goCliRoot
Invoke-SafeCommand -FilePath "go" -Arguments @("run", ".", "plan", "run", "--file", $relativeSafePlan, "--dry-run") -WorkingDirectory $goCliRoot

Write-Host "v0.5.0 runner validation passed."
