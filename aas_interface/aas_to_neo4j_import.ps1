<#
.SYNOPSIS
  Rueckrichtung AAS -> Neo4j: liest eine unserer drei AAS-Environment-JSON-Dateien
  (White/Grey/Black Box, siehe AAS-Boxenmodell-Dokument Abschnitt 4-6) und erzeugt
  daraus ein Cypher-Skript, das die passenden Knoten/Kanten importiert.

  Designentscheidung (siehe Abschnitt 7 "Mapping zu Neo4j" im Artifact):
  - Importierte Process-/Assessment-Knoten bekommen ein "EXT_"-Praefix und
    sourceAAS/traceabilityLevel-Properties -- sie werden NICHT stillschweigend
    mit den internen PROC_CNC/ASS_PREC_AL7075-Knoten verschmolzen. Ein von
    aussen per AAS empfangener Datensatz ist nicht automatisch identisch mit
    der eigenen internen Modellierung, auch wenn er denselben Sachverhalt
    beschreibt -- Abgleich waere ein eigener, spaeterer Schritt.
  - Flow-Knoten (UUIDs wie "ae206e6f-...") werden dagegen unveraendert
    wiederverwendet -- das sind global geteilte Referenzidentitaeten, kein
    organisationsinternes Konstrukt.
  - White Box: volle Process/Flow/HAS_FLOW-Rekonstruktion + Assessment/
    ImpactResult aus CarbonFootprintSummary, traceabilityLevel='white'.
  - Grey Box: Assessment/ImpactResult aus der PCF-Deklaration,
    traceabilityLevel='grey', PLUS Versuch, jede FragmentReference gegen die
    tatsaechlich vorhandenen HAS_FLOW.exchangeId-Werte im GRAPH aufzuloesen
    (das ist die eigentliche Grey-Box-Nutzung: partielle Verifizierbarkeit).
  - Black Box: Assessment-Knoten + je Indikator eine :DECLARES-Kante zu dem
    entsprechenden ImpactCategory-Knoten (traceabilityLevel='black' auf der
    Kante). Bewusst NICHT :CHARACTERIZES, obwohl strukturell identisch --
    :CHARACTERIZES ist aus echten Elementarfluessen berechnet, :DECLARES ist
    eine unverifizierte Lieferantenangabe. Getrennter Kantentyp macht diesen
    Unterschied sichtbar, erlaubt aber trotzdem einheitliche Graph-Traversal-
    Queries ueber ImpactCategory hinweg -- wichtig, sobald mehrere Bauteile
    im Graph verglichen werden sollen. Angehaengte Datei nur als
    unverarbeiteter String, keine Aufloesungsversuche.
  - Alle drei Boxen: die komplette Roh-JSON des importierten Submodells wird
    zusaetzlich als String-Property auf dem jeweiligen Ergebnisknoten
    gespeichert (rawSubmodelJson) -- Dekomposition fuer Abfragbarkeit, Blob
    fuer exakte Audit-Spur, was der Lieferant wortwoertlich deklariert hat.

.PARAMETER JsonPath
  Pfad zur AAS-Environment-JSON-Datei.

.PARAMETER OutCypher
  Zielpfad fuer das generierte Cypher-Skript. Default: <JsonPath-Basisname>_import.cypher

.EXAMPLE
  .\aas_to_neo4j_import.ps1 -JsonPath .\aas_instance_whitebox_prec_al7075_contact.json
#>
param(
  [Parameter(Mandatory=$true)][string]$JsonPath,
  [string]$OutCypher
)

if (-not $OutCypher) {
  $base = [System.IO.Path]::GetFileNameWithoutExtension($JsonPath)
  $OutCypher = Join-Path (Split-Path $JsonPath -Parent) "$base`_import.cypher"
}

