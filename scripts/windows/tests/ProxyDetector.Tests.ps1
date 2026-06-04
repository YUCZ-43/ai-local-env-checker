$ErrorActionPreference = "Stop"

$testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path (Split-Path -Parent $testDir) "modules\ProxyDetector.psm1"

Import-Module $modulePath -Force

function Assert-Equal {
    param(
        [string]$Name,
        $Expected,
        $Actual
    )

    if ($Expected -ne $Actual) {
        throw "$Name failed. Expected '$Expected', got '$Actual'"
    }
}

$masked = ConvertTo-MaskedProxyValue "http://user:password@127.0.0.1:7890"
Assert-Equal "credential masking" "http://***:***@127.0.0.1:7890" $masked

$info = Get-ProxyUrlInfo -Url "socks5h://user:password@localhost:1080" -Source "test"
Assert-Equal "masked url info" "socks5h://***:***@localhost:1080" $info.Url
Assert-Equal "protocol info" "socks5h" $info.Protocol
Assert-Equal "host info" "localhost" $info.Host
Assert-Equal "port info" 1080 $info.Port

$plain = Get-ProxyUrlInfo -Url "127.0.0.1:8080" -Source "test"
Assert-Equal "plain protocol" "unknown" $plain.Protocol
Assert-Equal "plain host" "127.0.0.1" $plain.Host
Assert-Equal "plain port" 8080 $plain.Port

Write-Output "ProxyDetector tests passed"
