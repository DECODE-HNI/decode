# Nachhaltigkeits-Erweiterung des Greifer-Wissensgraphen — Konsolidierte Referenz

Stand: 2026-08-27. Autoritativer Ist-Stand: Live-Neo4j-DB. Maschinenlesbares
Schema: [`../neo4j_model_export/graph_schema_v3x.json`](../neo4j_model_export/graph_schema_v3x.json).

**Live-DB (nach v3.g, 2026-08-28):** ~3 707 Knoten / ~82 400 Beziehungen · 35 Knoten-Labels · 45 Beziehungstypen · 37 Constraints.

---

## 1. Ausbaustufen (black → grey → white → Module)

| Stufe | Box | Kern | Migration |
|---|---|---|---|
| **v1** | black | Produktmodell + konkrete Indikatoren + Reparierbarkeit formalisiert | `v1_blackbox/migration_v1.cypher` |
| **v2** | grey | ILCD/EF3.1-Inventar + Rechenkern `ImpactResult.value`; Aluminium-A1-Pfad verdrahtet | `v2_greybox/migration_v2.cypher` |
| **v3** | white | `lca_generic($methodId)`, funkt. Einheit, EN-15804-Module, `AssessmentApproach`-Taxonomie (29 Verfahren) | `v3_whitebox/migration_v3.cypher` |
| **v3.a** | Modul | Zirkularität (vereinfachter MCI) | `v3x_a_circularity/migration_v3a.cypher` |
| **v3.b** | Modul | Kostendimension + MFCA/Ökoeffizienz (Prototyp) | `v3x_b_cost/migration_v3b.cypher` |
| **v3.c** | Modul | Parameter-/Szenario-Layer + Unsicherheits-Metadaten | `v3x_c_scenario/migration_v3c.cypher` |
| **v3.d** | Modul | Provenienz-Andockpunkte + Reparierbarkeit als Ergebnis + EPD/DPP | `v3x_d_provenance/migration_v3d.cypher` |
| **v3.e** | Modul | 2. LCIA-Methode ReCiPe 2016 Midpoint (H) | `v3x_e_recipe/migration_v3e.cypher` |
| **v3.f** | Modul | Emissions- & Schadstoffbilanzierung (THG-Scopes 1.1.4, Schadstoff 1.2.2, Wasser 1.1.3) | `v3x_nonlcia/migration_v3f.cypher` |
| **v3.g** | Modul | Cross-Impact-Matrix (2.2.2) + Szenario-Bewertung (2.2.1) | `v3x_nonlcia/migration_v3g.cypher` |
| **v3.h–i** | Modul | prospektiv/dynamisch/konsequenziell/hybrid (2.1.x), SEEA/KI-Andockpunkte — *geplant* | `v3x_nonlcia/PLAN.md` |
| **v2-data** | Daten | Part-Massen (alle 86), Fertigungsenergie, Werkstoff-GWP; Varianten A/B | `v2_data/` |
| **PRE-5** | Hygiene | ImpactCategory-Kanonisierung (44 → 29 vor ReCiPe) | `v3_followup_pre5/migration_pre5.cypher` |
| Korrektur | — | MERGE-Pfad-Falle (48 Dup-Knoten) | `v3x_repair.cypher` |

Flexibilitätsnachweis: neues Paradigma steckt additiv ein (v1→v2) · neue Metrik = reine Daten
(ReCiPe in v3.e, 0 Query-Änderung) · ganze Methodenfamilien als orthogonale Module (v3→v3.x).

---

## 2. Knoten-Labels

### Produktmodell (Kern, v1)
| Label | n | Schlüssel-Properties |
|---|---:|---|
| `Product` | 1 | id, name, productNumber, version |
| `Artifact` | 43 | + **v1**: disassemblyReversibility, repairabilityClass, componentCount, distinctMaterialCount, toollessRobotInterface, replaceableContactElement · **v3.a**: designLifetime, referenceLifetime · mass_g |
| `Assembly` / `Part` | 43 / 86 | Part **v2-data**: mass_g, massBasis (alle 86) |
| `Material` | 23 | density_kg_m3 · **v3.a**: recyclingRate, reusability, recycledContentAssumed, mci, mciMethod · **v3.b**: unitCost, costUnit · **v2-data**: gwp_A1_kgCO2e_per_kg, ef31_categories[], ef31_factors_A1[] |
| `Feature` / `Form` / `Geometry` | 14 / 14 / 14 | |
| `Function` / `Behavior` / `SolutionPrinciple` | 8 / 7 / 8 | |
| `Requirement` | 24 | + **v3.d**: sustainabilityIndicatorRef, sustainabilityThreshold, sustainabilityOperator, sustainabilityUnit, sustainabilityScope |
| `Specification` | 26 | |
| `Scenario` | 17 | Greifszenarien (`scenarioType:'gripping'`) — **nicht** LCA-Szenarien |
| `DataItem` / `DataSource` / `DataQuality` / `DataQualityCriterion` | 22 / 15 / 5 / 8 | Evidenz-/Datenqualitäts-Schicht |