# --- Hilfsfunktionen: AAS-JSON-Elemente per idShort finden -------------------
function Get-Elem($elements, [string]$idShort) {
  return $elements | Where-Object { $_.idShort -eq $idShort } | Select-Object -First 1
}
function Get-PropRaw($elements, [string]$idShort) {
  $e = Get-Elem $elements $idShort
  if ($null -eq $e) { return $null }
  return $e.value
}
# Wandelt AAS-idShorts wie "GWPTotal"/"ODP"/"EPFreshwater" in saubere camelCase-
# Property-Namen ("gwpTotal"/"odp"/"epFreshwater") statt nur den ersten
# Buchstaben kleinzuschreiben (was "gWPTotal" ergaebe).
function ConvertTo-CamelCaseProp([string]$idShort) {
  # -cmatch (case-sensitive!) ist hier zwingend -- das normale -match ist
  # case-insensitive, wodurch [A-Z]/[a-z] beide Faelle akzeptieren wuerden
  # und die Gross-/Kleinschreibungs-Logik wirkungslos machen wuerde.
  if ($idShort -cmatch '^([A-Z]+)([A-Z][a-z].*)$') {
    return $Matches[1].ToLower() + $Matches[2]
  }
  return $idShort.ToLower()
}

# Fuer Cypher: numerische valueTypes unquoted einsetzen, alles andere als String escapen.
function Format-CypherValue($elements, [string]$idShort) {
  $e = Get-Elem $elements $idShort
  if ($null -eq $e) { return $null }
  $v = $e.value
  $isNumeric = $e.valueType -in @('xs:double','xs:int','xs:float','xs:integer')
  if ($isNumeric) { return $v }
  $escaped = $v -replace "'", "\'"
  return "'$escaped'"
}

# Beliebiges PowerShell-Objekt kompakt zu JSON und Cypher-sicher als String-
# Literal escapen (fuer die Roh-JSON-Blob-Speicherung, Mischmodell aus
# Dekomposition + Audit-Blob).
function Format-CypherJsonBlob($obj) {
  $json = $obj | ConvertTo-Json -Depth 20 -Compress
  $escaped = $json -replace '\\', '\\\\' -replace "'", "\'"
  return "'$escaped'"
}

# Schlanke Zuordnung AAS-Indikator-idShort -> reale ImpactCategory.id im Graphen
# (fuer die Black-Box :DECLARES-Kanten). Nur die zehn Kernindikatoren, die
# aas_instance_blackbox_*.json aktuell nutzt -- bei neuen Indikatoren ergaenzen.
$IndicatorToImpactCategory = @{
  'GWPTotal'      = 'IC_CLIMATE'
  'ODP'           = 'IC_EF_OZONE_DEPLETION'
  'AP'            = 'IC_EF_ACIDIFICATION'
  'EPFreshwater'  = 'IC_EF_EF_EUTROPHICATION_FRESHWATER'
  'EPMarine'      = 'IC_EF_EUTROPH_MARINE'
  'EPTerrestrial' = 'IC_EF_EF_EUTROPHICATION_TERRESTRIAL'
  'POCP'          = 'IC_EF_PHOTOCHEM_OZONE'
  'ADPE'          = 'IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS'
  'ADPF'          = 'IC_EF_EF_RESOURCE_USE_FOSSILS'
  'WDP'           = 'IC_EF_WATER_USE'
}

Write-Output "Lese: $JsonPath"
$envJson = Get-Content -Raw $JsonPath | ConvertFrom-Json
$shell = $envJson.assetAdministrationShells[0]
$submodels = $envJson.submodels
$sourceAasId = $shell.id
Write-Output "AAS: $($shell.idShort)  [$sourceAasId]"

$cypherLines = New-Object System.Collections.Generic.List[string]
$cypherLines.Add("// Generiert von aas_to_neo4j_import.ps1 aus: $JsonPath")
$cypherLines.Add("// AAS-Shell: $($shell.idShort) [$sourceAasId]")
$cypherLines.Add("")

