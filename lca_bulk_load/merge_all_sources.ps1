<#
============================================================
merge_all_sources.ps1  (Stage B)

Merges all Stage A staging folders + the existing model (v7_verify) into
ONE consistent CSV set. Replaces ilcd_import_pipeline.ps1
(no process dedup, no CHARACTERIZES dedup across several sources,
colliding chunk file names).

Dedup rules:
- Process: baseline = existing Process.csv. For IDs in $expectedRefresh
  (PROC_ALU_EXTRUSION_EF + 22 metal IDs) the freshly prepared version
  overwrites the old row (new provenance columns). Other
  collisions (should not occur, since new IDs were deliberately assigned
  uniquely) are logged as WARNING, the old row is kept.
- Flow: baseline = existing Flow.csv, then first-write-wins across all
  sources (true content-based dedup via UUID equality).
- HAS_FLOW: existing rows of the 24 old processes are DISCARDED
  (replaced by the freshly generated ones with exchangeId) -- except
  PROC_WASTE_INCINERATION_MSW (no raw material available) --
  special handling for that one: keep existing rows, fix comma decimals,
  derive exchangeId from the stable row position. All other
  existing HAS_FLOW rows (if any) stay unchanged.
- CHARACTERIZES: built exclusively from the fresh r_CHARACTERIZES files (the
  old baseline is deliberately NOT taken over, see the comment further down).
  Dedup key (from_id,to_id,location). On a contradictory factor for the same
  key: log the conflict, KEEP THE FIRST value (do not silently
  overwrite).
- ImpactCategory: baseline = existing ImpactCategory.csv, merged with
  all ImpactCategory_neu.csv, deduplicated by id.
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
Log "Baseline (existing model): $($processes.Count) processes loaded."

$refreshed = 0; $added = 0; $unexpectedCollisions = 0
foreach ($srcName in $sourceOrder) {
    $srcProcCsv = Join-Path $stagingDir "$srcName\Process.csv"
    if (-not (Test-Path $srcProcCsv)) { Log "WARNING: $srcProcCsv is missing, skipping."; continue }
    foreach ($row in (Import-Csv $srcProcCsv)) {
        if ($processes.Contains($row.id)) {
            if ($expectedRefresh.Contains($row.id)) {
                $processes[$row.id] = $row
                $refreshed++
            } else {
                Log "UNEXPECTED COLLISION Process.id=$($row.id) from $srcName -- keeping the existing row."
                $unexpectedCollisions++
            }
        } else {
            $processes[$row.id] = $row
            $added++
        }
    }
}
Log "Process: $refreshed refreshed, $added newly added, $unexpectedCollisions unexpected collisions."
$processes.Values | Write-UnquotedCsv -Path (Join-Path $outDir "Process.csv") -Columns $procCols
Log "-> $($processes.Count) processes in total in Process.csv"

Log ""
Log "==================== FLOW ===================="
$flowCols = @('id','name','flowType','category','referenceUnit','casNumber','status','description','source','sourceDatabase')
$flows = [ordered]@{}
foreach ($row in (Import-Csv (Join-Path $existingDir "Flow.csv"))) {
    $obj = [ordered]@{}
    foreach ($c in $flowCols) { $obj[$c] = if ($row.PSObject.Properties.Name -contains $c) { $row.$c } else { "" } }
    $flows[$row.id] = [PSCustomObject]$obj
}
Log "Baseline: $($flows.Count) flows loaded."
$flowAdded = 0; $flowDeduped = 0
foreach ($srcName in $sourceOrder) {
    $srcFlowCsv = Join-Path $stagingDir "$srcName\Flow.csv"
    if (-not (Test-Path $srcFlowCsv)) { continue }
    foreach ($row in (Import-Csv $srcFlowCsv)) {
        if ($flows.Contains($row.id)) { $flowDeduped++ } else { $flows[$row.id] = $row; $flowAdded++ }
    }
}
Log "Flow: $flowAdded newly added, $flowDeduped recognised as duplicates (already present)."
$flows.Values | Write-UnquotedCsv -Path (Join-Path $outDir "Flow.csv") -Columns $flowCols
Log "-> $($flows.Count) flows in total in Flow.csv"

Log ""
Log "==================== HAS_FLOW ===================="
$hfCols = @('exchangeId','from_id','to_id','amount','unit','direction','location','quantitativeReference','ratioToReference','dataMaturity','referenceYear','uncertainty','comment')
$hasFlowRows = New-Object System.Collections.Generic.List[object]

# Existing HAS_FLOW rows: keep everything EXCEPT the 23 (now freshly generated
# aluminium/metal processes). PROC_WASTE_INCINERATION_MSW stays (special handling below:
# rewritten separately with fix + exchangeId, do NOT take it over from the old file here).
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
Log "Existing HAS_FLOW.csv: $existingHfCount rows read, $keptFromExisting kept (rest replaced by the fresh processing)."

# Some process UUIDs occur in several sources (e.g. PROC_ALU_EXTRUSION_EF
# both in existing_alu and again in new_alu, because the Sphera package
# simply bundles the process). A process may contribute its HAS_FLOW rows only ONCE
# -- otherwise duplicate exchangeId values arise (from_id+internalId
# repeats exactly). The first source in $sourceOrder wins, per process id.
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
        Log "  + $n HAS_FLOW rows from $srcName ($skipped skipped -- process already covered by an earlier source)"
    } else {
        Log "  + $n HAS_FLOW rows from $srcName"
    }
}

