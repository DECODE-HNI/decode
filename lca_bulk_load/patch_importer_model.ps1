<#
============================================================
patch_importer_model.ps1  (Phase 3)

Clones the existing neo4j_importer_model.json and applies targeted deltas
(no rebuild from scratch -- the internal $ref/#p:N/#nl:N/#r:N numbering
scheme is an undocumented tool-internal format; a delta patch based on
content matching (token/name) is less risky than a rebuild).

Changes:
1. Removes completely: nodeLabel "Exchange", relationshipTypes
   "HAS_EXCHANGE" and "REFERS_TO_FLOW" (including their properties), as well as the
   associated node/relationship mappings.
2. Removes HAS_FLOW and CHARACTERIZES COMPLETELY from the channel A schema
   (type + relationshipObjectType + mapping) -- channel B (Python/Bolt)
   takes over loading them, because the Data Importer structurally cannot merge
   parallel edges between the same nodes correctly. ORIGINALLY the plan was
   to leave the type definition in the schema as pure documentation without a
   mapping -- that fails: the Data Importer only loads a model if EVERY
   declared relationshipType has a complete, mapped CSV
   ("Your data model has errors", confirmed empirically in the UI). Hence complete
   removal now, no documentation in the schema.
3. Adds new properties: Process.source/sourceDatabase/referenceYear,
   Flow.source/sourceDatabase -- including propertyMappings in the existing
   Process/Flow nodeMappings (reads the new columns from the merged
   CSVs).
4. Cleans up dataSourceSchema.tableSchemas: removes entries for
   dropped CSVs, adds new fields for Process.csv/Flow.csv.

IMPORTANT LESSON (2nd failed attempt): setting a new property on a
SHARED relationshipType (e.g. HAS_DATA, used by several label pairs)
breaks ALL other mappings of that type that do not have the column
("Must be specified"). Set new relationship-specific properties only
on freshly created, exclusively used types (e.g. DERIVED_FROM),
never on shared types.

NOT included (deliberate scope decision): new
DataSource nodes + FROM_SOURCE relationship for Sphera/IDEMAT provenance.
The Process/Flow properties source/sourceDatabase already satisfy the provenance
requirement (section 14 of the original specification lists
properties AND/OR DataSource structures as equivalent options).
============================================================
#>

param(
    [string] $ExistingJson = "./ned2_gripper_full_model_neo4j/neo4j_importer_model.json",
    [string] $OutJson = "./build/neo4j_importer_model.json"
)
$ErrorActionPreference = "Stop"

$outBuildDir = Split-Path $OutJson -Parent
if (-not (Test-Path $outBuildDir)) { New-Item -ItemType Directory -Path $outBuildDir -Force | Out-Null }

$raw = Get-Content $ExistingJson -Raw
$model = $raw | ConvertFrom-Json

