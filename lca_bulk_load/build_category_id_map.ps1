param(
    [Parameter(Mandatory=$true)] [string] $FreshCategoryCsv,
    [Parameter(Mandatory=$true)] [string] $ExistingCategoryCsv,
    [Parameter(Mandatory=$true)] [string] $OutMapCsv
)
$ErrorActionPreference = "Stop"

$existing = Import-Csv $ExistingCategoryCsv
$byName = @{}
foreach ($row in $existing) { $byName[$row.name.Trim()] = $row.id }

$fresh = Import-Csv $FreshCategoryCsv
$mapRows = New-Object System.Collections.Generic.List[object]
$unmatched = 0
foreach ($row in $fresh) {
    $name = $row.name.Trim()
    if ($byName.ContainsKey($name)) {
        $mapRows.Add([PSCustomObject]@{ uuid = $row.id; existingId = $byName[$name]; name = $name })
    } else {
        $mapRows.Add([PSCustomObject]@{ uuid = $row.id; existingId = ""; name = $name })
        $unmatched++
        Write-Output "NO MATCH: $($row.id) [$name]"
    }
}
$mapRows | Export-Csv -Path $OutMapCsv -NoTypeInformation
Write-Output "Total: $($fresh.Count), matched: $($fresh.Count - $unmatched), unmatched: $unmatched"
Write-Output "Map written to: $OutMapCsv"
