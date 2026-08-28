<#
============================================================
merge_all_sources.ps1  (Stage B)

Fuehrt alle Stage-A-Staging-Ordner + das bestehende Modell (v7_verify) zu
EINEM konsistenten CSV-Satz zusammen. Ersetzt ilcd_import_pipeline.ps1
(keine Process-Dedup, kein CHARACTERIZES-Dedup ueber mehrere Quellen,
kollidierende Chunk-Dateinamen -- siehe Plan-Datei).

Dedup-Regeln:
- Process: Baseline = bestehendes Process.csv. Fuer IDs in $expectedRefresh
  (PROC_ALU_EXTRUSION_EF + 22 Metall-IDs) ueberschreibt die frisch
  aufbereitete Version die alte Zeile (neue Provenienz-Spalten). Andere
  Kollisionen (sollte nicht vorkommen, da neue IDs bewusst eindeutig
  vergeben wurden) werden als WARNUNG geloggt, alte Zeile bleibt erhalten.
- Flow: Baseline = bestehendes Flow.csv, danach first-write-wins ueber alle
  Quellen (echte inhaltliche Dedup durch UUID-Gleichheit).
- HAS_FLOW: bestehende Zeilen der 24 alten Prozesse werden VERWORFEN
  (durch die frisch generierten mit exchangeId ersetzt) -- ausser
  PROC_WASTE_INCINERATION_MSW (kein Rohmaterial verfuegbar, siehe Plan) --
  dafuer Sonderbehandlung: bestehende Zeilen uebernehmen, Komma-Dezimalen
  fixen, exchangeId aus stabiler Zeilenposition ableiten. Alle anderen
  bestehenden HAS_FLOW-Zeilen (falls vorhanden) bleiben unveraendert.
- CHARACTERIZES: Baseline = bestehendes CHARACTERIZES.csv, gemergt mit
  allen frischen r_CHARACTERIZES-Dateien. Dedup-Schluessel (from_id,to_id,
  location). Bei widersspruechlichem factor fuer denselben Schluessel:
  Konflikt loggen, ERSTEN Wert behalten (nicht stillschweigend
  ueberschreiben).
- ImpactCategory: Baseline = bestehendes ImpactCategory.csv, gemergt mit
  allen ImpactCategory_neu.csv, dedupe nach id.
============================================================
#>

$ErrorActionPreference = "Stop"

# Stage B of "Reproducing the load" (see lca_bulk_load/README.md).
# $existingDir is your current model snapshot (baseline to merge onto),
# $stagingDir the per-package output of run_phase2_extraction.ps1 -- adjust
# all paths below to your own environment before running.
$existingDir = "./scratch/v7_verify"
$stagingDir  = "./scratch/rebuild/staging"
$outDir      = "./scratch/rebuild/merged"
$reportFile  = "./scratch/rebuild/merge_report.txt"

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$report = New-Object System.Collections.Generic.List[string]
function Log($msg) { $report.Add($msg); Write-Output $msg }

function Write-UnquotedCsv {
    param([Parameter(ValueFromPipeline=$true)] $InputObject, [string]$Path, [string[]]$Columns)
    begin {
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add(($Columns -join ','))
    }
    process {
        $vals = foreach ($c in $Columns) { $InputObject.$c }
        $lines.Add(($vals -join ','))
    }
    end {
        [System.IO.File]::WriteAllLines($Path, $lines, (New-Object System.Text.UTF8Encoding($false)))
    }
}

$expectedRefresh = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
    "PROC_ALU_EXTRUSION_EF","PROC_ALU_EXTRUSION_IDEMAT","PROC_ALU_SHEET_IDEMAT","PROC_STEEL_SECTIONS_ILCD",
    "PROC_STEEL_HRC","PROC_COPPER_WIRE_CONSMIX","PROC_LEAD_SHEET_SECONDARY","PROC_COPPER_SHEET_MARKETMIX",
    "PROC_LEAD_PRIMSEC_MIX","PROC_COPPER_SHEET_CONSMIX","PROC_STEEL_REBAR","PROC_STEEL_GALV_ILCD",
    "PROC_COPPER_TUBE_MARKETMIX","PROC_STEEL_GALV_RECYCLED","PROC_COPPER_WIRE_MARKETMIX","PROC_STEEL_SECTIONS_RECYCLED",
    "PROC_COPPER_TUBE_CONSMIX","PROC_STEEL_TINPLATE","PROC_STEEL_HRC_RECYCLED","PROC_STEEL_HRC_ILCD",
    "PROC_STEEL_HR_SECTION","PROC_ZINC_PRIMARY","PROC_LEAD_PRIMARY"
))
$waste_id = "PROC_WASTE_INCINERATION_MSW"

