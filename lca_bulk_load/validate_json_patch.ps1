param(
    [string] $JsonPath = "./ned2_gripper_full_model_neo4j/neo4j_importer_model.json"
)
$ErrorActionPreference = "Stop"

$raw = Get-Content $JsonPath -Raw
$model = $raw | ConvertFrom-Json
Write-Output "[OK] JSON parst fehlerfrei."

# --- Alle $id einsammeln ---
$allIds = [System.Collections.Generic.HashSet[string]]::new()
[regex]::Matches($raw, '"\$id":\s*"([^"]+)"') | ForEach-Object { $allIds.Add($_.Groups[1].Value) | Out-Null }
Write-Output "[INFO] $($allIds.Count) eindeutige \$id-Werte gefunden."

# --- NEU: $ref-Werte OHNE fuehrendes '#' aufspueren -- das ist selbst schon
# ungueltig (Data Importer erwartet immer "#prefix:N"), wird aber vom
# normalen \$ref-Regex (das '#' verlangt) niemals als \$ref erkannt und
# daher NIE als haengender Verweis gemeldet. Genau dieser Bug ist einmal
# durchgerutscht (rp:31 statt #rp:31) und wurde erst vom Data Importer selbst
# gemeldet -- dieser Check schliesst die Luecke.
$malformedRefs = [regex]::Matches($raw, '"\$ref":\s*"([^"#][^"]*)"')
if ($malformedRefs.Count -gt 0) {
    Write-Output "[FEHLER] $($malformedRefs.Count) \$ref-Werte OHNE fuehrendes '#' gefunden (ungueltig):"
    $malformedRefs | ForEach-Object { Write-Output "  - $($_.Groups[1].Value)" }
} else {
    Write-Output "[OK] Keine \$ref-Werte ohne fuehrendes '#'."
}

