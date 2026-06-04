function Resolve-RunnerCommandPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CommandName,

        [string[]]$PreferredExtensions = @(".cmd", ".bat", ".exe", "")
    )

    if (-not $CommandName) {
        return $null
    }

    $candidateSet = New-Object System.Collections.ArrayList

    function Add-RunnerCommandCandidate {
        param([string]$Path)
        if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf) -and -not $candidateSet.Contains($Path)) {
            [void]$candidateSet.Add($Path)
        }
    }

    $hasDirectory = ($CommandName -match '[\\/]') -or [System.IO.Path]::IsPathRooted($CommandName)
    $extension = [System.IO.Path]::GetExtension($CommandName)

    if ($hasDirectory) {
        if ($extension) {
            Add-RunnerCommandCandidate $CommandName
        } else {
            foreach ($ext in $PreferredExtensions) {
                Add-RunnerCommandCandidate "$CommandName$ext"
            }
            Add-RunnerCommandCandidate $CommandName
        }
    } else {
        $names = @()
        if ($extension) {
            $names += $CommandName
        } else {
            foreach ($ext in $PreferredExtensions) {
                $names += "$CommandName$ext"
            }
            $names += $CommandName
        }

        if ($env:PATH) {
            foreach ($dir in ($env:PATH -split ';')) {
                if ($dir -and $dir.Trim()) {
                    foreach ($name in $names) {
                        Add-RunnerCommandCandidate (Join-Path $dir.Trim() $name)
                    }
                }
            }
        }

        try {
            $commands = Get-Command $CommandName -CommandType Application -ErrorAction SilentlyContinue
            foreach ($cmd in $commands) {
                if ($cmd.Path) {
                    Add-RunnerCommandCandidate $cmd.Path
                } elseif ($cmd.Source) {
                    Add-RunnerCommandCandidate $cmd.Source
                }
            }
        } catch { }
    }

    foreach ($ext in $PreferredExtensions) {
        $match = $candidateSet | Where-Object {
            if ($ext -eq "") {
                [System.IO.Path]::GetExtension($_) -eq ""
            } else {
                [System.IO.Path]::GetExtension($_).Equals($ext, [System.StringComparison]::OrdinalIgnoreCase)
            }
        } | Select-Object -First 1
        if ($match) {
            return $match
        }
    }

    return ($candidateSet | Select-Object -First 1)
}

function Invoke-CommandWithTimeout {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,

        [string]$Arguments = "",

        [int]$TimeoutSec = 10
    )

    if ($TimeoutSec -le 0) {
        $TimeoutSec = 10
    }

    $startTime = Get-Date
    $executionFile = Resolve-RunnerCommandPath -CommandName $FileName
    if (-not $executionFile) {
        $executionFile = $FileName
    }

    $isCmdBat = $executionFile -match '\.(cmd|bat)$'
    $argumentSuffix = if ($Arguments) { " $Arguments" } else { "" }
    $commandStr = $executionFile
    if ($Arguments) {
        $commandStr = "$executionFile $Arguments"
    }
    if ($isCmdBat) {
        $commandStr = "cmd.exe /d /s /c `"`"$executionFile`"$argumentSuffix`""
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($isCmdBat) {
        $psi.FileName = "cmd.exe"
        $psi.Arguments = "/d /s /c `"`"$executionFile`"$argumentSuffix`""
    } else {
        $psi.FileName = $executionFile
        $psi.Arguments = $Arguments
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    $stdOut = ""
    $stdErr = ""
    $exitCode = $null
    $status = "OK"

    try {
        $process.Start() | Out-Null
        $completed = $process.WaitForExit($TimeoutSec * 1000)

        if (-not $completed) {
            try { $process.Kill() } catch { }
            $process.WaitForExit(2000) | Out-Null
            $status = "TIMEOUT"
        }

        try {
            $stdOut = $process.StandardOutput.ReadToEnd()
            if ($stdOut) { $stdOut = $stdOut.Trim() }
        } catch {
            $stdOut = ""
        }

        try {
            $stdErr = $process.StandardError.ReadToEnd()
            if ($stdErr) { $stdErr = $stdErr.Trim() }
        } catch {
            $stdErr = ""
        }

        if ($status -ne "TIMEOUT") {
            $exitCode = $process.ExitCode
            if ($exitCode -eq 0) {
                $status = "OK"
            } else {
                $status = "ERROR"
            }
        }
    } catch [System.ComponentModel.Win32Exception] {
        $status = "ERROR"
        $stdErr = "command not found: $FileName"
    } catch {
        $status = "ERROR"
        $stdErr = $_.Exception.Message
    } finally {
        if ($process) {
            try {
                if (-not $process.HasExited) {
                    $process.Kill()
                }
            } catch { }
        }
    }

    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 1)

    return [ordered]@{
        Command = $commandStr
        FileName = $FileName
        ResolvedFileName = $executionFile
        Arguments = $Arguments
        ExitCode = $exitCode
        StdOut = $stdOut
        StdErr = $stdErr
        Status = $status
        ElapsedMs = $elapsed
    }
}

Export-ModuleMember -Function Resolve-RunnerCommandPath, Invoke-CommandWithTimeout
