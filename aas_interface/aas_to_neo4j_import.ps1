<#
.SYNOPSIS
  Reverse direction AAS -> Neo4j: reads one of our three AAS environment JSON files
  (white/grey/black box, see README.md in this folder) and generates from it a
  Cypher script that imports the matching nodes/edges.

  Design decision (see the mapping-to-Neo4j section of README.md):
  - Imported Process/Assessment nodes get an "EXT_" prefix and
    sourceAAS/traceabilityLevel properties -- they are NOT silently
    merged with the internal PROC_CNC/ASS_PREC_AL7075 nodes. A dataset
    received from outside via AAS is not automatically identical to
    one's own internal modelling, even if it describes the same facts --
    reconciliation would be a separate, later step.
  - Flow nodes (UUIDs such as "ae206e6f-...") on the other hand are reused
    unchanged -- they are globally shared reference identities, not an
    organisation-internal construct.
  - White box: full Process/Flow/HAS_FLOW reconstruction + Assessment/
    ImpactResult from CarbonFootprintSummary, traceabilityLevel='white'.
  - Grey box: Assessment/ImpactResult from the PCF declaration,
    traceabilityLevel='grey', PLUS an attempt to resolve every FragmentReference
    against the HAS_FLOW.exchangeId values actually present in the GRAPH
    (that is the real grey-box use: partial verifiability).
  - Black box: Assessment node + one :DECLARES edge per indicator to the
    corresponding ImpactCategory node (traceabilityLevel='black' on the
    edge). Deliberately NOT :CHARACTERIZES, although structurally identical --
    :CHARACTERIZES is computed from real elementary flows, :DECLARES is
    an unverified supplier statement. A separate edge type makes this
    difference visible, but still allows uniform graph traversal
    queries across ImpactCategory -- important as soon as several parts
    are to be compared in the graph. The attached file is stored only as an
    unprocessed string, no resolution attempts.
  - All three boxes: the complete raw JSON of the imported submodel is
    additionally stored as a string property on the respective result node
    (rawSubmodelJson) -- decomposition for queryability, blob
    for an exact audit trail of what the supplier declared verbatim.

.PARAMETER JsonPath
  Path to the AAS environment JSON file.

.PARAMETER OutCypher
  Target path for the generated Cypher script. Default: <JsonPath base name>_import.cypher

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

# --- Helper functions: find AAS JSON elements by idShort -------------------
function Get-Elem($elements, [string]$idShort) {
  return $elements | Where-Object { $_.idShort -eq $idShort } | Select-Object -First 1
}
function Get-PropRaw($elements, [string]$idShort) {
  $e = Get-Elem $elements $idShort
  if ($null -eq $e) { return $null }
  return $e.value
}
# Converts AAS idShorts such as "GWPTotal"/"ODP"/"EPFreshwater" into clean camelCase
# property names ("gwpTotal"/"odp"/"epFreshwater") instead of only lowercasing
# the first letter (which would give "gWPTotal").
function ConvertTo-CamelCaseProp([string]$idShort) {
  # -cmatch (case-sensitive!) is mandatory here -- the normal -match is
  # case-insensitive, so [A-Z]/[a-z] would both accept either case
  # and make the upper/lower-case logic ineffective.
  if ($idShort -cmatch '^([A-Z]+)([A-Z][a-z].*)$') {
    return $Matches[1].ToLower() + $Matches[2]
  }
  return $idShort.ToLower()
}

# For Cypher: insert numeric valueTypes unquoted, escape everything else as a string.
function Format-CypherValue($elements, [string]$idShort) {
  $e = Get-Elem $elements $idShort
  if ($null -eq $e) { return $null }
  $v = $e.value
  $isNumeric = $e.valueType -in @('xs:double','xs:int','xs:float','xs:integer')
  if ($isNumeric) { return $v }
  $escaped = $v -replace "'", "\'"
  return "'$escaped'"
}

# Compactly serialise any PowerShell object to JSON and escape it Cypher-safely as a string
# literal (for the raw JSON blob storage, mixed model of
# decomposition + audit blob).
function Format-CypherJsonBlob($obj) {
  $json = $obj | ConvertTo-Json -Depth 20 -Compress
  $escaped = $json -replace '\\', '\\\\' -replace "'", "\'"
  return "'$escaped'"
}

