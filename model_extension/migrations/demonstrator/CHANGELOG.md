# Demonstrator artifacts — change log

## 2026-08-29 — Consistency-review follow-up

- `02_verification_layer.cypher`: `TC_MAG_GWP` set from `complete:false` to
  `true` — the consistency review (F-03) bridged the steel dataset's EF3.1 CFs,
  so `ART_MAGNET` now has a real climate value.
- After the `refresh_variantA` re-run (F-01 prune): some EPD `REPORTS` edges
  pointed at deleted fossil results and fell away; `03_declarations.cypher`
  re-links them.
- Verification chain now **19 passed / 3 failed / 2 inconclusive** (was 18/3/3).

## 2026-08-29 — First cut: sustainability verification chain (8-gripper slice)

Closes the four thinly-populated demonstrator gaps into **one** end-to-end
chain `Requirement → TestCase → Assessment → ImpactResult → ImpactCategory`,
plus EPD/DPP with a status lifecycle. Scope per user decision: a
**representative slice of 8 grippers** (one per material archetype); the other
35 keep only the base LCA. Strictly additive, idempotent, rollback blocks per
file.

### Slice

`ART_V_AL`, `ART_FLAT_AL` (Al 6061, real data) · `ART_PREC_POM`,
`ART_FLAT_ABS`, `ART_PREC_PC` (thermoplastic, real data) · `ART_LONG_CFPA`
(CF-PA, no jaw dataset) · `ART_FINRAY_TPU` (TPU, no jaw dataset) ·
`ART_MAGNET` (steel + NdFeB, dataset present but no climate CF).

### Parts

| File | Effect | Scope |
|---|---|---|
| **`00_mci_rollup.cypher`** | `ASSESS_MCI` + `IR_MCI` for the 6 slice grippers without an MCI (v3.a made them only for the 5 aluminium grippers). Mass-weighted mean of `Material.mci`. | 12 nodes, 36 edges |
| **`01_sustainability_requirements.cypher`** | 3 `Requirement` — `REQ_SUS_GWP` (`IC_CLIMATE` ≤ 0.50 kg CO₂-eq), `REQ_SUS_MCI` (`IC_CIRCULARITY` ≥ 0.30), `REQ_SUS_REPAIR` (`IC_REPAIRABILITY` ≥ 0.70) — linked to the 8 via `SATISFIES_REQUIREMENT`. Field set as `REQ_COMPAT`. | 3 nodes, 24 edges |
| **`02_verification_layer.cypher`** | New label **`TestCase`** (RFLPV² spec §6 Neo4j target state, documented but not applied until now). 24 test cases = 8 × 3, each with `VERIFIES → Requirement`, `HAS_ASSESSMENT → Assessment`, `TESTS → Artifact`, cached `sustainabilityResult` / `sustainabilityStatus` ∈ {`passed`, `failed`, `inconclusive`, `notEvaluated`}. Writes the verdict back onto `SATISFIES_REQUIREMENT.verificationStatus`. Constraint `TestCase_id_unique`. | 24 nodes, 72 edges, 1 constraint |
| **`03_declarations.cypher`** | `Declaration` status lifecycle (`draft`/`verified`/`published`/`expired`, `verifiedBy`, `issuedAt`, `expiresAt`). EPD + DPP for the other 7 (`verified` for real data, `draft` for partial); `ART_V_AL` → `published`. EPD `REPORTS` the EF3.1 Variant-A category results, DPP additionally MCI + repairability. | 14 nodes, 141 `REPORTS`/`DECLARES` |
| **`04_scenario_coverage.cypher`** | `SC_GRID_2035` (prospective 2035 grid mix, 0.15 kg CO₂e/kWh) extended from the 5 aluminium grippers to the rest of the slice — identical formula to `v3x_nonlcia/migration_v3h`. Now 11 grippers. | 12 nodes, 30 edges |

### Result (24 test cases)

| Requirement | passed | failed | inconclusive |
|---|--:|--:|--:|
| `REQ_SUS_GWP` | 4 | 1 (`ART_V_AL`, 0.509 > 0.50) | 3 (no jaw dataset / no climate CF) |
| `REQ_SUS_MCI` | 6 | 2 (`ART_LONG_CFPA` 0.26; `ART_FINRAY_TPU` 0.24) | – |
| `REQ_SUS_REPAIR` | 8 | – | – |

The chain produces all four RFLPV² status values on a realistic spread of
materials.

### Live DB after

**5 718 nodes (+65) · 86 163 relationships (+317) · 41 labels (+`TestCase`) ·
57 relationship types (+`VERIFIES`, `HAS_ASSESSMENT`, `TESTS`) · 39 constraints** ·
0 label-less · LCA core results unchanged (`IC_RECIPE_GW` 0.134–0.536).
(Figures for this run; the consistency review afterwards lands the graph at
5 620 / 86 635 / 39 / 54 / 39 — see `../consistency/`.)

### Open / for the consistency review

- **`ART_MAGNET` GWP:** `PROC_STEEL_SECTIONS_ILCD` is linked via `MODELED_BY`
  but contributes 0 to `IC_CLIMATE` under `refresh_variantA`, while
  `refresh_recipe` does capture the steel. `TC_MAG_GWP` = `inconclusive` with a
  note. → `refresh_variantA` ↔ `refresh_recipe` divergence. *(Fixed by F-03.)*
- `DECL_EPD_ART_V_AL` reports 7 categories, the new EPDs ~18 — not harmonised
  (cosmetic).
- Repairability is 1.0 for every gripper (v1) → `REQ_SUS_REPAIR` trivially met.
- The thresholds (0.50 / 0.30 / 0.70) are demonstrator targets, not derived
  requirements.
