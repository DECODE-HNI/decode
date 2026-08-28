<#
Orchestrates ilcd_to_csv_v2.ps1 across all source ILCD/Sphera export
packages (see lca_bulk_load/README.md, "Reproducing the load" step 1).
$zipDir is wherever your raw export packages live; $root/$staging are
scratch working directories -- adjust all paths below to your own
environment before running.
#>
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = "./scratch/rebuild"
$staging = Join-Path $root "staging"
$script = Join-Path $root "ilcd_to_csv_v2.ps1"
$zipDir = "<path to your raw ILCD/Sphera export packages>"
$oldScratch = "./scratch/regen_eol/.."

if (-not (Test-Path $staging)) { New-Item -ItemType Directory -Path $staging | Out-Null }

function Extract-ZipSubset {
    param([string]$ZipPath, [string]$DestDir)
    if (Test-Path $DestDir) { Remove-Item -Recurse -Force $DestDir }
    New-Item -ItemType Directory -Path $DestDir | Out-Null
    $arc = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    $wanted = @("ILCD/processes/", "ILCD/flows/", "ILCD/flowproperties/", "ILCD/unitgroups/", "ILCD/lciamethods/")
    foreach ($entry in $arc.Entries) {
        $keep = $false
        foreach ($w in $wanted) { if ($entry.FullName.StartsWith($w) -and $entry.Name -ne "") { $keep = $true; break } }
        if (-not $keep) { continue }
        $destPath = Join-Path $DestDir $entry.FullName
        $destParent = Split-Path $destPath -Parent
        if (-not (Test-Path $destParent)) { New-Item -ItemType Directory -Path $destParent -Force | Out-Null }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destPath, $true)
    }
    $arc.Dispose()
}

# ============================================================
# Quellen-Definition
# ============================================================
$sources = @()

# --- Bereits vorhandene Quellen (Sphera/GaBi + IDEMAT), volle Wiederverarbeitung ---
$sources += [PSCustomObject]@{
    Name = "existing_alu"
    IlcdDir = Join-Path $oldScratch "ilcd_alu"
    Source = "Sphera"; SourceDatabase = "Sphera Managed LCA Content (MLC)"
    ProcessIdMap = @{ "62d37cbd-7499-4ed3-9354-e71cfcc56252" = "PROC_ALU_EXTRUSION_EF" }
    ProcessTypeMap = @{ "62d37cbd-7499-4ed3-9354-e71cfcc56252" = "RawMaterialProduction" }
    OnlyProcessUuids = @()
}
$sources += [PSCustomObject]@{
    Name = "existing_idemat_metal"
    IlcdDir = Join-Path $oldScratch "idemat_metal"
    Source = "IDEMAT"; SourceDatabase = "IDEMAT (TU Delft)"
    ProcessIdMap = @{
        "09215eb0-5fc9-11dd-ad8b-0800200c9a66" = "PROC_ALU_EXTRUSION_IDEMAT"
        "09215eb1-5fc9-11dd-ad8b-0800200c9a66" = "PROC_ALU_SHEET_IDEMAT"
        "09d61948-238a-40e7-8e1f-afdc0c98f902" = "PROC_STEEL_SECTIONS_ILCD"
        "119e8cc1-0859-45ca-8f63-93a8a518ffd2" = "PROC_STEEL_HRC"
        "11bceac4-b3d8-4048-8e80-b691ecd2c261" = "PROC_COPPER_WIRE_CONSMIX"
        "11f67def-dc2a-4e74-bb4f-885610a9ae9c" = "PROC_LEAD_SHEET_SECONDARY"
        "1323a7e6-7841-47db-8da1-06355432a908" = "PROC_COPPER_SHEET_MARKETMIX"
        "137f2286-e426-4231-b65d-e65503fa6e5c" = "PROC_LEAD_PRIMSEC_MIX"
        "14712dc3-ca9f-4032-aed2-2e5f449c13cb" = "PROC_COPPER_SHEET_CONSMIX"
        "268a11fb-baf2-4b9e-8867-38bea0e76ef6" = "PROC_STEEL_REBAR"
        "339b2536-c881-409d-ac71-49ab0d228fe3" = "PROC_STEEL_GALV_ILCD"
        "5098e9f2-e2f1-44e9-ac4e-62a8864ae2b6" = "PROC_COPPER_TUBE_MARKETMIX"
        "7dcb51ef-2d85-481c-b943-3b148d9f6500" = "PROC_STEEL_GALV_RECYCLED"
        "819e60d3-2652-47de-9f0b-d3bf8a4e0ea9" = "PROC_COPPER_WIRE_MARKETMIX"
        "9c0c2f04-fd6a-4d3c-950c-f9dead3639fe" = "PROC_STEEL_SECTIONS_RECYCLED"
        "a1baa4f2-50d3-44a1-b806-465c3d9ef1a7" = "PROC_COPPER_TUBE_CONSMIX"
        "a83ee9ac-e392-4ef8-b046-8d88c23a4187" = "PROC_STEEL_TINPLATE"
        "b0b413a1-2a7d-4cb5-a108-bfd7b37502e4" = "PROC_STEEL_HRC_RECYCLED"
        "e16174fe-6542-4572-90bc-8980616ebe53" = "PROC_STEEL_HRC_ILCD"
        "f9d4581e-14de-417e-8f9f-6c74e6f14051" = "PROC_STEEL_HR_SECTION"
        "fd9db252-4998-11dd-ae16-0800200c9a66" = "PROC_ZINC_PRIMARY"
        "fd9db253-4998-11dd-ae16-0800200c9a66" = "PROC_LEAD_PRIMARY"
    }
    ProcessTypeMap = @{}   # alle RawMaterialProduction -> Default greift
    OnlyProcessUuids = @()
}

