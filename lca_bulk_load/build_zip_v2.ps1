param(
    [string]$SourceDir = $PSScriptRoot,
    [string]$OutputZip = (Join-Path $PSScriptRoot "ned2_gripper_full_model_v8.zip")
)

# ============================================================
# build_zip_v2.ps1 -- extends the original build_zip.ps1 with four new checks:
#   2c) bidirectional CSV<->mapping check (the original only checks
#       JSON->CSV; orphaned CSVs without a mapping went undetected so far)
#   3b) Process/Flow id duplicates = hard error (original: warning only)
#   3c) regression check: no Exchange/HAS_EXCHANGE/REFERS_TO_FLOW leftovers
#   2b extended) quoting check also on real data rows (original:
#       header row only)
# Everything else taken over unchanged from the original.
# ============================================================

$jsonPath = Join-Path $SourceDir "neo4j_importer_model.json"
if (-not (Test-Path $jsonPath)) {
    throw "neo4j_importer_model.json not found in: $SourceDir"
}

# --- 1) Validate the JSON and rewrite it without BOM ---
$jsonContent = Get-Content $jsonPath -Raw
try {
    $null = $jsonContent | ConvertFrom-Json
} catch {
    throw "neo4j_importer_model.json is not valid JSON: $($_.Exception.Message)"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($jsonPath, $jsonContent, $utf8NoBom)

$bytes = [System.IO.File]::ReadAllBytes($jsonPath)
$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
if ($hasBom) { throw "BOM could not be removed -- aborting." }
Write-Output "[OK] JSON valid and written without BOM."

$json = Get-Content $jsonPath -Raw | ConvertFrom-Json

# --- 2) Referential consistency: JSON -> CSV ---
$missing = New-Object System.Collections.Generic.List[string]
foreach ($m in $json.dataModel.graphMappingRepresentation.nodeMappings) {
    if (-not (Test-Path (Join-Path $SourceDir $m.tableName))) { $missing.Add($m.tableName) }
}
foreach ($m in $json.dataModel.graphMappingRepresentation.relationshipMappings) {
    if (-not (Test-Path (Join-Path $SourceDir $m.tableName))) { $missing.Add($m.tableName) }
}
if ($missing.Count -gt 0) {
    Write-Output "[ERROR] CSV files referenced in the JSON but missing:"
    $missing | ForEach-Object { Write-Output "  - $_" }
    throw "Aborting: $($missing.Count) missing file(s)."
}
Write-Output "[OK] All CSV files referenced in the JSON are present."

# --- 2c) NEW: reverse direction CSV -> JSON. Every *.csv in SourceDir must
#        be referenced by at least one mapping -- orphaned CSVs
#        (e.g. leftovers of old intermediate steps) would otherwise be packed into the
#        ZIP unnoticed without the Data Importer ever using them. ---
$mappedCsvNames = [System.Collections.Generic.HashSet[string]]::new([string[]](
    ($json.dataModel.graphMappingRepresentation.nodeMappings.tableName) +
    ($json.dataModel.graphMappingRepresentation.relationshipMappings.tableName)
))
$allCsvOnDisk = Get-ChildItem -LiteralPath $SourceDir -Filter "*.csv" -File | Select-Object -ExpandProperty Name
$orphanCsvs = $allCsvOnDisk | Where-Object { -not $mappedCsvNames.Contains($_) }
if ($orphanCsvs.Count -gt 0) {
    Write-Output "[ERROR] CSV files in SourceDir without a matching JSON mapping (orphaned):"
    $orphanCsvs | ForEach-Object { Write-Output "  - $_" }
    throw "Aborting: $($orphanCsvs.Count) orphaned CSV file(s). Either add a mapping or remove the file."
}
Write-Output "[OK] No orphaned CSV files (every CSV has a mapping)."

# --- 2b) Quoting check, now also on data rows (not only the header) ---
$quotedFiles = New-Object System.Collections.Generic.List[string]
$allCsvFiles = $mappedCsvNames
foreach ($csvName in $allCsvFiles) {
    $csvPath = Join-Path $SourceDir $csvName
    if (-not (Test-Path $csvPath)) { continue }
    $sample = Get-Content -LiteralPath $csvPath -TotalCount 6
    foreach ($line in $sample) {
        $clean = $line -replace "^\xEF\xBB\xBF", ""
        if ($clean.StartsWith('"')) { $quotedFiles.Add($csvName); break }
    }
}
if ($quotedFiles.Count -gt 0) {
    Write-Output "[ERROR] Quoted CSV files found (header or data rows):"
    $quotedFiles | ForEach-Object { Write-Output "  - $_" }
    throw "Aborting: $($quotedFiles.Count) quoted file(s). Generate them with Write-UnquotedCsv instead of Export-Csv."
}
Write-Output "[OK] No quoted CSV files found (header + sample of data rows)."

# --- 3) Duplicate check on node ids. Process/Flow: hard error (strict
#        UUID dedup is now a hard requirement). Other node types:
#        still only a warning as in the original. ---
$nodeCsvNames = $json.dataModel.graphMappingRepresentation.nodeMappings.tableName | Sort-Object -Unique
$strictDedupFiles = @("Process.csv", "Flow.csv")
$hardFailures = New-Object System.Collections.Generic.List[string]
foreach ($csvName in $nodeCsvNames) {
    $csvPath = Join-Path $SourceDir $csvName
    $ids = Import-Csv $csvPath | Select-Object -ExpandProperty id -ErrorAction SilentlyContinue
    if ($ids) {
        $dups = $ids | Group-Object | Where-Object Count -gt 1
        if ($dups.Count -gt 0) {
            if ($strictDedupFiles -contains $csvName) {
                Write-Output "[ERROR] $csvName contains $($dups.Count) duplicate ID(s):"
                $dups | ForEach-Object { Write-Output "  - $($_.Name) ($($_.Count)x)" }
                $hardFailures.Add($csvName)
            } else {
                Write-Output "[WARNING] $csvName contains $($dups.Count) duplicate ID(s)."
            }
        }
    }
}
if ($hardFailures.Count -gt 0) {
    throw "Aborting: duplicate IDs in $($hardFailures -join ', ') -- strict dedup requirement violated."
}
Write-Output "[OK] Duplicate check completed (Process/Flow: hard, others: warning)."

# --- 3c) NEW: regression check -- the Exchange node was removed on purpose.
#        No mapping, no CSV file name and no relationship type may
#        still refer to it. ---
$forbidden = @("Exchange", "HAS_EXCHANGE", "REFERS_TO_FLOW")
$hits = New-Object System.Collections.Generic.List[string]
foreach ($token in $forbidden) {
    if ($json.dataModel.graphSchemaRepresentation.graphSchema.nodeLabels.token -contains $token) { $hits.Add("nodeLabel:$token") }
    if ($json.dataModel.graphSchemaRepresentation.graphSchema.relationshipTypes.token -contains $token) { $hits.Add("relationshipType:$token") }
    $matchingCsvs = $allCsvOnDisk | Where-Object { $_ -like "*$token*" }
    foreach ($mc in $matchingCsvs) { $hits.Add("csvFile:$mc") }
}
if ($hits.Count -gt 0) {
    Write-Output "[ERROR] Leftovers of the removed Exchange schema found:"
    $hits | ForEach-Object { Write-Output "  - $_" }
    throw "Aborting: Exchange/HAS_EXCHANGE/REFERS_TO_FLOW must be removed completely."
}
Write-Output "[OK] No Exchange/HAS_EXCHANGE/REFERS_TO_FLOW leftovers found."

# --- 4) Pack ---
if (Test-Path $OutputZip) {
    Remove-Item -LiteralPath $OutputZip -Force -ErrorAction SilentlyContinue
}
$files = Get-ChildItem -LiteralPath $SourceDir -File | Where-Object { $_.Extension -in ".json", ".csv" }
Compress-Archive -Path $files.FullName -DestinationPath $OutputZip -CompressionLevel Optimal -Force

$sizeMb = [math]::Round((Get-Item -LiteralPath $OutputZip).Length / 1MB, 2)
Write-Output "[OK] ZIP created: $OutputZip ($sizeMb MB, $($files.Count) files)"

# --- 5) Safety check: is the JSON in the packed ZIP really BOM-free? ---
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($OutputZip)
$entry = $zip.Entries | Where-Object { $_.Name -eq "neo4j_importer_model.json" }
$stream = $entry.Open()
$reader = New-Object System.IO.BinaryReader($stream)
$firstBytes = $reader.ReadBytes(3)
$reader.Close(); $stream.Close(); $zip.Dispose()
$bomInZip = ($firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF)
if ($bomInZip) { throw "BOM found in the packed ZIP -- the import will fail!" }
Write-Output "[OK] JSON in the ZIP is BOM-free."

Write-Output ""
Write-Output "Done. $OutputZip is ready for the Neo4j Data Importer."
