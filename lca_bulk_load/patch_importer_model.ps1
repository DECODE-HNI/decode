<#
============================================================
patch_importer_model.ps1  (Phase 3)

Klont die bestehende neo4j_importer_model.json und wendet gezielte Deltas an
(kein Neuaufbau von Grund auf -- das interne $ref/#p:N/#nl:N/#r:N-Nummerierungs-
schema ist ein nicht dokumentiertes Tool-internes Format, ein Delta-Patch auf
Basis von Inhalts-Matching (token/name) ist risikoaermer als ein Rebuild).

Aenderungen:
1. Entfernt vollstaendig: nodeLabel "Exchange", relationshipTypes
   "HAS_EXCHANGE" und "REFERS_TO_FLOW" (samt ihrer Properties), sowie die
   zugehoerigen node-/relationshipMappings.
2. Entfernt HAS_FLOW und CHARACTERIZES VOLLSTAENDIG aus dem Kanal-A-Schema
   (Typ + relationshipObjectType + Mapping) -- Kanal B (Python/Bolt)
   uebernimmt deren Laden, da der Data Importer Parallel-Kanten zwischen
   gleichen Knoten strukturell nicht korrekt mergen kann. URSPRUENGLICH war
   geplant, die Typ-Definition als reine Dokumentation ohne Mapping im
   Schema zu belassen -- das schlaegt fehl: der Data Importer laedt ein
   Modell nur, wenn JEDER deklarierte relationshipType eine vollstaendige,
   gemappte CSV hat ("Your data model has errors", vom Nutzer per Screenshot
   bestaetigt). Daher jetzt vollstaendige Entfernung, keine Doku im Schema.
3. Ergaenzt neue Properties: Process.source/sourceDatabase/referenceYear,
   Flow.source/sourceDatabase -- inkl. propertyMappings in den bestehenden
   Process-/Flow-nodeMappings (liest die neuen Spalten aus den gemergten
   CSVs).
4. Bereinigt dataSourceSchema.tableSchemas: entfernt Eintraege fuer
   entfallene CSVs, ergaenzt neue Felder fuer Process.csv/Flow.csv.

WICHTIGE LEKTION (2. gescheiterter Versuch): eine neue Property auf einen
GETEILTEN relationshipType (z.B. HAS_DATA, von mehreren Label-Paaren genutzt)
zu setzen, bricht ALLE anderen Mappings dieses Typs, die die Spalte nicht
haben ("Must be specified"). Neue relationship-spezifische Properties nur
auf frisch angelegte, alleinig genutzte Typen setzen (z.B. DERIVED_FROM),
niemals auf geteilte Typen.

