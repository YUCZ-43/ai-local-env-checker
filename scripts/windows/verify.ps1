param(
    [switch]$JsonOutput,
    [int]$CommandTimeoutSec = 10,

    [ValidateSet("zh-CN", "en-US")]
    [string]$Language = "zh-CN"
)

$rootScript = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "verify.ps1"
& $rootScript @PSBoundParameters
exit $LASTEXITCODE
