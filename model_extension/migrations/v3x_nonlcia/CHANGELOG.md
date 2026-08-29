# v3.x — non-LCIA method family · change log

Goal: the methods of the method diagram that do **not** compute via
`lca_generic` get a real schema + a tested base query. Additive, non-breaking.
Structure: see `PLAN.md`. _(The KI/ML paradigm, originally carried as a docking
point in v3.i, was removed on 2026-08-29 — see the v3.i section below.)_

In parallel (user): real ILCD/EPD datasets for the remaining materials — they
change the number base of v2-data, not the structure built here.

---

## v3.f — Emissions & pollutant accounting · `migration_v3f.cypher`

Methods: **1.1.4** GHG accounting by scope · **1.2.2** pollutant accounting ·
**1.1.3** water footprint (structure).
Base queries: `../../../methods/base_queries/ghg_by_scope.cypher` (new),
`../../../methods/base_queries/pollutant_inventory.cypher` (extended).

### Artifacts touched

| Artifact | Change |
|---|---|
| `Process` (all 55) | +`ghgScope` ('1'/'2'/'3'), +`ghgScopeCategory` (GHG Protocol category text), +`ghgScopeBasis`. Rule: RawMaterialProduction/Use/EndOfLife/Service → Scope 3; Manufacturing/Postprocess → Scope 2 (electricity, contract manufacturing); Assembly → Scope 1 (≈0, no on-site fossil combustion modelled). Distribution 1 / 13 / 41. |
| `Flow` (38 climate-characterised) | +`ghgSpecies` (CO₂, CH₄, N₂O, SF₆, NF₃, HFC/HCFC, PFC, other halocarbon) |
| `ImpactAssessmentMethod` `IAM_GHG` (new) | `methodStandard='GHG Protocol Corporate Standard + Scope 3 Standard'`; `HAS_CATEGORY → IC_CLIMATE` (**reused**, no new category node); `APPLIES_APPROACH → APM_GHG` |
| `Assessment` `ASSESS_GHG_<art>` (5) | aluminium demonstrator grippers; `dataVariant='B-literal'`; `APPLIES_APPROACH → APM_GHG` |
| `ImpactResult` `IR_GHG_<art>_{S1,S2,S3UP}` (15) | S1 = 0 (`status='data incomplete'`), S2 = material-independent electricity (mass·energyIntensity·0.38), S3UP = material A1 literals. **S2 + S3UP == the Variant-B climate figure** (delta 0.0 for all 5 verified) |
| `HazardStatement` (new label, 12) | GHS/CLP H-statements: H314, H317, H330, H334, H340, H350, H351, H360, H372, H400, H410, H411 |
| `Flow.hazardClass` + `(:Flow)-[:HAS_HAZARD {basis}]->(:HazardStatement)` | classes: heavy-metal (106), CMR (22), acidifying-precursor (22), VOC (20); class-based screening assignment |
| `Assessment` `ASSESS_POLLUTANT_ART_V_AL` (1) | register type, no `ImpactResult`; `APPLIES_APPROACH → APM_POLLUTANT` |
| `ImpactCategory` `IC_EF_WATER_USE` | +`referenceUnit='m3 world eq'` |
| `Assessment` `ASSESS_H2O_<art>` (5) + `ImpactResult` `IR_H2O_<art>` (5) | **shells**, `status='data incomplete'`, `value=NULL`. Diagnosis: the Al/steel datasets have no AWARE water factor; the PA66 proxy factor (~165 m³/kg) is implausible → real water inventory data pending. `APPLIES_APPROACH → APM_CF_H2O` |

### Change → affected methods

| Change | used directly by | also affects |
|---|---|---|
| `Process.ghgScope` | 1.1.4 GHG accounting | 1.1.1 LCA (scope breakdown as an extra view), 3.2.1 DPP (scope reporting), 2.1.3 consequential LCA (Scope 3 focus) |
| `Flow.ghgSpecies` | 1.1.4, 1.1.2 carbon footprint | 2.1.2 dynamic LCA (gas-specific GWP20), 2.3.3 hotspot (gas contribution) |
| `IAM_GHG` (uses `IC_CLIMATE`) | 1.1.4 | 1.1.2 (identical figure, different breakdown), 2.2.3 robustness (another result series) |
| `HazardStatement` + `HAS_HAZARD` + `Flow.hazardClass` | 1.2.2 pollutant accounting | 1.2.1 MFA (loss flows with a hazard link), 3.2.1 DPP (substance declaration REACH/ESPR), 1.1.1 LCA (human/eco-tox interpretation) |
| `IC_EF_WATER_USE.referenceUnit` | 1.1.3 water footprint | 1.1.1 LCA (category reporting) |

