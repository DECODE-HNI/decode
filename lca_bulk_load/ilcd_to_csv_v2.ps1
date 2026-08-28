<#
============================================================
ilcd_to_csv_v2.ps1

Erweiterung von ilcd_to_csv.ps1 (frueherer Entwicklungsstand):
- exchangeId (= "<processId>#<dataSetInternalID>") wird jetzt in die
  HAS_FLOW-CSV geschrieben -- war vorher nur intern bekannt.
- uncertainty (aus relativeStandardDeviation95In) und comment (aus
  dataSourceType + dataDerivationTypeStatus, beides echte ILCD-Felder --
  nichts erfunden) neu je Exchange.
- referenceYear auf HAS_FLOW UND zusaetzlich auf Process.csv (Provenienz).
- source/sourceDatabase auf Process.csv UND Flow.csv (Provenienz), da nach
  Dedup jeder Flow/Process genau einen Ursprung hat.
- ProcessTypeMap statt einzelnem ProcessType, da die neu ausgewaehlten
  Prozesse unterschiedliche Kategorien sind (Rohstoff/Fertigungsschritt/EoL).
Alles andere unveraendert aus der Originalversion uebernommen (Unquoted-CSV-
Schreiber, InvariantCulture ueberall, Scoping auf tatsaechlich genutzte
Flows/CFs, Sphera- wie IDEMAT-Exchange-Form).
============================================================
AUFRUF-BEISPIEL:

.\ilcd_to_csv_v2.ps1 -IlcdDir "C:\extracted\alu" -OutDir "C:\out\alu" `
  -Source "Sphera" -SourceDatabase "Sphera Managed LCA Content (MLC)" `
  -ProcessIdMap @{ "74571213-7e1d-4aba-b642-ea6eb4c1f20e" = "PROC_ALU_EXTRUSION_CN" } `
  -ProcessTypeMap @{ "74571213-7e1d-4aba-b642-ea6eb4c1f20e" = "RawMaterialProduction" } `
  -OnlyProcessUuids @("74571213-7e1d-4aba-b642-ea6eb4c1f20e", "...")
============================================================
#>

