# Sustainability extension of the gripper knowledge graph — consolidated reference

As of 2026-08-29. Authoritative current state: the live Neo4j DB.
Machine-readable schema: [`graph_schema_v3x.json`](graph_schema_v3x.json)
(93 keys).

**Live DB (after v3.i + ILCD imports + ReCiPe CF import + LCI hygiene + cleanup +
DQ concept + demonstrator slice + consistency review Layers 1–4 + KI removal,
2026-08-29):** **5 620 nodes / 86 635 relationships · 39 node labels ·
54 relationship types · 39 uniqueness constraints** (+ the `flow_casnorm` index;
42 indexes total). EF3.1 = 19 categories (all with a CF). DQ: 8 criteria
(inherent/system, 0..4), 3 `DQPhase` with gate target values, auto-DQ on 6 LCI
datasets + 155 assessments. Verification chain: 24 `TestCase` (RFLPV² §6) over an
8-gripper slice (19 passed / 3 failed / 2 inconclusive). Consistency review:
`refresh_*` with a stale prune, `Flow.casNumberNorm` + 530 bridged EF3.1 CFs,
every assessment fully wired, 12 `ExternalFramework` (+ISO 14067, EN 45554).
The KI/ML paradigm (3.1.x/3.3.x, `PredictionModel`/`Recommendation`,
`PREDICTS`/`ESTIMATED_BY`/`RECOMMENDS_FOR`, `ASSESS_AI_PREPARED`) has been
removed — `../migrations/consistency/remove_ki_stubs.cypher`.

---

## 1. Stages (black → grey → white → modules)

| Stage | Box | Core | Migration |
|---|---|---|---|
| **v1** | black | product model + concrete indicators + repairability formalised | `../migrations/v1_blackbox/migration_v1.cypher` |
| **v2** | grey | ILCD/EF3.1 inventory + computation core `ImpactResult.value`; aluminium A1 path wired | `../migrations/v2_greybox/migration_v2.cypher` |
| **v3** | white | `lca_generic($methodId)`, functional unit, EN 15804 modules, `AssessmentApproach` taxonomy (originally 29, 23 methods after the KI removal) | `../migrations/v3_whitebox/migration_v3.cypher` |
| **v3.a** | module | circularity (simplified MCI) | `../migrations/v3x_a_circularity/migration_v3a.cypher` |
| **v3.b** | module | cost dimension + MFCA/eco-efficiency (prototype) | `../migrations/v3x_b_cost/migration_v3b.cypher` |
| **v3.c** | module | parameter/scenario layer + uncertainty metadata | `../migrations/v3x_c_scenario/migration_v3c.cypher` |
| **v3.d** | module | provenance docking points + repairability as a result + EPD/DPP | `../migrations/v3x_d_provenance/migration_v3d.cypher` |
| **v3.e** | module | 2nd LCIA method ReCiPe 2016 Midpoint (H) | `../migrations/v3x_e_recipe/migration_v3e.cypher` |
| **v3.f** | module | emissions & pollutant accounting (GHG scopes 1.1.4, pollutant 1.2.2, water 1.1.3) | `../migrations/v3x_nonlcia/migration_v3f.cypher` |
| **v3.g** | module | cross-impact matrix (2.2.2) + scenario assessment (2.2.1) | `../migrations/v3x_nonlcia/migration_v3g.cypher` |
| **v3.h** | module | advanced LCA (2.1.1–2.1.4) — schema hooks + 1 worked example each | `../migrations/v3x_nonlcia/migration_v3h.cypher` |
| **v3.i** | module | external frameworks (1.3.3 SEEA), self-describing KG (3.2.2) | `../migrations/v3x_nonlcia/migration_v3i.cypher` (its KI docking points removed 2026-08-29) |
| **v2-data** | data | part masses (all 86), manufacturing energy, material GWP; variants A/B | `../migrations/v2_data/` |
| **PRE-5** | hygiene | ImpactCategory canonicalisation (44 → 29 before ReCiPe) | `../migrations/v3_followup_pre5/migration_pre5.cypher` |
| **LCI hygiene** | data care | casNumber/unit/compartment cleanup + cleanup of orphan categories/processes | `../migrations/v2_data/lci_hygiene/` |
| **DQ concept** | methodology | criteria inherent/system + 0..4, `DQPhase` gates, auto-DQ from edge metadata | `../migrations/dq_concept/` (01–03 + `methods/base_queries/dq_radar.cypher`) |
| **Demonstrator** | artifacts | sustainability `Requirement`s + `TestCase` verification chain (RFLPV² §6) + EPD/DPP status lifecycle + scenario coverage, 8-gripper slice | `../migrations/demonstrator/` (00–04) |
| Correction | — | MERGE path trap (48 dup nodes) | `../migrations/v3x_repair.cypher` |