### Rollback

Comment block at the end of `migration_v3f.cypher` (deletes `ASSESS_GHG_*`,
`ASSESS_H2O_*`, `ASSESS_POLLUTANT_*`, `IAM_GHG`, `HAS_HAZARD`, `HazardStatement`;
removes `Process.ghgScope*`, `Flow.ghgSpecies`, `Flow.hazardClass`).

---

## v3.g — Cross-impact & scenario assessment · `migration_v3g.cypher`

Methods: **2.2.2** cross-impact analysis · **2.2.1** scenario-based environmental
assessment.
Base queries: `../../../methods/base_queries/cross_impact.cypher` (new),
`../../../methods/base_queries/scenario_compare.cypher` (new).

### Artifacts touched

| Artifact | Change |
|---|---|
| `(:Feature\|:CoreProperty\|:Material)-[:INFLUENCES {sign,strength,mechanism,evidenceLevel,source,module}]->(:ImpactCategory)` (new relationship type) | **60 edges**, 30 `+` / 30 `-`. `sign '+'` = improves the target category, `'-'` = worsens it; `strength` 1..3. 14 lever→category (Feature/CoreProperty), 42 material→category (fanned out by `materialType`), 4 category→category (trade-offs). All `evidenceLevel='engineering-reasoned'`/`'LCA-textbook'`. |
| `Assessment` `ASSESS_CROSSIMPACT_ART_V_AL` (1) | cross-impact demonstrator, no `ImpactResult` (qualitative); `APPLIES_APPROACH → APM_CROSS_IMPACT` |
| `Assessment` `ASSESS_EF31_SCEN_RECALU_<art>` (5) | `assessmentType='scenario assessment'`, `scenarioRef='SC_RECYCLED_ALU'`, `dataVariant='B-literal'`; `APPLIES_APPROACH → APM_SCENARIO_ASSESSMENT`; `UNDER_SCENARIO → SC_RECYCLED_ALU` |
| `ImpactResult` `IR_EF31_SCEN_RECALU_<art>_IC_CLIMATE` (5) | climate with a recycled-content-adjusted Al A1 factor (rc = 0.75 → 2.83 kg CO₂e/kg instead of 9.67). Saving 12–27 % vs baseline (V_AL: 1.009 → 0.741). |
| `ModelScenario` `SC_RECYCLED_ALU` | now gets computed results for the first time (previously only parameter-setting from v3.c) |

### Change → affected methods

| Change | used directly by | also affects |
|---|---|---|
| `INFLUENCES` matrix | 2.2.2 cross-impact | 2.3.1 impact chain (a qualitative layer above the LCI chain), 1.2.4 circularity + 2.3.1 repairability (whose target quantities are nodes of the matrix) |
| `ASSESS_EF31_SCEN_RECALU_*` + `IR_*` under `SC_RECYCLED_ALU` | 2.2.1 scenario assessment | 2.2.3 robustness (baseline↔scenario spread), 2.1.1 prospective LCA (scenario mechanics reused), 1.1.1/1.1.4 (a second climate figure per gripper) |
| `scenario_compare.cypher` | 2.2.1 | 2.2.3, 3.2.1 DPP (scenario view) |

### Rollback

Comment block at the end of `migration_v3g.cypher` (deletes all
`INFLUENCES {module:'v3.g'}`, `ASSESS_CROSSIMPACT_*`, `ASSESS_EF31_SCEN_RECALU_*` +
results).

---

## v3.h — Advanced LCA (light: hooks + 1 worked example each) · `migration_v3h.cypher`

Methods: **2.1.1** prospective · **2.1.2** dynamic · **2.1.3** consequential ·
**2.1.4** hybrid.
Base queries: `../../../methods/base_queries/dynamic_gwp.cypher`,
`avoided_burden.cypher`, `hybrid_eeio.cypher` (2.1.1 via `scenario_compare.cypher`
+ `SC_GRID_2035`).

### Artifacts touched