param(
    [Parameter(Mandatory=$true)] [string] $IlcdDir,
    [Parameter(Mandatory=$true)] [string] $OutDir,

    [hashtable] $ProcessIdMap = @{},
    [hashtable] $ProcessTypeMap = @{},
    [string] $DefaultProcessType = "RawMaterialProduction",

    [string] $Source = "",
    [string] $SourceDatabase = "",
    [string] $DataMaturity = "background_LCI_secondary_ILCD",

    # Falls gesetzt: nur diese Prozess-UUIDs verarbeiten (Dateiname ohne .xml),
    # alle anderen im processes-Ordner ignorieren. Leer = alle verarbeiten.
    [string[]] $OnlyProcessUuids = @()
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

function Write-UnquotedCsv {
    param([Parameter(ValueFromPipeline=$true)] $InputObject, [string]$Path, [string[]]$Columns)
    begin {
        $lines = New-Object System.Collections.Generic.List[string]
        $cols = $Columns
        $lines.Add(($cols -join ','))
    }
    process {
        if (-not $cols) { $cols = $InputObject.PSObject.Properties.Name }
        $vals = foreach ($c in $cols) { $InputObject.$c }
        $lines.Add(($vals -join ','))
    }
    end {
        [System.IO.File]::WriteAllLines($Path, $lines, (New-Object System.Text.UTF8Encoding($false)))
    }
}

$procDir = Join-Path $IlcdDir "ILCD\processes"
$flowDir = Join-Path $IlcdDir "ILCD\flows"
$fpDir   = Join-Path $IlcdDir "ILCD\flowproperties"
$ugDir   = Join-Path $IlcdDir "ILCD\unitgroups"
$lciaDir = Join-Path $IlcdDir "ILCD\lciamethods"

foreach ($d in @($procDir, $flowDir, $fpDir, $ugDir)) {
    if (-not (Test-Path $d)) { throw "Erwarteter Ordner fehlt: $d" }
}

$fpCache = @{}
$ugCache = @{}

function Resolve-Unit {
    param($FlowPropertyUuid)
    if ($fpCache.ContainsKey($FlowPropertyUuid)) { return $fpCache[$FlowPropertyUuid] }
    $fpFile = Join-Path $fpDir "$FlowPropertyUuid.xml"
    if (-not (Test-Path $fpFile)) { $fpCache[$FlowPropertyUuid] = "?"; return "?" }

    [xml]$fx = Get-Content $fpFile
    $ns = New-Object System.Xml.XmlNamespaceManager($fx.NameTable)
    $ns.AddNamespace("f","http://lca.jrc.it/ILCD/FlowProperty")
    $ugRef = $fx.SelectSingleNode("//f:flowPropertiesInformation/f:quantitativeReference/f:referenceToReferenceUnitGroup", $ns)
    if (-not $ugRef) { $fpCache[$FlowPropertyUuid] = "?"; return "?" }

    $ugUuid = $ugRef.refObjectId
    if ($ugCache.ContainsKey($ugUuid)) {
        $unit = $ugCache[$ugUuid]
    } else {
        $unit = "?"
        $ugFile = Join-Path $ugDir "$ugUuid.xml"
        if (Test-Path $ugFile) {
            [xml]$ux = Get-Content $ugFile
            $nsu = New-Object System.Xml.XmlNamespaceManager($ux.NameTable)
            $nsu.AddNamespace("u","http://lca.jrc.it/ILCD/UnitGroup")
            $refUnitId = $ux.SelectSingleNode("//u:quantitativeReference/u:referenceToReferenceUnit", $nsu).InnerText
            $unitNode = $ux.SelectSingleNode("//u:units/u:unit[@dataSetInternalID='$refUnitId']/u:name", $nsu)
            $unit = if ($unitNode) { $unitNode.InnerText } else { "?" }
        }
        $ugCache[$ugUuid] = $unit
    }
    $fpCache[$FlowPropertyUuid] = $unit
    return $unit
}

function Read-FlowXml {
    param($Uuid)
    $file = Join-Path $flowDir "$Uuid.xml"
    if (-not (Test-Path $file)) { return $null }

    [xml]$x = Get-Content $file
    $ns = New-Object System.Xml.XmlNamespaceManager($x.NameTable)
    $ns.AddNamespace("f","http://lca.jrc.it/ILCD/Flow")
    $ns.AddNamespace("common","http://lca.jrc.it/ILCD/Common")

    $baseName = $x.SelectSingleNode("//f:dataSetInformation/f:name/f:baseName", $ns).InnerText
    $typeNode = $x.SelectSingleNode("//f:LCIMethod/f:typeOfDataSet", $ns)
    $flowType = if ($typeNode) { $typeNode.InnerText } else { "" }

    $cls0 = $x.SelectSingleNode("//common:elementaryFlowCategorization/common:category[@level='0']", $ns)
    $cls1 = $x.SelectSingleNode("//common:elementaryFlowCategorization/common:category[@level='1']", $ns)
    if (-not $cls0) {
        $cls0 = $x.SelectSingleNode("//common:classification/common:class[@level='0']", $ns)
        $cls1 = $x.SelectSingleNode("//common:classification/common:class[@level='1']", $ns)
    }
    $c0 = if ($cls0) { $cls0.InnerText } else { "" }
    $c1 = if ($cls1) { $cls1.InnerText } else { "" }
    $category = if ($c1) { "$c0 / $c1" } else { $c0 }

    $casNode = $x.SelectSingleNode("//f:dataSetInformation/f:CASNumber", $ns)
    $cas = if ($casNode) { $casNode.InnerText } else { "" }

    $refIdxNode = $x.SelectSingleNode("//f:quantitativeReference/f:referenceToReferenceFlowProperty", $ns)
    $unit = "?"
    if ($refIdxNode) {
        $fpNode = $x.SelectSingleNode("//f:flowProperties/f:flowProperty[@dataSetInternalID='$($refIdxNode.InnerText)']/f:referenceToFlowPropertyDataSet", $ns)
        if ($fpNode) { $unit = Resolve-Unit -FlowPropertyUuid $fpNode.refObjectId }
    }

    $ftMap = @{ "Elementary flow"="ElementaryFlow"; "Product flow"="ProductFlow"; "Waste flow"="WasteFlow" }
    $flowTypeOut = if ($ftMap.ContainsKey($flowType)) { $ftMap[$flowType] } else { $flowType }

    return [PSCustomObject]@{
        id = $Uuid
        name = ($baseName -replace ",",";")
        flowType = $flowTypeOut
        category = $category.Trim(' ','/')
        referenceUnit = $unit
        casNumber = $cas
        status = "reference"
        description = "ILCD background flow."
        source = $Source
        sourceDatabase = $SourceDatabase
    }
}

function Read-ProcessXml {
    param($ProcFile, $ProcId)

    [xml]$px = Get-Content $ProcFile
    $ns = New-Object System.Xml.XmlNamespaceManager($px.NameTable)
    $ns.AddNamespace("p","http://lca.jrc.it/ILCD/Process")
    $ns.AddNamespace("common","http://lca.jrc.it/ILCD/Common")

    $name = $px.SelectSingleNode("//p:processInformation/p:dataSetInformation/p:name/p:baseName", $ns).InnerText
    $refYearNode = $px.SelectSingleNode("//p:processInformation/p:time/common:referenceYear", $ns)
    $refYear = if ($refYearNode) { $refYearNode.InnerText } else { "" }
    $geoNode = $px.SelectSingleNode("//p:processInformation/p:geography/p:locationOfOperationSupplyOrProduction", $ns)
    $geo = if ($geoNode) { $geoNode.location } else { "" }

    $techNode = $px.SelectSingleNode("//p:processInformation/p:technology/p:technologyDescriptionAndIncludedProcesses", $ns)
    $techRaw = if ($techNode) { $techNode.InnerText } else { "" }
    $tech = ($techRaw -replace "[\r\n]+"," ") -replace ",",";"
    if ($tech.Length -gt 150) { $tech = $tech.Substring(0,150) }

    $qrNode = $px.SelectSingleNode("//p:processInformation/p:quantitativeReference/p:referenceToReferenceFlow", $ns)
    $refExchInternalId = if ($qrNode) { $qrNode.InnerText } else { "" }

    $exNodes = $px.SelectNodes("//p:exchanges/p:exchange", $ns)
    $exchanges = New-Object System.Collections.Generic.List[object]
    foreach ($ex in $exNodes) {
        $flowRef = $ex.SelectSingleNode("p:referenceToFlowDataSet", $ns)
        $dirNode = $ex.SelectSingleNode("p:exchangeDirection", $ns)
        $meanNode = $ex.SelectSingleNode("p:meanAmount", $ns)
        $amount = if ($meanNode) { $meanNode.InnerText } else { $ex.GetAttribute("olca:amount") }
        $locNode = $ex.SelectSingleNode("p:location", $ns)

        # Neu: Unsicherheit + Kommentar aus echten ILCD-Feldern (nichts erfunden;
        # falls das Feld fehlt, bleibt die Spalte leer statt eines erfundenen Werts).
        $rsdNode = $ex.SelectSingleNode("p:relativeStandardDeviation95In", $ns)
        $uncertainty = if ($rsdNode) { $rsdNode.InnerText } else { "" }
        $dstNode = $ex.SelectSingleNode("p:dataSourceType", $ns)
        $ddtNode = $ex.SelectSingleNode("p:dataDerivationTypeStatus", $ns)
        $commentParts = @()
        if ($dstNode) { $commentParts += $dstNode.InnerText }
        if ($ddtNode) { $commentParts += $ddtNode.InnerText }
        $comment = ($commentParts -join "; ") -replace ",",";"

        $exchanges.Add([PSCustomObject]@{
            internalId = $ex.GetAttribute("dataSetInternalID")
            flowUuid = $flowRef.refObjectId
            direction = if ($dirNode) { $dirNode.InnerText.ToLower() } else { "" }
            amount = $amount
            location = if ($locNode) { $locNode.InnerText } else { "" }
            uncertainty = $uncertainty
            comment = $comment
        })
    }

    return [PSCustomObject]@{
        id = $ProcId
        name = ($name -replace ",",";")
        refYear = $refYear
        geo = $geo
        tech = $tech
        refExchId = $refExchInternalId
        exchanges = $exchanges
    }
}

function Set-ReferenceNormalized {
    param($Process)

    $refEx = $Process.exchanges | Where-Object { $_.internalId -eq $Process.refExchId } | Select-Object -First 1
    if (-not $refEx) {
        $refEx = $Process.exchanges | Where-Object { $_.direction -eq "output" } | Select-Object -First 1
    }

    $refAmount = 1.0
    if ($refEx -and $refEx.amount) {
        $parsed = 0.0
        if ([double]::TryParse($refEx.amount, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
            $refAmount = $parsed
        }
    }

    foreach ($ex in $Process.exchanges) {
        $a = 0.0
        [void][double]::TryParse($ex.amount, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$a)
        $ratio = if ($refAmount -ne 0) { $a / $refAmount } else { 0 }
        $isRef = ($null -ne $refEx -and $ex.internalId -eq $refEx.internalId)
        $ratioStr = $ratio.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        $ex | Add-Member -NotePropertyName ratioToReference -NotePropertyValue $ratioStr -Force
        $ex | Add-Member -NotePropertyName isReference -NotePropertyValue $isRef -Force
    }
    return $Process
}

# ============================================================
# HAUPTABLAUF
# ============================================================

Write-Output "1) Prozesse einlesen..."
$processes = New-Object System.Collections.Generic.List[object]
$usedFlowUuids = New-Object 'System.Collections.Generic.HashSet[string]'

$procFiles = Get-ChildItem $procDir -Filter *.xml
if ($OnlyProcessUuids.Count -gt 0) {
    $wanted = [System.Collections.Generic.HashSet[string]]::new([string[]]$OnlyProcessUuids)
    $procFiles = $procFiles | Where-Object { $wanted.Contains($_.BaseName) }
}

foreach ($pf in $procFiles) {
    $uuid = $pf.BaseName
    $procId = if ($ProcessIdMap.ContainsKey($uuid)) { $ProcessIdMap[$uuid] } else { "PROC_$uuid" }
    $proc = Read-ProcessXml -ProcFile $pf.FullName -ProcId $procId
    $proc = Set-ReferenceNormalized -Process $proc
    $proc | Add-Member -NotePropertyName sourceUuid -NotePropertyValue $uuid -Force
    $proc | Add-Member -NotePropertyName processType -NotePropertyValue $(if ($ProcessTypeMap.ContainsKey($uuid)) { $ProcessTypeMap[$uuid] } else { $DefaultProcessType }) -Force
    $processes.Add($proc)
    foreach ($ex in $proc.exchanges) { [void]$usedFlowUuids.Add($ex.flowUuid) }
    Write-Output "   $procId ($uuid) : $($proc.exchanges.Count) Exchanges"
}
Write-Output "   -> $($processes.Count) Prozesse, $($usedFlowUuids.Count) referenzierte Flows"

Write-Output "2) Nur tatsaechlich genutzte Flows einlesen..."
$flowRows = New-Object System.Collections.Generic.List[object]
foreach ($uuid in $usedFlowUuids) {
    $f = Read-FlowXml -Uuid $uuid
    if ($f) { $flowRows.Add($f) }
}
Write-Output "   -> $($flowRows.Count) Flow-Zeilen"

Write-Output "3) Process.csv schreiben..."
$procCsvRows = foreach ($p in $processes) {
    [PSCustomObject]@{
        id = $p.id; name = $p.name; processType = $p.processType
        technology = $p.tech; geographicalLocation = $p.geo
        dataAcquisition = "background LCI dataset (secondary data ILCD)"
        status = "reference"
        source = $Source; sourceDatabase = $SourceDatabase; referenceYear = $p.refYear
    }
}
$procCsvRows | Write-UnquotedCsv -Path (Join-Path $OutDir "Process.csv") -Columns @('id','name','processType','technology','geographicalLocation','dataAcquisition','status','source','sourceDatabase','referenceYear')

Write-Output "4) Flow.csv schreiben..."
$flowRows | Write-UnquotedCsv -Path (Join-Path $OutDir "Flow.csv") -Columns @('id','name','flowType','category','referenceUnit','casNumber','status','description','source','sourceDatabase')

Write-Output "5) HAS_FLOW-Kanten schreiben (mit exchangeId, referenceYear, uncertainty, comment)..."
$unitLookup = @{}
$flowRows | ForEach-Object { $unitLookup[$_.id] = $_.referenceUnit }

$hasFlowRows = foreach ($p in $processes) {
    foreach ($ex in $p.exchanges) {
        [PSCustomObject]@{
            exchangeId = "$($p.id)#$($ex.internalId)"
            from_id = $p.id
            to_id = $ex.flowUuid
            amount = $ex.amount
            unit = $unitLookup[$ex.flowUuid]
            direction = $ex.direction
            location = $ex.location
            quantitativeReference = "$($ex.isReference)".ToLower()
            ratioToReference = $ex.ratioToReference
            dataMaturity = $DataMaturity
            referenceYear = $p.refYear
            uncertainty = $ex.uncertainty
            comment = $ex.comment
        }
    }
}
$hasFlowRows | Write-UnquotedCsv -Path (Join-Path $OutDir "r_HAS_FLOW_Process_TO_Flow.csv") -Columns @('exchangeId','from_id','to_id','amount','unit','direction','location','quantitativeReference','ratioToReference','dataMaturity','referenceYear','uncertainty','comment')
Write-Output "   -> $($hasFlowRows.Count) HAS_FLOW-Zeilen"

Write-Output "6) CHARACTERIZES (nur falls ILCD\lciamethods vorhanden)..."
if (Test-Path $lciaDir) {
    $catRows = New-Object System.Collections.Generic.List[object]
    $cfRows = New-Object System.Collections.Generic.List[object]

    foreach ($mf in (Get-ChildItem $lciaDir -Filter *.xml)) {
        [xml]$mx = Get-Content $mf.FullName
        $nsm = New-Object System.Xml.XmlNamespaceManager($mx.NameTable)
        $nsm.AddNamespace("m","http://lca.jrc.it/ILCD/LCIAMethod")
        $nsm.AddNamespace("common","http://lca.jrc.it/ILCD/Common")

        $catUuid = $mf.BaseName
        $catName = ($mx.SelectSingleNode("//m:LCIAMethodInformation/m:dataSetInformation/common:name", $nsm).InnerText -replace ",",";").Trim()
        $indicatorNode = $mx.SelectSingleNode("//m:LCIAMethodInformation/m:dataSetInformation/m:impactIndicator", $nsm)
        $unitDesc = $mx.SelectSingleNode("//m:LCIAMethodInformation/m:quantitativeReference/m:referenceQuantity/common:shortDescription", $nsm)
        $catRows.Add([PSCustomObject]@{
            id = $catUuid; name = $catName
            indicator = if ($indicatorNode) { ($indicatorNode.InnerText -replace ",",";").Trim() } else { "" }
            unit = if ($unitDesc) { ($unitDesc.InnerText -replace ",",";").Trim() } else { "" }
        })

        $factors = $mx.SelectNodes("//m:characterisationFactors/m:factor", $nsm)
        foreach ($f in $factors) {
            $refNode = $f.SelectSingleNode("m:referenceToFlowDataSet", $nsm)
            $flowUuid = $refNode.refObjectId
            if (-not $usedFlowUuids.Contains($flowUuid)) { continue }
            $meanVal = $f.SelectSingleNode("m:meanValue", $nsm).InnerText
            $locNode = $f.SelectSingleNode("m:location", $nsm)
            $loc = if ($locNode) { $locNode.InnerText } else { "" }
            $cfRows.Add([PSCustomObject]@{ from_id = $flowUuid; to_id = $catUuid; factor = $meanVal; location = $loc })
        }
    }

    $catRows | Write-UnquotedCsv -Path (Join-Path $OutDir "ImpactCategory_neu.csv") -Columns @('id','name','indicator','unit')
    $cfRows | Write-UnquotedCsv -Path (Join-Path $OutDir "r_CHARACTERIZES_Flow_TO_ImpactCategory.csv") -Columns @('from_id','to_id','factor','location')
    Write-Output "   -> $($catRows.Count) Kategorien, $($cfRows.Count) CHARACTERIZES-Zeilen"
} else {
    Write-Output "   kein lciamethods-Ordner gefunden -- ueberspringe CHARACTERIZES."
}

Write-Output ""
Write-Output "Fertig. CSVs liegen in: $OutDir"
