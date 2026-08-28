<#
Builds the Channel A Data Importer package (see lca_bulk_load/README.md,
"Reproducing the load" step 4). $existingDir is your current model
snapshot, $mergedDir the output of merge_all_sources.ps1 -- adjust all
paths below to your own environment before running.
#>
$ErrorActionPreference = "Stop"

$existingDir = "./scratch/v7_verify"
$mergedDir = "./scratch/rebuild/merged"
$buildDir = "./scratch/rebuild/build"

if (Test-Path $buildDir) { Remove-Item -Recurse -Force $buildDir }
New-Item -ItemType Directory -Path $buildDir | Out-Null

# JSON wurde bereits von patch_importer_model.ps1 direkt in $buildDir geschrieben,
# bleibt unangetastet. Nur nochmal sicherstellen, dass es vorhanden ist.
$jsonInBuild = Join-Path $buildDir "neo4j_importer_model.json"

# 1) Alle bestehenden CSVs kopieren, AUSSER den entfernten/ersetzten
$excluded = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
    "Exchange.csv",
    "r_5_DERIVED_FROM_ImpactResult_TO_Exchange.csv",
    "r_15_HAS_DATA_Exchange_TO_DataItem.csv",
    "r_20_HAS_EXCHANGE_Process_TO_Exchange.csv",
    "r_31_REFERS_TO_FLOW_Exchange_TO_Flow.csv",
    "r_38_HAS_FLOW_Process_TO_Flow.csv",
    "r_37_CHARACTERIZES_Flow_TO_ImpactCategory.csv",
    "Process.csv", "Flow.csv", "ImpactCategory.csv",
    "neo4j_importer_model.json"
))
$copied = 0
foreach ($f in (Get-ChildItem $existingDir -Filter "*.csv")) {
    if ($excluded.Contains($f.Name)) { continue }
    Copy-Item $f.FullName (Join-Path $buildDir $f.Name)
    $copied++
}
Write-Output "[OK] $copied unveraenderte CSVs aus dem bestehenden Modell kopiert."

# 2) Gemergte Process.csv/Flow.csv/ImpactCategory.csv einsetzen
foreach ($name in @("Process.csv", "Flow.csv", "ImpactCategory.csv")) {
    Copy-Item (Join-Path $mergedDir $name) (Join-Path $buildDir $name)
}
Write-Output "[OK] gemergte Process.csv/Flow.csv/ImpactCategory.csv eingesetzt."

# 3) Re-run patch_importer_model.ps1 damit die JSON sicher aktuell in $buildDir liegt
& "./scratch/rebuild/patch_importer_model.ps1" | Out-Null
Write-Output "[OK] neo4j_importer_model.json (gepatcht) liegt in $buildDir"

Write-Output ""
Write-Output "Kanal-A-Build-Verzeichnis fertig: $buildDir"
Get-ChildItem $buildDir | Measure-Object | ForEach-Object { Write-Output "Dateien total: $($_.Count)" }
