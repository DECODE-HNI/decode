# Development stages of the sustainability knowledge graph — plan

As of 2026-08-27. Paths are relative to the repository root or to this folder.

The gripper knowledge graph is developed and documented in staged versions.
The guiding axis is **black / grey / white-box transparency of the sustainability
assessment** (not of the product model — that is already detailed). Each stage has its
own value statement for development; each stage is **strictly additive and
non-breaking** with respect to the previous one (that is the proof of flexibility).

---

## 1. Stages at a glance

| Stage | Box | Contribution to development | Limit of the stage |
|---|---|---|---|
| **v1** | black | Assess environmental impact **early and lightweight**; directly produces **evidence data** (couples to the RFLPV² verification layer: `sustainabilityResult` / `sustainabilityStatus` on the Test Case) | Key figures are set, not decomposable → no supply-chain comparability |
| **v2** | grey | **real comparability across the supply chain** — results computed from `Process→Flow` chains, variants / suppliers comparable on the same basis (EF3.1) | one method, fixed system boundary; ILCD data imported, but not semantically open |
| **v3** | white | **Interpretability + exchangeability**: the ILCD format becomes interpretable in the graph — method-agnostic query, functional unit, life cycle modules, cleaned categories, second LCIA method as pure data | — |
| **v3.x** | white + modules | **further-reaching statements** (circularity, cost, scenario/uncertainty, provenance) plug in additively | own documentation + snapshot per module |

### Proof of flexibility on three levels

1. **v1 → v2** — a new *paradigm* (inventory-based LCA) plugs in additively.
2. **within v3** — a new *metric / method* is pure data (method node +
   categories + characterisation factors), **zero schema change**.
3. **v3 → v3.x** — entire *method families* attach as orthogonal, non-colliding
   modules.

---

## 2. Precise stage definition

### v1 — Black box: product model + concrete indicators

**Contains** (20 labels, 431 nodes / 1,392 relationships, as of 2026-08-27):
Product, Artifact, Assembly, Part, Material, Feature, Form, Geometry, Function,
Behavior, SolutionPrinciple, Requirement, Specification, Scenario (gripping scenarios),
CoreProperty, DataItem, DataSource, DataQuality, DataQualityCriterion, ProcessPlan
(as plan head — process steps only come in v2).

**Does *not* contain** the ILCD/inventory LCIA types: Flow, FlowProperty, Process,
ImpactCategory, ImpactAssessmentMethod, Assessment, ImpactResult (and their edges
HAS_FLOW, CHARACTERIZES, CONTAINS_PROCESS, HAS_CATEGORY, USES_METHOD, ASSESSES,
HAS_RESULT, FOR_CATEGORY, DERIVED_FROM, APPLIES_TO, HAS_FLOW_PROPERTY).

**v1 migration (still open)** — makes v1 a *complete* simple assessment,
not just a reduced snapshot:
- Formalise repairability: `connectionType` + `reversible` on `HAS_COMPONENT`
  and/or `Feature`; **re-attach** the joining information that currently sits in
  `DataItem.valueText` = "screw (reversible)" (attached to a *Process* "Screw fastening"),
  so that it survives without the ILCD layer.
- Repairability/disassembly index as `CoreProperty` (propertyType `sustainability`)
  + base query `repairability.cypher`.
- Further concrete indicators attributed directly: mass, recycled-content roll-up,
  declared GWP value, energy — as `CoreProperty` / `ImpactResult` with a
  **literal** value (no derivation).

### v2 — Grey box: ILCD/EF3.1 inventory + calculation

Adds: `Process`–`HAS_FLOW`–`Flow`, `FlowProperty`, `CHARACTERIZES`→`ImpactCategory`,
`ImpactAssessmentMethod` (EF3.1), the derived assessment layer.
**The calculation lives here:** `P ImpactResult.value` + `Q lca_computed_ef31` (fixed to EF3.1).
→ Comparability on EF3.1 categories. Foreground traceable, background
aggregated.

### v3 — White box: making ILCD interpretable

No new calculation core, only opening up and parametrising:
- `lca_computed_ef31` → `lca_generic($methodId)`
- `P Assessment.functionalUnit, .referenceFlow, .referenceQuantity, .referenceUnit,
  .systemBoundary` (+ `V systemBoundary`)
- `P Process.lifecycleModule` (+ `V` EN15804 A1..D) + backfill
- ImpactCategory hygiene (merge ~20 orphans / near-duplicates,
  normalise `indicator`/`unit`)
- Method taxonomy: `N AssessmentApproach` + `R BROADER` + `R APPLIES_APPROACH`,
  3 paradigms / 9 groups / 28 methods from the method diagram
- **second full LCIA method** (ReCiPe *or* CML) loaded as pure data

### v3.x — Composable modules (each: migration + base queries + docs + snapshot)

