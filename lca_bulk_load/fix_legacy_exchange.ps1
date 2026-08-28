<#
============================================================
fix_legacy_exchange.ps1

Behebt eine beim Entfernen von Exchange uebersehene Regression: die 9
"Candidate"-Fertigungsprozesse (PROC_MJF, PROC_SLS, PROC_FFF, PROC_CNC,
PROC_LASER, PROC_BEND, PROC_SILCAST, PROC_RUBBER, PROC_OVERMOLD) hatten
36 echte HAS_EXCHANGE/REFERS_TO_FLOW-Verbindungen (Material-/Energie-Input,
Bauteil-/Abfall-Output) -- ohne Migration waeren diese 9 Prozesse und ihre
10 Flows (FLOW_PA12 etc.) isoliert geblieben.

Zusaetzlich: ImpactResult -[:DERIVED_FROM]-> Exchange (165 Zeilen, echte
Hotspot-Provenienz-Verknuepfungen) und Exchange -[:HAS_DATA]-> DataItem
(1 Zeile) haetten beim Entfernen von Exchange ebenfalls stillschweigend
Daten verloren. Da eine Relationship in Neo4j nicht Ziel einer anderen
Relationship sein kann (Exchange existiert nur noch als HAS_FLOW-Property,
nicht mehr als Knoten), werden beide auf den jeweiligen FLOW-Knoten
umgebogen, mit der urspruenglichen Exchange-ID als neue exchangeId-Property
-- die Praezision "von welchem Exchange" bleibt damit erhalten.
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

# --- Lookups aus den alten (jetzt entfernten) Exchange-Strukturen ---
$exchanges = Import-Csv (Join-Path $v7 "Exchange.csv")
$hasExchange = Import-Csv (Join-Path $v7 "r_20_HAS_EXCHANGE_Process_TO_Exchange.csv")
$refersToFlow = Import-Csv (Join-Path $v7 "r_31_REFERS_TO_FLOW_Exchange_TO_Flow.csv")

$exchangeToProcess = @{}
foreach ($row in $hasExchange) { $exchangeToProcess[$row.to_id] = $row.from_id }
$exchangeToFlow = @{}
foreach ($row in $refersToFlow) { $exchangeToFlow[$row.from_id] = $row.to_id }

Write-Output "[INFO] $($exchanges.Count) Exchanges, $($exchangeToProcess.Count) Process-Zuordnungen, $($exchangeToFlow.Count) Flow-Zuordnungen geladen."

# --- 1) 36 legacy HAS_FLOW-Zeilen erzeugen (exchangeId = Original-Exchange-ID) ---
$hfCols = @('exchangeId','from_id','to_id','amount','unit','direction','location','quantitativeReference','ratioToReference','dataMaturity','referenceYear','uncertainty','comment')
$legacyHasFlow = foreach ($ex in $exchanges) {
    $procId = $exchangeToProcess[$ex.id]
    $flowId = $exchangeToFlow[$ex.id]
    if (-not $procId -or -not $flowId) { Write-Output "[WARNUNG] Keine vollstaendige Zuordnung fuer $($ex.id) -- uebersprungen."; continue }
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
Write-Output "[OK] $($legacyHasFlow.Count) legacy HAS_FLOW-Zeilen erzeugt (fuer die 9 Candidate-Fertigungsprozesse)."

# An die gemergte HAS_FLOW.csv anhaengen (Kanal B)
$existingMergedHf = Import-Csv (Join-Path $mergedDir "r_HAS_FLOW_Process_TO_Flow.csv")
$combinedHf = @($existingMergedHf) + @($legacyHasFlow)
$dupCheck = $combinedHf | Group-Object exchangeId | Where-Object { $_.Count -gt 1 }
if ($dupCheck.Count -gt 0) { throw "exchangeId-Duplikate nach Anhaengen der legacy HAS_FLOW-Zeilen: $($dupCheck.Name -join ', ')" }
$combinedHf | Write-UnquotedCsv -Path (Join-Path $mergedDir "r_HAS_FLOW_Process_TO_Flow.csv") -Columns $hfCols
$combinedHf | Write-UnquotedCsv -Path (Join-Path $kanalBDir "HAS_FLOW.csv") -Columns $hfCols
Write-Output "[OK] HAS_FLOW.csv aktualisiert: $($combinedHf.Count) Zeilen total (vorher $($existingMergedHf.Count))."

# --- 2) DERIVED_FROM: Exchange -> Flow umbiegen, exchangeId als neue Property ---
$derivedFrom = Import-Csv (Join-Path $v7 "r_5_DERIVED_FROM_ImpactResult_TO_Exchange.csv")
$dfCols = @('from_id','to_id','exchangeId','contribution')
$newDerivedFrom = foreach ($row in $derivedFrom) {
    $flowId = $exchangeToFlow[$row.to_id]
    if (-not $flowId) { Write-Output "[WARNUNG] DERIVED_FROM: keine Flow-Zuordnung fuer $($row.to_id) -- uebersprungen."; continue }
    [PSCustomObject]@{ from_id = $row.from_id; to_id = $flowId; exchangeId = $row.to_id; contribution = $row.contribution }
}
$newDerivedFrom | Write-UnquotedCsv -Path (Join-Path $buildDir "r_5_DERIVED_FROM_ImpactResult_TO_Flow.csv") -Columns $dfCols
Write-Output "[OK] r_5_DERIVED_FROM_ImpactResult_TO_Flow.csv erzeugt: $($newDerivedFrom.Count) Zeilen (Exchange->Flow umgebogen, exchangeId erhalten)."

# --- 3) HAS_DATA (Exchange->DataItem): Exchange -> Flow umbiegen ---
$hasDataEx = Import-Csv (Join-Path $v7 "r_15_HAS_DATA_Exchange_TO_DataItem.csv")
$hdCols = @('from_id','to_id','exchangeId','role')
$newHasDataFlow = foreach ($row in $hasDataEx) {
    $flowId = $exchangeToFlow[$row.from_id]
    if (-not $flowId) { Write-Output "[WARNUNG] HAS_DATA: keine Flow-Zuordnung fuer $($row.from_id) -- uebersprungen."; continue }
    [PSCustomObject]@{ from_id = $flowId; to_id = $row.to_id; exchangeId = $row.from_id; role = $row.role }
}
$newHasDataFlow | Write-UnquotedCsv -Path (Join-Path $buildDir "r_15b_HAS_DATA_Flow_TO_DataItem.csv") -Columns $hdCols
Write-Output "[OK] r_15b_HAS_DATA_Flow_TO_DataItem.csv erzeugt: $($newHasDataFlow.Count) Zeile(n)."

Write-Output ""
Write-Output "Fertig. Naechster Schritt: patch_importer_model.ps1 um die zwei neuen"
Write-Output "relationshipMappings ergaenzen (DERIVED_FROM ImpactResult->Flow mit neuer"
Write-Output "exchangeId-Property, HAS_DATA zusaetzliches Label-Paar Flow->DataItem)."
