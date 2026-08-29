# LCI hygiene — change log

## 2026-08-29 — Second pass: structural ballast (`model_cleanup.cypher`)

Removes nodes/edges that no query reads. Only C5 changes a result (removes a
wrong CF).

| Part | Action | Scope |
|---|---|---|
| **C1** | 6 orphan EF3.1 sub-fraction categories (`_ORGANICS` / `_INORGANICS`) + their `CHARACTERIZES` — redundant: every flow with a sub-fraction CF also has the parent CF, and `lca_generic` follows only `HAS_CATEGORY` | **6 nodes, 1 838 edges** |
| **C2** | `IC_ENERGY`, `IC_WASTE` — placeholders under `IAM_EF31` with no CF / result; EF3.1 does not define them, `ced.cypher` does not use them | **2 nodes, 2 edges** |
| **C3** | `PROC_PA66_GRANULATE_MIX` — the pre-ILCD PA6.6 proxy (2 728 `HAS_FLOW`), superseded by `PROC_PA66_PLASTICSEUROPE_EF`, no longer referenced; `PROC_FINISH` — empty stub (42 contentless `APPLIES_TO`) | **2 nodes, 2 770 edges** |
| **C4** | 4 superseded ILCD reference-product flows (ABS/PC/POM/PA66 granulate) | **4 nodes** |
| **C5** | `uranium -[:CHARACTERIZES]-> IC_EF_EF_RESOURCE_USE_FOSSILS` (CF 1.0) — uranium is nuclear primary energy, not a fossil raw material | **1 edge** |

**Live DB after:** 5 510 nodes · **84 830 relationships** (−4 611) · 39 labels ·
53 relationship types · 37 constraints · 0 label-less · 0 valueless results ·
0 orphan assessments. **`IAM_EF31` now 19 categories, all 19 with a CF**
(was 21/19).

### Open (for the consistency review)

- **Stale `ImpactResult` problem:** `refresh_variantA` / `refresh_recipe` create
  results only for the (dataset, category) pairs the recompute yields, and never
  delete stale ones. After the unit split, pure-plastic grippers such as
  `ART_FLAT_ABS` still show a pre-hygiene value for "Resource use, fossils"
  (23 MJ), because that pair dropped out. Needs a timestamp-based prune in the
  refresh scripts.
- Negative `HAS_FLOW` amounts (phosphorus/potassium/iron as a credit) produce a
  tiny negative minimum for "Resource use, minerals & metals" (~−4e-7) —
  magnitude negligible, deliberately left alone.
- `IC_EF_CLIMATE_CHANGE_LAND_USE_AND_LUC` has only **1** characterised flow →
  only 5 grippers get a value.
- PlasticsEurope fossil amounts (MJ labelled as kg) stay unreliable →
  `IC_RECIPE_FRS` structural.

## 2026-08-29 — First hygiene pass (`lci_hygiene.cypher`)

Cleanup of import-parser damage in the LCI layer (Sphera / PlasticsEurope
exports; the CSV/TSV parser mishandled commas and semicolons inside substance
names and merged flows booked in different units onto one node). Additive where
possible; the two result-affecting parts (P3, P6) are individually
reversible. Re-runnable.

### Parts

| Part | Effect | Scope |
|---|---|---|
| **P1** `casNumber` field | non-CAS values (units, compartment strings, name fragments, `""`) → `casNumberRaw`, field nulled, `dataFlag` | **415 flows** |
| **P2** land-use flows | name prefix `Occupation, ` / `Transformation, ` restored (`nameRaw`), unit removed from `casNumber`, `HAS_FLOW.compartment='resource/land'` | **50 flows** |
| **P3** unit split | flows with >1 unit split into one node per unit (`<id>#u=<unit>`); the characterised node keeps the unit its CF expects (kBq ionising radiation, MJ fossil resources, otherwise the modal unit) | **103 sibling nodes** (99 kg, 3 kBq, 1 m³) |
| **P4** compartment backfill (modal) | blank `HAS_FLOW.compartment` filled from the flow's unambiguous modal compartment | **9 223 edges** |
| **P5** compartment backfill (name rule) | blank compartment on characterised air-emission outputs from a curated name list (CO₂, CH₄, SO₂, NOx, NH₃, NMVOC, particulates …) | **237 edges** |
| **P6** quarantine | flows with fragment names (`"1"`, `"(2"`, `"2-chloro-N-(2"`) → `excludeFromCalc=true`, their 121 nonsensical `CHARACTERIZES` deleted | **27 flows** |

### Result deltas (43 grippers, Variant A)

| Category | before | after | why |
|---|---|---|---|
| EF3.1 ionising radiation | 0.020–0.049 | **0.0046**–0.049 | radionuclide masses booked as "kg" (e.g. 0.83 "kg" caesium-137) no longer multiplied by a kBq CF |
| ReCiPe ionising radiation | 0.0039–0.0095 | **0.0**–**0.0035** | same; the result was ~18× inflated on average |
| EF3.1 freshwater ecotoxicity | …–1.3408 | …–1.3408 | fragment-flow noise removed (~0.003 %) |

Climate, acidification, eutrophication, particulate matter, POCP, land use,
water and the remaining toxicity categories: unchanged.

### Live DB after

**5 524 nodes · 89 441 relationships · 39 labels · 53 relationship types ·
37 constraints** · 0 label-less · 0 valueless results · 0 orphan assessments ·
0 CF without a factor · 0 flows with mixed units · 0 non-CAS `casNumber`.

### Open (exposed by the cleanup)

- **EF3.1 "Resource use, fossils"** now over-reports for the ABS and PC
  datasets (`ART_FLAT_ABS` ≈ 23 MJ, `ART_PREC_PC` ≈ 16 MJ). Two pre-existing CF
  problems the unit split only exposed: `uranium` (nuclear primary energy, MJ)
  carries a CF of 1.0 for the fossil category, and the PlasticsEurope fossil
  inventory itself mixes MJ values labelled as kg. Needs a dedicated
  fossil-resource CF review.
- A calorific-value CF addendum for the fossil sibling nodes
  (`fossil_sibling_cf.cypher`) was drafted and **withdrawn**: the kg amounts
  are too unreliable (ABS/PC ~40 "kg" crude oil = mislabelled MJ, PA6.6 ~1 kg =
  real mass).
- `IC_RECIPE_FRS` / `IC_RECIPE_LU` stay structural (fossil amounts unreliable;
  almost no land-occupation flows).
- `IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS` still has a negative minimum
  across the 43 grippers — a separate CF/sign bug, untouched.
- ~18 900 blank output compartments remain (flows that carry no compartment
  anywhere — mostly obscure trace organics); not backfillable without the
  source packages.
