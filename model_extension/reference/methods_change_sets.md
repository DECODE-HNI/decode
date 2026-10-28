# Master spec: change set per assessment method

As of 2026-08-27 (spec + progress of that run). Belongs to
[`model_extension/migrations/PLAN.md`](../migrations/PLAN.md). Basis: live inspection
at the starting point (2,721 nodes / 79,647 relationships) and the
method diagram (3 paradigms / 9 groups / 29 approaches; after the
AI removal on 2026-08-29, 3.1.x/3.3.x are gone → 7 groups / 23 approaches).
**Current state:** [`model_extension/reference/EXTENSION_REFERENCE.md`](EXTENSION_REFERENCE.md)
— live DB 2026-08-29: 5,620 nodes / 86,635 relationships / 6 methods.

This document states **per approach** which nodes / edges / properties /
vocabularies / data / queries are needed, in which stage they sit, and
**which other approaches share the same change**.

---

## 0. Reading guide

**Change tokens**

| Token | Meaning |
|---|---|
| `P` | new property (node or edge) |
| `V` | controlled value list for a property |
| `R` | new relationship type |
| `N` | new label |
| `D` | data load (no schema) |
| `Q` | query only, no schema change |
| `~` | normalise / correct existing content |

**Stages** (see PLAN.md)

| Stage | Box | In short |
|---|---|---|
| **v1** | black | product model + concrete attributed indicators + repairability |
| **v2** | grey | ILCD/EF3.1 inventory + calculation core (`ImpactResult.value`, `lca_computed_ef31`) |
| **v3** | white | ILCD interpretable: `lca_generic($methodId)`, functional unit, modules, category hygiene, method taxonomy, 2nd LCIA method |
| **v3.x** | white + module | composable method families (a circularity · b cost · c scenario/uncertainty · d provenance/declaration) |

**Principle:** migrations run against the live DB; the stage snapshots are
filtered exports of the same state. Every stage is strictly additive.

---

## 1. Cross-cutting prerequisites (PRE)

One-off, carry several approaches at the same time.

| ID | Stage | Change | Tokens |
|---|---|---|---|
| **PRE‑1** | v2 | `P ImpactResult.value, .valueLow, .valueHigh, .computedAt, .provenance` + `V provenance=[LCI-calculated, measured, literature, ml-predicted, expert-estimate]` — today `ImpactResult` has **no** numeric value | 5P, 1V |
| **PRE‑2** | v3 | `P Process.lifecycleModule` + `V` EN15804 `[A1,A2,A3,A1-A3,A4,A5,B1..B7,C1..C4,D]` + `D` backfill ~55 processes (source: free-text names "… (EN15804 A1-A3)" + `processType`) + `~ Process.processType` (`EndOfLife` vs. "End of Life") | 1P,1V,1D,1~ |
| **PRE‑3** | v3 | `P Assessment.functionalUnit, .referenceFlow, .referenceQuantity, .referenceUnit, .systemBoundary` + `V systemBoundary=[cradle-to-gate, cradle-to-grave, gate-to-gate, cradle-to-cradle]` | 5P,1V |
| **PRE‑4** | v3 | Method taxonomy: `N AssessmentApproach{id,name,level,code}` + `R (AssessmentApproach)-[:BROADER]->(AssessmentApproach)` + `R (Assessment)-[:APPLIES_APPROACH]->(AssessmentApproach)` + `D` 3 paradigms / 9 groups / 29 approaches from the diagram | 1N,2R,1D |
| **PRE‑5** | v3 | `~` ImpactCategory hygiene: merge ~20 orphans / near-duplicates (`IC_EF_CLIMATE_BIOGENIC` vs `IC_EF_CLIMATE_CHANGE_BIOGENIC`, 3× ecotoxicity freshwater …), normalise `indicator`/`unit` (partly torn apart, e.g. `indicator=" freshwater"`) | 1~ (large) |

Category state at the time: 42 `ImpactCategory` nodes, of which 22 are attached to `IAM_EF31`
(`HAS_CATEGORY`), 1 to `IAM_PCF`, 20 orphaned.

---

## 2. Paradigm "accounting approaches" — focus, largely in the model

### 2.1 Life-cycle-based environmental assessment