Flexibility evidence: a new paradigm plugs in additively (v1→v2) · a new metric =
pure data (ReCiPe in v3.e, 0 query changes) · whole method families as orthogonal
modules (v3→v3.x).

---

## 2. Node labels

### Product model (core, v1)
| Label | n | Key properties |
|---|---:|---|
| `Product` | 1 | id, name, productNumber, version |
| `Artifact` | 43 | + **v1**: disassemblyReversibility, repairabilityClass, componentCount, distinctMaterialCount, toollessRobotInterface, replaceableContactElement · **v3.a**: designLifetime, referenceLifetime · mass_g |
| `Assembly` / `Part` | 43 / 86 | Part **v2-data**: mass_g, massBasis (all 86) |
| `Material` | 23 | density_kg_m3 · **v3.a**: recyclingRate, reusability, recycledContentAssumed, mci, mciMethod · **v3.b**: unitCost, costUnit · **v2-data**: gwp_A1_kgCO2e_per_kg, ef31_categories[], ef31_factors_A1[] |
| `Feature` / `Form` / `Geometry` | 14 / 14 / 14 | |
| `Function` / `Behavior` / `SolutionPrinciple` | 8 / 7 / 8 | |
| `Requirement` | 27 | + **v3.d/demonstrator**: sustainabilityIndicatorRef, sustainabilityThreshold, sustainabilityOperator, sustainabilityUnit, sustainabilityScope (3 × `REQ_SUS_*` from the demonstrator) |
| `Specification` | 26 | |
| `Scenario` | 17 | gripping scenarios (`scenarioType:'gripping'`) — **not** LCA scenarios |
| `DataItem` / `DataSource` / `DataQuality` / `DataQualityCriterion` | 22 / 15 / 166 / 8 | evidence / data-quality layer. **`DataQualityCriterion`** (`dq_concept/`): + `class` (`inherent`\|`system`), `derivation` (`auto`\|`semi-auto`\|`manual`), `scale='0..4'` (4 = optimal), `isoRef`, `pedigreeIndicator`. **`DataQuality`** 5 → 166: 5 presets (rescaled to `0..4`) + 6 `DQ_AUTO_<procId>` (`subject:'lci-dataset'`) + 155 `DQ_AUTO_<assessmentId>` (`subject:'assessment'`, roll-up as MIN), each with `worstScore` (gate-relevant) / `meanScoreInfo` (informational only) |
| `DQPhase` | 3 | `dq_concept/` — engineering/reporting phases `PH_SCREENING` / `PH_DESIGN` / `PH_DECLARATION` (`order`, `gate`, `boxStage`). Min-based gate, no aggregation |
| `TestCase` | 24 | `demonstrator/` — RFLPV² verification layer (spec §6). `verificationID`, `testCaseOwner`, `systemLevel`, `dataAnalysisType`, `testMethod`, `sustainabilityResult`, `sustainabilityStatus` (`passed`\|`failed`\|`inconclusive`\|`notEvaluated`) |