| Module | Adds | Demonstrates |
|---|---|---|
| **v3.a Circularity (MCI)** | material circularity parameters, `EndOfLifeRoute`, `IC_CIRCULARITY` | non-inventory-based metric is pluggable |
| **v3.b Cost / MFCA** (prototype) | `CostItem` + `HAS_COST`, `Flow.mfcaClass`, `mfca` + `eco_efficiency` query | economic dimension is pluggable |
| **v3.c Scenario + uncertainty** | `ModelScenario` / `Parameter` / `ParameterValue` layer, uncertainty distributions, sensitivity / robustness / hotspot query | analytical methods are pluggable |
| **v3.d Provenance** | `Declaration` as a type, `confidence`, EPD/DPP docking points | provenance/declaration dimension is pluggable |
| *v3.z (optional)* | all modules at once | composition proof — modules do not collide |

> The paradigm "learning approaches" (AI/ML) was originally intended as a pure
> docking point in v3.d/v3.i; it was removed completely from the graph and the docs on
> 2026-08-29 (outside the case-study scope) —
> `consistency/remove_ki_stubs.cypher`.

---

## 3. Documentation duty per change

Every schema change (nodes, edges, properties, vocabularies, data loads) is
**not just applied but documented**:

- **which existing artefacts** (nodes/edges/properties) are touched,
- **what the change means for each affected assessment method**,
- **which further methods** are affected by the same change
  (change → methods matrix, bidirectional where possible).

Target artefacts:
```
model_extension/reference/methods_change_sets.md      ← master spec: change set per method (still to be created)
model_extension/reference/change_method_matrix.csv    ← rows = atomic changes, columns = methods
methods/onepagers/<method>.md
```

---

## 4. Snapshot procedure

Stream export via `cypher-shell --format plain` + decoder works cleanly up to ~1 MB
(v1: 426 nodes). From v2 on (full graph, ~27 MB) the stream delivers **several**
`cypherStatements` lines and cannot be joined losslessly into a single file.

**Required before v3:** `apoc.export.file.enabled=true` in
`<DBMS directory>/conf/apoc.conf` (create the file) + DBMS restart via
Neo4j Desktop. Then `CALL apoc.export.cypher.all('v3_snapshot.cypher', {format:'plain'})`
→ writes into `<DBMS directory>/import/`.

The helper scripts used for this (export query with label exclusion filter, stream
decoder, `cypher-shell` wrapper) are not part of the repository.

As long as the switch has not been made: stage state as `vN_state.md` (schema + counters) +
`migration_vN.cypher` as the authoritative delta.

---

## 5. Status

