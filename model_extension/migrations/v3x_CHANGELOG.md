# v3.x modules — change log

> Per-module history, chronological. The counters in the individual entries are
> **states at the time of that run**, not the current model state. Current
> state: [`../reference/EXTENSION_REFERENCE.md`](../reference/EXTENSION_REFERENCE.md)
> — live DB 2026-08-29: 5 620 nodes / 86 635 relationships / 39 labels /
> 54 relationship types / 39 constraints.

## 2026-08-27 — Modules a–d in one run, with a repair pass

All four v3.x modules applied additively and verified. A repair pass
(`v3x_repair.cypher`) fixed two migration bugs (below). Live DB after
**2 917 nodes / 80 298 relationships**, 36 constraints, no label-less nodes, no
duplicate nodes.

---

### v3.a — Circularity (simplified MCI) · `v3x_a_circularity/`

`migration_v3a.cypher` · base query: MCI is stored as `Material.mci` +
`ImpactResult`.

| New | |
|---|---|
| `ImpactAssessmentMethod` `IAM_MCI` + `ImpactCategory` `IC_CIRCULARITY` (`indicator:'MCI'`) | + `HAS_CATEGORY`, `APPLIES_APPROACH → APM_CIRCULARITY` |
| `EndOfLifeRoute` (label) | 4 nodes: Recycling, Reuse, Energy recovery, Landfill |
| `(:Material)-[:HAS_EOL_ROUTE {fraction, basis}]->(:EndOfLifeRoute)` | 60 edges (class defaults) |
| `Material` +`recyclingRate`, `reusability`, `recycledContentAssumed`, `circularityBasis`, `mci`, `mciMethod` | all 23 |
| `Artifact` +`designLifetime`, `referenceLifetime`, `lifetimeBasis` | all 43 (neutral: 5 y = 5 y → utility factor 1) |
| `Assessment` `ASSESS_MCI_<art>` + `ImpactResult` `IR_MCI_<art>` | 5 each (aluminium grippers with part masses) |

**Result (material MCI, simplified linear):** metal 0.65 · polymer 0.33 ·
elastomer 0.16 · composite 0.14. Formula documented in the migration header
(reuse feedstock 0, utility factor 1, recycling efficiency 0.9). All inputs are
**class defaults** (`basis` property).

---

### v3.b — Cost dimension + MFCA/eco-efficiency (prototype) · `v3x_b_cost/`

`migration_v3b.cypher` · `mfca.cypher` (query fixed 2026-08-27: cartesian
multiplication of the cost sum by the loss-flow `OPTIONAL MATCH` fixed →
`FLAT_AL` 0.078 EUR instead of a wrong 0.70)

| New | |
|---|---|
| `CostItem` (label) + `(:Part)-[:HAS_COST]->(:CostItem)` | 5 material cost items (aluminium path) |
| `Material` +`unitCost`, `costUnit`, `costBasis` | 18 real materials, **placeholder** EUR/kg by class (metal 4 / polymer 6 / elastomer 12 / composite 40) |
| `Flow` +`mfcaClass` | `FLOW_COMPONENT`=product, `FLOW_WASTE`=material-loss |
| `Assessment` +`productSystemValue`, `productSystemValueUnit`, `productSystemValueBasis` | 5 EF3.1 assessments (placeholder) |

All monetary values are explicitly prototype placeholders.

---

### v3.c — Parameter/scenario layer + uncertainty · `v3x_c_scenario/`

`migration_v3c.cypher` · `hotspot.cypher`

| New | |
|---|---|
| `HAS_FLOW` +`uncertaintyDistribution` (=`lognormal`), `uncertaintyBasis` | 40 671 edges (where `uncertainty` is set) |
| `Parameter`, `ParameterValue`, `ModelScenario` (labels) | 1 / 1 / 2 (`SC_BASELINE`, `SC_RECYCLED_ALU`) |
| `(:Parameter)-[:PARAM_OF]->`, `(:ModelScenario)-[:SETS]->(:ParameterValue)-[:FOR]->(:Parameter)` | 1 each — illustrative scenario "recycled aluminium 0.35→0.75" on `MAT_AL6061` |
| `(:Assessment)-[:UNDER_SCENARIO]->(:ModelScenario)` + `Assessment.scenarioRef` + `ImpactResult.scenarioRef` | all 96 assessments → `SC_BASELINE` |
| `hotspot.cypher` | contribution ranking of the dataset flows per category (pure query) |

---

### v3.d — Provenance / EPD/DPP · `v3x_d_provenance/`

> **Addendum 2026-08-29:** the KI/ML docking points (`PredictionModel`,
> `Recommendation`, vocabulary `ml-model`/`surrogate-model`) have been removed
> from graph and docs — out of the case-study scope. See
> `consistency/remove_ki_stubs.cypher`. The rest of v3.d (`IAM_REPAIR`,
> `BASED_ON`, `Declaration`, sustainability `Requirement`) stays.

`migration_v3d.cypher`

| New | |
|---|---|
| `ImpactAssessmentMethod` `IAM_REPAIR` + `ImpactCategory` `IC_REPAIRABILITY` | repairability becomes a first-class assessment result |
| `Assessment` `ASSESS_REPAIR_<art>` + `ImpactResult` `IR_REPAIR_<art>` | 43 each, `value = disassemblyReversibility` (from v1), `provenance:'expert-estimate'`, `confidence:0.6` |
| `(:ImpactResult)-[:BASED_ON]->(:CoreProperty\|:Feature)` | 57 edges (→ `CP_DISASSEMBLY`, `FEAT_EASY`/`FEAT_PRINTABLE`) — traceability edge (gap 4) |
| `Declaration` (label) + `[:DECLARES]`, `[:REPORTS]` | `DECL_EPD_ART_V_AL` (EN 15804+A2, 7 results) + `DECL_DPP_ART_V_AL` (ESPR draft, 9 results) for `ART_V_AL` |
| `Requirement` +`sustainabilityIndicatorRef/Threshold/Operator/Unit/Scope/Basis` | 1 demonstrator (`REQ_COMPAT`: GWP ≤ 0.5 kg CO₂-eq) |
_(The types `PredictionModel` / `Recommendation` and the `ml-model`/
`surrogate-model` vocabulary originally defined here were removed 2026-08-29 —
see above.)_

---

## Repair pass · `v3x_repair.cypher`

Two bugs in v3.a/v3.c/v3.d, caused by `;`-separated Cypher statements being
**independent** (variables from earlier statements not bound):

1. **MERGE path trap:** `MERGE (as)-[:APPLIES_APPROACH]->(:AssessmentApproach {id:...})`
   **created** the approach node instead of matching it → 48 duplicate
   `AssessmentApproach`. Fixed with `apoc.refactor.mergeNodes` (back to 41), the
   missing `AssessmentApproach_id_unique` constraint added.
2. **Scoping:** `MERGE (m)-[:HAS_CATEGORY]->(ic)` with `m`/`ic` from a previous
   statement created label-less nodes (later removed) → `IAM_MCI`/`IAM_REPAIR`
   without `HAS_CATEGORY`. Re-linked.

Additionally, 7 uniqueness constraints added for the new v3.x labels
(`AssessmentApproach`, `EndOfLifeRoute`, `CostItem`, `Declaration`,
`ModelScenario`, `Parameter`, `ParameterValue`). The migration files v3.a/v3.d
were corrected to the safe pattern (always re-`MATCH` by id).

**Lesson for future migrations:** in `.cypher` files, never use a variable
across a `;`, and never leave an existing node as an inline pattern inside a
path `MERGE` — always `MATCH` it separately first.