#### Life cycle assessment (LCA, ISO 14040/44)
- **What:** Complete multi-category LCIA. `Artifact → ProcessPlan → CONTAINS_PROCESS → Process → HAS_FLOW → Flow → CHARACTERIZES → ImpactCategory`, filtered per method.
- **Stage:** v2 (EF3.1, single-method calculation) → v3 (method-agnostic)
- **Uses:** the complete ILCD structure (2,102 `Flow`, 49,672 `HAS_FLOW`, 27,768 `CHARACTERIZES`), `IAM_EF31`
- **Δ schema:** PRE‑1 (v2), PRE‑2/PRE‑3/PRE‑4/PRE‑5 (v3)
- **Δ data:** `D` attach the remaining EF3.1 categories to `HAS_CATEGORY`, check CF coverage
- **Base query:** v2 `lca_computed_ef31($artifactId)` = Σ `CONTAINS_PROCESS.share · HAS_FLOW.amount · CHARACTERIZES.factor` per category → `ImpactResult.value`; v3 `lca_generic($methodId, $artifactId)`
- **Change set:** beyond PRE: 1D, 1Q (v2) + 1Q refactor (v3)
- **Affected methods:** all following LCA derivatives (CF, H₂O, GHG, CED) hang on the same query + PRE‑1

#### Carbon footprint (CO₂, ISO 14067)
- **What:** LCA subset = climate change categories only (fossil / biogenic / LULUC).
- **Stage:** v2 (exists as `IAM_PCF`) → v3 (clean sub-categories)
- **Uses:** `IAM_PCF`, `IC_CLIMATE` + EF climate sub-categories
- **Δ schema:** none beyond PRE
- **Δ data:** `D` bundle the GWP sub-categories under one PCF approach
- **Base query:** `carbon_footprint.cypher` = `lca_generic` with `methodId='IAM_PCF'`
- **Change set:** 1D, 1Q
- **Affected methods:** greenhouse gas accounting (shares GWP categories), EPD/DPP (reports PCF)

#### Water footprint (H₂O, ISO 14046)
- **What:** subset = water use, regionalised.
- **Stage:** v3
- **Uses:** `IC_EF_WATER_USE`, `CHARACTERIZES.location` (224 regions already present)
- **Δ schema:** none
- **Δ data:** `D` method instance `IAM_WATER` (AWARE) + `HAS_CATEGORY` → water category; `D` AWARE CFs as `CHARACTERIZES{factor,location}` for water flows; check `Flow.category` "water"
- **Base query:** `water_footprint.cypher`
- **Change set:** 2D, 1Q
- **Affected methods:** —

#### Greenhouse gas accounting (GHG Protocol)
- **What:** like CF, but structured by **Scope 1/2/3** instead of by life cycle modules.
- **Stage:** v3
- **Uses:** GWP categories, `lca_generic`
- **Δ schema:** `P Process.ghgScope` + `V [scope1,scope2,scope3]`; opt. `P Process.ghgScope3Category`
- **Δ data:** `D` classify ~55 processes by scope
- **Base query:** `ghg_inventory.cypher` = GWP grouped by `ghgScope`
- **Change set:** 1–2P, 1V, 1D, 1Q
- **Affected methods:** shares GWP categories with CF; classifier design identical to PRE‑2 (`lifecycleModule`)

### 2.2 Substance- and resource-related accounting

#### Substance and material flow analysis (MFA)
- **What:** mass balance of the flows through a defined system boundary.
- **Stage:** v3
- **Uses:** `HAS_FLOW{amount,unit,direction}`, `Flow.flowType`, `Flow.referenceUnit`, `Material.density_kg_m3`, `CONTAINS_PROCESS.sequence`
- **Δ schema:** `P Flow.balanceRole` + `V [input,product,coproduct,emission,waste,resource]`; opt. `N SystemBoundary` + `R (Assessment)-[:HAS_BOUNDARY]->(SystemBoundary)` + `R (SystemBoundary)-[:INCLUDES]->(Process)`
- **Δ data:** `D` tag flows; volume→mass via `referenceUnit` + density
- **Base query:** `mfa_balance.cypher` = mass in/out per process, Δ = imbalance
- **Change set:** 1P, 1V, 1D, 1Q (+ opt 1N, 2R)
- **Affected methods:** circularity (uses material shares), MFCA (same flow classification product/loss)