$sourceOrder = @("existing_alu","existing_idemat_metal","new_screws","new_adhesive","new_alu","new_steel","new_electricity","new_base_polyamide","new_pa6gf30_waste")

Log "==================== PROCESS ===================="
$procCols = @('id','name','processType','technology','geographicalLocation','dataAcquisition','status','source','sourceDatabase','referenceYear')
$processes = [ordered]@{}
foreach ($row in (Import-Csv (Join-Path $existingDir "Process.csv"))) {
    $obj = [ordered]@{}
    foreach ($c in $procCols) { $obj[$c] = if ($row.PSObject.Properties.Name -contains $c) { $row.$c } else { "" } }
    $processes[$row.id] = [PSCustomObject]$obj
}
Log "Baseline (bestehendes Modell): $($processes.Count) Prozesse geladen."

$refreshed = 0; $added = 0; $unexpectedCollisions = 0
foreach ($srcName in $sourceOrder) {
    $srcProcCsv = Join-Path $stagingDir "$srcName\Process.csv"
    if (-not (Test-Path $srcProcCsv)) { Log "WARNUNG: $srcProcCsv fehlt, ueberspringe."; continue }
    foreach ($row in (Import-Csv $srcProcCsv)) {
        if ($processes.Contains($row.id)) {
            if ($expectedRefresh.Contains($row.id)) {
                $processes[$row.id] = $row
                $refreshed++
            } else {
                Log "UNERWARTETE KOLLISION Process.id=$($row.id) aus $srcName -- behalte bestehende Zeile."
                $unexpectedCollisions++
            }
        } else {
            $processes[$row.id] = $row
            $added++
        }
    }
}
Log "Process: $refreshed aufgefrischt, $added neu hinzugefuegt, $unexpectedCollisions unerwartete Kollisionen."
$processes.Values | Write-UnquotedCsv -Path (Join-Path $outDir "Process.csv") -Columns $procCols
Log "-> $($processes.Count) Prozesse total in Process.csv"

Log ""
Log "==================== FLOW ===================="
$flowCols = @('id','name','flowType','category','referenceUnit','casNumber','status','description','source','sourceDatabase')
$flows = [ordered]@{}
foreach ($row in (Import-Csv (Join-Path $existingDir "Flow.csv"))) {
    $obj = [ordered]@{}
    foreach ($c in $flowCols) { $obj[$c] = if ($row.PSObject.Properties.Name -contains $c) { $row.$c } else { "" } }
    $flows[$row.id] = [PSCustomObject]$obj
}
Log "Baseline: $($flows.Count) Flows geladen."
$flowAdded = 0; $flowDeduped = 0
foreach ($srcName in $sourceOrder) {
    $srcFlowCsv = Join-Path $stagingDir "$srcName\Flow.csv"
    if (-not (Test-Path $srcFlowCsv)) { continue }
    foreach ($row in (Import-Csv $srcFlowCsv)) {
        if ($flows.Contains($row.id)) { $flowDeduped++ } else { $flows[$row.id] = $row; $flowAdded++ }
    }
}
Log "Flow: $flowAdded neu hinzugefuegt, $flowDeduped als Duplikat erkannt (bereits vorhanden)."
$flows.Values | Write-UnquotedCsv -Path (Join-Path $outDir "Flow.csv") -Columns $flowCols
Log "-> $($flows.Count) Flows total in Flow.csv"

Log ""
Log "==================== HAS_FLOW ===================="
$hfCols = @('exchangeId','from_id','to_id','amount','unit','direction','location','quantitativeReference','ratioToReference','dataMaturity','referenceYear','uncertainty','comment')
$hasFlowRows = New-Object System.Collections.Generic.List[object]