$whiteSm = $submodels | Where-Object { $_.idShort -eq 'ILCDProcessDataset' }
$greySm  = $submodels | Where-Object { $_.idShort -eq 'CarbonFootprintGrey' }
$blackSm = $submodels | Where-Object { $_.idShort -eq 'EnvironmentalFootprintBlack' }
$cfSummarySm = $submodels | Where-Object { $_.idShort -eq 'CarbonFootprintSummary' }

# ==============================================================
# WHITE BOX
# ==============================================================
if ($whiteSm) {
  Write-Output "Erkannt: WHITE BOX (ILCDProcessDataset gefunden)"
  $cypherLines.Add("// ================= WHITE BOX: Process/Flow/HAS_FLOW =================")

  $mfgListElem = Get-Elem $whiteSm.submodelElements 'ManufacturingProcesses'
  $serviceElem = Get-Elem $whiteSm.submodelElements 'ServiceStageProcess_PROC_REPAIR'

  $processSections = New-Object System.Collections.Generic.List[object]
  if ($mfgListElem) { foreach ($p in $mfgListElem.value) { $processSections.Add($p) } }
  if ($serviceElem) { $processSections.Add($serviceElem) }

  foreach ($procSmc in $processSections) {
    $procElems = $procSmc.value
    $procId = Get-PropRaw $procElems 'ProcessId'
    $procName = Get-PropRaw $procElems 'ProcessName'
    $extProcId = "EXT_$procId"

    $cypherLines.Add("MERGE (p:Process {id:'$extProcId'})")
    $cypherLines.Add("  SET p.name = $(Format-CypherValue $procElems 'ProcessName'),")
    $cypherLines.Add("      p.sourceProcessId = '$procId',")
    $cypherLines.Add("      p.sourceAAS = '$sourceAasId',")
    $cypherLines.Add("      p.traceabilityLevel = 'white';")

    $exchangesElem = Get-Elem $procElems 'Exchanges'
    if ($exchangesElem) {
      foreach ($ex in $exchangesElem.value) {
        $exElems = $ex.value
        $exchangeId = Get-PropRaw $exElems 'ExchangeId'
        $direction = Get-PropRaw $exElems 'Direction'
        if (-not $direction) { $direction = 'input' }  # ServiceStage-Exchanges lassen Direction implizit
        $flowId = Get-PropRaw $exElems 'FlowId'
        $flowName = Get-PropRaw $exElems 'FlowName'

        # exchangeId traegt einen GLOBALEN Unique-Constraint (has_flow_exchangeid_unique).
        # Der String aus der AAS ist der von PROC_CNCs EIGENER interner Kante --
        # den unveraendert wiederzuverwenden wuerde mit genau dieser Kante kollidieren.
        # Praefix wie bei Process/ImpactResult, Original bleibt als sourceExchangeId erhalten.
        $extExchangeId = "EXT_$exchangeId"
        $cypherLines.Add("MERGE (f:Flow {id:'$flowId'})")
        $cypherLines.Add("  ON CREATE SET f.name = $(Format-CypherValue $exElems 'FlowName');")
        $cypherLines.Add("MATCH (p:Process {id:'$extProcId'}), (f:Flow {id:'$flowId'})")
        $cypherLines.Add("MERGE (p)-[r:HAS_FLOW {exchangeId:'$extExchangeId'}]->(f)")
        $cypherLines.Add("  SET r.sourceExchangeId = '$exchangeId',")
        $cypherLines.Add("      r.direction = '$direction',")
        $cypherLines.Add("      r.amount = $(Format-CypherValue $exElems 'MeanAmount'),")
        $cypherLines.Add("      r.unit = $(Format-CypherValue $exElems 'Unit');")
        $cypherLines.Add("")
      }
    }
  }

  if ($cfSummarySm) {
    $cypherLines.Add("// ---- CarbonFootprintSummary -> Assessment/ImpactResult (traceabilityLevel=white) ----")
    foreach ($pcfSmc in $cfSummarySm.submodelElements) {
      $pcfElems = $pcfSmc.value
      $extResultId = "EXT_" + (Get-PropRaw $pcfElems 'SourceImpactResultId')
      $cypherLines.Add("MERGE (ir:ImpactResult {id:'$extResultId'})")
      $cypherLines.Add("  SET ir.value = $(Format-CypherValue $pcfElems 'PCFCO2eq'),")
      $cypherLines.Add("      ir.unit = 'kg CO2-eq',")
      $cypherLines.Add("      ir.lifeCyclePhase = $(Format-CypherValue $pcfElems 'PCFLifeCyclePhase'),")
      $cypherLines.Add("      ir.calculationMethod = $(Format-CypherValue $pcfElems 'PCFCalculationMethod'),")
      $cypherLines.Add("      ir.sourceAAS = '$sourceAasId',")
      $cypherLines.Add("      ir.traceabilityLevel = 'white',")
      $cypherLines.Add("      ir.rawSubmodelJson = $(Format-CypherJsonBlob $pcfSmc);")
      $cypherLines.Add("")
    }
  }
}