#### Pollutant accounting
- **What:** filter on hazardous substances, sum per substance/compartment.
- **Stage:** v3
- **Uses:** `Flow.casNumber`, `Flow.category`, `HAS_FLOW.amount`
- **Δ schema:** `P Flow.hazardClass` (String[]) + `V [SVHC,CMR,PBT,vPvB,GHS-H…]` **or** `N HazardStatement{code,ghs}` + `R (Flow)-[:HAS_HAZARD]->(HazardStatement)`
- **Δ data:** `D` annotate hazardous flows (subset with CAS)
- **Base query:** `pollutant_inventory.cypher`
- **Change set:** 1P, 1V, 1D, 1Q *(or 1N, 1R, 1D, 1Q)*
- **Affected methods:** digital product passport (SVHC reporting), human toxicity categories (plausibility check)

#### Cumulative energy demand (CED / KEA, VDI 4600)
- **What:** sum of primary energy, renewable / non-renewable.
- **Stage:** v3
- **Uses:** `IC_ENERGY` ("Energy demand", MJ), `lca_generic`
- **Δ schema:** `P Flow.energyResourceType` + `V [renewable,non-renewable,nuclear]`
- **Δ data:** `D` method instance `IAM_CED`; 3 category instances (CED total/renewable/non-renewable); `D` CED CFs as `CHARACTERIZES{factor}` from primary energy resource flows
- **Base query:** `ced.cypher` = `lca_generic` with `methodId='IAM_CED'`
- **Change set:** 1P, 1V, 3D, 1Q
- **Affected methods:** eco-efficiency (can use CED as denominator), prospective LCA (energy mix scenarios)

#### Circularity assessment (MCI, Ellen MacArthur)  → **module v3.a**
- **What:** material circularity index per part, mass-weighted per artifact.
- **Stage:** v3.a
- **Uses:** `USES_MATERIAL.fraction`, `Material.recycledContent_pct` (note: actually NULL everywhere), `HAS_COMPONENT.quantity`, `Artifact.componentCount`/`distinctMaterialCount`/`disassemblyReversibility` (from v1!), `Process{processType:'EndOfLife'}` + `CONTAINS_PROCESS.share`
- **Δ schema:** `P Material.recyclingRate, .recyclability, .reusability`; `P Artifact.designLifetime, .usageIntensity, .referenceLifetime`; `N EndOfLifeRoute{id,name,type}` + `R (Material)-[:HAS_EOL_ROUTE{fraction}]->(EndOfLifeRoute)` *(or use* `P Process.eolRouteType` *instead)*
- **Δ data:** `D` 1 category instance `IC_CIRCULARITY{indicator:'MCI',unit:'dimensionless'}`; circularity parameters for ~23 `Material`; EoL shares; `D` real `recycledContent_pct` values (data gap!)
- **Base query:** `mci.cypher` = V (virgin), W (waste), utility factor, LFI, MCI
- **Change set:** ~6P, (1N + 1R or 1P), 2D, 1Q
- **Affected methods:** uses v1 repairability; feeds EPD/DPP; consequential LCA (module D / avoided burden)

### 2.3 Integrated ecological-economic accounting  → **module v3.b (prototype)**

**Cost dimension** (today **no** economic property in the graph):

| Variant | Change | For |
|---|---|---|
| **A lean** | `P Material.unitCost,.costUnit`; `P Process.unitCost,.costUnit`; `P CONTAINS_PROCESS.costShare`; `P HAS_FLOW.unitCost` | eco-efficiency, rough cost view |
| **B structured** *(recommended)* | `N CostItem{category,amount,currency,perUnit}` + `R (Process\|Part\|Material\|Flow)-[:HAS_COST]->(CostItem)` + `V category=[material,energy,system,waste-management,capital,labour]` | MFCA (needs separation of cost types), hybrid LCA |

#### Material flow cost accounting (MFCA, ISO 14051)
- **What:** cost per material stream, product path vs. loss path.
- **Stage:** v3.b
- **Uses:** cost B, `HAS_FLOW.amount`, `Flow.flowType`
- **Δ schema:** cost B + `P Flow.mfcaClass` + `V [product, material-loss]`
- **Δ data:** `D` CostItems per process; classify output flows
- **Base query:** `mfca.cypher` = input costs → product vs. loss path by mass share; roll up the "cost of waste"
- **Change set:** [1N,1R,1V] + 1P, 1V, 1D, 1Q
- **Affected methods:** eco-efficiency (value basis), hybrid LCA (monetary I-O), MFA (flow product/loss)

