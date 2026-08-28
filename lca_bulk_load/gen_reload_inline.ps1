<#
One-time historical build script (model rebuild, see lca_bulk_load/README.md)
-- not part of the regular reproducible pipeline. Its input ($build) isn't
included in this repo; adjust the paths below to your own environment
before running.
#>
$ErrorActionPreference = "Stop"
$build = "./scratch/rebuild/build"
$out = "./scratch/rebuild/reload_applies_to_evaluates_criterion.cypher"

function Esc($s) {
    if ($null -eq $s) { return "" }
    return $s.Replace('\', '\\').Replace('"', '\"')
}

$sb = New-Object System.Text.StringBuilder

# --- APPLIES_TO Process -> Part ---
$rows1 = Import-Csv (Join-Path $build "r_1_APPLIES_TO_Process_TO_Part.csv")
$null = $sb.AppendLine("// --- APPLIES_TO: Process -> Part ($($rows1.Count) Zeilen) ---")
$null = $sb.AppendLine("UNWIND [")
$lines1 = foreach ($r in $rows1) { '{f:"' + (Esc $r.from_id) + '", t:"' + (Esc $r.to_id) + '", role:"' + (Esc $r.role) + '"}' }
$null = $sb.AppendLine(($lines1 -join ",`r`n"))
$null = $sb.AppendLine("] AS row")
$null = $sb.AppendLine("MATCH (source:Process {id: row.f})")
$null = $sb.AppendLine("MATCH (target:Part {id: row.t})")
$null = $sb.AppendLine("MERGE (source)-[r:APPLIES_TO]->(target)")
$null = $sb.AppendLine("SET r.role = row.role;")
$null = $sb.AppendLine("")

# --- APPLIES_TO Process -> Material ---
$rows2 = Import-Csv (Join-Path $build "r_39_APPLIES_TO_Process_TO_Material.csv")
$null = $sb.AppendLine("// --- APPLIES_TO: Process -> Material ($($rows2.Count) Zeilen) ---")
$null = $sb.AppendLine("UNWIND [")
$lines2 = foreach ($r in $rows2) { '{f:"' + (Esc $r.from_id) + '", t:"' + (Esc $r.to_id) + '", role:"' + (Esc $r.role) + '"}' }
$null = $sb.AppendLine(($lines2 -join ",`r`n"))
$null = $sb.AppendLine("] AS row")
$null = $sb.AppendLine("MATCH (source:Process {id: row.f})")
$null = $sb.AppendLine("MATCH (target:Material {id: row.t})")
$null = $sb.AppendLine("MERGE (source)-[r:APPLIES_TO]->(target)")
$null = $sb.AppendLine("SET r.role = row.role;")
$null = $sb.AppendLine("")

# --- EVALUATES_CRITERION DataQuality -> DataQualityCriterion ---
$rows3 = Import-Csv (Join-Path $build "r_6_EVALUATES_CRITERION_DataQuality_TO_DataQualityCriterion.csv")
$null = $sb.AppendLine("// --- EVALUATES_CRITERION: DataQuality -> DataQualityCriterion ($($rows3.Count) Zeilen) ---")
$null = $sb.AppendLine("UNWIND [")
$lines3 = foreach ($r in $rows3) {
    $scoreVal = if ($r.score) { $r.score } else { "null" }
    '{f:"' + (Esc $r.from_id) + '", t:"' + (Esc $r.to_id) + '", score:' + $scoreVal + ', rating:"' + (Esc $r.rating) + '"}'
}
$null = $sb.AppendLine(($lines3 -join ",`r`n"))
$null = $sb.AppendLine("] AS row")
$null = $sb.AppendLine("MATCH (source:DataQuality {id: row.f})")
$null = $sb.AppendLine("MATCH (target:DataQualityCriterion {id: row.t})")
$null = $sb.AppendLine("MERGE (source)-[r:EVALUATES_CRITERION]->(target)")
$null = $sb.AppendLine("SET r.score = row.score, r.rating = row.rating;")

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($out, $sb.ToString(), $utf8NoBom)
Write-Output "Written: $out"
Write-Output "Rows: APPLIES_TO(Part)=$($rows1.Count), APPLIES_TO(Material)=$($rows2.Count), EVALUATES_CRITERION=$($rows3.Count)"