### LCI / LCIA (v2)
| Label | n | Key properties |
|---|---:|---|
| `Process` | 58 | processType, technology, geographicalLocation, referenceYear · **v3**: lifecycleModule (EN 15804, live on all 58) · **v2-data**: energyIntensity_kWh_per_kg, materialFactor |
| `ProcessPlan` | 43 | plan header; `CONTAINS_PROCESS {sequence, share}` → Process |
| `Flow` | 2711 | flowType, casNumber, category, referenceUnit · **v2-data**: FLOW_ELECTRICITY gets gwp_kgCO2e_per_kWh_{DE,DE_green,CN,EU} · **consistency F-03**: `casNumberNorm` (leading zeros stripped, index `flow_casnorm`) |
| `FlowProperty` | 3 | |
| `ImpactAssessmentMethod` | 6 | `IAM_EF31`, `IAM_PCF`, `IAM_MCI` (v3.a), `IAM_REPAIR` (v3.d), `IAM_RECIPE` (v3.e), `IAM_GHG` (v3.f) |
| `ImpactCategory` | 39 | 21 EF3.1/other (after PRE-5 canonicalisation + LCI-hygiene orphan cleanup: 19 EF3.1-relevant with a CF + `IC_CIRCULARITY` + `IC_REPAIRABILITY`) + 18 `IC_RECIPE_*` |
| `Assessment` | 264 | + **v3**: systemBoundary, functionalUnit, referenceFlow/Quantity/Unit · **v3.b**: productSystemValue · **v3.c**: scenarioRef · **v2-data**: dataVariant ('A-realdataset' \| 'B-literal') · growth mainly from v3.f–i, scenario assessments and the demonstrator slice |
| `ImpactResult` | 1826 | value (1778 set), provenance, status, coverage, computedAt · **v3.d**: confidence · **v3.c**: scenarioRef · **v2-data**: dataVariant |

### v3.x extensions
| Label | n | Module | Properties |
|---|---:|---|---|
| `AssessmentApproach` | 33 | v3 | id, name, level (paradigm\|group\|method), code — 23 methods + 7 groups + 3 paradigms (the KI/ML paradigm material: 2 groups + 6 methods, removed 2026-08-29) |
| `EndOfLifeRoute` | 4 | v3.a | id, name, type (recycling\|reuse\|incineration-ER\|landfill) |
| `CostItem` | 5 | v3.b | category (material\|energy\|system\|waste-management\|capital\|labour), amount, currency, perUnit |
| `ModelScenario` | 2 | v3.c | type (baseline\|what-if\|prospective\|stress), horizonYear — `SC_BASELINE`, `SC_RECYCLED_ALU` |
| `Parameter` / `ParameterValue` | 1 / 1 | v3.c | Parameter{name,unit,baseValue} · ParameterValue{value,unit} |
| `Declaration` | 16 | v3.d + demonstrator | type (EPD\|DPP), standard, functionalUnit, validFrom/Until, status — `DECL_EPD_ART_V_AL`/`DECL_DPP_ART_V_AL` (v3.d) + a DPP+EPD each over the 8-gripper demonstrator slice |

### v3.f–v3.i extensions
| Label | n | Module | Properties |
|---|---:|---|---|
| `HazardStatement` | 12 | v3.f | code (GHS/CLP H-statement), text, hazardClass, scheme — `HazardStatement_code_unique` |
| `ImpactAssessmentMethod` `IAM_GHG` | +1 | v3.f | reuses `IC_CLIMATE` (no new category node); `methodStandard='GHG Protocol …'` |
| `EEIOSector` | 4 | v3.h | id, name, isicCode, gwpIntensity_kgCO2e_per_EUR, priceYear, source |
| `ExternalFramework` | 12 | v3.i (+2 from consistency review DE-02) | id, name, standard, domain — SEEA/GHGP/EN15804/ISO 14040-59020/PEF/ESPR/ISO 14067/EN 45554 |

New relationship types v3.h/i: `CHARACTERIZES_DYNAMIC {timeHorizon, factor, metric}` ·
`AVOIDS {ratio, module, avoidedGwp_kgCO2e_per_kg}` · `SUBSTITUTES {ratio}` ·
`COVERED_BY_EEIO {monetaryValue, currency}` · `MAPS_TO {element}`.
(`PREDICTS` / `ESTIMATED_BY` / `RECOMMENDS_FOR` and the labels
`PredictionModel` / `Recommendation` fell away with the KI removal 2026-08-29.)

---

## 3. Relationship types

