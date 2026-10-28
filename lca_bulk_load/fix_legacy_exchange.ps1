<#
============================================================
fix_legacy_exchange.ps1

Fixes a regression overlooked when Exchange was removed: the 9
"candidate" manufacturing processes (PROC_MJF, PROC_SLS, PROC_FFF, PROC_CNC,
PROC_LASER, PROC_BEND, PROC_SILCAST, PROC_RUBBER, PROC_OVERMOLD) had
36 real HAS_EXCHANGE/REFERS_TO_FLOW connections (material/energy input,
part/waste output) -- without a migration these 9 processes and their
10 flows (FLOW_PA12 etc.) would have remained isolated.

In addition: ImpactResult -[:DERIVED_FROM]-> Exchange (165 rows, real
hotspot provenance links) and Exchange -[:HAS_DATA]-> DataItem
(1 row) would likewise have silently lost data when Exchange was removed.
Since a relationship in Neo4j cannot be the target of another
relationship (Exchange now exists only as a HAS_FLOW property,
no longer as a node), both are redirected to the respective FLOW node,
with the original Exchange id as a new exchangeId property
-- so the precision "from which Exchange" is preserved.
============================================================
#>

<#
One-time historical build script (model rebuild, see lca_bulk_load/README.md)
-- not part of the regular reproducible pipeline. Its inputs ($v7, an older
model snapshot) aren't included in this repo; adjust all paths below to
your own environment before running.
#>
$ErrorActionPreference = "Stop"

$v7 = "./scratch/v7_verify"
$mergedDir = "./scratch/rebuild/merged"
$buildDir = "./scratch/rebuild/build"
$kanalBDir = "./scratch/rebuild/kanal_b"

function Write-UnquotedCsv {
    param([Parameter(ValueFromPipeline=$true)] $InputObject, [string]$Path, [string[]]$Columns)
    begin { $lines = New-Object System.Collections.Generic.List[string]; $lines.Add(($Columns -join ',')) }
    process { $vals = foreach ($c in $Columns) { $InputObject.$c }; $lines.Add(($vals -join ',')) }
    end { [System.IO.File]::WriteAllLines($Path, $lines, (New-Object System.Text.UTF8Encoding($false))) }
}

# --- Lookups from the old (now removed) Exchange structures ---
$exchanges = Import-Csv (Join-Path $v7 "Exchange.csv")
$hasExchange = Import-Csv (Join-Path $v7 "r_20_HAS_EXCHANGE_Process_TO_Exchange.csv")
$refersToFlow = Import-Csv (Join-Path $v7 "r_31_REFERS_TO_FLOW_Exchange_TO_Flow.csv")

$exchangeToProcess = @{}
foreach ($row in $hasExchange) { $exchangeToProcess[$row.to_id] = $row.from_id }
$exchangeToFlow = @{}
foreach ($row in $refersToFlow) { $exchangeToFlow[$row.from_id] = $row.to_id }

Write-Output "[INFO] $($exchanges.Count) exchanges, $($exchangeToProcess.Count) process assignments, $($exchangeToFlow.Count) flow assignments loaded."

# --- 1) Create 36 legacy HAS_FLOW rows (exchangeId = original exchange id) ---
$hfCols = @('exchangeId','from_id','to_id','amount','unit','direction','location','quantitativeReference','ratioToReference','dataMaturity','referenceYear','uncertainty','comment')
$legacyHasFlow = foreach ($ex in $exchanges) {
    $procId = $exchangeToProcess[$ex.id]
    $flowId = $exchangeToFlow[$ex.id]
    if (-not $procId -or -not $flowId) { Write-Output "[WARNING] No complete assignment for $($ex.id) -- skipped."; continue }
    [PSCustomObject]@{
        exchangeId = $ex.id
        from_id = $procId
        to_id = $flowId
        amount = $ex.amount
        unit = $ex.unit
        direction = $ex.direction
        location = $ex.location
        quantitativeReference = $ex.quantitativeReference
        ratioToReference = $ex.amount   # Referenzmenge ist ueberall 1.0 -> ratio == amount
        dataMaturity = $ex.dataMaturity
        referenceYear = ""
        uncertainty = ""
        comment = $ex.comment
    }
}
Write-Output "[OK] $($legacyHasFlow.Count) legacy HAS_FLOW rows created (for the 9 candidate manufacturing processes)."

