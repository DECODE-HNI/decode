param(
    [string]$SourceDir = $PSScriptRoot,
    [string]$OutputZip = (Join-Path $PSScriptRoot "ned2_gripper_full_model_v8.zip")
)

# ============================================================
# build_zip_v2.ps1 -- erweitert build_zip.ps1 um vier neue Pruefungen
# (siehe Plan agile-sparking-cloud.md, Abschnitt "Phase 0"):
#   2c) bidirektionale CSV<->Mapping-Pruefung (Original prueft nur
#       JSON->CSV; verwaiste CSVs ohne Mapping blieben bisher unentdeckt)
#   3b) Process/Flow-ID-Duplikate = harter Fehler (Original: nur Warnung)
#   3c) Regressionscheck: keine Exchange/HAS_EXCHANGE/REFERS_TO_FLOW-Reste
#   2b erweitert) Quotierungscheck auch auf echte Datenzeilen (Original:
#       nur Header-Zeile)
# Alles andere unveraendert aus dem Original uebernommen.
# ============================================================

$jsonPath = Join-Path $SourceDir "neo4j_importer_model.json"
if (-not (Test-Path $jsonPath)) {
    throw "neo4j_importer_model.json nicht gefunden in: $SourceDir"
}

# --- 1) JSON validieren und BOM-frei neu schreiben ---
$jsonContent = Get-Content $jsonPath -Raw
try {
    $null = $jsonContent | ConvertFrom-Json
} catch {
    throw "neo4j_importer_model.json ist kein gueltiges JSON: $($_.Exception.Message)"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($jsonPath, $jsonContent, $utf8NoBom)

$bytes = [System.IO.File]::ReadAllBytes($jsonPath)
$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
if ($hasBom) { throw "BOM konnte nicht entfernt werden -- Abbruch." }
Write-Output "[OK] JSON gueltig und BOM-frei geschrieben."

$json = Get-Content $jsonPath -Raw | ConvertFrom-Json

# --- 2) Referenzielle Konsistenz: JSON -> CSV ---
$missing = New-Object System.Collections.Generic.List[string]
foreach ($m in $json.dataModel.graphMappingRepresentation.nodeMappings) {
    if (-not (Test-Path (Join-Path $SourceDir $m.tableName))) { $missing.Add($m.tableName) }
}
foreach ($m in $json.dataModel.graphMappingRepresentation.relationshipMappings) {
    if (-not (Test-Path (Join-Path $SourceDir $m.tableName))) { $missing.Add($m.tableName) }
}
if ($missing.Count -gt 0) {
    Write-Output "[FEHLER] Im JSON referenzierte, aber fehlende CSV-Dateien:"
    $missing | ForEach-Object { Write-Output "  - $_" }
    throw "Abbruch: $($missing.Count) fehlende Datei(en)."
}
Write-Output "[OK] Alle im JSON referenzierten CSV-Dateien sind vorhanden."

# --- 2c) NEU: umgekehrte Richtung CSV -> JSON. Jede *.csv im SourceDir muss
#        von mindestens einem Mapping referenziert werden -- verwaiste CSVs
#        (z.B. Reste alter Zwischenschritte) wuerden sonst unbemerkt mit ins
#        ZIP gepackt, ohne dass der Data Importer sie je nutzt. ---
$mappedCsvNames = [System.Collections.Generic.HashSet[string]]::new([string[]](
    ($json.dataModel.graphMappingRepresentation.nodeMappings.tableName) +
    ($json.dataModel.graphMappingRepresentation.relationshipMappings.tableName)
))
$allCsvOnDisk = Get-ChildItem -LiteralPath $SourceDir -Filter "*.csv" -File | Select-Object -ExpandProperty Name
$orphanCsvs = $allCsvOnDisk | Where-Object { -not $mappedCsvNames.Contains($_) }
if ($orphanCsvs.Count -gt 0) {
    Write-Output "[FEHLER] CSV-Dateien im SourceDir ohne zugehoeriges JSON-Mapping (verwaist):"
    $orphanCsvs | ForEach-Object { Write-Output "  - $_" }
    throw "Abbruch: $($orphanCsvs.Count) verwaiste CSV-Datei(en). Entweder Mapping ergaenzen oder Datei entfernen."
}
Write-Output "[OK] Keine verwaisten CSV-Dateien (jede CSV hat ein Mapping)."

# --- 2b) Quotierungs-Check, jetzt auch auf Datenzeilen (nicht nur Header) ---
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
    Write-Output "[FEHLER] Gequotete CSV-Dateien gefunden (Header oder Datenzeilen):"
    $quotedFiles | ForEach-Object { Write-Output "  - $_" }
    throw "Abbruch: $($quotedFiles.Count) gequotete Datei(en). Mit Write-UnquotedCsv statt Export-Csv erzeugen."
}
Write-Output "[OK] Keine gequoteten CSV-Dateien gefunden (Header + Stichprobe Datenzeilen)."