# Slim mapping AAS indicator idShort -> real ImpactCategory.id in the graph
# (for the black-box :DECLARES edges). Only the ten core indicators that
# aas_instance_blackbox_*.json currently uses -- extend when adding new indicators.
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

Write-Output "Reading: $JsonPath"
$envJson = Get-Content -Raw $JsonPath | ConvertFrom-Json
$shell = $envJson.assetAdministrationShells[0]
$submodels = $envJson.submodels
$sourceAasId = $shell.id
Write-Output "AAS: $($shell.idShort)  [$sourceAasId]"

$cypherLines = New-Object System.Collections.Generic.List[string]
$cypherLines.Add("// Generated by aas_to_neo4j_import.ps1 from: $JsonPath")
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
  Write-Output "Detected: WHITE BOX (ILCDProcessDataset found)"
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
        if (-not $direction) { $direction = 'input' }  # ServiceStage exchanges leave direction implicit
        $flowId = Get-PropRaw $exElems 'FlowId'
        $flowName = Get-PropRaw $exElems 'FlowName'

        # exchangeId carries a GLOBAL unique constraint (has_flow_exchangeid_unique).
        # The string from the AAS is that of PROC_CNC's OWN internal edge --
        # reusing it unchanged would collide with exactly that edge.
        # Prefix as with Process/ImpactResult, the original is kept as sourceExchangeId.
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
  Write-Output "Detected: GREY BOX (CarbonFootprintGrey found)"
  $cypherLines.Add("// ================= GREY BOX: Assessment + FragmentReference resolution =================")

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
      $cypherLines.Add("// Verification attempt for '$($rel.idShort)': does '$refExchangeId' exist in the graph?")
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
  Write-Output "Detected: BLACK BOX (EnvironmentalFootprintBlack found)"
  $cypherLines.Add("// ================= BLACK BOX: Assessment + :DECLARES edges to ImpactCategory =================")

  $indElems = (Get-Elem $blackSm.submodelElements 'EnvironmentalIndicators').value
  $fileElem = Get-Elem $blackSm.submodelElements 'SupportingReport'
  $attachedFile = if ($fileElem) { $fileElem.value } else { $null }

  $extId = "EXT_BLACK_" + ($shell.idShort -replace '[^A-Za-z0-9_]', '_')
  $cypherLines.Add("MERGE (a:Assessment {id:'$extId'})")
  $cypherLines.Add("  SET a.traceabilityLevel = 'black',")
  $cypherLines.Add("      a.sourceAAS = '$sourceAasId',")
  $cypherLines.Add("      a.lifeCycleStage = $(Format-CypherValue $indElems 'LifeCycleStage'),")
  $cypherLines.Add("      a.attachedFile = '$attachedFile',  // blob reference, NOT parsed")
  $cypherLines.Add("      a.rawSubmodelJson = $(Format-CypherJsonBlob $blackSm);")
  $cypherLines.Add("")

  foreach ($prop in $indElems) {
    if ($prop.idShort -eq 'LifeCycleStage' -or $prop.idShort -match 'Unit$') { continue }
    $icId = $IndicatorToImpactCategory[$prop.idShort]
    $unitValue = Get-PropRaw $indElems "$($prop.idShort)Unit"
    if (-not $icId) {
      $cypherLines.Add("// WARNING: no ImpactCategory mapping for indicator '$($prop.idShort)' -- add it to IndicatorToImpactCategory in aas_to_neo4j_import.ps1.")
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
  Write-Output "WARNING: No known box submodel found (ILCDProcessDataset / CarbonFootprintGrey / EnvironmentalFootprintBlack) -- nothing generated."
  exit 1
}

# Set-Content -Encoding UTF8 would prepend a BOM under Windows PowerShell 5.1,
# on which cypher-shell fails with a syntax error -- hence
# explicitly BOM-free UTF-8.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($OutCypher, $cypherLines, $utf8NoBom)
Write-Output ""
Write-Output "Cypher script written: $OutCypher ($($cypherLines.Count) lines)"