# ==============================================================
# GREY BOX
# ==============================================================
if ($greySm) {
  Write-Output "Erkannt: GREY BOX (CarbonFootprintGrey gefunden)"
  $cypherLines.Add("// ================= GREY BOX: Assessment + FragmentReference-Aufloesung =================")

  $pcfElems = (Get-Elem $greySm.submodelElements 'ProductCarbonFootprint').value
  $fileElem = Get-Elem $greySm.submodelElements 'AttachedILCDDataset'
  $attachedFile = if ($fileElem) { $fileElem.value } else { $null }

  $extId = "EXT_GREY_" + ($shell.idShort -replace '[^A-Za-z0-9_]', '_')
  $cypherLines.Add("MERGE (ir:ImpactResult {id:'$extId'})")
  $cypherLines.Add("  SET ir.value = $(Format-CypherValue $pcfElems 'PCFCO2eq'),")
  $cypherLines.Add("      ir.unit = 'kg CO2-eq',")
  $cypherLines.Add("      ir.lifeCyclePhase = $(Format-CypherValue $pcfElems 'PCFLifeCyclePhase'),")
  $cypherLines.Add("      ir.calculationMethod = $(Format-CypherValue $pcfElems 'PCFCalculationMethod'),")
  $cypherLines.Add("      ir.attachedFile = '$attachedFile',")
  $cypherLines.Add("      ir.sourceAAS = '$sourceAasId',")
  $cypherLines.Add("      ir.traceabilityLevel = 'grey',")
  $cypherLines.Add("      ir.rawSubmodelJson = $(Format-CypherJsonBlob $greySm);")
  $cypherLines.Add("")

  $relElems = $greySm.submodelElements | Where-Object { $_.modelType -eq 'AnnotatedRelationshipElement' }
  foreach ($rel in $relElems) {
    $fragKey = $rel.second.keys | Select-Object -Last 1
    $fragValue = $fragKey.value   # z.B. "ilcd:exchange:EX_PROC_CNC_FLOW_AL_IN"
    if ($fragValue -match '^ilcd:exchange:(.+)$') {
      $refExchangeId = $Matches[1]
      $cypherLines.Add("// Verifikationsversuch fuer '$($rel.idShort)': existiert '$refExchangeId' im Graphen?")
      $cypherLines.Add("MATCH (ir:ImpactResult {id:'$extId'})")
      $cypherLines.Add("OPTIONAL MATCH (srcP:Process)-[srcHf:HAS_FLOW {exchangeId:'$refExchangeId'}]->(srcF:Flow)")
      $cypherLines.Add("FOREACH (_ IN CASE WHEN srcF IS NOT NULL THEN [1] ELSE [] END |")
      $cypherLines.Add("  MERGE (ir)-[v:VERIFIED_AGAINST {exchangeId:'$refExchangeId'}]->(srcF)")
      $cypherLines.Add("  SET v.resolvedAmount = srcHf.amount, v.resolvedUnit = srcHf.unit, v.resolvedFromProcess = srcP.id")
      $cypherLines.Add(")")
      $cypherLines.Add("WITH ir, srcF")
      $cypherLines.Add("FOREACH (_ IN CASE WHEN srcF IS NULL THEN [1] ELSE [] END |")
      $cypherLines.Add("  SET ir.unresolvedFragments = coalesce(ir.unresolvedFragments, []) + ['$refExchangeId']")
      $cypherLines.Add(")")
      $cypherLines.Add(";")
      $cypherLines.Add("")
    }
  }
}