# Special handling PROC_WASTE_INCINERATION_MSW: no raw XML available (only a
# PowerShell-serialised cache object + a quoted CSV with a decimal-comma bug).
# Deterministic exchangeId from the stable row position (fallback scheme per the
# original requirement section 8, since no ILCD dataSetInternalID can be reconstructed).
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
        dataMaturity = $row.dataMaturity; referenceYear = ""; uncertainty = ""; comment = "exchangeId technically generated (raw source not available, see merge_report.txt)"
    })
    $idx++
}
Log "  + $($eolRows.Count) HAS_FLOW rows from regen_eol ($waste_id, exchangeId technically generated from the row position, NO real ILCD dataSetInternalID available)."

# Uniqueness check on exchangeId (must always be unique by construction)
$dupExchangeIds = $hasFlowRows | Group-Object exchangeId | Where-Object { $_.Count -gt 1 }
if ($dupExchangeIds.Count -gt 0) {
    Log "ERROR: $($dupExchangeIds.Count) duplicate exchangeId values found!"
    foreach ($d in $dupExchangeIds | Select-Object -First 10) { Log "  DUPLICATE: $($d.Name) ($($d.Count)x)" }
} else {
    Log "exchangeId uniqueness: OK, no duplicates among $($hasFlowRows.Count) rows."
}

$hasFlowRows | Write-UnquotedCsv -Path (Join-Path $outDir "r_HAS_FLOW_Process_TO_Flow.csv") -Columns $hfCols
Log "-> $($hasFlowRows.Count) HAS_FLOW rows in total"

Log ""
Log "==================== IMPACT CATEGORY (first, provides the UUID->id map for CHARACTERIZES) ===================="
# Fresh extractions deliver ImpactCategory ids as raw lciamethod UUIDs,
# the existing model uses descriptive ids (IC_EF_CLIMATE_TOTAL etc.). Without
# remapping there would be two nodes side by side per category (old
# descriptive + new UUID node) and CHARACTERIZES would wrongly never collide with the
# existing data. Mapping via name matching (as for Process/UUID).
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
Log "ImpactCategory: $icMatched fresh UUIDs mapped to existing descriptive ids, $icAdded genuinely new categories created, $($categories.Count) in total."
$categories.Values | Write-UnquotedCsv -Path (Join-Path $outDir "ImpactCategory.csv") -Columns $icCols

Log ""
Log "==================== CHARACTERIZES ===================="
function Resolve-CatId($rawId) { if ($catUuidToId.ContainsKey($rawId)) { return $catUuidToId[$rawId] } else { return $rawId } }

# Numerically tolerant equality instead of string comparison: the same number can
# appear as "1" vs "1.0" or with differing rounding depending on the export run --
# that is not a substantive conflict, just formatting noise.
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
# Do NOT take over the old r_37_CHARACTERIZES.csv as baseline (2921 rows):
# a spot-check comparison shows that the old file stems from an early ad-hoc
# extraction that can no longer be traced and in part deviates considerably from
# a clean re-extraction of the SAME raw source (ilcd_alu) (not
# just rounding -- e.g. IC_EF_LAND_USE: -134 vs. -663, in one case even a
# sign change). Consistent with the decision already taken for HAS_FLOW
# (full wipe + rebuild from raw sources), CHARACTERIZES is therefore built
# exclusively from the fresh Stage A extractions -- the old
# file is discarded completely, not just partly overwritten.
Log "Baseline CHARACTERIZES: deliberately NOT taken over (see comment in the script) -- complete rebuild from fresh sources."

# existing_alu (raw source ilcd_alu) itself contributes NO fresh CHARACTERIZES:
# a direct XML comparison confirms that its lciamethods dataset is an older
# version (e.g. "Land use" method dataSetVersion 01.00.009 / flow reference
# 03.00.000) than all 9 packages freshly exported today (2026-08-25) (01.00.010 /
# 03.00.004) -- the Sphera database was updated between the export times.
# Mixing would silently combine outdated with current EF3.1
# factors for the same (flow, category, location) combination. HAS_FLOW/Process/
# Flow are not affected (raw inventory data independent of the method version).
$cfSourceOrder = $sourceOrder | Where-Object { $_ -ne "existing_alu" }
Log "CHARACTERIZES source order WITHOUT existing_alu (outdated method version, see comment): $($cfSourceOrder -join ', ')"

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
                Log "  CONFLICT $k : existing factor=$existingFactor vs. new factor=$($row.factor) from $srcName -- keeping the first value."
                $cfConflicts++; $nConflictHere++
            }
            $nDup++
        } else {
            $cfDict[$k] = [PSCustomObject]@{ from_id = $row.from_id; to_id = $resolvedToId; factor = $row.factor; location = $row.location }
            $nAdd++
        }
    }
    Log "  + $srcName : $nAdd new, $nDup deduplicated ($nConflictHere genuine value conflicts)"
}
Log "CHARACTERIZES conflicts in total (same key, numerically differing factor): $cfConflicts"
$cfCols = @('from_id','to_id','factor','location')
$cfDict.Values | Write-UnquotedCsv -Path (Join-Path $outDir "r_CHARACTERIZES_Flow_TO_ImpactCategory.csv") -Columns $cfCols
Log "-> $($cfDict.Count) CHARACTERIZES rows in total"

[System.IO.File]::WriteAllLines($reportFile, $report, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ""
Write-Output "Merge report saved: $reportFile"