# Bestehende HAS_FLOW-Zeilen: alles behalten AUSSER den 23 (jetzt frisch generierten
# Alu/Metall-Prozessen). PROC_WASTE_INCINERATION_MSW bleibt (Sonderbehandlung unten:
# separat neu geschrieben mit Fix + exchangeId, hier NICHT aus der alten Datei uebernehmen).
$dropFromExisting = [System.Collections.Generic.HashSet[string]]::new([string[]]$expectedRefresh)
$dropFromExisting.Add($waste_id) | Out-Null
$existingHfCount = 0; $keptFromExisting = 0
foreach ($row in (Import-Csv (Join-Path $existingDir "r_38_HAS_FLOW_Process_TO_Flow.csv"))) {
    $existingHfCount++
    if ($dropFromExisting.Contains($row.from_id)) { continue }
    $obj = [ordered]@{}
    foreach ($c in $hfCols) { $obj[$c] = if ($row.PSObject.Properties.Name -contains $c) { $row.$c } else { "" } }
    $hasFlowRows.Add([PSCustomObject]$obj)
    $keptFromExisting++
}
Log "Bestehende HAS_FLOW.csv: $existingHfCount Zeilen gelesen, $keptFromExisting behalten (Rest durch Frischverarbeitung ersetzt)."

# Manche Prozess-UUIDs kommen in mehreren Quellen vor (z.B. PROC_ALU_EXTRUSION_EF
# sowohl in existing_alu als auch erneut in new_alu, da das Sphera-Paket den
# Prozess einfach mitbuendelt). Ein Prozess darf seine HAS_FLOW-Zeilen nur EINMAL
# beitragen -- sonst entstehen doppelte exchangeId-Werte (from_id+internalId
# wiederholt sich exakt). Erste Quelle in $sourceOrder gewinnt, pro Prozess-ID.
$processIdsWithHasFlow = [System.Collections.Generic.HashSet[string]]::new()
foreach ($srcName in $sourceOrder) {
    $srcHfCsv = Join-Path $stagingDir "$srcName\r_HAS_FLOW_Process_TO_Flow.csv"
    if (-not (Test-Path $srcHfCsv)) { continue }
    $n = 0; $skipped = 0
    foreach ($row in (Import-Csv $srcHfCsv)) {
        if ($processIdsWithHasFlow.Contains($row.from_id)) { $skipped++; continue }
        $hasFlowRows.Add($row); $n++
    }
    foreach ($row in (Import-Csv $srcHfCsv | Select-Object -ExpandProperty from_id -Unique)) { $processIdsWithHasFlow.Add($row) | Out-Null }
    if ($skipped -gt 0) {
        Log "  + $n HAS_FLOW-Zeilen aus $srcName ($skipped uebersprungen -- Prozess bereits durch frueheres Quelle abgedeckt)"
    } else {
        Log "  + $n HAS_FLOW-Zeilen aus $srcName"
    }
}

# Sonderbehandlung PROC_WASTE_INCINERATION_MSW: kein Roh-XML verfuegbar (nur ein
# PowerShell-serialisiertes Cache-Objekt + eine gequotete CSV mit Dezimalkomma-Bug).
# Deterministische exchangeId aus stabiler Zeilenposition (Fallback-Schema gemaess
# ursprnglicher Anforderung Abschnitt 8, da keine ILCD dataSetInternalID rekonstruierbar ist).
$eolSrc = "./scratch/regen_eol/r_HAS_FLOW_Process_TO_Flow.csv"
$eolRows = Import-Csv $eolSrc
$idx = 0
foreach ($row in $eolRows) {
    $ratioFixed = $row.ratioToReference -replace ',', '.'
    $hasFlowRows.Add([PSCustomObject]@{
        exchangeId = "$waste_id#$idx"
        from_id = $row.from_id; to_id = $row.to_id; amount = $row.amount; unit = $row.unit
        direction = $row.direction; location = $row.location
        quantitativeReference = $row.quantitativeReference; ratioToReference = $ratioFixed
        dataMaturity = $row.dataMaturity; referenceYear = ""; uncertainty = ""; comment = "exchangeId technisch generiert (Rohquelle nicht verfuegbar, siehe merge_report.txt)"
    })
    $idx++
}
Log "  + $($eolRows.Count) HAS_FLOW-Zeilen aus regen_eol ($waste_id, exchangeId technisch generiert aus Zeilenposition, KEIN echtes ILCD dataSetInternalID verfuegbar)."