### Core (v1/v2)
`HAS_ARTIFACT` · `HAS_COMPONENT {quantity, unit, role` + **v1** `, connectionType, reversible, toolless, evidenceLevel, evidenceRef}` · `USES_MATERIAL {fraction, role}` · `HAS_FORM`/`HAS_GEOMETRY`/`HAS_FEATURE` · `HAS_BEHAVIOR` · `REALIZES_FUNCTION {degreeOfFulfilment}` · `REALIZES_PRINCIPLE` · `SATISFIES_REQUIREMENT {verificationStatus}` · `SPECIFIED_BY` · `SUITABLE_FOR {suitability, rationale}` · `HAS_PROCESS_PLAN` · `CONTAINS_PROCESS {sequence, share}` · `APPLIES_TO {role}` · `HAS_FLOW {amount, unit, direction, uncertainty, ...` + **v3.c** `, uncertaintyDistribution}` · `CHARACTERIZES {factor, location, characterizesId, source}` · `HAS_CATEGORY {order}` · `HAS_FLOW_PROPERTY` · `HAS_DATA`/`HAS_DATA_QUALITY`/`FROM_SOURCE`/`EVALUATES_CRITERION {score, rating, derivation, derivedFrom}` · `CHARACTERIZES_PROPERTY`

### Assessment layer
`ASSESSES` (Assessment→Artifact) · `USES_METHOD` (→ImpactAssessmentMethod) · `HAS_RESULT` (→ImpactResult) · `FOR_CATEGORY` (ImpactResult→ImpactCategory) · `DERIVED_FROM {exchangeId}` (ImpactResult→Flow)

### New in v3.x
| Rel | n | Module | Meaning |
|---|---:|---|---|
| `MODELED_BY {proxy, proxyRationale, lifecycleModule}` | 9 | v2/v2-data | Material → ILCD dataset (Al, steel, PA proxy, PlasticsEurope datasets) |
| `BROADER` | 30 | v3 | AssessmentApproach: method→group→paradigm |
| `APPLIES_APPROACH` | 268 | v3 | Assessment → method |
| `HAS_EOL_ROUTE {fraction, basis}` | 60 | v3.a | Material → EndOfLifeRoute |
| `HAS_COST` | 5 | v3.b | Part/Process/Material → CostItem |
| `PARAM_OF` / `SETS` / `FOR` | 1 / 1 / 1 | v3.c | Parameter↔element, ModelScenario→ParameterValue→Parameter |
| `UNDER_SCENARIO` | 264 | v3.c | Assessment → ModelScenario |
| `BASED_ON` | 57 | v3.d | ImpactResult → Feature\|CoreProperty\|DataItem (traceability / gap 4) |
| `DECLARES` / `REPORTS` | 16 / 140 | v3.d + demonstrator | Declaration → Artifact / ImpactResult |
| `HAS_HAZARD {basis}` | 446 | v3.f | Flow → HazardStatement (GHS screening) |
| `INFLUENCES {sign, strength, mechanism, evidenceLevel, source, module}` | 60 | v3.g | Feature\|CoreProperty\|Material\|ImpactCategory → ImpactCategory (cross-impact matrix; `sign '+'` = improves) |
| `TARGETS {minScore, basis}` | 24 | dq_concept | DQPhase → DataQualityCriterion (gate target per phase; min-based, no aggregation) |
| `HAS_DATA_QUALITY` (auto) | +161 | dq_concept | Process → `DQ_AUTO` (6) · Assessment → `DQ_AUTO` roll-up (155); 182 total incl. the preset edges |
| `EVALUATES_CRITERION {score, rating, derivation, derivedFrom}` | 1001 | dq_concept | DataQuality → DataQualityCriterion (radar vector per assessment) |
| `VERIFIES` / `HAS_ASSESSMENT` / `TESTS` | 24 / 24 / 24 | demonstrator | TestCase → Requirement / Assessment / Artifact (RFLPV² §6 chain) |
| `SATISFIES_REQUIREMENT {verificationStatus, verifiedByTestCase}` | +24 | demonstrator | Artifact → `REQ_SUS_*`; status written back from the test case |
| `MAPS_TO {element}` | 14 | v3.i + DE-02 | ImpactAssessmentMethod → ExternalFramework |

---

## 4. Base queries

Full index + call examples:
[`../../methods/base_queries/README.md`](../../methods/base_queries/README.md).
19 queries in `methods/base_queries/` (+ `v3_whitebox/lca_generic.cypher` + 2 v2
reference queries), all tested against the live DB:

- **LCIA:** `../migrations/v3_whitebox/lca_generic.cypher` (`$methodId` —
  EF3.1/PCF/ReCiPe) · `../migrations/v2_data/lca_from_literals.cypher` (Variant B,
  all 43) · `../migrations/v2_greybox/lca_computed_ef31.cypher` (v2 reference)
