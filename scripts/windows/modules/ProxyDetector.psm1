$moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$commandRunnerPath = Join-Path $moduleDir "CommandRunner.psm1"
if (Test-Path -LiteralPath $commandRunnerPath) {
    Import-Module $commandRunnerPath -Force
}

$Script:CommonProxyPorts = @(7890, 7891, 7897, 1080, 10808, 10809, 2080, 3128, 8000, 8080, 8888, 9090)
$Script:LocalProxyHosts = @("127.0.0.1", "localhost", "::1")

function ConvertTo-MaskedProxyValue {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $masked = [string]$Value
    $masked = [regex]::Replace($masked, '(?i)\b([a-z][a-z0-9+.-]*://)([^/@\s:]+):([^/@\s]+)@', '$1***:***@')
    return $masked
}

function Test-ProxyValuePresent {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { return $false }

    $trimmed = $Value.Trim()
    if (-not $trimmed) { return $false }

    $lower = $trimmed.ToLowerInvariant()
    return -not ($lower -eq "null" -or $lower -eq "undefined" -or $lower -eq "none" -or $lower -eq "direct")
}

function Get-DefaultPortForScheme {
    param([string]$Scheme)

    switch -Regex ($Scheme) {
        '^https$' { return 443 }
        '^http$' { return 80 }
        '^socks' { return 1080 }
        default { return $null }
    }
}

function Test-LocalProxyHost {
    param([string]$HostName)

    if (-not $HostName) { return $false }
    $h = $HostName.Trim().ToLowerInvariant()
    return ($h -eq "localhost" -or $h -eq "127.0.0.1" -or $h -eq "::1" -or $h -eq "[::1]")
}

function Get-ProxyUrlInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [string]$Source = "unknown"
    )

    $value = $Url.Trim()
    $masked = ConvertTo-MaskedProxyValue $value
    $protocol = "unknown"
    $hostName = $null
    $port = $null

    $parseValue = $value
    if ($parseValue -match '^[a-zA-Z][a-zA-Z0-9+.-]*=') {
        $parseValue = ($parseValue -replace '^[^=]+=', '')
    }

    if ($parseValue -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        try {
            $uri = [System.Uri]$parseValue
            $protocol = $uri.Scheme
            $hostName = $uri.Host
            if ($uri.Port -gt 0) {
                $port = $uri.Port
            } else {
                $port = Get-DefaultPortForScheme -Scheme $protocol
            }
        } catch { }
    }

    if (-not $hostName -and $parseValue -match '^\[([^\]]+)\]:(\d+)$') {
        $hostName = $Matches[1]
        $port = [int]$Matches[2]
    } elseif (-not $hostName -and $parseValue -match '^([^:/\s;]+):(\d+)$') {
        $hostName = $Matches[1]
        $port = [int]$Matches[2]
    }

    return [ordered]@{
        Url = $masked
        Protocol = $protocol
        Host = $hostName
        Port = $port
        Source = $Source
        IsLocal = (Test-LocalProxyHost -HostName $hostName)
        IsValid = [bool]($hostName -and $port)
    }
}

function Test-ProxyTcpEndpoint {
    param(
        [Parameter(Mandatory=$true)]
        [string]$HostName,

        [Parameter(Mandatory=$true)]
        [int]$Port,

        [int]$TimeoutMs = 800
    )

    $tcp = $null
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($HostName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($wait) {
            $tcp.EndConnect($connect)
            return [ordered]@{ Host = $HostName; Port = $Port; Reachable = $true; Error = $null }
        }
        return [ordered]@{ Host = $HostName; Port = $Port; Reachable = $false; Error = "timeout" }
    } catch {
        return [ordered]@{ Host = $HostName; Port = $Port; Reachable = $false; Error = $_.Exception.Message }
    } finally {
        if ($tcp) {
            try { $tcp.Close() } catch { }
        }
    }
}

function Invoke-ProxyCurlTest {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProxyUrl,

        [int]$TimeoutSec = 10
    )

    $curlPath = Resolve-RunnerCommandPath -CommandName "curl.exe"
    if (-not $curlPath) {
        return [ordered]@{ Status = "SKIPPED"; ExitCode = $null; Notes = "curl.exe not available" }
    }

    $maxTime = 8
    if ($TimeoutSec -gt 0 -and $TimeoutSec -lt 8) {
        $maxTime = $TimeoutSec
    }

    $args = "-x $ProxyUrl -I https://github.com --max-time $maxTime --connect-timeout $maxTime -sS"
    $r = Invoke-CommandWithTimeout -FileName "curl.exe" -Arguments $args -TimeoutSec ($maxTime + 2)
    return [ordered]@{
        Status = $r.Status
        ExitCode = $r.ExitCode
        Notes = if ($r.Status -eq "OK") { "curl proxy test passed" } else { ConvertTo-MaskedProxyValue ($r.StdErr + $r.StdOut) }
    }
}