# Append to the merged HAS_FLOW.csv (channel B)
$existingMergedHf = Import-Csv (Join-Path $mergedDir "r_HAS_FLOW_Process_TO_Flow.csv")
$combinedHf = @($existingMergedHf) + @($legacyHasFlow)
$dupCheck = $combinedHf | Group-Object exchangeId | Where-Object { $_.Count -gt 1 }
if ($dupCheck.Count -gt 0) { throw "exchangeId duplicates after appending the legacy HAS_FLOW rows: $($dupCheck.Name -join ', ')" }
$combinedHf | Write-UnquotedCsv -Path (Join-Path $mergedDir "r_HAS_FLOW_Process_TO_Flow.csv") -Columns $hfCols
$combinedHf | Write-UnquotedCsv -Path (Join-Path $kanalBDir "HAS_FLOW.csv") -Columns $hfCols
Write-Output "[OK] HAS_FLOW.csv updated: $($combinedHf.Count) rows in total (before: $($existingMergedHf.Count))."

# --- 2) DERIVED_FROM: redirect Exchange -> Flow, exchangeId as a new property ---
$derivedFrom = Import-Csv (Join-Path $v7 "r_5_DERIVED_FROM_ImpactResult_TO_Exchange.csv")
$dfCols = @('from_id','to_id','exchangeId','contribution')
$newDerivedFrom = foreach ($row in $derivedFrom) {
    $flowId = $exchangeToFlow[$row.to_id]
    if (-not $flowId) { Write-Output "[WARNING] DERIVED_FROM: no flow assignment for $($row.to_id) -- skipped."; continue }
    [PSCustomObject]@{ from_id = $row.from_id; to_id = $flowId; exchangeId = $row.to_id; contribution = $row.contribution }
}
$newDerivedFrom | Write-UnquotedCsv -Path (Join-Path $buildDir "r_5_DERIVED_FROM_ImpactResult_TO_Flow.csv") -Columns $dfCols
Write-Output "[OK] r_5_DERIVED_FROM_ImpactResult_TO_Flow.csv created: $($newDerivedFrom.Count) rows (Exchange->Flow redirected, exchangeId preserved)."

# --- 3) HAS_DATA (Exchange->DataItem): redirect Exchange -> Flow ---
$hasDataEx = Import-Csv (Join-Path $v7 "r_15_HAS_DATA_Exchange_TO_DataItem.csv")
$hdCols = @('from_id','to_id','exchangeId','role')
$newHasDataFlow = foreach ($row in $hasDataEx) {
    $flowId = $exchangeToFlow[$row.from_id]
    if (-not $flowId) { Write-Output "[WARNING] HAS_DATA: no flow assignment for $($row.from_id) -- skipped."; continue }
    [PSCustomObject]@{ from_id = $flowId; to_id = $row.to_id; exchangeId = $row.from_id; role = $row.role }
}
$newHasDataFlow | Write-UnquotedCsv -Path (Join-Path $buildDir "r_15b_HAS_DATA_Flow_TO_DataItem.csv") -Columns $hdCols
Write-Output "[OK] r_15b_HAS_DATA_Flow_TO_DataItem.csv created: $($newHasDataFlow.Count) row(s)."

Write-Output ""
Write-Output "Done. Next step: extend patch_importer_model.ps1 with the two new"
Write-Output "relationshipMappings (DERIVED_FROM ImpactResult->Flow with a new"
Write-Output "exchangeId property, HAS_DATA additional label pair Flow->DataItem)."