# ------------------------------------------------------------
# Helper function: find the next free p:N id (current maximum in use + 1)
# ------------------------------------------------------------
$maxP = ([regex]::Matches($raw, '"\$id":\s*"p:(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
$nextP = $maxP + 1
function New-PropId { param() $script:id = "p:$script:nextP"; $script:nextP++; return $script:id }

$graphSchema = $model.dataModel.graphSchemaRepresentation.graphSchema
$graphMapping = $model.dataModel.graphMappingRepresentation

# ------------------------------------------------------------
# 1) Remove Exchange completely -- as a graph traversal, not as a list
#    of hard-coded tokens. Reason: Exchange is not only connected via HAS_EXCHANGE/
#    REFERS_TO_FLOW, but also appears as an endpoint in
#    reused relationship types (HAS_DATA: Exchange->DataItem,
#    DERIVED_FROM: ImpactResult->Exchange -- both found only by inspecting the
#    JSON, a token-based approach would have missed them). Therefore:
#    1. remove nodeLabel Exchange (nl:N)
#    2. remove all nodeObjectTypes (n:N) whose labels refer ONLY to Exchange
#    3. remove all relationshipObjectTypes (r:N) whose from/to refer to a removed
#       n:N
#    4. also remove relationshipTypes (rt:N) that consequently have NO remaining
#       relationshipObjectType usage (e.g.
#       DERIVED_FROM existed only for Exchange -> gone; HAS_DATA has 4 more
#       usages -> stays)
#    5. clean up dependent entries: constraints, nodeKeyProperties,
#       relationshipKeyProperties, visualisation.nodes, nodeMappings,
#       relationshipMappings
# ------------------------------------------------------------
$exchangeLabel = $graphSchema.nodeLabels | Where-Object { $_.token -eq "Exchange" }
if (-not $exchangeLabel) { throw "nodeLabel 'Exchange' not found -- aborting (the script requires it to exist)." }
$exchangeLabelId = $exchangeLabel.'$id'
$exchangeLabelRef = "#$exchangeLabelId"
$graphSchema.nodeLabels = @($graphSchema.nodeLabels | Where-Object { $_.token -ne "Exchange" })
Write-Output "[OK] nodeLabel 'Exchange' ($exchangeLabelId) removed ($($exchangeLabel.properties.Count) properties removed with it)."

# Step 2: remove nodeObjectTypes with EXCLUSIVELY the Exchange label
$removedNodeObjs = $graphSchema.nodeObjectTypes | Where-Object {
    (($_.labels | ForEach-Object { $_.'$ref' }) -contains $exchangeLabelRef) -and $_.labels.Count -eq 1
}
$removedNodeObjRefs = [System.Collections.Generic.HashSet[string]]::new([string[]]($removedNodeObjs | ForEach-Object { "#$($_.'$id')" }))
$before = $graphSchema.nodeObjectTypes.Count
$graphSchema.nodeObjectTypes = @($graphSchema.nodeObjectTypes | Where-Object { -not $removedNodeObjRefs.Contains("#$($_.'$id')") })
Write-Output "[OK] nodeObjectTypes removed: $(($removedNodeObjs | ForEach-Object { $_.'$id' }) -join ', ') ($before -> $($graphSchema.nodeObjectTypes.Count))"

# Step 3: remove relationshipObjectTypes whose from/to point to a removed n:N
$exchangeRelatedRObjs = $graphSchema.relationshipObjectTypes | Where-Object {
    $removedNodeObjRefs.Contains($_.from.'$ref') -or $removedNodeObjRefs.Contains($_.to.'$ref')
}
# HAS_FLOW/CHARACTERIZES: the Data Importer only loads a model if EVERY
# declared relationshipType has a complete, active mapping file --
# a "documentation without mapping" state (original approach) is rejected as
# a model error ("Your data model has errors", confirmed in the UI:
# HAS_DATA/CHARACTERIZES/HAS_FLOW all showed errors).
# Therefore HAS_FLOW/CHARACTERIZES are now removed COMPLETELY from the channel A
# schema (like HAS_EXCHANGE/REFERS_TO_FLOW) -- channel B remains the
# sole source for this data, just without schema presence in channel A.
$hasFlowRt = $graphSchema.relationshipTypes | Where-Object { $_.token -eq "HAS_FLOW" }
$characterizesRt = $graphSchema.relationshipTypes | Where-Object { $_.token -eq "CHARACTERIZES" }
$hfCfRtRefs = [System.Collections.Generic.HashSet[string]]::new([string[]](@($hasFlowRt, $characterizesRt) | Where-Object { $_ } | ForEach-Object { "#$($_.'$id')" }))
$hfCfRObjs = $graphSchema.relationshipObjectTypes | Where-Object { $hfCfRtRefs.Contains($_.type.'$ref') }

$removedRObjs = @($exchangeRelatedRObjs) + @($hfCfRObjs)
$removedRObjRefs = [System.Collections.Generic.HashSet[string]]::new([string[]]($removedRObjs | ForEach-Object { "#$($_.'$id')" }))
$allMappingRemoveRefs = $removedRObjRefs

Write-Output "[INFO] relationshipObjectTypes removed completely (Exchange endpoint): $(($exchangeRelatedRObjs | ForEach-Object { "$($_.'$id')(type=$($_.type.'$ref'))" }) -join ', ')"
Write-Output "[INFO] relationshipObjectTypes removed completely (HAS_FLOW/CHARACTERIZES, channel B takes over): $(($hfCfRObjs | ForEach-Object { $_.'$id' }) -join ', ')"

$before = $graphSchema.relationshipObjectTypes.Count
$graphSchema.relationshipObjectTypes = @($graphSchema.relationshipObjectTypes | Where-Object { -not $removedRObjRefs.Contains("#$($_.'$id')") })
Write-Output "[OK] relationshipObjectTypes removed: $before -> $($graphSchema.relationshipObjectTypes.Count)"

# Step 4: remove relationshipTypes without remaining relationshipObjectType usage
$remainingTypeRefs = [System.Collections.Generic.HashSet[string]]::new([string[]]($graphSchema.relationshipObjectTypes | ForEach-Object { $_.type.'$ref' }))
$candidateRtIds = ($removedRObjs | ForEach-Object { $_.type.'$ref' }) | Sort-Object -Unique
$orphanedRt = $candidateRtIds | Where-Object { -not $remainingTypeRefs.Contains($_) }
$orphanedTokens = $graphSchema.relationshipTypes | Where-Object { $orphanedRt -contains "#$($_.'$id')" } | ForEach-Object { $_.token }
Write-Output "[INFO] relationshipTypes orphaned as a result (no usage left): $($orphanedTokens -join ', ')"
$before = $graphSchema.relationshipTypes.Count
$graphSchema.relationshipTypes = @($graphSchema.relationshipTypes | Where-Object { -not ($orphanedRt -contains "#$($_.'$id')") })
Write-Output "[OK] relationshipTypes removed: $before -> $($graphSchema.relationshipTypes.Count)"

# Step 5a: remove constraints on Exchange
$graphSchema.constraints = @($graphSchema.constraints | Where-Object { $_.nodeLabel.'$ref' -ne $exchangeLabelRef })
Write-Output "[OK] constraints cleaned up (Exchange_id_unique removed if present)."

# Step 5b: clean up nodeKeyProperties / relationshipKeyProperties
$ext = $model.dataModel.graphSchemaExtensionsRepresentation
$before = $ext.nodeKeyProperties.Count
$ext.nodeKeyProperties = @($ext.nodeKeyProperties | Where-Object { -not $removedNodeObjRefs.Contains($_.node.'$ref') })
Write-Output "[OK] nodeKeyProperties cleaned up: $before -> $($ext.nodeKeyProperties.Count)"
if ($ext.relationshipKeyProperties -and $ext.relationshipKeyProperties.Count -gt 0) {
    $ext.relationshipKeyProperties = @($ext.relationshipKeyProperties | Where-Object { -not $removedRObjRefs.Contains($_.relationship.'$ref') })
}

# Step 5c: clean up visualisation.nodes (layout positions, cosmetic)
if ($model.visualisation -and $model.visualisation.nodes) {
    $removedNodeObjIds = [System.Collections.Generic.HashSet[string]]::new([string[]]($removedNodeObjs | ForEach-Object { $_.'$id' }))
    $before = $model.visualisation.nodes.Count
    $model.visualisation.nodes = @($model.visualisation.nodes | Where-Object { -not $removedNodeObjIds.Contains($_.id) })
    Write-Output "[OK] visualisation.nodes cleaned up: $before -> $($model.visualisation.nodes.Count)"
}

# Step 5d: remove the nodeMapping for Exchange.csv
$before = $graphMapping.nodeMappings.Count
$graphMapping.nodeMappings = @($graphMapping.nodeMappings | Where-Object { -not $removedNodeObjRefs.Contains($_.node.'$ref') })
Write-Output "[OK] nodeMappings with Exchange nodes removed: $before -> $($graphMapping.nodeMappings.Count)"

# Step 5e: remove relationshipMappings -- all completely removed r:N
# PLUS the HAS_FLOW/CHARACTERIZES mappings (their r:N stays, only the mapping
# file is dropped because channel B takes over loading).
$removedMappingTables = @()
$graphMapping.relationshipMappings | ForEach-Object {
    if ($allMappingRemoveRefs.Contains($_.relationship.'$ref')) { $removedMappingTables += $_.tableName }
}
$before = $graphMapping.relationshipMappings.Count
$graphMapping.relationshipMappings = @($graphMapping.relationshipMappings | Where-Object {
    -not $allMappingRemoveRefs.Contains($_.relationship.'$ref')
})
Write-Output "[OK] relationshipMappings removed: $($removedMappingTables -join ', ') ($before -> $($graphMapping.relationshipMappings.Count))"

# ------------------------------------------------------------
# 2) New properties: Process (source, sourceDatabase, referenceYear),
#    Flow (source, sourceDatabase)
# ------------------------------------------------------------
function Add-StringProperty {
    param($NodeLabel, [string]$Token, [bool]$Nullable = $true)
    $newId = New-PropId
    $prop = [PSCustomObject]@{
        '$id' = $newId
        token = $Token
        type = [PSCustomObject]@{ type = "string" }
        nullable = $Nullable
    }
    $NodeLabel.properties = @($NodeLabel.properties) + $prop
    return $newId
}

$processLabel = $graphSchema.nodeLabels | Where-Object { $_.token -eq "Process" }
$flowLabel = $graphSchema.nodeLabels | Where-Object { $_.token -eq "Flow" }
if (-not $processLabel) { throw "nodeLabel 'Process' not found -- aborting." }
if (-not $flowLabel) { throw "nodeLabel 'Flow' not found -- aborting." }

$procSourceId = Add-StringProperty -NodeLabel $processLabel -Token "source"
$procSourceDbId = Add-StringProperty -NodeLabel $processLabel -Token "sourceDatabase"
$procRefYearId = Add-StringProperty -NodeLabel $processLabel -Token "referenceYear"
Write-Output "[OK] Process: 3 new properties ($procSourceId, $procSourceDbId, $procRefYearId)"

$flowSourceId = Add-StringProperty -NodeLabel $flowLabel -Token "source"
$flowSourceDbId = Add-StringProperty -NodeLabel $flowLabel -Token "sourceDatabase"
Write-Output "[OK] Flow: 2 new properties ($flowSourceId, $flowSourceDbId)"

# Add property mappings to the existing Process/Flow nodeMappings
function Add-PropertyMapping {
    param($NodeMapping, [string]$PropId, [string]$FieldName)
    $pm = [PSCustomObject]@{
        property = [PSCustomObject]@{ '$ref' = "#$PropId" }
        fieldName = $FieldName
    }
    $NodeMapping.propertyMappings = @($NodeMapping.propertyMappings) + $pm
}

$processMapping = $graphMapping.nodeMappings | Where-Object { $_.tableName -eq "Process.csv" }
$flowMapping = $graphMapping.nodeMappings | Where-Object { $_.tableName -eq "Flow.csv" }
if (-not $processMapping) { throw "nodeMapping for Process.csv not found -- aborting." }
if (-not $flowMapping) { throw "nodeMapping for Flow.csv not found -- aborting." }

Add-PropertyMapping -NodeMapping $processMapping -PropId $procSourceId -FieldName "source"
Add-PropertyMapping -NodeMapping $processMapping -PropId $procSourceDbId -FieldName "sourceDatabase"
Add-PropertyMapping -NodeMapping $processMapping -PropId $procRefYearId -FieldName "referenceYear"
Add-PropertyMapping -NodeMapping $flowMapping -PropId $flowSourceId -FieldName "source"
Add-PropertyMapping -NodeMapping $flowMapping -PropId $flowSourceDbId -FieldName "sourceDatabase"
Write-Output "[OK] propertyMappings for Process.csv (+3) and Flow.csv (+2) added."

# ------------------------------------------------------------
# 3) clean up dataSourceSchema.tableSchemas
# ------------------------------------------------------------
$tableSchemas = $model.dataModel.graphMappingRepresentation.dataSourceSchema.tableSchemas
$removedTableNames = [System.Collections.Generic.HashSet[string]]::new([string[]](@("Exchange.csv") + $removedMappingTables))
$before = $tableSchemas.Count
$tableSchemas = @($tableSchemas | Where-Object { -not $removedTableNames.Contains($_.name) })
Write-Output "[OK] tableSchemas cleaned up (removed: $($removedTableNames -join ', ')): $before -> $($tableSchemas.Count)"

function Add-FieldSchema {
    param($TableSchema, [string]$Name, [string]$Sample)
    $f = [PSCustomObject]@{
        name = $Name; sample = $Sample
        recommendedType = [PSCustomObject]@{ type = "string" }
    }
    $TableSchema.fields = @($TableSchema.fields) + $f
}
$procTs = $tableSchemas | Where-Object { $_.name -eq "Process.csv" }
$flowTs = $tableSchemas | Where-Object { $_.name -eq "Flow.csv" }
if ($procTs) {
    Add-FieldSchema -TableSchema $procTs -Name "source" -Sample "Sphera"
    Add-FieldSchema -TableSchema $procTs -Name "sourceDatabase" -Sample "Sphera Managed LCA Content (MLC)"
    Add-FieldSchema -TableSchema $procTs -Name "referenceYear" -Sample "2024"
}
if ($flowTs) {
    Add-FieldSchema -TableSchema $flowTs -Name "source" -Sample "Sphera"
    Add-FieldSchema -TableSchema $flowTs -Name "sourceDatabase" -Sample "Sphera Managed LCA Content (MLC)"
}
$model.dataModel.graphMappingRepresentation.dataSourceSchema.tableSchemas = $tableSchemas
Write-Output "[OK] Process.csv/Flow.csv field schema extended."

# ------------------------------------------------------------
# 4) Fix the legacy Exchange regression: DERIVED_FROM (ImpactResult->Exchange,
#    166 real rows) and HAS_DATA (Exchange->DataItem, 1 row) refer to
#    Exchange as target/source -- without a replacement they would have been silently
#    lost when Exchange was removed. Since a relationship cannot be the
#    target of another, both are redirected to the respective FLOW node
#    (see fix_legacy_exchange.ps1), with the original
#    Exchange id as a new exchangeId property (the precision "from which
#    Exchange" is preserved without restoring the node).
#    Both pairings are unique on (from,to) -- a normal Data Importer
#    import (channel A) is unproblematic here, not a channel B case.
# ------------------------------------------------------------
function Find-NodeObjByLabel {
    param([string]$Token)
    $lbl = $graphSchema.nodeLabels | Where-Object { $_.token -eq $Token }
    if (-not $lbl) { throw "nodeLabel '$Token' not found." }
    $lblRef = "#$($lbl.'$id')"
    $obj = $graphSchema.nodeObjectTypes | Where-Object { ($_.labels | ForEach-Object { $_.'$ref' }) -contains $lblRef }
    if (-not $obj) { throw "nodeObjectType for '$Token' not found." }
    return $obj
}
$impactResultNodeObj = Find-NodeObjByLabel -Token "ImpactResult"
$flowNodeObj = Find-NodeObjByLabel -Token "Flow"
$dataItemNodeObj = Find-NodeObjByLabel -Token "DataItem"

$maxR = ([regex]::Matches($raw, '"\$id":\s*"r:(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
$maxRt = ([regex]::Matches($raw, '"\$id":\s*"rt:(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
$maxRp = ([regex]::Matches($raw, '"\$id":\s*"rp:(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
$nextR = $maxR + 1; $nextRt = $maxRt + 1; $nextRp = $maxRp + 1
function New-RId  { $v = "r:$script:nextR";  $script:nextR++;  return $v }
function New-RtId { $v = "rt:$script:nextRt"; $script:nextRt++; return $v }
function New-RpId { $v = "rp:$script:nextRp"; $script:nextRp++; return $v }

# --- 4a) Recreate DERIVED_FROM: ImpactResult -> Flow, properties: contribution + exchangeId ---
$dfRtId = New-RtId
$dfContribId = New-RpId
$dfExchangeIdId = New-RpId
$derivedFromType = [PSCustomObject]@{
    '$id' = $dfRtId
    token = "DERIVED_FROM"
    properties = @(
        [PSCustomObject]@{ '$id' = $dfContribId; token = "contribution"; type = [PSCustomObject]@{ type = "float" }; nullable = $true },
        [PSCustomObject]@{ '$id' = $dfExchangeIdId; token = "exchangeId"; type = [PSCustomObject]@{ type = "string" }; nullable = $true }
    )
}
$graphSchema.relationshipTypes = @($graphSchema.relationshipTypes) + $derivedFromType
$dfRId = New-RId
$derivedFromRObj = [PSCustomObject]@{
    '$id' = $dfRId
    type = [PSCustomObject]@{ '$ref' = "#$dfRtId" }
    from = [PSCustomObject]@{ '$ref' = "#$($impactResultNodeObj.'$id')" }
    to = [PSCustomObject]@{ '$ref' = "#$($flowNodeObj.'$id')" }
}
$graphSchema.relationshipObjectTypes = @($graphSchema.relationshipObjectTypes) + $derivedFromRObj
Write-Output "[OK] DERIVED_FROM recreated: type=$dfRtId, relationshipObjectType=$dfRId (ImpactResult->Flow), properties contribution=$dfContribId, exchangeId=$dfExchangeIdId"

$derivedFromMapping = [PSCustomObject]@{
    relationship = [PSCustomObject]@{ '$ref' = "#$dfRId" }
    tableName = "r_5_DERIVED_FROM_ImpactResult_TO_Flow.csv"
    propertyMappings = @(
        [PSCustomObject]@{ property = [PSCustomObject]@{ '$ref' = "#$dfExchangeIdId" }; fieldName = "exchangeId" },
        [PSCustomObject]@{ property = [PSCustomObject]@{ '$ref' = "#$dfContribId" }; fieldName = "contribution" }
    )
    fromMappings = [PSCustomObject]@{}
    toMappings = [PSCustomObject]@{}
}
# fromMappings/toMappings reference the respective ID property of the node
# (same pattern as for HAS_FLOW/CHARACTERIZES: "#p:<idProperty>": "csv_column")
$processIdProp = ($graphMapping.nodeMappings | Where-Object { $_.tableName -eq "Process.csv" }).propertyMappings | Where-Object { $_.fieldName -eq "id" } | Select-Object -First 1
$impactResultMapping = $graphMapping.nodeMappings | Where-Object { $_.tableName -eq "ImpactResult.csv" }
$impactResultIdProp = $impactResultMapping.propertyMappings | Where-Object { $_.fieldName -eq "id" } | Select-Object -First 1
$flowIdProp = $flowMapping.propertyMappings | Where-Object { $_.fieldName -eq "id" } | Select-Object -First 1
$dataItemMapping = $graphMapping.nodeMappings | Where-Object { $_.tableName -eq "DataItem.csv" }
$dataItemIdProp = $dataItemMapping.propertyMappings | Where-Object { $_.fieldName -eq "id" } | Select-Object -First 1

$derivedFromMapping.fromMappings = [PSCustomObject]@{ ($impactResultIdProp.property.'$ref') = "from_id" }
$derivedFromMapping.toMappings = [PSCustomObject]@{ ($flowIdProp.property.'$ref') = "to_id" }
$graphMapping.relationshipMappings = @($graphMapping.relationshipMappings) + $derivedFromMapping
Write-Output "[OK] relationshipMapping for DERIVED_FROM (ImpactResult->Flow) added."

# --- 4b) HAS_DATA: new label pair Flow -> DataItem ---
# IMPORTANT: do NOT set a new property on the SHARED HAS_DATA type. HAS_DATA
# is used by several label pairs (Material->DataItem, Process->DataItem,
# ...); a property belongs to the TYPE, not to the individual pairing -- the Data
# Importer then demands a field for it in EVERY mapping of that type ("Must
# be specified"), also for the existing pairings that do not have this column
# at all. That is exactly what broke the model on the first attempt
# (confirmed in the UI: role/exchangeId on Material->DataItem).
# Fix: map only "role" (like all the other HAS_DATA pairings). The
# exchangeId stays in the CSV as a column (human-readable),
# but is deliberately not mapped into the schema/graph.
$hasDataType = $graphSchema.relationshipTypes | Where-Object { $_.token -eq "HAS_DATA" }
if (-not $hasDataType) { throw "relationshipType 'HAS_DATA' not found -- aborting." }

$hdRId = New-RId
$hasDataFlowRObj = [PSCustomObject]@{
    '$id' = $hdRId
    type = [PSCustomObject]@{ '$ref' = "#$($hasDataType.'$id')" }
    from = [PSCustomObject]@{ '$ref' = "#$($flowNodeObj.'$id')" }
    to = [PSCustomObject]@{ '$ref' = "#$($dataItemNodeObj.'$id')" }
}
$graphSchema.relationshipObjectTypes = @($graphSchema.relationshipObjectTypes) + $hasDataFlowRObj
Write-Output "[OK] HAS_DATA new label pair Flow->DataItem: relationshipObjectType=$hdRId (no new property on the shared type)"

$hasDataMapping = [PSCustomObject]@{
    relationship = [PSCustomObject]@{ '$ref' = "#$hdRId" }
    tableName = "r_15b_HAS_DATA_Flow_TO_DataItem.csv"
    propertyMappings = @(
        [PSCustomObject]@{ property = [PSCustomObject]@{ '$ref' = "#$(($hasDataType.properties | Where-Object { $_.token -eq "role" } | Select-Object -First 1).'$id')" }; fieldName = "role" }
    )
    fromMappings = [PSCustomObject]@{ ($flowIdProp.property.'$ref') = "from_id" }
    toMappings = [PSCustomObject]@{ ($dataItemIdProp.property.'$ref') = "to_id" }
}
$graphMapping.relationshipMappings = @($graphMapping.relationshipMappings) + $hasDataMapping
Write-Output "[OK] relationshipMapping for HAS_DATA (Flow->DataItem, role only) added."

# --- 4c) add tableSchemas for the two new CSVs ---
$dfTableSchema = [PSCustomObject]@{
    name = "r_5_DERIVED_FROM_ImpactResult_TO_Flow.csv"; expanded = $true
    fields = @(
        [PSCustomObject]@{ name = "from_id"; sample = "RES_CUSTOM_CC"; recommendedType = [PSCustomObject]@{ type = "string" } },
        [PSCustomObject]@{ name = "to_id"; sample = "FLOW_PA12"; recommendedType = [PSCustomObject]@{ type = "string" } },
        [PSCustomObject]@{ name = "exchangeId"; sample = "EX_PROC_MJF_FLOW_PA12_IN"; recommendedType = [PSCustomObject]@{ type = "string" } },
        [PSCustomObject]@{ name = "contribution"; sample = ""; recommendedType = [PSCustomObject]@{ type = "string" } }
    )
}
$hdTableSchema = [PSCustomObject]@{
    name = "r_15b_HAS_DATA_Flow_TO_DataItem.csv"; expanded = $true
    fields = @(
        [PSCustomObject]@{ name = "from_id"; sample = "FLOW_ELECTRICITY"; recommendedType = [PSCustomObject]@{ type = "string" } },
        [PSCustomObject]@{ name = "to_id"; sample = "DATA_0019"; recommendedType = [PSCustomObject]@{ type = "string" } },
        [PSCustomObject]@{ name = "exchangeId"; sample = "EX_PROC_MJF_FLOW_ELEC_IN"; recommendedType = [PSCustomObject]@{ type = "string" } },
        [PSCustomObject]@{ name = "role"; sample = "assessment-relevant value"; recommendedType = [PSCustomObject]@{ type = "string" } }
    )
}
$tableSchemas = @($tableSchemas) + $dfTableSchema + $hdTableSchema
$model.dataModel.graphMappingRepresentation.dataSourceSchema.tableSchemas = $tableSchemas
Write-Output "[OK] tableSchemas for the 2 new CSVs added."

# ------------------------------------------------------------
# Write (without BOM)
# ------------------------------------------------------------
$outJsonText = $model | ConvertTo-Json -Depth 100
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutJson, $outJsonText, $utf8NoBom)
Write-Output ""
Write-Output "Written: $OutJson"
