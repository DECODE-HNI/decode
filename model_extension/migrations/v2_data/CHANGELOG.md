# `v2-data` — change log (LCI completion)

## 2026-08-27 — Masses, manufacturing energy, two data variants

All values literature-based, documented in `../../reference/ASSUMPTIONS.md`.
Order: `1_masses` → `1b_masses_fix_cups` → `2_manufacturing_energy` →
`3_material_gwp_literals` → `4A_realonly` **and** `4B_full_coverage` (parallel
variants).

### Common base

| Artifact | Change |
|---|---|
| `Part.mass_g` + `massBasis` | **all 86 parts**. Contact parts (43) from bounding-box geometry × fill factor (CNC 0.55 / print 0.40 / cast 0.85 / laser 0.90) × density; suction cups via π/4·d²·h × 0.30; interface parts (43) type default 20 g polymer / 35 g metal. Computed gripper mass 20–61 g (sanity check: 5 known `Artifact.mass_g` 19.5–115 g incl. actuator). |
| `Process.energyIntensity_kWh_per_kg` + `materialFactor` + `energyBasis` | 11 manufacturing processes (MJF 15 · SLS 30 · FFF 20 · CNC 20 · … kWh/kg; CNC scrap 1.8) |
| `Flow FLOW_ELECTRICITY` +`gwp_kgCO2e_per_kWh_{DE,DE_green,CN,EU}` | 0.38 / 0.04 / 0.58 / 0.28 |
| `(FLOW_ELECTRICITY)-[:CHARACTERIZES]->(IC_CLIMATE)` | `factor=0.38`, `location='DE'` — electricity gets a climate factor |
| manufacturing template flows (`FLOW_PA12`, `FLOW_ELECTRICITY` …) | real (representative) amounts instead of the placeholder `1.0` |
| `Material` +`gwp_A1_kgCO2e_per_kg`, `ef31_categories`/`ef31_factors_A1` (parallel arrays, no map type in Neo4j), `gwpBasis` | 18 real materials |
| `Material` circularity refinement | `recycledContentAssumed`/`recyclingRate`/`reusability` per material class from ASSUMPTIONS.md §5 (refined vs the v3.a defaults) |

### Variant A — `4A_realonly.cypher` (real ILCD datasets only)

`(:Material)-[:MODELED_BY]->(:Process)` **only** where a dataset exists in the
graph:
- aluminium (`MAT_AL6061/7075` → `PROC_ALU_EXTRUSION_EF`, from v2)
- steel (`MAT_STEEL/SPRING` → `PROC_STEEL_SECTIONS_ILCD`)
- polyamide (`MAT_PA12/PA11` → `PROC_PA66_GRANULATE_MIX`, proxy, chemistry
  differs)

`Assessment`/`ImpactResult` with `dataVariant='A-realdataset'`, 43 grippers ×
8 categories (only parts with a modelled material contribute — elastomers, PETG,
POM, PC, ABS, ASA, PLA, CF-PA remain without a contribution). Climate
0.16–0.54 kg CO₂-eq/gripper.

### Variant B — `4B_full_coverage.cypher` (literature values, full coverage)

All 43 grippers, EF3.1 **A1 (all materials) + A3 (electricity climate)** from the
per-kg literals. `dataVariant='B-literal'`. Climate **0.34–1.01 kg
CO₂-eq/gripper** (avg 0.50). Base query `lca_from_literals.cypher` (parameter
`$electricityCF`). EF3.1 non-climate factors are scaled from the aluminium
dataset ratio → weak for polymers/elastomers, flagged accordingly.

### Comparison (V-groove Al6061, climate change)

| Calculation | kg CO₂-eq |
|---|---:|
| v2 (aluminium contact parts only, A1) | 0.345 |
| Variant A (Al + PA interface + steel, A1) | 0.540 |
| Variant B (all materials A1 + A3 electricity, literal) | 1.009 |

### Decision open (later settled)

**A vs B** — A is rigorous (real datasets only, partial coverage), B is complete
(every gripper assessable, mixed data quality). Both live in the graph in
parallel (`dataVariant` property). To be decided later which becomes the
case-study standard. *(Decided 2026-08-28: Variant A is the standard, B stays as
a fallback — see `../../reference/EXTENSION_REFERENCE.md` §5.)*

### Live DB after v2-data

3 648 nodes / 81 937 relationships. `Assessment` 182 (96 + 43 A + 43 B),
`ImpactResult` 771 (126 + 344 A + 301 B). 0 label-less nodes, 0 parts without a
mass.