| Artifact | Change |
|---|---|
| `ModelScenario` `SC_GRID_2035` (new) | prospective, `horizonYear=2035`, DE grid CF 0.15 kg CO₂e/kWh (policy scenario) |
| `Process.marketPeriod/timeValidFrom/Until` | on manufacturing/postprocess processes (temporal validity) |
| `Assessment` `ASSESS_EF31_SCEN_GRID2035_<art>` (5) + `IR_*_IC_CLIMATE` (5) | climate of the 5 Al grippers under grid-2035; 0.35–0.74 kg CO₂e (−25…−30 % vs baseline for the electricity-heavy ones). `APPLIES_APPROACH → APM_PROSPECTIVE_LCA`, `UNDER_SCENARIO → SC_GRID_2035` |
| `(:Flow)-[:CHARACTERIZES_DYNAMIC {timeHorizon:20, factor, metric:'GWP20', source:'IPCC AR6'}]->(:ImpactCategory)` (new relationship type) | 6 edges: CO₂ 1, CH₄ fossil 82.5, CH₄ biogenic 80.3, N₂O 273, SF₆ 18300 |
| `(:EndOfLifeRoute {EOL_RECYCLING})-[:AVOIDS {ratio:0.90, module:'D', avoidedGwp_kgCO2e_per_kg:8.2}]->(:Process {PROC_ALU_EXTRUSION_EF})` (new relationship type) | module-D recycling credit → avoided primary aluminium (0.90 × (9.67 − 0.55)) |
| `Process` `PROC_ALU_SECONDARY_MARGINAL` (new) + `(:Process)-[:SUBSTITUTES]->(:Process)` (new relationship type) | secondary aluminium (marginal, remelt, 0.55 kg CO₂e/kg) displaces primary |
| `Process.marketType` ('average'/'marginal') | `PROC_ALU_EXTRUSION_EF` = average, secondary = marginal |
| `EEIOSector` (new label, 4) | C25 metal products 0.80 · C22 plastics 1.20 · D35 electricity 1.50 · H49 transport 0.90 kg CO₂e/EUR (EXIOBASE-3 order of magnitude) |
| `(:CostItem)-[:COVERED_BY_EEIO {monetaryValue, currency}]->(:EEIOSector)` (new relationship type) | 5 edges (all CostItems → C25); hybrid €-uplift |
| `Assessment` `ASSESS_DYNLCA_ART_V_AL` / `ASSESS_CONSEQ_ART_V_AL` / `ASSESS_HYBRID_ART_V_AL` (1 each) | demonstrators, `status='partial'`; `APPLIES_APPROACH → APM_DYNAMIC_LCA` / `APM_CONSEQUENTIAL_LCA` / `APM_HYBRID_LCA` |

### Result evidence

- **Dynamic:** V_AL climate GWP20 = 0.557 vs GWP100 = 0.509 (+9.6 %, methane in
  the aluminium upstream mix).
- **Consequential:** module-D credit −0.29 (V_AL) … −0.07 (PREC) kg CO₂e/gripper.
- **Hybrid:** EEIO uplift 0.026 … 0.115 kg CO₂e/gripper (material cost × 0.80).
- **Prospective:** V_AL 1.009 (baseline) → 0.737 (grid 2035).

### Change → affected methods

| Change | used directly by | also affects |
|---|---|---|
| `SC_GRID_2035` + results | 2.1.1 prospective LCA | 2.2.1 scenario assessment (another scenario), 2.2.3 robustness |
| `CHARACTERIZES_DYNAMIC` (GWP20) | 2.1.2 dynamic LCA | 1.1.4 GHG (time-horizon sensitivity), 2.3.2 sensitivity |
| `AVOIDS` / `SUBSTITUTES` / `marketType` | 2.1.3 consequential LCA | 1.2.4 circularity (recycling credit ↔ MCI), EPD module D |
| `EEIOSector` + `COVERED_BY_EEIO` | 2.1.4 hybrid LCA | 1.3.1 MFCA / 1.3.2 eco-efficiency (monetary coupling) |

### Rollback

Comment block at the end of `migration_v3h.cypher`.

---

## v3.i — External frameworks + self-describing KG · `migration_v3i.cypher`

> **Addendum 2026-08-29:** the KI/ML docking points from this migration
> (`PredictionModel` `PM_GWP_SURROGATE`, `Recommendation`
> `REC_DEMO_LIGHTWEIGHT_CONTACT`, `ASSESS_AI_PREPARED`, the 5+2 taxonomy nodes
> `APM_*`/`APG_*`, the relationship types `PREDICTS`/`ESTIMATED_BY`/`RECOMMENDS_FOR`)
> have been removed from graph and docs — out of the case-study scope.
> Migration + rollback: `../consistency/remove_ki_stubs.cypher`. The KI rows
> below are historical. `ExternalFramework` + `MAPS_TO` stay (now 12, +ISO 14067
> / EN 45554 from DE-02).