# --- Neue Pakete (nur die vom Nutzer bestaetigten 17 Prozesse) ---
$sources += [PSCustomObject]@{
    Name = "new_screws"; ZipName = "Meine_Professional_Datenbank_EN_D4E EF3.1 2026_08_25_screws.zip"
    Source = "Sphera"; SourceDatabase = "Sphera Managed LCA Content (MLC)"
    ProcessIdMap = @{
        "a50d90a7-457c-482b-bab7-da985c8e51f0" = "PROC_SCREW_GALVANIZED"
        "bdc62969-b4a5-448b-9e36-9e908fc45696" = "PROC_SCREW_STAINLESS"
    }
    ProcessTypeMap = @{}
    OnlyProcessUuids = @("a50d90a7-457c-482b-bab7-da985c8e51f0","bdc62969-b4a5-448b-9e36-9e908fc45696")
}
$sources += [PSCustomObject]@{
    Name = "new_adhesive"; ZipName = "Meine_Professional_Datenbank_EN_D4E EF3.1 2026_08_25_adhesive.zip"
    Source = "Sphera"; SourceDatabase = "Sphera Managed LCA Content (MLC)"
    ProcessIdMap = @{ "9318cb4c-6dc3-44f2-a736-b0809eef9ffe" = "PROC_ADHESIVE_TPU" }
    ProcessTypeMap = @{}
    OnlyProcessUuids = @("9318cb4c-6dc3-44f2-a736-b0809eef9ffe")
}
$sources += [PSCustomObject]@{
    Name = "new_alu"; ZipName = "Meine_Professional_Datenbank_EN_D4E EF3.1 2026_08_25_alu.zip"
    Source = "Sphera"; SourceDatabase = "Sphera Managed LCA Content (MLC)"
    ProcessIdMap = @{
        "74571213-7e1d-4aba-b642-ea6eb4c1f20e" = "PROC_ALU_EXTRUSION_CN"
        "d32af9c8-d201-4774-9888-d2d6e7da9a6d" = "PROC_ALU_EXTRUSION_OPENINPUT_DE"
        "62d37cbd-7499-4ed3-9354-e71cfcc56252" = "PROC_ALU_EXTRUSION_EF"
        "28809b90-fc6b-49ed-b3a8-b694dc04d6bd" = "PROC_ALU_CAST_MACHINING"
        "e11a1c21-79ce-4f58-bdc6-379280ee9f7f" = "PROC_ALU_SHEET_STAMPING"
        "84d84df1-4a0c-4fdb-9857-7a3f8e6fc84c" = "PROC_ALU_SHEET_MIX_PRIMARY"
        "dd93261c-d6da-44ec-a842-78b4a42c2884" = "PROC_ALU_INGOT_MIX_CONSUMPTION"
    }
    ProcessTypeMap = @{
        "28809b90-fc6b-49ed-b3a8-b694dc04d6bd" = "Manufacturing"
        "e11a1c21-79ce-4f58-bdc6-379280ee9f7f" = "Manufacturing"
    }
    OnlyProcessUuids = @("74571213-7e1d-4aba-b642-ea6eb4c1f20e","d32af9c8-d201-4774-9888-d2d6e7da9a6d","62d37cbd-7499-4ed3-9354-e71cfcc56252","28809b90-fc6b-49ed-b3a8-b694dc04d6bd","e11a1c21-79ce-4f58-bdc6-379280ee9f7f","84d84df1-4a0c-4fdb-9857-7a3f8e6fc84c","dd93261c-d6da-44ec-a842-78b4a42c2884")
}
$sources += [PSCustomObject]@{
    Name = "new_steel"; ZipName = "Meine_Professional_Datenbank_EN_D4E EF3.1 2026_08_25_steel.zip"
    Source = "Sphera"; SourceDatabase = "Sphera Managed LCA Content (MLC)"
    ProcessIdMap = @{
        "de9c95af-e1b1-47dd-9b41-94a780aefc49" = "PROC_STEEL_COLD_ROLL_STAINLESS"
        "51a7d5ff-2872-413f-b22a-5208a7507ff4" = "PROC_STEEL_FORGED_COMPONENT"
        "9c3ae20c-2786-4287-8885-0425779b58e9" = "PROC_STEEL_SHEET_075MM_HDA"
    }
    ProcessTypeMap = @{ "51a7d5ff-2872-413f-b22a-5208a7507ff4" = "Manufacturing" }
    OnlyProcessUuids = @("de9c95af-e1b1-47dd-9b41-94a780aefc49","51a7d5ff-2872-413f-b22a-5208a7507ff4","9c3ae20c-2786-4287-8885-0425779b58e9")
}
$sources += [PSCustomObject]@{
    Name = "new_electricity"; ZipName = "Meine_Professional_Datenbank_EN_D4E EF3.1 2026_08_25_Electriticy.zip"
    Source = "Sphera"; SourceDatabase = "Sphera Managed LCA Content (MLC)"
    ProcessIdMap = @{
        "7e4084b5-8767-4d3e-a484-c5959600b47e" = "PROC_ELECTRICITY_GRID_MIX_CN"
        "51a60958-a91b-4e75-b280-15983499c610" = "PROC_ELECTRICITY_GREEN_GRID_MIX_DE"
    }
    ProcessTypeMap = @{}
    OnlyProcessUuids = @("7e4084b5-8767-4d3e-a484-c5959600b47e","51a60958-a91b-4e75-b280-15983499c610")
}
$sources += [PSCustomObject]@{
    Name = "new_base_polyamide"; ZipName = "Meine_Professional_Datenbank_EN_D4E EF3.1 2026_08_25.zip"
    Source = "Sphera"; SourceDatabase = "Sphera Managed LCA Content (MLC)"
    ProcessIdMap = @{ "ece7efc0-b02a-4d80-9328-32a969bdab2c" = "PROC_PA66_GRANULATE_MIX" }
    ProcessTypeMap = @{}
    OnlyProcessUuids = @("ece7efc0-b02a-4d80-9328-32a969bdab2c")
}
$sources += [PSCustomObject]@{
    Name = "new_pa6gf30_waste"; ZipName = "Polyamide (PA) 6 GF30 (4.5% H2O) in waste incineration plant EF3.1 2026_08_25.zip"
    Source = "Sphera"; SourceDatabase = "Sphera Managed LCA Content (MLC)"
    ProcessIdMap = @{ "e515afe9-363e-4145-b238-800d8639498f" = "PROC_PA6_GF30_WASTE_INCINERATION" }
    ProcessTypeMap = @{ "e515afe9-363e-4145-b238-800d8639498f" = "EndOfLife" }
    OnlyProcessUuids = @("e515afe9-363e-4145-b238-800d8639498f")
}

# ============================================================
# Verarbeitung
# ============================================================
foreach ($src in $sources) {
    Write-Output ""
    Write-Output "=============================================="
    Write-Output "Quelle: $($src.Name)"
    Write-Output "=============================================="

    $ilcdDir = $src.IlcdDir
    if (-not $ilcdDir) {
        $zipPath = Join-Path $zipDir $src.ZipName
        $extractDir = Join-Path $staging "_extracted_$($src.Name)"
        Write-Output "Extrahiere $($src.ZipName) ..."
        Extract-ZipSubset -ZipPath $zipPath -DestDir $extractDir
        $ilcdDir = $extractDir
    }

    $outDir = Join-Path $staging $src.Name
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }

    & $script -IlcdDir $ilcdDir -OutDir $outDir `
        -Source $src.Source -SourceDatabase $src.SourceDatabase `
        -ProcessIdMap $src.ProcessIdMap -ProcessTypeMap $src.ProcessTypeMap `
        -OnlyProcessUuids $src.OnlyProcessUuids
}

Write-Output ""
Write-Output "=============================================="
Write-Output "Alle Quellen verarbeitet. Staging-Ordner: $staging"
Write-Output "=============================================="