### LCI / LCIA (v2)
| Label | n | Schlüssel-Properties |
|---|---:|---|
| `Process` | 55 | processType, technology, geographicalLocation, referenceYear · **v3**: lifecycleModule (EN 15804) · **v2-data**: energyIntensity_kWh_per_kg, materialFactor |
| `ProcessPlan` | 43 | Plan-Kopf; `CONTAINS_PROCESS {sequence, share}` → Process |
| `Flow` | 2102 | flowType, casNumber, category, referenceUnit · **v2-data**: FLOW_ELECTRICITY bekommt gwp_kgCO2e_per_kWh_{DE,DE_green,CN,EU} |
| `FlowProperty` | 3 | |
| `ImpactAssessmentMethod` | 5 | `IAM_EF31`, `IAM_PCF`, `IAM_MCI` (v3.a), `IAM_REPAIR` (v3.d), `IAM_RECIPE` (v3.e) |
| `ImpactCategory` | 47 | 29 EF3.1/Sonstige (nach PRE-5 kanonisiert) + 18 `IC_RECIPE_*` |
| `Assessment` | 182 | + **v3**: systemBoundary, functionalUnit, referenceFlow/Quantity/Unit · **v3.b**: productSystemValue · **v3.c**: scenarioRef · **v2-data**: dataVariant ('A-realdataset' \| 'B-literal') |
| `ImpactResult` | 771 | value, provenance, status, coverage, computedAt · **v3.d**: confidence · **v3.c**: scenarioRef · **v2-data**: dataVariant |

### v3.x-Erweiterungen
| Label | n | Modul | Properties |
|---|---:|---|---|
| `AssessmentApproach` | 41 | v3 | id, name, level (paradigm\|group\|method), code — die 29 Verfahren + 9 Gruppen + 3 Paradigmen des Diagramms |
| `EndOfLifeRoute` | 4 | v3.a | id, name, type (recycling\|reuse\|incineration-ER\|landfill) |
| `CostItem` | 5 | v3.b | category (material\|energy\|system\|waste-management\|capital\|labour), amount, currency, perUnit |
| `ModelScenario` | 2 | v3.c | type (baseline\|what-if\|prospective\|stress), horizonYear — `SC_BASELINE`, `SC_RECYCLED_ALU` |
| `Parameter` / `ParameterValue` | 1 / 1 | v3.c | Parameter{name,unit,baseValue} · ParameterValue{value,unit} |
| `Declaration` | 2 | v3.d | type (EPD\|DPP), standard, functionalUnit, validFrom/Until — `DECL_EPD_ART_V_AL`, `DECL_DPP_ART_V_AL` |

### v3.f/v3.g-Erweiterungen
| Label | n | Modul | Properties |
|---|---:|---|---|
| `HazardStatement` | 12 | v3.f | code (GHS/CLP-H-Satz), text, hazardClass, scheme — `HazardStatement_code_unique` |
| `ImpactAssessmentMethod` `IAM_GHG` | +1 | v3.f | nutzt `IC_CLIMATE` wieder (kein neuer Kategorieknoten); `methodStandard='GHG Protocol …'` |

**Nur als Typ definiert (keine Instanzen), für v3.h/v3.i geplant:** `PredictionModel`, `Recommendation`, `ExternalFramework`, `EEIOSector`, `SystemBoundary`.

---

## 3. Beziehungstypen

### Kern (v1/v2)
`HAS_ARTIFACT` · `HAS_COMPONENT {quantity, unit, role` + **v1** `, connectionType, reversible, toolless, evidenceLevel, evidenceRef}` · `USES_MATERIAL {fraction, role}` · `HAS_FORM`/`HAS_GEOMETRY`/`HAS_FEATURE` · `HAS_BEHAVIOR` · `REALIZES_FUNCTION {degreeOfFulfilment}` · `REALIZES_PRINCIPLE` · `SATISFIES_REQUIREMENT {verificationStatus}` · `SPECIFIED_BY` · `SUITABLE_FOR {suitability, rationale}` · `HAS_PROCESS_PLAN` · `CONTAINS_PROCESS {sequence, share}` · `APPLIES_TO {role}` · `HAS_FLOW {amount, unit, direction, uncertainty, ...` + **v3.c** `, uncertaintyDistribution}` · `CHARACTERIZES {factor, location, characterizesId, source}` · `HAS_CATEGORY {order}` · `HAS_FLOW_PROPERTY` · `HAS_DATA`/`HAS_DATA_QUALITY`/`FROM_SOURCE`/`EVALUATES_CRITERION` · `CHARACTERIZES_PROPERTY`

### Assessment-Schicht
`ASSESSES` (Assessment→Artifact) · `USES_METHOD` (→ImpactAssessmentMethod) · `HAS_RESULT` (→ImpactResult) · `FOR_CATEGORY` (ImpactResult→ImpactCategory) · `DERIVED_FROM {exchangeId}` (ImpactResult→Flow)

