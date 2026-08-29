# ILCD import — change log

## 2026-08-29 — Consistency review: CAS normalisation + stale prune (F-01, F-03)

Two corrections from the consistency review (`../../consistency/`), both on
`refresh_variantA.cypher` and the CF layer.

### F-03 · EF3.1 CF gap on zero-padded CAS (`../../consistency/fix_F03_cas_bridge.cypher`)

Several imported ILCD datasets store `Flow.casNumber` zero-padded
(`000124-38-9`). The EF3.1 CF layer was matched without leading-zero
normalisation → those flows (incl. the steel CO₂ flow) never got EF3.1 CFs,
whereas the ReCiPe importer (`norm_cas()`) does normalise. Consequence: EF3.1
and ReCiPe diverge (steel 8/19 vs 14/18 categories; 4 steel grippers showed a
PA12-only climate value). Fix: `Flow.casNumberNorm` (leading zeros stripped) on
1 759 flows + index; **530 EF3.1 CFs** bridged from the clean-CAS twin (same
normalised CAS + same substance name), `derived=true`,
`matchedBy:'cas-normalised'`. Steel dataset 8 → 14 EF3.1 categories; steel CO₂
`perKg` 0 → 1.575; the steel grippers' EF3.1/ReCiPe ratio 1.4–1.5 → 1.02–1.03.

### F-01 · stale `ImpactResult` prune (`refresh_variantA.cypher` + `refresh_recipe.cypher`)

The `MERGE` logic of the refresh scripts creates results only for (artifact,
category) pairs the recompute yields, and **never deleted** stale ones — e.g.
fossil-resource results whose flows moved to MJ siblings after the unit split
(P3). Both files get a final prune step: a result is deleted when its category
is no longer characterised via the artifact's BOM by any flow. Re-run:
**−110 stale `ImpactResult`** (38 wrong fossil-resource values + others).
`Declaration` `REPORTS` edges to deleted results fall away;
`demonstrator/03_declarations.cypher` re-links them on its next run.

## 2026-08-29 — Non-CAS flow harmonisation + precision fix

Two additive, non-breaking corrections to Variant A's number base. No new
methods, no schema change.

### 1. Non-CAS flow harmonisation (`harmonize_noncas.cypher`, `gen_import.sh` step 5b)

The PlasticsEurope packages emit some elementary flows **without a CAS number**
that the CAS-based harmonisation (step 4) cannot reach. They are now bridged by
a fixed alias → canonical flow UUID over name + compartment:

| alias flow (air) | UUID | → canonical | EF3.1 factor(s) |
|---|---|---|---|
| `particles (PM2.5 - PM10)` | `08a91e70-…-9501-…` | `particles (PM10)` (2.5–10 µm fraction) | particulate matter 5.48544e-5 |
| `volatile organic compound` | `08a91e70-…-9155-…` | `non-methane volatile organic compounds` | POCP 1.0 · freshwater ecotox. 8.6069 · human tox. non-canc. 6.2186e-8 |
| `Particulates (unspecified)` | `38a9d121-…` | `particles (PM10)` (proxy, `confidence:'low'`) | particulate matter 5.48544e-5 |
| `Dust (unspecified)` | `4f520365-…` | `particles (PM10)` (proxy, `confidence:'low'`) | particulate matter 5.48544e-5 |

**6 new `CHARACTERIZES {derived:true}`** (marker `source='harmonised via non-CAS
name+compartment'` resp. `'proxy: unspecified particulates -> PM10 CF'`).
`particles (PM2.5 - PM10)` hangs off 19 processes (incl. aluminium/steel/
electricity) → correctly affects **all 43 grippers**; the other aliases only the
PlasticsEurope processes.

**Deliberately not bridged:**
- `particles (> PM10)` — the EF3.1 CF of the > 10 µm fraction is 0 (no modelled
  health effect); leaving it unassessed is exact.
- `chemical/biological oxygen demand` (COD/BOD) — **no** EF3.1 or ReCiPe 2016
  category is driven by COD/BOD (freshwater eutrophication is purely P-based,
  marine purely N-based). COD/BOD only feed a CML-2001 "aquatic eutrophication",
  which this model does not carry. Unassessed is therefore methodically correct,
  not a gap.

### 2. Precision fix in `refresh_variantA.cypher`

`round(sum(mass_kg*perKg), 6)` flattened the small-magnitude EF3.1 categories to
`0.0`. Now `round(…, 12)`. Affected (previously 0.0 for **all 43** grippers, now
populated):

| category | unit | new range (43 grippers) |
|---|---|---|
| particulate matter | disease incidence | 2.9e-9 … 3.3e-8 |
| human toxicity, cancer | CTUh | 1.7e-10 … 5.3e-10 |
| human toxicity, non-cancer | CTUh | 1.9e-8 … 4.6e-8 |
| ozone depletion | kg CFC-11 eq | 0.0 (38 grippers, truly zero) … 3e-12 |
| POCP | kg NMVOC eq | 2.74e-4 … 1.479e-3 (was 2.71e-4 … 1.476e-3) |