#### Eco-efficiency assessment (ISO 14045)
- **What:** environmental impact ÷ product/system value.
- **Stage:** v3.b
- **Uses:** LCA result (v2/v3) + cost or price
- **Δ schema:** `P Assessment.productSystemValue, .productSystemValueUnit`
- **Δ data:** `D` 1 category instance `IC_ECOEFF`; choose the value basis (MFCA cost / price / functional output)
- **Base query:** `eco_efficiency.cypher` = chosen `ImpactResult.value` ÷ `productSystemValue`
- **Change set:** 2P, 1D, 1Q
- **Affected methods:** depends on LCA + MFCA

#### Environmental-economic accounting (SEEA)
- **What:** macroeconomic accounts framework.
- **Stage:** — (not computed in the KG)
- **Δ schema:** documentation hook only: `N ExternalFramework{id,name,url}` + `R (Assessment)-[:REPORTS_TO]->(ExternalFramework)`
- **Base query:** —
- **Change set:** 1N, 1R, 0 calculation
- **Affected methods:** —

---

## 3. Paradigm "data-driven approaches" — compact, no focus right now

**Building block C — parameter/scenario layer** (prerequisite for 3.1 partly, 3.2, 3.3), **module v3.c**:
`N ModelScenario{id,name,type,horizonYear}` · `N Parameter{id,name,unit,baseValue}` ·
`N ParameterValue{value,unit}` · `R (Parameter)-[:PARAM_OF]->(Process\|Part\|Material\|Assessment)` ·
`R (ModelScenario)-[:SETS]->(ParameterValue)` · `R (ParameterValue)-[:FOR]->(Parameter)` ·
`R (Assessment)-[:UNDER_SCENARIO]->(ModelScenario)` · `P ImpactResult.scenarioRef`
→ **3N, 4R, 1P**. Important: kept separate from the existing gripping `Scenario`s (17×, `scenarioType:'gripping'`).

### 3.1 Prospective life-cycle-based environmental assessment

| Approach | Stage | Δ beyond building block C | Amount | Affected methods |
|---|---|---|---|---|
| **prospective life cycle assessment** | v3.c | `P ModelScenario.horizonYear`; `D` scenario-overridden background values | 1P, 1D, 1Q | CED (energy mix), consequential LCA |
| **dynamic life cycle assessment** | v3.c+ | `P HAS_FLOW.emissionTiming`; `R (Flow)-[:CHARACTERIZES_DYNAMIC{timeHorizon,factor}]->(ImpactCategory)`; `D` time-resolved CF | 1P, 1R, 1D, 1Q *(larger)* | CF (GWP time horizon) |
| **consequential life cycle assessment** | v3.c | `P Process.modelingApproach` + `V [attributional,consequential]`; `R (Process)-[:SUBSTITUTES{ratio}]->(Process)`; `R (Process)-[:AVOIDS]->(Flow)`; `D` marginal processes | 1P, 1V, 2R, 1D, 1Q | circularity (module D), prospective LCA |
| **hybrid life cycle assessment** | v3.b+c | `N EEIOSector{id,name,region,emissionIntensity,unit}` + `R (Process)-[:COMPLEMENTED_BY{monetaryAmount,currency}]->(EEIOSector)` + cost B; `D` sector intensities | 1N, 1R, 1D, 1Q *(low priority)* | MFCA (monetary basis) |

### 3.2 Scenario-based environmental assessment

| Approach | Stage | Δ beyond building block C | Amount | Affected methods |
|---|---|---|---|---|
| **scenario-supported assessment** | v3.c | `D` scenario set | 1D, 1Q | all v3.c approaches |
| **cross-impact analysis** | v3.c | `R (Parameter\|Function\|ImpactCategory)-[:INFLUENCES{sign,strength}]->(…)`; `D` influence matrix | 1R, 1D, 1Q | impact chain analysis |
| **robustness and resilience analysis** | v3.c | none; opt. `P Assessment.robustnessIndex` | 0–1P, 1Q | uncertainty/sensitivity analysis |