function Add-ProxyCandidate {
    param(
        [System.Collections.ArrayList]$Candidates,
        [string]$Source,
        [string]$Name,
        [string]$Value
    )

    if (Test-ProxyValuePresent $Value) {
        [void]$Candidates.Add([ordered]@{ Source = $Source; Name = $Name; Value = $Value.Trim() })
    }
}

function Get-MaskedProxyMap {
    param([hashtable]$RawMap)

    $masked = [ordered]@{}
    foreach ($k in $RawMap.Keys) {
        $masked[$k] = ConvertTo-MaskedProxyValue $RawMap[$k]
    }
    return $masked
}

function Read-CommandProxyValue {
    param(
        [string]$FileName,
        [string]$Arguments,
        [int]$TimeoutSec
    )

    $r = Invoke-CommandWithTimeout -FileName $FileName -Arguments $Arguments -TimeoutSec $TimeoutSec
    if ($r.Status -eq "OK" -and (Test-ProxyValuePresent $r.StdOut)) {
        return $r.StdOut.Trim()
    }
    return $null
}

function Get-ProxyConfigEntriesFromValue {
    param(
        [string]$Source,
        [string]$Name,
        [string]$Value
    )

    $entries = New-Object System.Collections.ArrayList
    if (-not (Test-ProxyValuePresent $Value)) {
        return $entries
    }

    $parts = $Value -split ';'
    foreach ($part in $parts) {
        $p = $part.Trim()
        if (-not $p) { continue }

        if ($p -match '^[a-zA-Z][a-zA-Z0-9+.-]*=') {
            $schemeName = ($p -replace '=.*$', '')
            $target = ($p -replace '^[^=]+=', '')
            if ($target -and $target -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
                $target = "${schemeName}://$target"
            }
            [void]$entries.Add([ordered]@{ Source = $Source; Name = $Name; Value = $target })
        } else {
            [void]$entries.Add([ordered]@{ Source = $Source; Name = $Name; Value = $p })
        }
    }

    return $entries
}

function Get-ProxyCandidatePorts {
    param([System.Collections.ArrayList]$Candidates)

    $ports = New-Object System.Collections.ArrayList
    $seen = @{}

    foreach ($port in $Script:CommonProxyPorts) {
        $key = [string]$port
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            [void]$ports.Add([int]$port)
        }
    }

    foreach ($candidate in $Candidates) {
        $entries = Get-ProxyConfigEntriesFromValue -Source $candidate.Source -Name $candidate.Name -Value $candidate.Value
        foreach ($entry in $entries) {
            $info = Get-ProxyUrlInfo -Url $entry.Value -Source $entry.Source
            if ($info.IsValid -and $info.IsLocal -and $info.Port -ge 1 -and $info.Port -le 65535) {
                $key = [string]$info.Port
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    [void]$ports.Add([int]$info.Port)
                }
            }
        }
    }

    return @($ports)
}

function Test-CandidateUsability {
    param([object]$Info)

    if (-not $Info.IsValid) {
        return [ordered]@{ IsUsable = $false; Confidence = "none"; Notes = @("proxy value could not be parsed") }
    }

    if ($Info.IsLocal) {
        $hostForTest = $Info.Host
        if ($hostForTest -eq "[::1]") { $hostForTest = "::1" }
        $tcp = Test-ProxyTcpEndpoint -HostName $hostForTest -Port $Info.Port -TimeoutMs 800
        if ($tcp.Reachable) {
            return [ordered]@{ IsUsable = $true; Confidence = "high"; Notes = @("local proxy TCP port is reachable") }
        }
        return [ordered]@{ IsUsable = $false; Confidence = "low"; Notes = @("local proxy TCP port is not reachable") }
    }

    return [ordered]@{ IsUsable = $true; Confidence = "medium"; Notes = @("configured non-local proxy; TCP probing skipped") }
}