# --- Alle $ref einsammeln, pruefen ob jedes ein existierendes $id referenziert ---
$allRefs = [regex]::Matches($raw, '"\$ref":\s*"#([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$dangling = @()
foreach ($r in $allRefs) { if (-not $allIds.Contains($r)) { $dangling += $r } }
if ($dangling.Count -gt 0) {
    Write-Output "[FEHLER] $($dangling.Count) haengende \$ref-Verweise (Ziel-\$id existiert nicht):"
    $dangling | ForEach-Object { Write-Output "  - $_" }
} else {
    Write-Output "[OK] Keine haengenden \$ref-Verweise ($($allRefs.Count) geprueft)."
}

# --- Keine Exchange/HAS_EXCHANGE/REFERS_TO_FLOW-Reste ---
$forbidden = @("Exchange", "HAS_EXCHANGE", "REFERS_TO_FLOW")
$hits = @()
foreach ($tok in $forbidden) {
    if (([regex]::Matches($raw, [regex]::Escape('"token":  "' + $tok + '"'))).Count -gt 0) { $hits += $tok }
    if (([regex]::Matches($raw, [regex]::Escape('"tableName":  "' + $tok))).Count -gt 0) { $hits += "$tok (tableName)" }
}
if ($hits.Count -gt 0) {
    Write-Output "[FEHLER] Reste gefunden: $($hits -join ', ')"
} else {
    Write-Output "[OK] Keine Exchange/HAS_EXCHANGE/REFERS_TO_FLOW-Reste."
}

# --- Process/Flow: neue Properties vorhanden? ---
$graphSchema = $model.dataModel.graphSchemaRepresentation.graphSchema
$processLabel = $graphSchema.nodeLabels | Where-Object { $_.token -eq "Process" }
$flowLabel = $graphSchema.nodeLabels | Where-Object { $_.token -eq "Flow" }
$procTokens = $processLabel.properties.token
$flowTokens = $flowLabel.properties.token
foreach ($t in @("source","sourceDatabase","referenceYear")) {
    if ($procTokens -contains $t) { Write-Output "[OK] Process.$t vorhanden." } else { Write-Output "[FEHLER] Process.$t FEHLT." }
}
foreach ($t in @("source","sourceDatabase")) {
    if ($flowTokens -contains $t) { Write-Output "[OK] Flow.$t vorhanden." } else { Write-Output "[FEHLER] Flow.$t FEHLT." }
}

# --- HAS_FLOW/CHARACTERIZES Typ noch da, aber keine Mapping-Datei mehr ---
foreach ($tok in @("HAS_FLOW","CHARACTERIZES")) {
    $present = ($graphSchema.relationshipTypes | Where-Object { $_.token -eq $tok }) -ne $null
    Write-Output "[INFO] relationshipType '$tok' im Schema (Dokumentation) vorhanden: $present"
}
$graphMapping = $model.dataModel.graphMappingRepresentation
$mappingTables = $graphMapping.relationshipMappings.tableName
foreach ($pattern in @("HAS_FLOW","CHARACTERIZES")) {
    $stillMapped = $mappingTables | Where-Object { $_ -match $pattern -and $_ -notmatch "PROPERTY" }
    Write-Output "[INFO] verbleibende Mappings die '$pattern' matchen (sollten leer sein, ausser _PROPERTY-Varianten): $($stillMapped -join ', ')"
}

# --- Array-Kollaps-Check: kritische Arrays muessen als Array serialisiert sein ---
Write-Output ""
Write-Output "=== Array-Typ-Check (PowerShell ConvertTo-Json Kollaps-Risiko) ==="
$checks = @(
    @{ Name = "nodeLabels"; Val = $graphSchema.nodeLabels },
    @{ Name = "relationshipTypes"; Val = $graphSchema.relationshipTypes },
    @{ Name = "nodeObjectTypes"; Val = $graphSchema.nodeObjectTypes },
    @{ Name = "relationshipObjectTypes"; Val = $graphSchema.relationshipObjectTypes },
    @{ Name = "nodeMappings"; Val = $graphMapping.nodeMappings },
    @{ Name = "relationshipMappings"; Val = $graphMapping.relationshipMappings },
    @{ Name = "Process.properties"; Val = $processLabel.properties },
    @{ Name = "Flow.properties"; Val = $flowLabel.properties }
)
foreach ($c in $checks) {
    $isArray = $c.Val -is [array]
    Write-Output "$($c.Name): Count=$($c.Val.Count), IsArray=$isArray"
}

# --- NEU: Vollstaendigkeits-Check -- fuer JEDEN relationshipType muss JEDES
# seiner deklarierten Properties in JEDEM relationshipMapping, das diesen Typ
# nutzt, gemappt sein. Genau das Fehlen dieses Checks hat den zweiten
# fehlgeschlagenen Import verursacht (exchangeId auf dem geteilten HAS_DATA-
# Typ ergaenzt, aber nur in einem von mehreren Mappings tatsaechlich gemappt).
Write-Output ""
Write-Output "=== Vollstaendigkeits-Check: relationshipType-Properties vs. Mappings ==="
$rObjById = @{}
foreach ($r in $graphSchema.relationshipObjectTypes) { $rObjById["#$($r.'$id')"] = $r }
$incompleteFound = $false
foreach ($rt in $graphSchema.relationshipTypes) {
    $rtRef = "#$($rt.'$id')"
    $declaredProps = [System.Collections.Generic.HashSet[string]]::new([string[]]($rt.properties | ForEach-Object { "#$($_.'$id')" }))
    if ($declaredProps.Count -eq 0) { continue }
    $usingRObjs = $graphSchema.relationshipObjectTypes | Where-Object { $_.type.'$ref' -eq $rtRef }
    foreach ($robj in $usingRObjs) {
        $robjRef = "#$($robj.'$id')"
        $mapping = $graphMapping.relationshipMappings | Where-Object { $_.relationship.'$ref' -eq $robjRef }
        if (-not $mapping) { Write-Output "[FEHLER] $($rt.token): relationshipObjectType $($robj.'$id') hat KEIN Mapping."; $incompleteFound = $true; continue }
        $mappedProps = [System.Collections.Generic.HashSet[string]]::new([string[]]($mapping.propertyMappings | ForEach-Object { $_.property.'$ref' }))
        $missing = $declaredProps | Where-Object { -not $mappedProps.Contains($_) }
        if ($missing.Count -gt 0) {
            Write-Output "[FEHLER] $($rt.token) (Mapping $($mapping.tableName)): fehlende Property-Mappings fuer $($missing -join ', ')"
            $incompleteFound = $true
        }
    }
}
if (-not $incompleteFound) { Write-Output "[OK] Jedes relationshipType-Property ist in jedem verwendenden Mapping vollstaendig abgebildet." }

Write-Output ""
Write-Output "=== Vollstaendigkeits-Check: nodeLabel-Properties vs. Mappings ==="
$nObjById = @{}
foreach ($n in $graphSchema.nodeObjectTypes) { $nObjById["#$($n.'$id')"] = $n }
$incompleteNodeFound = $false
foreach ($nl in $graphSchema.nodeLabels) {
    $nlRef = "#$($nl.'$id')"
    $declaredProps = [System.Collections.Generic.HashSet[string]]::new([string[]]($nl.properties | ForEach-Object { "#$($_.'$id')" }))
    if ($declaredProps.Count -eq 0) { continue }
    $usingNObjs = $graphSchema.nodeObjectTypes | Where-Object { ($_.labels | ForEach-Object { $_.'$ref' }) -contains $nlRef }
    foreach ($nobj in $usingNObjs) {
        $nobjRef = "#$($nobj.'$id')"
        $mapping = $graphMapping.nodeMappings | Where-Object { $_.node.'$ref' -eq $nobjRef }
        if (-not $mapping) { Write-Output "[FEHLER] $($nl.token): nodeObjectType $($nobj.'$id') hat KEIN Mapping."; $incompleteNodeFound = $true; continue }
        $mappedProps = [System.Collections.Generic.HashSet[string]]::new([string[]]($mapping.propertyMappings | ForEach-Object { $_.property.'$ref' }))
        $missing = $declaredProps | Where-Object { -not $mappedProps.Contains($_) }
        if ($missing.Count -gt 0) {
            Write-Output "[FEHLER] $($nl.token) (Mapping $($mapping.tableName)): fehlende Property-Mappings fuer $($missing -join ', ')"
            $incompleteNodeFound = $true
        }
    }
}
if (-not $incompleteNodeFound) { Write-Output "[OK] Jedes nodeLabel-Property ist in jedem verwendenden Mapping vollstaendig abgebildet." }

Write-Output ""
Write-Output "Validierung abgeschlossen."