### 3.3 Impact and uncertainty analyses

| Approach | Stage | Δ | Amount | Affected methods |
|---|---|---|---|---|
| **impact chain analysis** | v3 / v3.d | `R (ImpactResult)-[:BASED_ON]->(Feature\|CoreProperty\|DataItem)` (gap 4); `Q` variable-length path `Requirement→…→ImpactCategory` | 1R, 1Q | cross-impact |
| **uncertainty & sensitivity analysis** | v3.c | `P HAS_FLOW.uncertaintyDistribution` + `V [lognormal,normal,uniform,triangular]`, `.uncertaintyGSD/.min/.max`; `P CHARACTERIZES.uncertainty`; `P Parameter.uncertainty*`; `Q` OAT sensitivity | ~5P, 1V, 1Q | robustness; basis: `HAS_FLOW.uncertainty` 82 % populated (40,671/49,672) |
| **hotspot analysis** | v2 | none; `Q` contribution ranking of processes/flows per category | 1Q | all LCA approaches |

---

## 4. Provenance + declaration  → **module v3.d**

> **2026-08-29:** The paradigm "learning approaches" (AI/ML — environmental impact
> forecasts, AI-based LCA modelling, surrogate/approximation models, learning
> scenario models, predictive environmental impact assessments, automated design
> recommendation) is, by the user's decision, **not** part of the case study and has been
> removed from the graph and the docs — `model_extension/migrations/consistency/remove_ki_stubs.cypher`.
> What **remains** of the original v3.d docking-point set (because it is implemented and
> AI-independent):

`P ImpactResult.confidence` (+ `.provenance` from PRE‑1) ·
gap 4 `R (ImpactResult)-[:BASED_ON]->(Feature|CoreProperty|DataItem)` ·
`N Declaration{id,type:[EPD,DPP],standard,functionalUnit,validFrom,validUntil}`
+ `R (Declaration)-[:DECLARES]->(Artifact)` + `R (Declaration)-[:REPORTS]->(ImpactResult)` ·
`P Requirement.sustainabilityIndicatorRef/Threshold/Operator/Unit/Scope` (from the RFLPV² spec).

| Approach | Stage | Contribution in the KG | Amount |
|---|---|---|---|
| **Digital product passport** | v3.d | `Declaration{type:'DPP'}` — reporting view over material, recycled content, EoL, PCF, SVHC, repairability (v1!) | shares `Declaration` with EPD |
| **Environmental knowledge graph** | — | *is this project* — substrate, no change | 0 |

EPD (EN 15804) is not a sheet of its own in the diagram, but comes along automatically with
`Declaration{type:'EPD'}` + PRE‑2 (modules) + PRE‑3 (functional unit).

---

## 5. Consolidated building blocks beyond the 5 known gaps

The 5 "flexibility gaps" from the original analysis:
1 `Process.lifecycleModule` · 2 functional unit · 3 extend `ASSESSES` to Part/Material/Process/ProcessPlan ·
4 `ImpactResult -[:BASED_ON]->` · 5 property additions (recyclability, service life, joining type).

In addition, from the method diagram:

| # | Building block | Stage | Unlocks | Effort |
|---|---|---|---|---|
| **A** | Method taxonomy as data (`AssessmentApproach`) | v3 (PRE‑4) | each of the 29 methods explicitly in the graph | small |
| **L** | `ImpactResult.value` (+ interval, `computedAt`) | v2 (PRE‑1) | every quantitative method + all downstream analyses | small, essential |
| **M** | ImpactCategory hygiene | v3 (PRE‑5) | reliable multi-category methods (EF3.1, ReCiPe, CML) | medium |
| **C** | Parameter/model scenario layer | v3.c | the entire "data-driven" paradigm | large, high leverage |
| **B** | Economic dimension (`CostItem`) | v3.b | MFCA, eco-efficiency, hybrid LCA | large |
| **D** | Time dimension (emission timing, time-dependent CF) | v3.c+ | dynamic & prospective LCA | medium–large |
| **E** | Uncertainty metadata (`{distribution,params}`) | v3.c | uncertainty/sensitivity, robustness | medium (basis 82 % populated) |
| **F** | Classifier tags (scope 1/2/3, attributional/consequential, water scarcity) | v3 | GHG accounting, consequential LCA, water footprint | small |
| **G** | `SUBSTITUTES`/`AVOIDS` edge | v3.c | consequential LCA, circularity module D | small |
| **H** | `INFLUENCES{sign,strength}` edge | v3.c | cross-impact analysis | small |
| **J** | `ImpactResult.provenance` + `confidence` (general, not AI-specific) | v3.d | provenance marking of all results | small |
| **K** | `Declaration`/`Report` nodes | v3.d | EPD, digital product passport | medium |
| **I** | EEIO sector data | v3.b+c | hybrid LCA | large, low priority |

