# Module v3.e — ReCiPe 2016 Midpoint (H) · change log

## 2026-08-27

`migration_v3e.cypher`

### Purpose

A second LCIA method as evidence for "a new method = pure data, zero query
change". `lca_generic($methodId='IAM_RECIPE')` works unchanged.

### New

| Artifact | Scope |
|---|---|
| `ImpactAssessmentMethod` `IAM_RECIPE` | ReCiPe 2016 midpoint, Hierarchist; `methodFamily='ReCiPe'` |
| `ImpactCategory` `IC_RECIPE_*` | **18 midpoint categories** (Global warming, Stratospheric ozone depletion, Ionizing radiation, Ozone formation HH/EC, Fine PM, Terrestrial acidification, Freshwater/Marine eutrophication, 3× Ecotoxicity, 2× Human toxicity, Land use, Mineral/Fossil resource scarcity, Water consumption) |
| `HAS_CATEGORY` | 18 (`IAM_RECIPE` → all `IC_RECIPE_*`) |
| `APPLIES_APPROACH` | `IAM_RECIPE` → `APM_LCA` |
| `CHARACTERIZES` → `IC_RECIPE_GW` | 38 factors, **approximated** from the EF3.1 climate factors × 1.06 (ReCiPe-H climate-carbon-feedback uplift), noted in a `source` property |

### Coverage

- **Climate category (`IC_RECIPE_GW`): computable** — `lca_generic('IAM_RECIPE')`
  yields climate values for every gripper with a `MODELED_BY` material (Al, PA,
  steel), values ≈ 1.06 × EF3.1 climate.
- **17 further categories: structural only** — node + `HAS_CATEGORY` present,
  factors not yet populated (a data task).

*(Later filled by the full CF import, `cf_import/`: 16 of 18 categories now
compute; see `cf_import/README.md`.)*

### Method-agnosticism evidence

Three LCIA methods over the same query: `lca_generic('IAM_EF31')` (19 cats),
`lca_generic('IAM_PCF')` (1 cat), `lca_generic('IAM_RECIPE')` (1 cat populated
at this point). No schema or query change when adding ReCiPe.

### Rollback

Comment block at the end of the migration (delete factors + categories +
method).
