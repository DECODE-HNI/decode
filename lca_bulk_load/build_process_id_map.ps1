param(
    [Parameter(Mandatory=$true)] [string] $ProcDir,
    [Parameter(Mandatory=$true)] [string] $ExistingProcessCsv
)
$ErrorActionPreference = "Stop"

$existing = Import-Csv $ExistingProcessCsv
$byName = @{}
foreach ($row in $existing) { $byName[$row.name] = $row.id }

$ns = @{}
foreach ($pf in (Get-ChildItem $ProcDir -Filter *.xml)) {
    $uuid = $pf.BaseName
    [xml]$px = Get-Content $pf.FullName
    $nsMgr = New-Object System.Xml.XmlNamespaceManager($px.NameTable)
    $nsMgr.AddNamespace("p","http://lca.jrc.it/ILCD/Process")
    $nsMgr.AddNamespace("common","http://lca.jrc.it/ILCD/Common")
    $rawName = $px.SelectSingleNode("//p:processInformation/p:dataSetInformation/p:name/p:baseName", $nsMgr).InnerText
    $name = ($rawName -replace ",",";")

    if ($byName.ContainsKey($name)) {
        Write-Output "$uuid => $($byName[$name])  [MATCHED: $name]"
    } else {
        Write-Output "$uuid => NO MATCH  [$name]"
    }
}
