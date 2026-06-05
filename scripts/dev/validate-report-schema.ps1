[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

function Read-JsonFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RelativePath
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required JSON file: $RelativePath"
    }

    try {
        return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    } catch {
        throw "Invalid JSON in $RelativePath`: $($_.Exception.Message)"
    }
}

function Test-JsonProperty {
    param(
        [Parameter(Mandatory=$true)]
        $Object,

        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    foreach ($property in $Object.PSObject.Properties) {
        if ($property.Name -ceq $Name) {
            return $true
        }
    }

    return $false
}

function Assert-JsonProperty {
    param(
        [Parameter(Mandatory=$true)]
        $Object,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$RelativePath
    )

    if (-not (Test-JsonProperty -Object $Object -Name $Name)) {
        throw "$RelativePath must contain '$Name'."
    }
}

function Assert-AnyJsonProperty {
    param(
        [Parameter(Mandatory=$true)]
        $Object,

        [Parameter(Mandatory=$true)]
        [string[]]$Names,

        [Parameter(Mandatory=$true)]
        [string]$RelativePath
    )

    foreach ($name in $Names) {
        if (Test-JsonProperty -Object $Object -Name $name) {
            return
        }
    }

    throw "$RelativePath must contain one of: $($Names -join ', ')."
}

$schemaPath = "core/schema/report.schema.json"
$installExamplePath = "examples/reports/install-report.example.json"
$verifyExamplePath = "examples/reports/verify-report.example.json"
$productExamplePath = "examples/reports/product-report.example.json"

Write-Host "Checking report schema JSON..."
$null = Read-JsonFile -RelativePath $schemaPath

Write-Host "Checking example report JSON..."
$installExample = Read-JsonFile -RelativePath $installExamplePath
$verifyExample = Read-JsonFile -RelativePath $verifyExamplePath
$productExample = Read-JsonFile -RelativePath $productExamplePath

Write-Host "Checking example report structure..."
Assert-JsonProperty -Object $installExample -Name "Meta" -RelativePath $installExamplePath
Assert-AnyJsonProperty -Object $installExample -Names @("Results", "CommandResults") -RelativePath $installExamplePath

Assert-JsonProperty -Object $verifyExample -Name "Meta" -RelativePath $verifyExamplePath
Assert-AnyJsonProperty -Object $verifyExample -Names @("Status", "Commands") -RelativePath $verifyExamplePath

Assert-JsonProperty -Object $productExample -Name "meta" -RelativePath $productExamplePath
Assert-JsonProperty -Object $productExample -Name "summary" -RelativePath $productExamplePath

Write-Host "Report schema validation checks passed."