- **inventory:** `methods/base_queries/` — `water_footprint`, `ghg_inventory`,
  `mfa_balance`, `pollutant_inventory`, `ced`, `mfca`, `eco_efficiency`
- **analysis:** `hotspot`, `sensitivity_oat`, `robustness`, `impact_chain`
- **structural / reporting:** `repairability`, `dpp_view`
- **data quality:** `dq_radar` (radar vector + `DQPhase` gate per assessment;
  `dq_concept/`)
- **circularity:** in `../migrations/v3x_a_circularity/migration_v3a.cypher`
  (sets `Material.mci` + `IR_MCI_*`)

`ImpactResult` stocks: `ASSESS_EF31_*` (v2, Al-A1) · `ASSESS_EF31A_*` (Variant A)
· `ASSESS_EF31B_*` (Variant B) · `ASSESS_RECIPE_A_*` (43 grippers, ReCiPe 2016 H,
16 cats) · `ASSESS_MCI_*` · `ASSESS_REPAIR_*` · 43 PCF placeholders.

---

## 5. Open items

| Topic | Status |
|---|---|
| **Data variant A vs B** | **decided (2026-08-28):** from v3 on, **Variant A** (ILCD-style real datasets, `dataVariant='A-realdataset'`) is the standard; **Variant B** (`B-literal`) stays only as a fallback/base where no real dataset exists |
| **Cost dimension** | **decided (2026-08-28):** stays **lean** (`Material.unitCost` placeholders); the `CostItem`/`HAS_COST` node model is not pursued |
| **v2-data refinement** | **ongoing:** ABS/PC/POM/PA6.6 loaded as real PlasticsEurope ILCD datasets (`../migrations/v2_data/ilcd_import/`, pipeline + `MODELED_BY` Variant A, GWP 3.1–6.5 kg CO₂e/kg). Non-CAS alias flows (2026-08-29) bridged to EF3.1 (`harmonize_noncas.cypher`) → particulate matter/human tox./POCP now populated for all 43 grippers; `refresh_variantA.cypher` with `round(…,12)` instead of `…,6`. Open: elastomers/PETG/PLA/PA12-specific/CF (proxy/literal). Designations: [`../migrations/v2_data/SPHERA_DATASET_MAP.md`](../migrations/v2_data/SPHERA_DATASET_MAP.md) |
| **ReCiPe factors** | **done 2026-08-29:** full CF import from the free openLCA LCIA pack (`../migrations/v3x_e_recipe/cf_import/`), **16 of 18 categories compute**, 43 `ASSESS_RECIPE_A_*` persisted. Open: fossil resource scarcity + land use (unit/data gap, see `cf_import/README.md`) |
| **PRE-5 side effect** | 180 duplicate `CHARACTERIZES` removed on the merged toxicity/resource categories (0.6 %); the 7 computing core categories unchanged |
| **Full snapshot** | **done 2026-08-29:** `apoc.conf` set + DBMS restarted; `graph_full_2026-08-29.{cypher,graphml}` + `schema_2026-08-29.json` generated locally (the 2 large dumps are NOT committed — see the repository README) |
| **Consistency review Layers 1–4** | **done 2026-08-29:** `../migrations/consistency/` — Layer 1 (building blocks), 2 (model, 8 findings), 3 (tools, 43 PASS / F-11 accepted), 4 (logical DECODE embedding, DE-01/DE-02 fixed). `FINDINGS.md` / `CHANGELOG.md` |
| **KI/ML paradigm** | **removed 2026-08-29:** out of the case-study scope; `../migrations/consistency/remove_ki_stubs.cypher` (11 nodes / 18 edges, with rollback). Docs updated accordingly |
| **Non-LCIA methods — done** | v3.f: 1.1.4 GHG scopes (computes), 1.2.2 pollutant (computes, class screening), 1.1.3 water (structure, number blocked). v3.g: 2.2.2 cross-impact (computes), 2.2.1 scenario assessment (computes) |
| **Non-LCIA methods — open (v3.h/v3.i)** | 2.1.1–2.1.4 prospective/dynamic/consequential/hybrid; 1.3.3 SEEA; 3.2.2 environmental KG. Plan: `../migrations/v3x_nonlcia/PLAN.md` |
