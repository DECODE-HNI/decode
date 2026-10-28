param(
    [string] $JsonPath = "./ned2_gripper_full_model_neo4j/neo4j_importer_model.json"
)
$ErrorActionPreference = "Stop"

$raw = Get-Content $JsonPath -Raw
$model = $raw | ConvertFrom-Json
Write-Output "[OK] JSON parses without errors."

# --- Collect all $id values ---
$allIds = [System.Collections.Generic.HashSet[string]]::new()
[regex]::Matches($raw, '"\$id":\s*"([^"]+)"') | ForEach-Object { $allIds.Add($_.Groups[1].Value) | Out-Null }
Write-Output "[INFO] $($allIds.Count) unique \$id values found."

# --- NEW: find $ref values WITHOUT a leading '#' -- that is itself
# invalid (the Data Importer always expects "#prefix:N"), but the
# normal \$ref regex (which requires the '#') never recognises it as a \$ref and
# therefore NEVER reports it as a dangling reference. Exactly this bug slipped
# through once (rp:31 instead of #rp:31) and was only reported by the Data Importer
# itself -- this check closes the gap.
$malformedRefs = [regex]::Matches($raw, '"\$ref":\s*"([^"#][^"]*)"')
if ($malformedRefs.Count -gt 0) {
    Write-Output "[ERROR] $($malformedRefs.Count) \$ref values WITHOUT a leading '#' found (invalid):"
    $malformedRefs | ForEach-Object { Write-Output "  - $($_.Groups[1].Value)" }
} else {
    Write-Output "[OK] No \$ref values without a leading '#'."
}

# --- Collect all $ref values, check that each references an existing $id ---
$allRefs = [regex]::Matches($raw, '"\$ref":\s*"#([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$dangling = @()
foreach ($r in $allRefs) { if (-not $allIds.Contains($r)) { $dangling += $r } }
if ($dangling.Count -gt 0) {
    Write-Output "[ERROR] $($dangling.Count) dangling \$ref references (target \$id does not exist):"
    $dangling | ForEach-Object { Write-Output "  - $_" }
} else {
    Write-Output "[OK] No dangling \$ref references ($($allRefs.Count) checked)."
}

# --- No Exchange/HAS_EXCHANGE/REFERS_TO_FLOW leftovers ---
$forbidden = @("Exchange", "HAS_EXCHANGE", "REFERS_TO_FLOW")
$hits = @()
foreach ($tok in $forbidden) {
    if (([regex]::Matches($raw, [regex]::Escape('"token":  "' + $tok + '"'))).Count -gt 0) { $hits += $tok }
    if (([regex]::Matches($raw, [regex]::Escape('"tableName":  "' + $tok))).Count -gt 0) { $hits += "$tok (tableName)" }
}
if ($hits.Count -gt 0) {
    Write-Output "[ERROR] Leftovers found: $($hits -join ', ')"
} else {
    Write-Output "[OK] No Exchange/HAS_EXCHANGE/REFERS_TO_FLOW leftovers."
}

# --- Process/Flow: new properties present? ---
$graphSchema = $model.dataModel.graphSchemaRepresentation.graphSchema
$processLabel = $graphSchema.nodeLabels | Where-Object { $_.token -eq "Process" }
$flowLabel = $graphSchema.nodeLabels | Where-Object { $_.token -eq "Flow" }
$procTokens = $processLabel.properties.token
$flowTokens = $flowLabel.properties.token
foreach ($t in @("source","sourceDatabase","referenceYear")) {
    if ($procTokens -contains $t) { Write-Output "[OK] Process.$t present." } else { Write-Output "[ERROR] Process.$t MISSING." }
}
foreach ($t in @("source","sourceDatabase")) {
    if ($flowTokens -contains $t) { Write-Output "[OK] Flow.$t present." } else { Write-Output "[ERROR] Flow.$t MISSING." }
}

# --- HAS_FLOW/CHARACTERIZES type still present, but no mapping file any more ---
foreach ($tok in @("HAS_FLOW","CHARACTERIZES")) {
    $present = ($graphSchema.relationshipTypes | Where-Object { $_.token -eq $tok }) -ne $null
    Write-Output "[INFO] relationshipType '$tok' present in the schema (documentation): $present"
}
$graphMapping = $model.dataModel.graphMappingRepresentation
$mappingTables = $graphMapping.relationshipMappings.tableName
foreach ($pattern in @("HAS_FLOW","CHARACTERIZES")) {
    $stillMapped = $mappingTables | Where-Object { $_ -match $pattern -and $_ -notmatch "PROPERTY" }
    Write-Output "[INFO] remaining mappings matching '$pattern' (should be empty, except _PROPERTY variants): $($stillMapped -join ', ')"
}

# --- Array collapse check: critical arrays must be serialised as arrays ---
Write-Output ""
Write-Output "=== Array type check (PowerShell ConvertTo-Json collapse risk) ==="
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

# --- NEW: completeness check -- for EVERY relationshipType EVERY
# declared property must be mapped in EVERY relationshipMapping that uses that
# type. The absence of exactly this check caused the second
# failed import (exchangeId added on the shared HAS_DATA
# type, but actually mapped in only one of several mappings).
Write-Output ""
Write-Output "=== Completeness check: relationshipType properties vs. mappings ==="
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
        if (-not $mapping) { Write-Output "[ERROR] $($rt.token): relationshipObjectType $($robj.'$id') has NO mapping."; $incompleteFound = $true; continue }
        $mappedProps = [System.Collections.Generic.HashSet[string]]::new([string[]]($mapping.propertyMappings | ForEach-Object { $_.property.'$ref' }))
        $missing = $declaredProps | Where-Object { -not $mappedProps.Contains($_) }
        if ($missing.Count -gt 0) {
            Write-Output "[ERROR] $($rt.token) (mapping $($mapping.tableName)): missing property mappings for $($missing -join ', ')"
            $incompleteFound = $true
        }
    }
}
if (-not $incompleteFound) { Write-Output "[OK] Every relationshipType property is fully mapped in every mapping that uses it." }

Write-Output ""
Write-Output "=== Completeness check: nodeLabel properties vs. mappings ==="
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
        if (-not $mapping) { Write-Output "[ERROR] $($nl.token): nodeObjectType $($nobj.'$id') has NO mapping."; $incompleteNodeFound = $true; continue }
        $mappedProps = [System.Collections.Generic.HashSet[string]]::new([string[]]($mapping.propertyMappings | ForEach-Object { $_.property.'$ref' }))
        $missing = $declaredProps | Where-Object { -not $mappedProps.Contains($_) }
        if ($missing.Count -gt 0) {
            Write-Output "[ERROR] $($nl.token) (mapping $($mapping.tableName)): missing property mappings for $($missing -join ', ')"
            $incompleteNodeFound = $true
        }
    }
}
if (-not $incompleteNodeFound) { Write-Output "[OK] Every nodeLabel property is fully mapped in every mapping that uses it." }

Write-Output ""
Write-Output "Validation completed."