# Eindeutigkeitscheck exchangeId (muss laut Konstruktion immer eindeutig sein)
$dupExchangeIds = $hasFlowRows | Group-Object exchangeId | Where-Object { $_.Count -gt 1 }
if ($dupExchangeIds.Count -gt 0) {
    Log "FEHLER: $($dupExchangeIds.Count) doppelte exchangeId-Werte gefunden!"
    foreach ($d in $dupExchangeIds | Select-Object -First 10) { Log "  DUPLIKAT: $($d.Name) ($($d.Count)x)" }
} else {
    Log "exchangeId-Eindeutigkeit: OK, keine Duplikate unter $($hasFlowRows.Count) Zeilen."
}

$hasFlowRows | Write-UnquotedCsv -Path (Join-Path $outDir "r_HAS_FLOW_Process_TO_Flow.csv") -Columns $hfCols
Log "-> $($hasFlowRows.Count) HAS_FLOW-Zeilen total"

Log ""
Log "==================== IMPACT CATEGORY (zuerst, liefert UUID->id-Map fuer CHARACTERIZES) ===================="
# Frische Extraktionen liefern ImpactCategory-IDs als rohe lciamethod-UUIDs,
# das bestehende Modell nutzt sprechende IDs (IC_EF_CLIMATE_TOTAL etc.). Ohne
# Remapping wuerden pro Kategorie zwei Knoten nebeneinander existieren (alter
# sprechender + neuer UUID-Knoten) und CHARACTERIZES faelschlich nie gegen den
# Bestand kollidieren. Mapping ueber Namensabgleich (wie bei Process/UUID).
$icCols = @('id','name','indicator','unit')
$categories = [ordered]@{}
foreach ($row in (Import-Csv (Join-Path $existingDir "ImpactCategory.csv"))) {
    $obj = [ordered]@{}
    foreach ($c in $icCols) { $obj[$c] = if ($row.PSObject.Properties.Name -contains $c) { $row.$c } else { "" } }
    $categories[$row.id] = [PSCustomObject]$obj
}
$byCatName = @{}
foreach ($c in $categories.Values) { $byCatName[$c.name.Trim()] = $c.id }

$catUuidToId = @{}   # UUID (aus frischer Extraktion) -> finale sprechende ID
$icAdded = 0; $icMatched = 0
function Slugify($name) {
    $s = $name.ToUpper() -replace '[^A-Z0-9]+', '_'
    return ("IC_EF_" + $s.Trim('_'))
}
foreach ($srcName in $sourceOrder) {
    $srcIcCsv = Join-Path $stagingDir "$srcName\ImpactCategory_neu.csv"
    if (-not (Test-Path $srcIcCsv)) { continue }
    foreach ($row in (Import-Csv $srcIcCsv)) {
        if ($catUuidToId.ContainsKey($row.id)) { continue }
        $name = $row.name.Trim()
        if ($byCatName.ContainsKey($name)) {
            $catUuidToId[$row.id] = $byCatName[$name]
            $icMatched++
        } else {
            $newId = Slugify $name
            while ($categories.Contains($newId)) { $newId = $newId + "_2" }
            $categories[$newId] = [PSCustomObject]@{ id = $newId; name = $name; indicator = $row.indicator; unit = $row.unit }
            $byCatName[$name] = $newId
            $catUuidToId[$row.id] = $newId
            $icAdded++
        }
    }
}
Log "ImpactCategory: $icMatched frische UUIDs auf bestehende sprechende IDs gemappt, $icAdded echte neue Kategorien angelegt, $($categories.Count) total."
$categories.Values | Write-UnquotedCsv -Path (Join-Path $outDir "ImpactCategory.csv") -Columns $icCols

Log ""
Log "==================== CHARACTERIZES ===================="
function Resolve-CatId($rawId) { if ($catUuidToId.ContainsKey($rawId)) { return $catUuidToId[$rawId] } else { return $rawId } }

# Numerisch tolerante Gleichheit statt String-Vergleich: dieselbe Zahl kann je
# nach Exportlauf als "1" vs "1.0" oder mit abweichender Rundung auftauchen --
# das ist kein fachlicher Konflikt, nur Formatierungsrauschen.
function Factors-Equal($a, $b) {
    $da = 0.0; $db = 0.0
    $okA = [double]::TryParse($a, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$da)
    $okB = [double]::TryParse($b, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$db)
    if (-not ($okA -and $okB)) { return ($a -eq $b) }
    $tol = [Math]::Max([Math]::Abs($da), [Math]::Abs($db)) * 1e-6 + 1e-12
    return ([Math]::Abs($da - $db) -le $tol)
}