NICHT enthalten (bewusste Scope-Entscheidung, siehe Statusbericht): neue
DataSource-Knoten + FROM_SOURCE-Relationship fuer Sphera/IDEMAT-Provenienz.
Die Process/Flow-Properties source/sourceDatabase erfuellen die Provenienz-
Anforderung bereits (Abschnitt 14 der urspruenglichen Spezifikation nennt
Properties UND/ODER DataSource-Strukturen als gleichwertige Optionen).
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
# Hilfsfunktion: naechste freie p:N-ID ermitteln (max aktuell verwendeter + 1)
# ------------------------------------------------------------
$maxP = ([regex]::Matches($raw, '"\$id":\s*"p:(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
$nextP = $maxP + 1
function New-PropId { param() $script:id = "p:$script:nextP"; $script:nextP++; return $script:id }

$graphSchema = $model.dataModel.graphSchemaRepresentation.graphSchema
$graphMapping = $model.dataModel.graphMappingRepresentation

# ------------------------------------------------------------
# 1) Exchange vollstaendig entfernen -- als Graph-Traversal, nicht als Liste
#    hart codierter Token. Grund: Exchange ist nicht nur ueber HAS_EXCHANGE/
#    REFERS_TO_FLOW verbunden, sondern taucht als Endpunkt AUCH bei
#    wiederverwendeten Relationship-Typen auf (HAS_DATA: Exchange->DataItem,
#    DERIVED_FROM: ImpactResult->Exchange -- beide erst durch Nachschauen im
#    JSON gefunden, ein Token-basierter Ansatz haette sie uebersehen). Daher:
#    1. nodeLabel Exchange (nl:N) entfernen
#    2. alle nodeObjectTypes (n:N), deren labels NUR auf Exchange verweisen,
#       entfernen
#    3. alle relationshipObjectTypes (r:N), deren from/to auf ein entferntes
#       n:N verweisen, entfernen
#    4. relationshipTypes (rt:N), die dadurch KEINE verbleibende
#       relationshipObjectType-Nutzung mehr haben, ebenfalls entfernen (z.B.
#       DERIVED_FROM war nur fuer Exchange da -> weg; HAS_DATA hat 4 weitere
#       Nutzungen -> bleibt)
#    5. abhaengige Eintraege bereinigen: constraints, nodeKeyProperties,
#       relationshipKeyProperties, visualisation.nodes, nodeMappings,
#       relationshipMappings
# ------------------------------------------------------------
$exchangeLabel = $graphSchema.nodeLabels | Where-Object { $_.token -eq "Exchange" }
if (-not $exchangeLabel) { throw "nodeLabel 'Exchange' nicht gefunden -- Abbruch (Skript setzt sein Vorhandensein voraus)." }
$exchangeLabelId = $exchangeLabel.'$id'
$exchangeLabelRef = "#$exchangeLabelId"
$graphSchema.nodeLabels = @($graphSchema.nodeLabels | Where-Object { $_.token -ne "Exchange" })
Write-Output "[OK] nodeLabel 'Exchange' ($exchangeLabelId) entfernt ($($exchangeLabel.properties.Count) Properties mitentfernt)."

# Schritt 2: nodeObjectTypes mit AUSSCHLIESSLICH Exchange-Label entfernen
$removedNodeObjs = $graphSchema.nodeObjectTypes | Where-Object {
    (($_.labels | ForEach-Object { $_.'$ref' }) -contains $exchangeLabelRef) -and $_.labels.Count -eq 1
}
$removedNodeObjRefs = [System.Collections.Generic.HashSet[string]]::new([string[]]($removedNodeObjs | ForEach-Object { "#$($_.'$id')" }))
$before = $graphSchema.nodeObjectTypes.Count
$graphSchema.nodeObjectTypes = @($graphSchema.nodeObjectTypes | Where-Object { -not $removedNodeObjRefs.Contains("#$($_.'$id')") })
Write-Output "[OK] nodeObjectTypes entfernt: $(($removedNodeObjs | ForEach-Object { $_.'$id' }) -join ', ') ($before -> $($graphSchema.nodeObjectTypes.Count))"

# Schritt 3: relationshipObjectTypes mit from/to auf ein entferntes n:N entfernen
$exchangeRelatedRObjs = $graphSchema.relationshipObjectTypes | Where-Object {
    $removedNodeObjRefs.Contains($_.from.'$ref') -or $removedNodeObjRefs.Contains($_.to.'$ref')
}
# HAS_FLOW/CHARACTERIZES: der Data Importer laedt ein Modell nur, wenn JEDER
# deklarierte relationshipType eine vollstaendige, aktive Mapping-Datei hat --
# ein "Dokumentation ohne Mapping"-Zustand (urspruenglicher Ansatz) wird als
# Modellfehler abgelehnt ("Your data model has errors", vom Nutzer per
# Screenshot bestaetigt: HAS_DATA/CHARACTERIZES/HAS_FLOW zeigten alle Fehler).
# Deshalb werden HAS_FLOW/CHARACTERIZES jetzt VOLLSTAENDIG aus dem Kanal-A-
# Schema entfernt (wie HAS_EXCHANGE/REFERS_TO_FLOW) -- Kanal B bleibt die
# alleinige Quelle fuer diese Daten, nur eben ohne Schema-Presenz in Kanal A.
$hasFlowRt = $graphSchema.relationshipTypes | Where-Object { $_.token -eq "HAS_FLOW" }
$characterizesRt = $graphSchema.relationshipTypes | Where-Object { $_.token -eq "CHARACTERIZES" }
$hfCfRtRefs = [System.Collections.Generic.HashSet[string]]::new([string[]](@($hasFlowRt, $characterizesRt) | Where-Object { $_ } | ForEach-Object { "#$($_.'$id')" }))
$hfCfRObjs = $graphSchema.relationshipObjectTypes | Where-Object { $hfCfRtRefs.Contains($_.type.'$ref') }

$removedRObjs = @($exchangeRelatedRObjs) + @($hfCfRObjs)
$removedRObjRefs = [System.Collections.Generic.HashSet[string]]::new([string[]]($removedRObjs | ForEach-Object { "#$($_.'$id')" }))
$allMappingRemoveRefs = $removedRObjRefs

Write-Output "[INFO] relationshipObjectTypes komplett entfernt (Exchange-Endpunkt): $(($exchangeRelatedRObjs | ForEach-Object { "$($_.'$id')(type=$($_.type.'$ref'))" }) -join ', ')"
Write-Output "[INFO] relationshipObjectTypes komplett entfernt (HAS_FLOW/CHARACTERIZES, Kanal B uebernimmt): $(($hfCfRObjs | ForEach-Object { $_.'$id' }) -join ', ')"

$before = $graphSchema.relationshipObjectTypes.Count
$graphSchema.relationshipObjectTypes = @($graphSchema.relationshipObjectTypes | Where-Object { -not $removedRObjRefs.Contains("#$($_.'$id')") })
Write-Output "[OK] relationshipObjectTypes entfernt: $before -> $($graphSchema.relationshipObjectTypes.Count)"

# Schritt 4: relationshipTypes ohne verbleibende relationshipObjectType-Nutzung entfernen
$remainingTypeRefs = [System.Collections.Generic.HashSet[string]]::new([string[]]($graphSchema.relationshipObjectTypes | ForEach-Object { $_.type.'$ref' }))
$candidateRtIds = ($removedRObjs | ForEach-Object { $_.type.'$ref' }) | Sort-Object -Unique
$orphanedRt = $candidateRtIds | Where-Object { -not $remainingTypeRefs.Contains($_) }
$orphanedTokens = $graphSchema.relationshipTypes | Where-Object { $orphanedRt -contains "#$($_.'$id')" } | ForEach-Object { $_.token }
Write-Output "[INFO] Dadurch verwaiste relationshipTypes (keine Nutzung mehr): $($orphanedTokens -join ', ')"
$before = $graphSchema.relationshipTypes.Count
$graphSchema.relationshipTypes = @($graphSchema.relationshipTypes | Where-Object { -not ($orphanedRt -contains "#$($_.'$id')") })
Write-Output "[OK] relationshipTypes entfernt: $before -> $($graphSchema.relationshipTypes.Count)"

# Schritt 5a: constraints auf Exchange entfernen
$graphSchema.constraints = @($graphSchema.constraints | Where-Object { $_.nodeLabel.'$ref' -ne $exchangeLabelRef })
Write-Output "[OK] constraints bereinigt (Exchange_id_unique entfernt falls vorhanden)."

# Schritt 5b: nodeKeyProperties / relationshipKeyProperties bereinigen
$ext = $model.dataModel.graphSchemaExtensionsRepresentation
$before = $ext.nodeKeyProperties.Count
$ext.nodeKeyProperties = @($ext.nodeKeyProperties | Where-Object { -not $removedNodeObjRefs.Contains($_.node.'$ref') })
Write-Output "[OK] nodeKeyProperties bereinigt: $before -> $($ext.nodeKeyProperties.Count)"
if ($ext.relationshipKeyProperties -and $ext.relationshipKeyProperties.Count -gt 0) {
    $ext.relationshipKeyProperties = @($ext.relationshipKeyProperties | Where-Object { -not $removedRObjRefs.Contains($_.relationship.'$ref') })
}

# Schritt 5c: visualisation.nodes (Layout-Positionen, kosmetisch) bereinigen
if ($model.visualisation -and $model.visualisation.nodes) {
    $removedNodeObjIds = [System.Collections.Generic.HashSet[string]]::new([string[]]($removedNodeObjs | ForEach-Object { $_.'$id' }))
    $before = $model.visualisation.nodes.Count
    $model.visualisation.nodes = @($model.visualisation.nodes | Where-Object { -not $removedNodeObjIds.Contains($_.id) })
    Write-Output "[OK] visualisation.nodes bereinigt: $before -> $($model.visualisation.nodes.Count)"
}

# Schritt 5d: nodeMapping fuer Exchange.csv entfernen
$before = $graphMapping.nodeMappings.Count
$graphMapping.nodeMappings = @($graphMapping.nodeMappings | Where-Object { -not $removedNodeObjRefs.Contains($_.node.'$ref') })
Write-Output "[OK] nodeMappings mit Exchange-Knoten entfernt: $before -> $($graphMapping.nodeMappings.Count)"

# Schritt 5e: relationshipMappings entfernen -- alle komplett entfernten r:N
# PLUS die HAS_FLOW/CHARACTERIZES-Mappings (deren r:N bleibt, nur die Mapping-
# Datei entfaellt, da Kanal B das Laden uebernimmt).
$removedMappingTables = @()
$graphMapping.relationshipMappings | ForEach-Object {
    if ($allMappingRemoveRefs.Contains($_.relationship.'$ref')) { $removedMappingTables += $_.tableName }
}
$before = $graphMapping.relationshipMappings.Count
$graphMapping.relationshipMappings = @($graphMapping.relationshipMappings | Where-Object {
    -not $allMappingRemoveRefs.Contains($_.relationship.'$ref')
})
Write-Output "[OK] relationshipMappings entfernt: $($removedMappingTables -join ', ') ($before -> $($graphMapping.relationshipMappings.Count))"

# ------------------------------------------------------------
# 2) Neue Properties: Process (source, sourceDatabase, referenceYear),
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
if (-not $processLabel) { throw "nodeLabel 'Process' nicht gefunden -- Abbruch." }
if (-not $flowLabel) { throw "nodeLabel 'Flow' nicht gefunden -- Abbruch." }

$procSourceId = Add-StringProperty -NodeLabel $processLabel -Token "source"
$procSourceDbId = Add-StringProperty -NodeLabel $processLabel -Token "sourceDatabase"
$procRefYearId = Add-StringProperty -NodeLabel $processLabel -Token "referenceYear"
Write-Output "[OK] Process: 3 neue Properties ($procSourceId, $procSourceDbId, $procRefYearId)"

$flowSourceId = Add-StringProperty -NodeLabel $flowLabel -Token "source"
$flowSourceDbId = Add-StringProperty -NodeLabel $flowLabel -Token "sourceDatabase"
Write-Output "[OK] Flow: 2 neue Properties ($flowSourceId, $flowSourceDbId)"

# Property-Mappings in den bestehenden Process-/Flow-nodeMappings ergaenzen
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
if (-not $processMapping) { throw "nodeMapping fuer Process.csv nicht gefunden -- Abbruch." }
if (-not $flowMapping) { throw "nodeMapping fuer Flow.csv nicht gefunden -- Abbruch." }

Add-PropertyMapping -NodeMapping $processMapping -PropId $procSourceId -FieldName "source"
Add-PropertyMapping -NodeMapping $processMapping -PropId $procSourceDbId -FieldName "sourceDatabase"
Add-PropertyMapping -NodeMapping $processMapping -PropId $procRefYearId -FieldName "referenceYear"
Add-PropertyMapping -NodeMapping $flowMapping -PropId $flowSourceId -FieldName "source"
Add-PropertyMapping -NodeMapping $flowMapping -PropId $flowSourceDbId -FieldName "sourceDatabase"
Write-Output "[OK] propertyMappings fuer Process.csv (+3) und Flow.csv (+2) ergaenzt."

# ------------------------------------------------------------
# 3) dataSourceSchema.tableSchemas bereinigen
# ------------------------------------------------------------
$tableSchemas = $model.dataModel.graphMappingRepresentation.dataSourceSchema.tableSchemas
$removedTableNames = [System.Collections.Generic.HashSet[string]]::new([string[]](@("Exchange.csv") + $removedMappingTables))
$before = $tableSchemas.Count
$tableSchemas = @($tableSchemas | Where-Object { -not $removedTableNames.Contains($_.name) })
Write-Output "[OK] tableSchemas bereinigt (entfernt: $($removedTableNames -join ', ')): $before -> $($tableSchemas.Count)"

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
Write-Output "[OK] Process.csv/Flow.csv Feldschema ergaenzt."

# ------------------------------------------------------------
# 4) Legacy-Exchange-Regression beheben: DERIVED_FROM (ImpactResult->Exchange,
#    166 echte Zeilen) und HAS_DATA (Exchange->DataItem, 1 Zeile) verweisen auf
#    Exchange als Ziel/Quelle -- ohne Ersatz waeren diese beim Entfernen von
#    Exchange stillschweigend verloren gegangen. Da eine Relationship kein
#    Ziel einer anderen sein kann, werden beide auf den jeweiligen FLOW-Knoten
#    umgebogen (siehe fix_legacy_exchange.ps1), mit der urspruenglichen
#    Exchange-ID als neue exchangeId-Property (Praezision "von welchem
#    Exchange" bleibt erhalten, ohne den Knoten wiederherzustellen).
#    Beide Paarungen sind eindeutig auf (from,to) -- normaler Data-Importer-
#    Import (Kanal A) ist hier unproblematisch, kein Kanal-B-Fall.
# ------------------------------------------------------------
function Find-NodeObjByLabel {
    param([string]$Token)
    $lbl = $graphSchema.nodeLabels | Where-Object { $_.token -eq $Token }
    if (-not $lbl) { throw "nodeLabel '$Token' nicht gefunden." }
    $lblRef = "#$($lbl.'$id')"
    $obj = $graphSchema.nodeObjectTypes | Where-Object { ($_.labels | ForEach-Object { $_.'$ref' }) -contains $lblRef }
    if (-not $obj) { throw "nodeObjectType fuer '$Token' nicht gefunden." }
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

# --- 4a) DERIVED_FROM neu anlegen: ImpactResult -> Flow, Properties: contribution + exchangeId ---
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
Write-Output "[OK] DERIVED_FROM neu angelegt: type=$dfRtId, relationshipObjectType=$dfRId (ImpactResult->Flow), Properties contribution=$dfContribId, exchangeId=$dfExchangeIdId"

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
# fromMappings/toMappings referenzieren die jeweilige ID-Property des Knotens
# (gleiches Muster wie bei HAS_FLOW/CHARACTERIZES: "#p:<idProperty>": "csv_spalte")
$processIdProp = ($graphMapping.nodeMappings | Where-Object { $_.tableName -eq "Process.csv" }).propertyMappings | Where-Object { $_.fieldName -eq "id" } | Select-Object -First 1
$impactResultMapping = $graphMapping.nodeMappings | Where-Object { $_.tableName -eq "ImpactResult.csv" }
$impactResultIdProp = $impactResultMapping.propertyMappings | Where-Object { $_.fieldName -eq "id" } | Select-Object -First 1
$flowIdProp = $flowMapping.propertyMappings | Where-Object { $_.fieldName -eq "id" } | Select-Object -First 1
$dataItemMapping = $graphMapping.nodeMappings | Where-Object { $_.tableName -eq "DataItem.csv" }
$dataItemIdProp = $dataItemMapping.propertyMappings | Where-Object { $_.fieldName -eq "id" } | Select-Object -First 1

$derivedFromMapping.fromMappings = [PSCustomObject]@{ ($impactResultIdProp.property.'$ref') = "from_id" }
$derivedFromMapping.toMappings = [PSCustomObject]@{ ($flowIdProp.property.'$ref') = "to_id" }
$graphMapping.relationshipMappings = @($graphMapping.relationshipMappings) + $derivedFromMapping
Write-Output "[OK] relationshipMapping fuer DERIVED_FROM (ImpactResult->Flow) ergaenzt."

# --- 4b) HAS_DATA: neues Label-Paar Flow -> DataItem ---
# WICHTIG: KEINE neue Property auf den GETEILTEN HAS_DATA-Typ setzen. HAS_DATA
# wird von mehreren Label-Paaren genutzt (Material->DataItem, Process->DataItem,
# ...); eine Property gehoert zum TYP, nicht zur einzelnen Paarung -- der Data
# Importer verlangt dann fuer JEDES Mapping dieses Typs ein Feld dafuer ("Must
# be specified"), auch fuer die bestehenden Paarungen, die diese Spalte gar
# nicht haben. Genau das hat das Modell beim ersten Versuch zerschossen (vom
# Nutzer per Screenshot bestaetigt: role/exchangeId auf Material->DataItem).
# Fix: nur "role" mappen (wie alle anderen HAS_DATA-Paarungen auch). Die
# exchangeId bleibt als Spalte in der CSV erhalten (menschlich nachvollziehbar),
# wird aber bewusst nicht ins Schema/den Graphen gemappt.
$hasDataType = $graphSchema.relationshipTypes | Where-Object { $_.token -eq "HAS_DATA" }
if (-not $hasDataType) { throw "relationshipType 'HAS_DATA' nicht gefunden -- Abbruch." }

$hdRId = New-RId
$hasDataFlowRObj = [PSCustomObject]@{
    '$id' = $hdRId
    type = [PSCustomObject]@{ '$ref' = "#$($hasDataType.'$id')" }
    from = [PSCustomObject]@{ '$ref' = "#$($flowNodeObj.'$id')" }
    to = [PSCustomObject]@{ '$ref' = "#$($dataItemNodeObj.'$id')" }
}
$graphSchema.relationshipObjectTypes = @($graphSchema.relationshipObjectTypes) + $hasDataFlowRObj
Write-Output "[OK] HAS_DATA neues Label-Paar Flow->DataItem: relationshipObjectType=$hdRId (keine neue Property auf dem geteilten Typ)"

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
Write-Output "[OK] relationshipMapping fuer HAS_DATA (Flow->DataItem, nur role) ergaenzt."

# --- 4c) tableSchemas fuer die zwei neuen CSVs ergaenzen ---
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
Write-Output "[OK] tableSchemas fuer die 2 neuen CSVs ergaenzt."

# ------------------------------------------------------------
# Schreiben (BOM-frei)
# ------------------------------------------------------------
$outJsonText = $model | ConvertTo-Json -Depth 100
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutJson, $outJsonText, $utf8NoBom)
Write-Output ""
Write-Output "Geschrieben: $OutJson"