# ==============================================================
# BLACK BOX
# ==============================================================
if ($blackSm) {
  Write-Output "Erkannt: BLACK BOX (EnvironmentalFootprintBlack gefunden)"
  $cypherLines.Add("// ================= BLACK BOX: Assessment + :DECLARES-Kanten zu ImpactCategory =================")

  $indElems = (Get-Elem $blackSm.submodelElements 'EnvironmentalIndicators').value
  $fileElem = Get-Elem $blackSm.submodelElements 'SupportingReport'
  $attachedFile = if ($fileElem) { $fileElem.value } else { $null }

  $extId = "EXT_BLACK_" + ($shell.idShort -replace '[^A-Za-z0-9_]', '_')
  $cypherLines.Add("MERGE (a:Assessment {id:'$extId'})")
  $cypherLines.Add("  SET a.traceabilityLevel = 'black',")
  $cypherLines.Add("      a.sourceAAS = '$sourceAasId',")
  $cypherLines.Add("      a.lifeCycleStage = $(Format-CypherValue $indElems 'LifeCycleStage'),")
  $cypherLines.Add("      a.attachedFile = '$attachedFile',  // Blob-Referenz, wird NICHT geparst")
  $cypherLines.Add("      a.rawSubmodelJson = $(Format-CypherJsonBlob $blackSm);")
  $cypherLines.Add("")

  foreach ($prop in $indElems) {
    if ($prop.idShort -eq 'LifeCycleStage' -or $prop.idShort -match 'Unit$') { continue }
    $icId = $IndicatorToImpactCategory[$prop.idShort]
    $unitValue = Get-PropRaw $indElems "$($prop.idShort)Unit"
    if (-not $icId) {
      $cypherLines.Add("// WARNUNG: kein ImpactCategory-Mapping fuer Indikator '$($prop.idShort)' -- IndicatorToImpactCategory in aas_to_neo4j_import.ps1 ergaenzen.")
      continue
    }
    $cypherLines.Add("MATCH (a:Assessment {id:'$extId'}), (ic:ImpactCategory {id:'$icId'})")
    $cypherLines.Add("MERGE (a)-[d:DECLARES]->(ic)")
    $cypherLines.Add("  SET d.value = $(Format-CypherValue $indElems $prop.idShort),")
    $cypherLines.Add("      d.unit = '$unitValue',")
    $cypherLines.Add("      d.traceabilityLevel = 'black';")
    $cypherLines.Add("")
  }
}

if (-not $whiteSm -and -not $greySm -and -not $blackSm) {
  Write-Output "WARNUNG: Kein bekanntes Box-Submodell gefunden (ILCDProcessDataset / CarbonFootprintGrey / EnvironmentalFootprintBlack) -- nichts generiert."
  exit 1
}

# Set-Content -Encoding UTF8 wuerde unter Windows PowerShell 5.1 ein BOM
# voranstellen, an dem cypher-shell mit einem Syntaxfehler scheitert -- daher
# explizit BOM-freies UTF-8.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($OutCypher, $cypherLines, $utf8NoBom)
Write-Output ""
Write-Output "Cypher-Skript geschrieben: $OutCypher ($($cypherLines.Count) Zeilen)"