Methods: **1.3.3** SEEA / environmental-economic accounting · **3.2.2**
environmental knowledge graph.
Base queries: `../../../methods/base_queries/framework_coverage.cypher`,
`kg_self_description.cypher`.

### Artifacts touched

| Artifact | Change |
|---|---|
| `ExternalFramework` (new label, 10) | SEEA-EA, GHG Protocol, EN 15804+A2, ISO 14040/44, ISO 14046, ISO 14051, ISO 14045, ISO 59020, PEF/EF3.1, ESPR/DPP |
| `(:ImpactAssessmentMethod\|:AssessmentApproach\|:ImpactCategory\|:Declaration)-[:MAPS_TO {element}]->(:ExternalFramework)` (new relationship type) | 12 edges; each method/approach/declaration bound to its framework |
| `Assessment` `ASSESS_SEEA_ART_V_AL` (1) | register type, no `ImpactResult`; `status='prepared'`; `APPLIES_APPROACH → APM_EEA` |
| `Assessment` `ASSESS_ENVKG` (1) | the graph itself as a transparency artifact; `APPLIES_APPROACH → APM_ENV_KG`; the "result" = `kg_self_description.cypher` |
| ~~`PredictionModel` (new label, 1) `PM_GWP_SURROGATE`~~ | *(removed 2026-08-29)* `kind='surrogate'`, `target='IC_CLIMATE'`, `status='prepared'`, no weights; `(:PredictionModel)-[:PREDICTS]->(:ImpactCategory)` |
| ~~`Recommendation` (new label, 1) `REC_DEMO_LIGHTWEIGHT_CONTACT`~~ | *(removed 2026-08-29)* `status='prepared'`, `provenance='illustrative'`; `(:Recommendation)-[:RECOMMENDS_FOR]->(:Artifact)` |
| ~~`(:ImpactResult)-[:ESTIMATED_BY {provenance:'illustrative'}]->(:PredictionModel)`~~ | *(removed 2026-08-29)* 1 type-defining edge, clearly marked as not predicted |
| ~~`Assessment` `ASSESS_AI_PREPARED` (1)~~ | *(removed 2026-08-29)* marker; `APPLIES_APPROACH` → the 5 KI taxonomy nodes |

**Result (historical):** taxonomy nodes with an assessment now 20 of 29
(was 9). All 29 methods addressable; the KI methods explicitly only *prepared*
(no ML logic in the graph). *(After the KI/ML removal: 23 methods, of which the
non-KI markers stay.)*

### Change → affected methods

| Change | used directly by | also affects |
|---|---|---|
| `ExternalFramework` + `MAPS_TO` | 1.3.3 SEEA mapping | EPD/DPP (3.2.1 — standard reference), every inventory method (standard conformity visible) |
| `kg_self_description.cypher` | 3.2.2 environmental KG | reporting/navigation, consistency review |
| ~~`PredictionModel` / `Recommendation` / `ESTIMATED_BY`~~ | *(removed)* 3.1.x / 3.3.1–2 docking points | — |

### Rollback

Comment block at the end of `migration_v3i.cypher`.

---

## Live DB after v3.h + v3.i

**4 690 nodes · 86 001 relationships · 39 labels · 53 relationship types ·
37 constraints.** 0 label-less nodes · 0 valueless "calculated" results ·
0 orphan assessments. New labels (v3.h/i): `EEIOSector`, `ExternalFramework`,
`PredictionModel`, `Recommendation`. New relationship types:
`CHARACTERIZES_DYNAMIC`, `AVOIDS`, `SUBSTITUTES`, `COVERED_BY_EEIO`, `MAPS_TO`,
`PREDICTS`, `ESTIMATED_BY`, `RECOMMENDS_FOR`.

*(After the KI/ML removal 2026-08-29: `PredictionModel` / `Recommendation` and
`PREDICTS` / `ESTIMATED_BY` / `RECOMMENDS_FOR` are gone. Final live DB —
5 620 / 86 635 / 39 / 54 / 39 — see `../consistency/` and
`../../reference/EXTENSION_REFERENCE.md`.)*