$cfKey = { param($fromId, $toId, $loc) "$fromId|$toId|$loc" }
$cfDict = [ordered]@{}
$cfConflicts = 0
# KEINE Baseline-Uebernahme des alten r_37_CHARACTERIZES.csv (2921 Zeilen):
# Stichprobenvergleich zeigt, dass die alte Datei aus einer nicht mehr
# nachvollziehbaren fruehen Ad-hoc-Extraktion stammt und teils erheblich von
# einer sauberen Neuextraktion DERSELBEN Rohquelle (ilcd_alu) abweicht (nicht
# nur Rundung -- z.B. IC_EF_LAND_USE: -134 vs. -663, in einem Fall sogar
# Vorzeichenwechsel). Konsistent mit der bereits fuer HAS_FLOW getroffenen
# Entscheidung (voller Wipe+Rebuild aus Rohquellen) wird CHARACTERIZES daher
# ausschliesslich aus den frischen Stage-A-Extraktionen aufgebaut -- die alte
# Datei wird komplett verworfen, nicht nur teilweise ueberschrieben.
Log "Baseline CHARACTERIZES: bewusst NICHT uebernommen (siehe Kommentar im Skript) -- vollstaendiger Rebuild aus frischen Quellen."

# existing_alu (Rohquelle ilcd_alu) traegt selbst KEINE frischen CHARACTERIZES bei:
# direkter XML-Vergleich bestaetigt, dass ihr lciamethods-Datensatz eine aeltere
# Version ist (z.B. "Land use"-Methode dataSetVersion 01.00.009 / Flow-Referenz
# 03.00.000) als alle 9 heute (2026-08-25) frisch exportierten Pakete (01.00.010 /
# 03.00.004) -- die Sphera-Datenbank wurde zwischen den Exportzeitpunkten
# aktualisiert. Vermischen wuerde stillschweigend veraltete mit aktuellen EF3.1-
# Faktoren fuer dieselbe (Flow,Kategorie,Location)-Kombination. HAS_FLOW/Process/
# Flow sind davon nicht betroffen (methodenversions-unabhaengige Rohinventardaten).
$cfSourceOrder = $sourceOrder | Where-Object { $_ -ne "existing_alu" }
Log "CHARACTERIZES-Quellreihenfolge OHNE existing_alu (veraltete Methodenversion, siehe Kommentar): $($cfSourceOrder -join ', ')"

foreach ($srcName in $cfSourceOrder) {
    $srcCfCsv = Join-Path $stagingDir "$srcName\r_CHARACTERIZES_Flow_TO_ImpactCategory.csv"
    if (-not (Test-Path $srcCfCsv)) { continue }
    $nAdd = 0; $nDup = 0; $nConflictHere = 0
    foreach ($row in (Import-Csv $srcCfCsv)) {
        $resolvedToId = Resolve-CatId $row.to_id
        $k = & $cfKey $row.from_id $resolvedToId $row.location
        if ($cfDict.Contains($k)) {
            $existingFactor = $cfDict[$k].factor
            if (-not (Factors-Equal $existingFactor $row.factor)) {
                Log "  KONFLIKT $k : bestehender factor=$existingFactor vs. neuer factor=$($row.factor) aus $srcName -- behalte ersten Wert."
                $cfConflicts++; $nConflictHere++
            }
            $nDup++
        } else {
            $cfDict[$k] = [PSCustomObject]@{ from_id = $row.from_id; to_id = $resolvedToId; factor = $row.factor; location = $row.location }
            $nAdd++
        }
    }
    Log "  + $srcName : $nAdd neu, $nDup dedupliziert ($nConflictHere echte Wertkonflikte)"
}
Log "CHARACTERIZES-Konflikte gesamt (gleicher Schluessel, numerisch abweichender factor): $cfConflicts"
$cfCols = @('from_id','to_id','factor','location')
$cfDict.Values | Write-UnquotedCsv -Path (Join-Path $outDir "r_CHARACTERIZES_Flow_TO_ImpactCategory.csv") -Columns $cfCols
Log "-> $($cfDict.Count) CHARACTERIZES-Zeilen total"

[System.IO.File]::WriteAllLines($reportFile, $report, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ""
Write-Output "Merge-Report gespeichert: $reportFile"