function New-ProxyRecommendation {
    param(
        [System.Collections.ArrayList]$Candidates,
        [array]$LocalPortScan
    )

    $empty = [ordered]@{
        Url = $null
        Protocol = $null
        Host = $null
        Port = $null
        Source = $null
        Confidence = "none"
        IsUsable = $false
        Notes = @("no proxy candidates found")
    }

    $priorityGroups = @(
        @{ Sources = @("Environment.Process", "Environment.User", "Environment.Machine"); Names = @("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy") },
        @{ Sources = @("Npm", "Git"); Names = @("proxy", "https-proxy", "http.proxy", "https.proxy") },
        @{ Sources = @("WinHTTP", "WindowsInternetSettings"); Names = @("ProxyServer", "WinHTTP") }
    )

    foreach ($group in $priorityGroups) {
        foreach ($candidate in $Candidates) {
            if (($group.Sources -contains $candidate.Source) -and ($group.Names -contains $candidate.Name)) {
                $entries = Get-ProxyConfigEntriesFromValue -Source $candidate.Source -Name $candidate.Name -Value $candidate.Value
                foreach ($entry in $entries) {
                    $info = Get-ProxyUrlInfo -Url $entry.Value -Source "$($entry.Source):$($entry.Name)"
                    if ($info.Protocol -eq "http" -or $info.Protocol -eq "https" -or $info.Protocol -eq "unknown") {
                        $usable = Test-CandidateUsability -Info $info
                        if ($usable.IsUsable) {
                            return [ordered]@{
                                Url = $info.Url
                                Protocol = $info.Protocol
                                Host = $info.Host
                                Port = $info.Port
                                Source = $info.Source
                                Confidence = $usable.Confidence
                                IsUsable = $usable.IsUsable
                                Notes = $usable.Notes
                            }
                        }
                    }
                }
            }
        }
    }

    foreach ($protocol in @("http", "socks5h", "unknown")) {
        foreach ($scan in $LocalPortScan) {
            if ($scan.TcpReachable -and $scan.Protocol -eq $protocol) {
                return [ordered]@{
                    Url = $scan.Url
                    Protocol = $scan.Protocol
                    Host = "127.0.0.1"
                    Port = $scan.Port
                    Source = "LocalPortScan"
                    Confidence = if ($protocol -eq "unknown") { "low" } else { "medium" }
                    IsUsable = $true
                    Notes = if ($protocol -eq "unknown") { @("TCP listener found but proxy protocol was not confirmed") } else { @("local proxy protocol identified by curl test") }
                }
            }
        }
    }

    return $empty
}

