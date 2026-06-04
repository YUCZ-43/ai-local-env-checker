[CmdletBinding(DefaultParameterSetName = "CheckOnly")]
param(
    [Parameter(ParameterSetName = "CheckOnly")]
    [switch]$CheckOnly,

    [Parameter(ParameterSetName = "Install")]
    [switch]$Install,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$FixPath,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$VerboseLog,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$SkipCodex,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$SkipClaude,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$SkipVSCode,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$SkipWSL,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [switch]$SkipNetwork,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [int]$CommandTimeoutSec = 10,

    [Parameter(ParameterSetName = "CheckOnly")]
    [Parameter(ParameterSetName = "Install")]
    [ValidateSet("zh-CN", "en-US")]
    [string]$Language = "zh-CN"
)

$rootScript = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "install.ps1"
& $rootScript @PSBoundParameters
exit $LASTEXITCODE
