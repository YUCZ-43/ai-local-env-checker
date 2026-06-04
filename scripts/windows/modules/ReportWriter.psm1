function Save-JsonData {
    param(
        [Parameter(Mandatory=$true)]
        $Data,

        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $Data | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}

function ConvertTo-SimpleMarkdownTable {
    param([hashtable]$Rows)

    $lines = @("| Field | Value |", "|-------|-------|")
    foreach ($key in $Rows.Keys) {
        $lines += "| $key | $($Rows[$key]) |"
    }
    return ($lines -join "`n")
}

Export-ModuleMember -Function Save-JsonData, ConvertTo-SimpleMarkdownTable