---

## 6. Order

> **Progress 2026-08-27 (autonomous run):** fully implemented —
> v1 · v2-minimal · v3-minimal · v3.x modules **a–e** (a circularity/MCI ·
> b cost/MFCA prototype · c parameter/scenario/uncertainty layer ·
> d provenance + repairability-as-result + EPD/DPP · **e ReCiPe 2016 Midpoint**) ·
> **v2-data** (part masses of all 86 parts, manufacturing energy, material GWP literals;
> variants **A** real-only and **B** literal full coverage, in parallel via `dataVariant`) ·
> **PRE‑5** (ImpactCategory 44→29 canonicalised, EF3.1 computes 19 instead of 7 categories) ·
> repair pass `v3x_repair.cypher`.
> Docs: `model_extension/reference/EXTENSION_REFERENCE.md`, `ASSUMPTIONS.md`,
> `model_extension/reference/graph_schema_v3x.json`, `methods/onepagers/` (now 23),
> `model_extension/reference/change_method_matrix.csv`, `CHANGELOG.md` per module.
> **Live DB (final state 2026-08-29, after v3.f–i · LCI hygiene · DQ concept ·
> demonstrator slice · consistency review layers 1–4 · AI removal):**
> 5,620 nodes / 86,635 relationships / 39 labels / 54 relationship types /
> 39 constraints, 6 `ImpactAssessmentMethod`, 0 inconsistencies.
> **Decision data variant A vs. B:** made (2026-08-28) — variant A is the
> case-study standard, B remains a fallback (see `model_extension/migrations/PLAN.md`).
> **Open data tasks:** real ILCD/EPD datasets for non-Al/steel materials;
> ReCiPe factors for the 17 non-climate categories; base queries + data for the
> non-LCIA approaches (1.1.3/1.1.4/1.2.1–3/1.3.1–2/2.x).

1. **PRE** (v2: PRE‑1 · v3: PRE‑2…PRE‑5) → unlocks LCA, CF, hotspot, method taxonomy
2. **v2** calculation core + `lca_computed_ef31` → comparability
3. **v3** `lca_generic` + 2nd LCIA method (ReCiPe/CML as pure data) → interpretability
4. **v3 P1 remainder**: H₂O, GHG, MFA, pollutants, CED (each 1P–1V–a few D–1Q)
5. **v3.a** circularity → **v3.b** cost prototype → **v3.c** parameter/scenario layer → **v3.d** docking points
6. dynamic/hybrid LCA + full cross-impact: documented extension paths

Repairability / disassembly (structural-qualitative index) is already **v1**
(`migration_v1.cypher`, `repairability.cypher`), classes A/B/C. Refinements
(weighted eDIM, number of connectors, tool classes) = optional v3.x.

---

## 7. Open data gaps (live finding 2026-08-27)

| Gap | Affects |
|---|---|
| `Material.recycledContent_pct` NULL for **all** real materials | circularity/MCI, recycled-content indicator, EPD/DPP |
| `ImpactResult` without numeric value (`status:"not calculated"`) | every quantitative method → PRE‑1 |
| `Process.lifecycleModule` missing; only free-text names + inconsistent `processType` | EN15804 staging, EPD, GHG, MFA → PRE‑2 |
| no economic property | the whole group 2.3 → building block B |
| `Scenario` = gripping scenarios only | the "data-driven" paradigm needs a separate `ModelScenario` → building block C |
| ImpactCategory: 20 orphans / near-duplicates, `indicator`/`unit` partly torn apart | EF3.1/ReCiPe/CML → PRE‑5 |
| `CHARACTERIZES` without uncertainty | sensitivity analysis → building block E |