### v3.x neu
| Rel | n | Modul | Bedeutung |
|---|---:|---|---|
| `MODELED_BY {proxy, proxyRationale, lifecycleModule}` | 6 | v2/v2-data | Material → ILCD-Datensatz (Al, Stahl, PA-Proxy) |
| `BROADER` | 38 | v3 | AssessmentApproach: Verfahren→Gruppe→Paradigma |
| `APPLIES_APPROACH` | 185 | v3 | Assessment → Verfahren |
| `HAS_EOL_ROUTE {fraction, basis}` | 60 | v3.a | Material → EndOfLifeRoute |
| `HAS_COST` | 5 | v3.b | Part/Process/Material → CostItem |
| `PARAM_OF` / `SETS` / `FOR` | 1 / 1 / 1 | v3.c | Parameter↔Element, ModelScenario→ParameterValue→Parameter |
| `UNDER_SCENARIO` | 182 | v3.c | Assessment → ModelScenario |
| `BASED_ON` | 57 | v3.d | ImpactResult → Feature\|CoreProperty\|DataItem (Nachvollziehbarkeit / Gap 4) |
| `DECLARES` / `REPORTS` | 2 / 16 | v3.d | Declaration → Artifact / ImpactResult |
| `HAS_HAZARD {basis}` | 170 | v3.f | Flow → HazardStatement (GHS-Screening) |
| `INFLUENCES {sign, strength, mechanism, evidenceLevel, source, module}` | 60 | v3.g | Feature\|CoreProperty\|Material\|ImpactCategory → ImpactCategory (Cross-Impact-Matrix; `sign '+'`=verbessert) |

---

## 4. Basisqueries

Vollständiger Index + Aufrufbeispiele: [`../base_queries/README.md`](../base_queries/README.md).
18 Queries, alle gegen die Live-DB getestet:

- **LCIA:** `v3_whitebox/lca_generic.cypher` (`$methodId` — EF3.1/PCF/ReCiPe) ·
  `v2_data/lca_from_literals.cypher` (Variante B, alle 43) ·
  `v2_greybox/lca_computed_ef31.cypher` (v2-Beleg)
- **bilanzierend:** `base_queries/` — `water_footprint`, `ghg_inventory`, `mfa_balance`,
  `pollutant_inventory`, `ced`, `mfca`, `eco_efficiency`
- **Analyse:** `hotspot`, `sensitivity_oat`, `robustness`, `impact_chain`
- **strukturell / Reporting:** `repairability`, `dpp_view`, `design_recommendation`
- **Zirkularität:** in `v3x_a_circularity/migration_v3a.cypher` (setzt `Material.mci` + `IR_MCI_*`)

`ImpactResult`-Bestände: `ASSESS_EF31_*` (v2, Al-A1) · `ASSESS_EF31A_*` (Variante A) ·
`ASSESS_EF31B_*` (Variante B) · `ASSESS_MCI_*` · `ASSESS_REPAIR_*` · 43 PCF-Platzhalter.

---

## 5. Offene Punkte

| Thema | Status |
|---|---|
| **Datenvariante A vs. B** | **entschieden (2026-08-28):** ab v3 ist **Variante A** (ILCD-nahe reale Datensätze, `dataVariant='A-realdataset'`) der Standard; **Variante B** (`B-literal`) bleibt nur als Fallback/Grundlage, wo kein realer Datensatz existiert |
| **Kostendimension** | **entschieden (2026-08-28):** bleibt **schlank** (`Material.unitCost`-Platzhalter); `CostItem`/`HAS_COST`-Knotenmodell wird nicht weiterverfolgt |
| **v2-data Verfeinerung** | **läuft:** ABS/PC/POM/PA6.6 als reale PlasticsEurope-ILCD-Datensätze eingespielt (`v2_data/ilcd_import/`, Pipeline + `MODELED_BY` Variante A, GWP 3,1–6,5 kg CO₂e/kg). Offen: Elastomere/PETG/PLA/PA12-spez./CF (Proxy/Literal). Bezeichnungen: [`v2_data/SPHERA_DATASET_MAP.md`](v2_data/SPHERA_DATASET_MAP.md) |
| **ReCiPe-Faktoren** | nur Klimakategorie befüllt (× 1,06 aus EF3.1); 17 weitere Kategorien nur strukturell |
| **PRE-5 Nebeneffekt** | 180 doppelte `CHARACTERIZES` auf den zusammengeführten Toxizitäts-/Ressourcen-Kategorien entfernt (0,6 %); die 7 rechnenden Kernkategorien unverändert |
| **Voll-Snapshot** | braucht `apoc.export.file.enabled` + DBMS-Neustart |
| **Nicht-LCIA-Methoden — erledigt** | v3.f: 1.1.4 THG-Scopes (rechnet), 1.2.2 Schadstoff (rechnet, Klassen-Screening), 1.1.3 Wasser (Struktur, Zahl blockiert). v3.g: 2.2.2 Cross-Impact (rechnet), 2.2.1 Szenario-Bewertung (rechnet) |
| **Nicht-LCIA-Methoden — offen (Modul v3.h/v3.i)** | 2.1.1–2.1.4 prospektiv/dynamisch/konsequenziell/hybrid; 1.3.3 SEEA; 3.2.2 Umwelt-KG; 3.1.x/3.3.1–2 KI (nur vorbereiten). Plan: `v3x_nonlcia/PLAN.md` |