| Artefact | State |
|---|---|
| `v1_blackbox/v1_snapshot.cypher` | **current** (2026-08-27, after migration) — 426 nodes / 1,397 relationships, ILCD types + `MAT_*_GENERIC` excluded, verified |
| `v1_blackbox/migration_v1.cypher` + `repairability.cypher` | **applied & verified** — repairability formalised, `repairabilityClass` A=1 / B=12 / C=30. Docs: `v1_blackbox/CHANGELOG.md` |
| `_fixes/fix_generic_materials.cypher` | **applied** — CSV column shift of the 5 generic materials fixed |
| [`model_extension/reference/methods_change_sets.md`](../reference/methods_change_sets.md) | **created** (2026-08-27) — change set per approach (29), PRE building blocks, order, data gaps |
| `v2_greybox/migration_v2.cypher` + `lca_computed_ef31.cypher` | **applied & verified** (v2-minimal) — calculation core on the aluminium A1 path, 5 grippers × 7 EF3.1 categories computed. Docs: `v2_greybox/CHANGELOG.md`, `v2_state.md` |
| `v3_whitebox/migration_v3.cypher` + `lca_generic.cypher` | **applied & verified** (v3-minimal) — PRE‑2 `lifecycleModule` (55), PRE‑3 functional unit (48), PRE‑4 `AssessmentApproach` taxonomy (41), method-parametrised query. Method switch EF31↔PCF without schema change. Docs: `v3_whitebox/CHANGELOG.md`, `v3_state.md` |
| `v3x_{a..d}/migration_v3*.cypher` + `v3x_repair.cypher` | **applied & verified** — a circularity (MCI, `IAM_MCI`), b cost/MFCA prototype (`CostItem`), c parameter/scenario/uncertainty layer, d provenance + repairability as a result + EPD/DPP demonstrator. One repair pass (48 duplicate nodes, 2 lost edges). Docs: `v3x_CHANGELOG.md`, `v3x_state.md` |
| [`model_extension/reference/change_method_matrix.csv`](../reference/change_method_matrix.csv) | **created** — atomic changes v1…v3.x with affected methods |
| `v2_data/` (variants A + B) | **applied & verified** — part masses (all 86), manufacturing energy, material GWP literals; **A** (real ILCD datasets only: Al/steel/PA proxy) and **B** (literals, all 43 grippers, A1-A3) in parallel via `dataVariant`. Docs: `v2_data/CHANGELOG.md`, `ASSUMPTIONS.md` |
| `v3_followup_pre5/migration_pre5.cypher` | **applied & verified** — ImpactCategory canonicalised (44 → 29), EF3.1 now computes **19** instead of 7 categories; core categories untouched. Docs: `v3_followup_pre5/CHANGELOG.md` |
| `v3x_e_recipe/migration_v3e.cypher` | **applied & verified** — 2nd LCIA method `IAM_RECIPE` (18 midpoint categories, climate populated × 1.06). `lca_generic` unchanged. Docs: `v3x_e_recipe/CHANGELOG.md` |
| [`methods/onepagers/`](../../methods/onepagers/) | **created** — 29 approach one-pagers + README |
| [`model_extension/reference/graph_schema_v3x.json`](../reference/graph_schema_v3x.json) + `EXTENSION_REFERENCE.md` | **created & continuously maintained** — complete as-built schema (93 keys) + consolidated reference |
| `dq_concept/`, `demonstrator/`, `v3x_e_recipe/cf_import/`, `v2_data/lci_hygiene/` | **applied & verified** (2026-08-29) — data quality concept, verification chain for the 8-gripper slice, full ReCiPe CF import (16/18 compute), LCI hygiene (CAS/units/compartment) |
| `consistency/` (layers 1–4) | **completed** (2026-08-29) — read-only check harness; 8 + 1 + 2 findings triaged; `FINDINGS.md`, `CHANGELOG.md`. AI/ML paradigm removed (`remove_ki_stubs.cypher`) |
| Full snapshots | **done** (2026-08-29) — `apoc.conf` set + DBMS restart; `snapshots/graph_full_2026-08-29.{cypher,graphml}` + `schema_2026-08-29.json` (only in the maintainer's working copy; the 2 large dumps are NOT in the repository) |

Live DB after this run (2026-08-27): 3,652 nodes / 81,813 relationships /
36 constraints. **Developed further since** — current state:
[`EXTENSION_REFERENCE.md`](../reference/EXTENSION_REFERENCE.md), live DB 2026-08-29:
**5,620 nodes / 86,635 relationships / 39 constraints**, 0 label-less nodes,
0 duplicates, 0 orphaned results.
**6 methods** in the graph: `IAM_EF31` (19 cat., computes), `IAM_PCF` (climate),
`IAM_RECIPE` (18 cat., 16 compute), `IAM_MCI` (computes), `IAM_REPAIR` (computes),
`IAM_GHG` (GHG by scope). All **23 approaches** of the diagram (after the
AI removal) are addressable as `AssessmentApproach` nodes.

### v2 scope decision (2026-08-27)

Leanest feasible variant chosen: **v2-minimal** — calculation core end-to-end on
**one** clean path (aluminium, A1) as a proof of mechanism; full LCI coverage is a
separate data work strand `v2-data`. System boundary **A1** (the only stage
with characterised ILCD data). Material→dataset via the new edge `MODELED_BY`.
Details: `v2_greybox/CHANGELOG.md`.

### Open decision (resolved)

**Option 2** — v1 without ILCD types; v2 adds them additively. Implemented.

### Data variant A vs. B — DECIDED (2026-08-28)

Both variants exist side by side in the graph, distinguishable via
`Assessment.dataVariant` / `ImpactResult.dataVariant`:

- **A-realdataset** — `MODELED_BY` only to real ILCD datasets. Rigorous, close to ILCD.
  Climate 0.16–0.54 kg CO₂-eq/gripper.
- **B-literal** — material GWP literals for all 18 materials, A1 + A3 electricity climate.
  Full coverage of all 43 grippers, mixed data quality. Climate 0.34–1.01.

**User's decision:** from **v3** on, **variant A** (real datasets close to ILCD) is the
**case-study standard**. **Variant B** remains only as a basis/fallback.

**State 2026-08-28:** import pipeline `v2_data/ilcd_import/` built; **ABS, PC, POM,
PA 6.6** loaded as real PlasticsEurope ILCD packages (GWP 3.1–6.5 kg CO₂e/kg,
`MODELED_BY` variant A), `refresh_variantA.cypher` → variant A results across
all 43 grippers. Open: elastomers, PETG, PLA, PA12-specific, carbon fibre
(proxy/literal until a dataset is available). Sphera licence = base version only.

### Cost dimension — DECIDED (2026-08-28)

Stays **lean**: only the `Material.unitCost` placeholder (v3.b variant A). The
structured `CostItem`/`HAS_COST` node model (v3.b variant B) will **not be pursued
further**; the nodes remain in the graph but are not built out.
`mfca.cypher` / `eco_efficiency.cypher` continue to run on `unitCost`.