# --- 3) Duplikat-Check auf Node-IDs. Process/Flow: harter Fehler (strikte
#        UUID-Dedup ist jetzt eine harte Anforderung). Andere Node-Typen:
#        weiterhin nur Warnung wie im Original. ---
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
                Write-Output "[FEHLER] $csvName enthaelt $($dups.Count) doppelte ID(s):"
                $dups | ForEach-Object { Write-Output "  - $($_.Name) ($($_.Count)x)" }
                $hardFailures.Add($csvName)
            } else {
                Write-Output "[WARNUNG] $csvName enthaelt $($dups.Count) doppelte ID(s)."
            }
        }
    }
}
if ($hardFailures.Count -gt 0) {
    throw "Abbruch: Doppelte IDs in $($hardFailures -join ', ') -- strikte Dedup-Anforderung verletzt."
}
Write-Output "[OK] Duplikat-Check abgeschlossen (Process/Flow: hart, uebrige: Warnung)."

# --- 3c) NEU: Regressionscheck -- Exchange-Knoten wurde bewusst entfernt.
#        Kein Mapping, kein CSV-Dateiname und kein Relationship-Typ darf
#        noch darauf verweisen. ---
$forbidden = @("Exchange", "HAS_EXCHANGE", "REFERS_TO_FLOW")
$hits = New-Object System.Collections.Generic.List[string]
foreach ($token in $forbidden) {
    if ($json.dataModel.graphSchemaRepresentation.graphSchema.nodeLabels.token -contains $token) { $hits.Add("nodeLabel:$token") }
    if ($json.dataModel.graphSchemaRepresentation.graphSchema.relationshipTypes.token -contains $token) { $hits.Add("relationshipType:$token") }
    $matchingCsvs = $allCsvOnDisk | Where-Object { $_ -like "*$token*" }
    foreach ($mc in $matchingCsvs) { $hits.Add("csvFile:$mc") }
}
if ($hits.Count -gt 0) {
    Write-Output "[FEHLER] Reste des entfernten Exchange-Schemas gefunden:"
    $hits | ForEach-Object { Write-Output "  - $_" }
    throw "Abbruch: Exchange/HAS_EXCHANGE/REFERS_TO_FLOW muss vollstaendig entfernt sein."
}
Write-Output "[OK] Keine Exchange/HAS_EXCHANGE/REFERS_TO_FLOW-Reste gefunden."

# --- 4) Packen ---
if (Test-Path $OutputZip) {
    Remove-Item -LiteralPath $OutputZip -Force -ErrorAction SilentlyContinue
}
$files = Get-ChildItem -LiteralPath $SourceDir -File | Where-Object { $_.Extension -in ".json", ".csv" }
Compress-Archive -Path $files.FullName -DestinationPath $OutputZip -CompressionLevel Optimal -Force

$sizeMb = [math]::Round((Get-Item -LiteralPath $OutputZip).Length / 1MB, 2)
Write-Output "[OK] ZIP erstellt: $OutputZip ($sizeMb MB, $($files.Count) Dateien)"

# --- 5) Sicherheitscheck: JSON im gepackten ZIP wirklich BOM-frei? ---
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($OutputZip)
$entry = $zip.Entries | Where-Object { $_.Name -eq "neo4j_importer_model.json" }
$stream = $entry.Open()
$reader = New-Object System.IO.BinaryReader($stream)
$firstBytes = $reader.ReadBytes(3)
$reader.Close(); $stream.Close(); $zip.Dispose()
$bomInZip = ($firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF)
if ($bomInZip) { throw "BOM im gepackten ZIP gefunden -- Import wird fehlschlagen!" }
Write-Output "[OK] JSON im ZIP ist BOM-frei."

Write-Output ""
Write-Output "Fertig. $OutputZip ist bereit fuer den Neo4j Data Importer."
