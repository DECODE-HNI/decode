# v2 (grey box) — change log

## 2026-08-27 — Computation core wired (v2-minimal, aluminium A1 path)

Migration: `migration_v2.cypher` · base query: `lca_computed_ef31.cypher`

### Decisions (leanest workable variant)

| # | Decision | Rationale |
|---|---|---|
| 1 | Material→ILCD dataset via a new additive edge `(:Material)-[:MODELED_BY]->(:Process)` | a distinct, clearly named edge instead of overloading `APPLIES_TO`; documentable |
| 2 | Mass model: `Part.mass_g` = bounding-box volume × 0.5 fill factor × density | the only consistently available source (14 `Geometry` nodes with L/W/H); flagged as an estimate |
| 3 | Scope: only aluminium contact parts of 5 grippers; rest `status:"data incomplete"` | only `MAT_AL6061`/`MAT_AL7075` have a defensible ILCD proxy; polymers/elastomers have no dataset |
| 4 | System boundary A1 (cradle-to-gate raw material) | the only stage with characterised ILCD data; manufacturing/use/EoL flows are placeholders |
| — | Regionalisation: non-regionalised factor; where only regionalised ones exist, their mean | `CHARACTERIZES.location` is set 213 times across 99 flow-category pairs |

### Artifacts touched / new

| Artifact | Change | Scope |
|---|---|---|
| `ImpactResult` (node) | new properties `value`, `provenance`, `computedAt`, `datasetRef`, `coverage`, `status` | all 78: 35 `status:"calculated"`, 43 `status:"data incomplete"` |
| `(:Material)-[:MODELED_BY]->(:Process)` | **new relationship type** | 2 edges (`MAT_AL6061`, `MAT_AL7075` → `PROC_ALU_EXTRUSION_EF`), `proxy=true`, `lifecycleModule='A1-A3'` |
| `Part` (node) | `mass_g`, `massBasis` | 5 aluminium contact parts (estimate). *Note: `Part.mass_g` is really v1 product data, populated here as part of v2.* |
| `Assessment` (node) | 5 new: `ASSESS_EF31_<art>`, `USES_METHOD → IAM_EF31`, `systemBoundary`, `functionalUnit`, `characterizationLocationRule`, `status='partial'` | + `ASSESSES`, `USES_METHOD` |
| `ImpactResult` (node) | 35 new: `IR_EF31_<art>_<cat>` with `value` | 5 grippers × 7 covered EF3.1 categories |

**Live DB:** 2 761 nodes (+40) / 79 729 relationships (+82).

### Result (climate change, EF3.1, A1 aluminium contact parts)

| Gripper | GWP [kg CO₂-eq] | Al mass [kg] |
|---|---|---|
| Precision jaws / Al7075 / CNC | 0.078 | 0.0081 |
| Internal-expansion fingers / Al6061 | 0.172 | 0.0178 |
| Flat jaws / Al6061 / CNC | 0.188 | 0.0194 |
| V-groove jaws / Al6061 / CNC | 0.345 | 0.0356 |
| Long-reach fingers / Al6061 / CNC | 0.347 | 0.0359 |

Per-kg value of the dataset: **9.67 kg CO₂-eq/kg** — within the literature range
for an aluminium extrusion profile A1–A3. Covered EF3.1 categories: climate
change, acidification, marine eutrophication, land use, ozone depletion,
particulate matter, photochemical ozone (7 of 22 — only these have CF coverage
in the dataset). The base query reproduces every stored value independently.

### Affected methods (change-→-method matrix)

| Change | needed by | used by |
|---|---|---|
| `ImpactResult.value` (+ `provenance`, `status`) | **every** quantitative method (LCA, CF, H₂O, GHG, CED, hotspot, eco-efficiency …) | all downstream analyses (robustness, sensitivity, recommendation) |
| `(:Material)-[:MODELED_BY]->(:Process)` | LCA/EF3.1, CF, CED, MFA (material link to the inventory) | circularity (dataset recycled-content), hybrid LCA |
| `Part.mass_g` + `massBasis` | every mass-based calculation (LCA A1, MFA, MCI) | eco-efficiency (value per mass) |
| `Assessment.systemBoundary` / `functionalUnit` | LCA, EPD, all inventory methods | comparability check between assessments |

### Open work stream: `v2-data` (LCI completion)

Separate from the schema migration. Needed for full v2 coverage:
- `MODELED_BY` proxies for the remaining ~16 real materials (PA12, PETG, POM,
  silicone, TPU, steel …) — an LCA modelling decision per material
- part masses for all 86 parts (not just the 5 aluminium parts)
- manufacturing LCI (A3): the 4 template flows per process with real amounts +
  factors, or ILCD manufacturing datasets
- EF3.1 CF coverage for the missing 15 categories

### Rollback

Comment block at the end of `migration_v2.cypher`.