Climate unchanged (0.12965 … 0.511727), only more decimal places.

**Live DB after:** 4 690 nodes · 86 007 relationships · 39 labels ·
53 relationship types · 37 constraints · 0 label-less · 0 valueless results ·
0 orphan assessments · 50 `CHARACTERIZES {derived:true}` (44 + 6).

### Change → affected methods

| change | used directly by | also affects |
|---|---|---|
| 6 non-CAS `CHARACTERIZES {derived:true}` | 1.1.1 LCA (EF3.1 particulate matter, POCP, human tox. for the imported datasets) | 1.2.2 pollutant inventory, 2.3.3 hotspot, 3.2.1 DPP; ReCiPe inherits once non-climate factors exist |
| `round(…,12)` in `refresh_variantA.cypher` | any Variant-A evaluation of small-magnitude categories | robustness/sensitivity (the A↔B spread for particulate matter / human tox. is only now visible) |

## 2026-08-28 — First 4 real PlasticsEurope datasets (Variant A)

Pipeline built (`extract_package.pl`, `gen_import.sh`, `refresh_variantA.cypher`)
and applied to four ILCD `_dependencies.zip` packages downloaded by the user.

| Material | process node | dataset (UUID) | geo / year | GWP A1-A3 real | old (literal) |
|---|---|---|---|---:|---:|
| `MAT_ABS` | `PROC_ABS_PLASTICSEUROPE_EF` | `864a6be9-…` | EU-27 / 2010 | **3.14** kg CO₂e/kg | 4.0 |
| `MAT_PC` | `PROC_PC_PLASTICSEUROPE_EF` | `c4161063-…` | EU-25 / 2007 | **4.19** | 5.5 |
| `MAT_POM` | `PROC_POM_PLASTICSEUROPE_EF` | `e3b65970-…` | EU-27 / 2010 | **3.26** | 3.6 |
| `MAT_PA12`, `MAT_PA11` (proxy) | `PROC_PA66_PLASTICSEUROPE_EF` | `35d4884b-…` | EU-27 / 2011 | **6.48** | 9.0 / 5.5 |

- Per dataset: `Process` + ~420–920 `HAS_FLOW` + missing `Flow` nodes
  (ABS +22, PC +6, POM +468, PA6.6 +14) + `MODELED_BY` (`dataVariant='A-realdataset'`).
- Characterisation harmonisation: **36 derived `CHARACTERIZES {derived:true}`**
  (only ABS + PC needed them; POM/PA6.6 match natively by UUID).
- **Superseded:** the old proxy edges `MAT_PA11/PA12 → PROC_PA66_GRANULATE_MIX`
  deleted (replaced by `PROC_PA66_PLASTICSEUROPE_EF`); the old node stays
  unreferenced in the graph (later removed in LCI hygiene C3).
- `refresh_variantA.cypher`: `ASSESS_EF31A_*` / `IR_EF31A_*` rebuilt over **all
  43 grippers** (was ~13). Variant-A climate now **0.13–0.51 kg CO₂e/gripper**
  (material cradle-to-gate; part shaping not included → use Variant B for that).

**Live DB after:** 4 656 nodes · 85 932 relationships · 35 labels ·
45 relationship types · 37 constraints · 0 label-less · 0 duplicate
`MODELED_BY` · 0 valueless results. Aluminium control value unchanged
(9.67 kg CO₂e/kg).

### Change → affected methods

| change | used directly by | also affects |
|---|---|---|
| 4 real `Process` + `HAS_FLOW` + `MODELED_BY` (Variant A) | 1.1.1 LCA (`lca_generic('IAM_EF31')`, Variant A), 1.1.2 carbon footprint | 1.1.4 GHG scopes, 1.2.4 MCI (recycled-content assumptions), 2.2.1 scenario, 2.3.3 hotspot, 3.2.1 DPP; ReCiPe (`IAM_RECIPE`) once factors are present |
| derived `CHARACTERIZES {derived:true}` | any EF3.1 category evaluation of these datasets | ReCiPe climate (`IC_RECIPE_GW`) inherits CO₂/CH₄ |
| `refresh_variantA.cypher` (43 grippers) | Variant-A comparisons, `$dataVariant='A-realdataset'` | robustness (A↔B spread) |

### Open

- ~~Name-based bridging for non-CAS flows~~ → done 2026-08-29 (see above).
  Remaining non-CAS flows (e.g. `NMVOC` with empty compartment, GaBi
  "unspecified" groups such as `Alkane (unspecified)`) stay deliberately
  unassessed — marginal by mass, assignment not unambiguous.
- ABS freshwater ecotoxicity dominated by chloride (EF3.1 method-inherent) —
  check / note.
- The PC value 4.19 is the **EU-25 2007 version**; newer PC eco-profiles quote
  ~7.7 kg CO₂e/kg.
- Further downloads (elastomers, PETG, PLA, PA12-specific, CF): proxy/literal
  until a dataset is available.
- ReCiPe 2016 factors for the 17 non-climate categories; afterwards extend
  `harmonize_noncas.cypher` with the ReCiPe counterparts of the alias flows.