function Invoke-ProxyDetection {
    param(
        [int]$TimeoutSec = 10,
        [switch]$SkipNetwork
    )

    $candidates = New-Object System.Collections.ArrayList
    $result = [ordered]@{}

    $envNamesProcess = @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")
    $envNamesScoped = @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY")
    $environment = [ordered]@{ Process = [ordered]@{}; User = [ordered]@{}; Machine = [ordered]@{} }

    foreach ($name in $envNamesProcess) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if (Test-ProxyValuePresent $value) {
            $environment.Process[$name] = ConvertTo-MaskedProxyValue $value
            Add-ProxyCandidate -Candidates $candidates -Source "Environment.Process" -Name $name -Value $value
        }
    }
    foreach ($name in $envNamesScoped) {
        $value = [Environment]::GetEnvironmentVariable($name, "User")
        if (Test-ProxyValuePresent $value) {
            $environment.User[$name] = ConvertTo-MaskedProxyValue $value
            Add-ProxyCandidate -Candidates $candidates -Source "Environment.User" -Name $name -Value $value
        }
    }
    foreach ($name in $envNamesScoped) {
        $value = [Environment]::GetEnvironmentVariable($name, "Machine")
        if (Test-ProxyValuePresent $value) {
            $environment.Machine[$name] = ConvertTo-MaskedProxyValue $value
            Add-ProxyCandidate -Candidates $candidates -Source "Environment.Machine" -Name $name -Value $value
        }
    }
    $result.Environment = $environment

    $npmRaw = @{}
    $npmProxy = Read-CommandProxyValue -FileName "npm.cmd" -Arguments "config get proxy" -TimeoutSec $TimeoutSec
    if ($npmProxy) {
        $npmRaw["proxy"] = $npmProxy
        Add-ProxyCandidate -Candidates $candidates -Source "Npm" -Name "proxy" -Value $npmProxy
    }
    $npmHttpsProxy = Read-CommandProxyValue -FileName "npm.cmd" -Arguments "config get https-proxy" -TimeoutSec $TimeoutSec
    if ($npmHttpsProxy) {
        $npmRaw["https-proxy"] = $npmHttpsProxy
        Add-ProxyCandidate -Candidates $candidates -Source "Npm" -Name "https-proxy" -Value $npmHttpsProxy
    }
    $result.Npm = Get-MaskedProxyMap -RawMap $npmRaw

    $gitRaw = @{}
    $gitHttpProxy = Read-CommandProxyValue -FileName "git" -Arguments "config --global --get http.proxy" -TimeoutSec $TimeoutSec
    if ($gitHttpProxy) {
        $gitRaw["http.proxy"] = $gitHttpProxy
        Add-ProxyCandidate -Candidates $candidates -Source "Git" -Name "http.proxy" -Value $gitHttpProxy
    }
    $gitHttpsProxy = Read-CommandProxyValue -FileName "git" -Arguments "config --global --get https.proxy" -TimeoutSec $TimeoutSec
    if ($gitHttpsProxy) {
        $gitRaw["https.proxy"] = $gitHttpsProxy
        Add-ProxyCandidate -Candidates $candidates -Source "Git" -Name "https.proxy" -Value $gitHttpsProxy
    }
    $result.Git = Get-MaskedProxyMap -RawMap $gitRaw

    $winhttpRaw = ""
    $winhttpParsed = @()
    $winhttpResult = Invoke-CommandWithTimeout -FileName "netsh" -Arguments "winhttp show proxy" -TimeoutSec $TimeoutSec
    if ($winhttpResult.Status -eq "OK" -or $winhttpResult.Status -eq "ERROR") {
        $winhttpRaw = ($winhttpResult.StdOut + $winhttpResult.StdErr).Trim()
        if ($winhttpRaw -match "Proxy Server\(s\)\s*:\s*(.+)") {
            $serverText = $Matches[1].Trim()
            Add-ProxyCandidate -Candidates $candidates -Source "WinHTTP" -Name "WinHTTP" -Value $serverText
            $winhttpParsed = @(Get-ProxyConfigEntriesFromValue -Source "WinHTTP" -Name "WinHTTP" -Value $serverText)
        }
    }
    $result.WinHTTP = [ordered]@{
        Status = $winhttpResult.Status
        Raw = ConvertTo-MaskedProxyValue $winhttpRaw
        Parsed = @($winhttpParsed | ForEach-Object { Get-ProxyUrlInfo -Url $_.Value -Source "WinHTTP" })
    }

    $internetSettings = [ordered]@{ ProxyEnable = $null; ProxyServer = $null; AutoConfigURL = $null; Error = $null }
    try {
        $reg = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction Stop
        $internetSettings.ProxyEnable = $reg.ProxyEnable
        if (Test-ProxyValuePresent $reg.ProxyServer) {
            $internetSettings.ProxyServer = ConvertTo-MaskedProxyValue $reg.ProxyServer
            Add-ProxyCandidate -Candidates $candidates -Source "WindowsInternetSettings" -Name "ProxyServer" -Value $reg.ProxyServer
        }
        if (Test-ProxyValuePresent $reg.AutoConfigURL) {
            $internetSettings.AutoConfigURL = ConvertTo-MaskedProxyValue $reg.AutoConfigURL
        }
    } catch {
        $internetSettings.Error = $_.Exception.Message
    }
    $result.WindowsInternetSettings = $internetSettings

    $localScan = New-Object System.Collections.ArrayList
    foreach ($port in (Get-ProxyCandidatePorts -Candidates $candidates)) {
        $endpoints = @()
        $reachable = $false
        foreach ($hostName in $Script:LocalProxyHosts) {
            $tcp = Test-ProxyTcpEndpoint -HostName $hostName -Port $port -TimeoutMs 500
            $endpoints += $tcp
            if ($tcp.Reachable) {
                $reachable = $true
            }
        }

        $httpTest = [ordered]@{ Status = "SKIPPED"; ExitCode = $null; Notes = "TCP not reachable" }
        $socksTest = [ordered]@{ Status = "SKIPPED"; ExitCode = $null; Notes = "TCP not reachable" }
        $protocol = "unknown"
        $url = $null
        $notes = @()

        if ($reachable) {
            if ($SkipNetwork) {
                $notes += "protocol test skipped by -SkipNetwork"
            } else {
                $httpUrl = "http://127.0.0.1:$port"
                $socksUrl = "socks5h://127.0.0.1:$port"
                $httpTest = Invoke-ProxyCurlTest -ProxyUrl $httpUrl -TimeoutSec $TimeoutSec
                if ($httpTest.Status -eq "OK") {
                    $protocol = "http"
                    $url = $httpUrl
                } else {
                    $socksTest = Invoke-ProxyCurlTest -ProxyUrl $socksUrl -TimeoutSec $TimeoutSec
                    if ($socksTest.Status -eq "OK") {
                        $protocol = "socks5h"
                        $url = $socksUrl
                    }
                }
            }

            if (-not $url) {
                $url = "tcp://127.0.0.1:$port"
                $notes += "TCP listener found; proxy protocol not confirmed"
            }
        }

        [void]$localScan.Add([ordered]@{
            Port = $port
            TcpReachable = $reachable
            Endpoints = $endpoints
            Protocol = $protocol
            Url = $url
            HttpProxyTest = $httpTest
            Socks5ProxyTest = $socksTest
            Notes = $notes
        })
    }
    $result.LocalPortScan = $localScan
    $result.RecommendedProxy = New-ProxyRecommendation -Candidates $candidates -LocalPortScan $localScan

    return $result
}

Export-ModuleMember -Function ConvertTo-MaskedProxyValue, Get-ProxyUrlInfo, Invoke-ProxyDetection, Test-ProxyTcpEndpoint
