# Model extension: staged sustainability-assessment schema

The bulk load and the four interfaces give the Ned2 graph a product model and
an LCA backbone. This folder is what turns that into a graph that can carry
**many sustainability-assessment methods at once** — life-cycle assessment,
carbon and water footprints, GHG-by-scope, material circularity,
material-flow cost accounting, scenario and cross-impact analysis, and hooks
for the rest of the method catalogue in [`../methods/`](../methods/).

It is delivered as a sequence of **strictly additive, non-breaking Cypher
migrations**. Each one only adds labels, properties, relationship types,
vocabulary and computed results; none renames or removes anything an earlier
stage or the bulk load created. That "never breaks what came before" property
*is* the flexibility argument the extension is meant to demonstrate.

> **Status:** every migration was applied and verified against a running
> Neo4j Desktop instance. Each `.cypher` file ends with a verification
> `RETURN` (counts / spot values) and a commented rollback block; the numbers
> quoted in the per-module `CHANGELOG.md` files are those returns, not
> estimates. On top of modules a–g this folder now also carries **v3.h/v3.i**
> (advanced LCA hooks + external frameworks), **`v2_data/ilcd_import/`** (per-
> package PlasticsEurope import + non-CAS bridging), **`v2_data/lci_hygiene/`**
> (import-parser cleanup), **`v3x_e_recipe/cf_import/`** (full ReCiPe CF import,
> 16/18 categories), **`dq_concept/`** (data-quality layer), **`demonstrator/`**
> (an 8-gripper verification chain) and **`consistency/`** (a 4-layer review
> harness). The reference instance reaches **5,620 nodes / 86,635 relationships
> / 39 labels / 54 relationship types / 39 constraints** (2026-08-29). It also
> carries four ILCD packages imported locally via
> [`../lca_bulk_load/incremental/`](../lca_bulk_load/incremental/) and
> `v2_data/ilcd_import/` — those packages are **not** in this repository (see
> those folders' READMEs), so a clean rebuild from the bulk load plus these
> migrations lands a little below the reference instance's totals but reproduces
> every structural claim and every literal-based result exactly. The AI/ML
> paradigm that modules d/i originally sketched was removed as out of scope —
> `migrations/consistency/remove_ki_stubs.cypher`.

## The transparency framing

The stages map to how transparent the *sustainability assessment* is — not the
product model, which is already detailed from the start.

| Stage | Box | What it adds | Purpose |
|---|---|---|---|
| **v1** | black | product model + concrete indicators attached directly to artifacts (repairability index, stated GWP, recycled content, mass); repairability formalised | lightweight impact screening early in design; verification data for the RFLPV² layer. Deliberately has none of the ILCD inventory node types. |
| **v2** | grey | the ILCD/EF3.1 inventory (`Process`–`HAS_FLOW`–`Flow`, `CHARACTERIZES`→`ImpactCategory`) wired to a computation: `ImpactResult.value` + a base query hardwired to EF3.1 | real comparability across the supply chain: results computed from `Process→Flow` chains on a consistent basis |
| **v3** | white | generalise the hardwired query to `lca_generic($methodId)`; declared functional unit, EN 15804 lifecycle modules, ImpactCategory hygiene, an `AssessmentApproach` taxonomy (29 methods, later 23 after the AI/ML paradigm was dropped), and a second full LCIA method (ReCiPe) loaded as **pure data** | interpretability and method exchangeability |
| **v3.x** | modules | independently loadable method families on the white-box base: `a` circularity/MCI · `b` cost/MFCA (prototype) · `c` scenario + uncertainty layer · `d` provenance + repairability-as-result + EPD/DPP · `e` ReCiPe · `f` GHG-by-scope + pollutant register · `g` cross-impact + scenario assessment · `h` advanced-LCA hooks (prospective/dynamic/consequential/hybrid) · `i` external frameworks + self-describing KG | capture further assertions without disturbing the core |
| **v2-data** | data | part masses (all 86), manufacturing energy, material GWP; two coexisting data variants — `A` real ILCD datasets, `B` literature literals — tagged with `dataVariant`. Includes `ilcd_import/` (per-package PlasticsEurope import) and `lci_hygiene/` (import-parser cleanup). | populate the computation; keep a rigorous partial set and a full-coverage set side by side |
| **PRE-5** | hygiene | ImpactCategory canonicalisation (44 → 29) before the second method | keep the category set clean as methods multiply |
| **dq_concept** | methodology | a published-model data-quality layer: 8 criteria inherent/system on a 0..4 pedigree scale, `DQPhase` gates (min-based, no aggregation), auto-DQ from edge metadata | say how far each result can be trusted, per engineering phase |
| **demonstrator** | artifacts | an 8-gripper slice with sustainability `Requirement`s, a `TestCase` verification chain (RFLPV² spec §6), EPD/DPP status lifecycle and scenario coverage | one end-to-end `Requirement → TestCase → Assessment → ImpactResult` chain |
| **consistency** | QA | a read-only 4-layer review harness (building blocks, model, tools, logical DECODE embedding) + the fixes it produced | prove doc ↔ live agreement and tool ↔ graph agreement |

The three-level flexibility claim:

1. a **new paradigm** plugs in additively (v1 → v2 adds the whole inventory layer);
2. a **new metric** is pure data with zero query change (ReCiPe in v3.e — method node + `HAS_CATEGORY` + `CHARACTERIZES` factors, nothing else);
3. **whole method families** attach as orthogonal modules (v3 → v3.x).

## Layout

```
model_extension/
├── migrations/           the ordered .cypher files, one sub-folder per stage
│   ├── v1_blackbox/  v2_greybox/  v3_whitebox/
│   ├── v2_data/          part masses, energy, material GWP, Variant A / B
│   │   ├── ilcd_import/  per-package PlasticsEurope import + non-CAS bridging
│   │   └── lci_hygiene/  import-parser cleanup (casNumber, unit split, compartments)
│   ├── v3_followup_pre5/ ImpactCategory canonicalisation
│   ├── v3x_a_circularity/ … v3x_e_recipe/   the module families a–e
│   │   └── v3x_e_recipe/cf_import/  full ReCiPe 2016 CF import (16/18 categories)
│   ├── v3x_nonlcia/      modules f–i (GHG/pollutant, cross-impact/scenario, advanced LCA, frameworks) + PLAN
│   ├── v3x_repair.cypher a one-off fix pass (see v3x_CHANGELOG.md)
│   ├── dq_concept/       data-quality layer (01–03 + README/CHANGELOG)
│   ├── demonstrator/     8-gripper verification chain (00–04 + README/CHANGELOG)
│   ├── consistency/      4-layer review harness (check_*, fix_*, FINDINGS, CHANGELOG)
│   └── _fixes/           data-quality corrections
└── reference/
    ├── EXTENSION_REFERENCE.md   consolidated label / relationship / query catalogue
    ├── ASSUMPTIONS.md          every literature value used, with sources
    ├── change_method_matrix.csv  one row per atomic change × the methods it affects
    ├── graph_schema_v3x.json    machine-readable schema of the extended graph
    └── Sustainability_Assessment_Flexibility_Analysis.md
```

Each stage folder carries its own `CHANGELOG.md` (touched artifacts + a
change→methods table). `v3x_CHANGELOG.md` and `v3x_state.md` cover the module
set as a whole.

## Applying it

Prerequisite: the bulk load from [`../lca_bulk_load/`](../lca_bulk_load/) is in
place. Then run the migrations **in order**; each is idempotent (re-running is
safe) and independent at the statement level (`;`-separated statements never
share a variable — always re-`MATCH` by id).

```bash
export NEO4J_URI=bolt://localhost:7687 NEO4J_USER=neo4j NEO4J_PASSWORD=...
CS="cypher-shell -a $NEO4J_URI -u $NEO4J_USER -p $NEO4J_PASSWORD"

$CS -f migrations/_fixes/fix_generic_materials.cypher
$CS -f migrations/v1_blackbox/migration_v1.cypher
$CS -f migrations/v2_greybox/migration_v2.cypher
$CS -f migrations/v3_whitebox/migration_v3.cypher
$CS -f migrations/v3x_a_circularity/migration_v3a.cypher
$CS -f migrations/v3x_b_cost/migration_v3b.cypher
$CS -f migrations/v3x_c_scenario/migration_v3c.cypher
$CS -f migrations/v3x_d_provenance/migration_v3d.cypher
$CS -f migrations/v3x_repair.cypher
$CS -f migrations/v2_data/1_masses.cypher
$CS -f migrations/v2_data/1b_masses_fix_cups.cypher
$CS -f migrations/v2_data/2_manufacturing_energy.cypher
$CS -f migrations/v2_data/3_material_gwp_literals.cypher
$CS -f migrations/v2_data/4A_realonly.cypher
$CS -f migrations/v2_data/4B_full_coverage.cypher
$CS -f migrations/v3_followup_pre5/migration_pre5.cypher
$CS -f migrations/v3x_e_recipe/migration_v3e.cypher
$CS -f migrations/v3x_nonlcia/migration_v3f.cypher
$CS -f migrations/v3x_nonlcia/migration_v3g.cypher
$CS -f migrations/v3x_nonlcia/migration_v3h.cypher
$CS -f migrations/v3x_nonlcia/migration_v3i.cypher
# optional data refinements (need locally downloaded ILCD / openLCA packages):
#   migrations/v2_data/ilcd_import/  (per-package import + harmonize_noncas + refresh_variantA)
#   migrations/v2_data/lci_hygiene/  (lci_hygiene.cypher + model_cleanup.cypher)
#   migrations/v3x_e_recipe/cf_import/  (import_recipe_cf.py --> refresh_recipe.cypher)
$CS -f migrations/dq_concept/01_criteria_catalogue.cypher
$CS -f migrations/dq_concept/02_phase_targets.cypher
$CS -f migrations/dq_concept/03_compute_dq.cypher
$CS -f migrations/demonstrator/00_mci_rollup.cypher
$CS -f migrations/demonstrator/01_sustainability_requirements.cypher
$CS -f migrations/demonstrator/02_verification_layer.cypher
$CS -f migrations/demonstrator/03_declarations.cypher
$CS -f migrations/demonstrator/04_scenario_coverage.cypher
# consistency review (read-only checks + the fixes it produced) — see migrations/consistency/README.md
```

Watch each file's closing `RETURN` — it prints the counts / values that stage
is meant to produce. To undo one, use the commented rollback block at the
bottom of its file.

## Using the methods afterwards

- `lca_generic($methodId, $artifactId)` in `migrations/v3_whitebox/` — one
  query, any LCIA method (`IAM_EF31`, `IAM_PCF`, `IAM_RECIPE`).
- The per-method base queries in [`../methods/base_queries/`](../methods/base_queries/).
- The 23 method one-pagers in [`../methods/onepagers/`](../methods/onepagers/)
  say, per method, what is already computed, what schema it needs, and which
  other methods a given change also touches.
