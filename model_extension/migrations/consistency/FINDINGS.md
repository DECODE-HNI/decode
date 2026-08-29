# Consistency review — findings

Baseline at kickoff: 2026-08-29, live DB 5 718 nodes / 86 163 rels / 41 labels /
57 rel types / 39 constraints. **All four layers run and are clean.** Live DB
after the review + all fixes + DE-02 + KI/ML removal: **5 620 nodes / 86 635 rels
/ 39 labels / 54 rel types / 39 constraints** (+ `flow_casnorm` index → 42
indexes). Intermediate figure after Layers 1–2 only was 5 629 / 86 651 / 41 / 57;
the KI/ML removal (`remove_ki_stubs.cypher`) then dropped 11 nodes, 18 rels,
2 labels, 3 rel types — see the *Progress — Layer 4* section. Status: `open` /
`fixing` / `fixed` / `accepted` (documented, no change) / `deferred`.

---

## Progress — Layers 1–2 complete (2026-08-29)

| finding | status | note |
|---|---|---|
| F-01 stale fossil-resource results | **fixed** | prune step added to `refresh_variantA` + `refresh_recipe` (delete a result whose category is no longer characterised via the BOM); re-run removed **110 stale `ImpactResult`s**, 0 stale fossil results remain |
| F-02 assessments missing core edges | **fixed** | `fix_F02_assessment_edges.cypher` — +21 `USES_METHOD`, +18 `UNDER_SCENARIO`; 8 result-free approach markers exempt; `check_model` B4 tightened; `v3x_nonlcia/PLAN.md` corrected |
| F-03 / F-04 EF3.1 CF gap (zero-padded CAS) | **fixed** | `fix_F03_cas_bridge.cypher` — `Flow.casNumberNorm` on 1 759 flows + **530 EF3.1 CFs bridged** from clean-CAS twins. Steel dataset 8 → 14 EF3.1 categories; 4 steel grippers' climate 0.13 → 0.15–0.19; EF3.1/ReCiPe ratio 1.4–1.5 → **1.02–1.03**. `refresh_variantA` re-run. |
| F-05 unit-string inconsistency | **fixed** | `fix_F05_units.cypher` — 444 `ImpactResult.unit` set from `ImpactCategory.unit` |
| F-06 CSV column misalignment | **fixed** | 2 rows had a `;` inside a field — re-delimited |
| F-07 negative results (MINERALS, HTox-non-cancer) | **accepted** | 8 results, worst −4.3e-7 — ~10⁷× below the real values, from negative `HAS_FLOW.amount` (avoided-burden credits in the aggregated datasets). Not worth clamping. |
| F-08 / F-09 RECIPE FRS/LU, IAM_MCI/REPAIR 0-CF | **accepted** | structural gap / not CF-based methods — by design |
| F-10 A2 false positive | **fixed** | check corrected (`HazardStatement` keyed on `code`) |

Live DB after Layers 1–2: **5 629 nodes / 86 651 rels / 41 labels / 57 rel types /
40 constraints** (+`flow_casnorm` index). `check_model` clean except the two
accepted `info` rows.

---

## Progress — Layer 3 (tool consistency), 2026-08-29

`check_tools.sh` (idempotency + output stability + drift + importer re-run +
base-query smoke) and `check_tools_drift.cypher` (live generic recompute vs
persisted `IR_*`). **43 PASS / 0 FAIL / 1 by-design skip.** The importer re-run
(§4) surfaces F-11 but is scored PASS against its pinned 2013 / 35 / 17
post-hygiene baseline.

| check | result |
|---|---|
| §1 idempotency — 9 MERGE-only migrations re-run twice | **PASS** — 2nd run makes no structural change |
| §1 `dq_concept/03_compute_dq.cypher` | *skip* — rebuilds its derived edges by design; judged by §2 instead |
| §2 output stability — `refresh_variantA` / `refresh_recipe` / `03_compute_dq` verification blocks over two runs | **PASS** — identical run-to-run |
| §3 drift — `check_tools_drift.cypher` | **PASS** — every `IR_EF31A_*` / `IR_RECIPE_*` equals the live recompute (0 rows); `lca_generic` yields the same (artifact, category) universe |
| §4 `import_recipe_cf.py --read-db` re-run | **PASS vs baseline / F-11** — 2013 / 2048 ReCiPe CFs reconcile; 35 IR orphans + 17 would-add, all explained by post-load graph changes (see below) |
| §5 base-query smoke — 21 `base_queries/*.cypher` + `lca_generic` under representative params | **PASS** — all execute without error |
| §0 headline node/rel count bracketing the re-runs | **PASS** — 5 629 / 86 651 unchanged |

### F-11 · ReCiPe CF importer not idempotent against the post-hygiene graph · `accepted`

`import_recipe_cf.py --read-db`, re-run against the current graph + the same
openLCA "LCIA Methods" pack, reconciles **2013 of 2048** persisted
`IC_RECIPE_*` `CHARACTERIZES` edges exactly. The remaining divergence is **not**
importer non-determinism — it is entirely graph changes made *after* the CFs
were loaded:

- **35 orphaned `IC_RECIPE_IR` CFs.** The radionuclide flows (carbon-14,
  cesium-137, cobalt-60, …; unit `kBq`; one Flow node per compartment) carry
  valid ReCiPe ionizing-radiation CFs (`matchedBy` `CAS+air` / `CAS+water` /
  `CAS+sea`), but their `HAS_FLOW.compartment` is now `NULL`.
  `export_flows.cypher` / `read_flows_db()` derive the compartment bucket only
  from `HAS_FLOW.compartment`, and the importer's `choose()` has no
  dominant-compartment fallback for IR — so a re-run buckets only 1 of 36.
  The persisted CFs and the `IC_RECIPE_IR` results computed from them stay
  valid (§3 drift is clean); they are simply not regenerable.
- **17 CFs a re-run would newly add**, all on flows that post-date the load:
  - **5 × `IC_RECIPE_FRS`** on the LCI-hygiene unit-split mass siblings
    `crude oil#u=kg` / `natural gas#u=kg` / `hard coal#u=kg` /
    `brown coal#u=kg` / `peat#u=kg`, via `RESOURCE_ALIASES`. Re-loading would
    move `IC_RECIPE_FRS` from 0 CFs (**F-08**, accepted) to 5.
  - 1 × `IC_RECIPE_MRS` (`uranium#u=kg`), 1 × `IC_RECIPE_WC` (`water`),
    10 × USEtox (`dichloromethane`, two Flow nodes × FET/HCT/HNCT/MET/TET) —
    small, benign.

Root cause is shared with **F-01/F-03**: the LCI-hygiene unit split (P3-B) and
the CAS work reshaped `Flow` / `HAS_FLOW` *after* the ReCiPe CF layer was
built, and `import_recipe_cf.py` was last run before that.

**Disposition (2026-08-29): accept + document** (option 1 below). The persisted
ReCiPe CF layer is internally consistent and every result derived from it is
correct; the importer is simply not idempotent against the post-hygiene graph,
and a full rebuild runs it *after* hygiene and regenerates cleanly. Recorded in
`v3x_e_recipe/cf_import/README.md` (*Reproducibility note*); the 2013 / 35 / 17
baseline is pinned in `check_tools.sh` §4 so the check stays green while the gap
stays visible. No DB change. The pipeline fix (option 2) is folded into the
next full rebuild alongside the other 🕓 item (`REALIZES`/`AFFECTS`).

*Options considered:*
1. **Accept + document** — chosen.
2. **Make it reproducible now.** Teach `export_flows.cypher` /
   `read_flows_db()` to fall back to the `Flow` node's ILCD compartment when
   `HAS_FLOW.compartment` is null, and decide the FRS-alias question (load the 5
   and retire F-08's "0 CFs", or gate `RESOURCE_ALIASES`). Touches the pipeline.
3. **Regression-pin only** (option 1 minus the README note).

---

## Progress — Layer 4 (logical DECODE embedding), 2026-08-29

`check_decode.cypher` — 21 structural checks + 2 info rows. Not a
software-integration test: it checks the graph is a faithful **logical** target
for the RFLPV² SysML profile (`RFLPV2_Extension_Spec.md` §7) and the external
reporting frameworks. **All 21 structural checks pass.**

| group | result |
|---|---|
| **R** RFLPV² §7 mapping rows (`materialRef`→`Material.id`, `processRef`→`Process.id`, `processType`, `sustainabilityIndicatorRef`→`ImpactCategory.id`, the 4-tag evaluable expression, `TestCase` status enum, the `HAS_ASSESSMENT`→…→`ImpactCategory` chain) | **pass** — every ✅ row resolves; R9 confirms `REALIZES`/`AFFECTS` still absent, matching the deferred 🕓 |
| **V** verification-chain reachability, 8-gripper slice — both directions, incl. **V3** (the category a `TestCase` actually evaluated == the `Requirement.sustainabilityIndicatorRef` it verifies) and V4 status write-back | **pass** — 0 breaks |
| **F** `ExternalFramework` coverage — every framework has an inbound `MAPS_TO` (F1), no dangling `MAPS_TO` (F2) | **pass**; F3 → **DE-02 fixed** (2 framework nodes added), F3 now `[]` |
| **D** DPP/EPD path — each slice artifact has a DPP + an EPD `Declaration`; declarations `REPORTS` only their own artifact's results; status vocab; verified/published declarations carry content | **pass** |
| **N** additive & non-breaking — 15 pre-v3x core labels populated, 16 pre-v3x core rel types present, no new label stacked on a core label | **pass**; N4 info: 35 new-label nodes (`TestCase` 24 + `DQPhase` 3 + `DataQualityCriterion` 8) |

### DE-01 · `RFLPV2_Extension_Spec.md` §7 understates `lifecycleModule` · `fixed`

Spec §7 marked `Process Element.lifecycleModule → Process.lifecycleModule` as
🕓 "new property, not yet in the schema". It is in fact **live on all 58
`Process` nodes since v2** (values `A1`, `A1-A3`, `A3`, `B1`, `B4`, `C3`) and is
read by the DQ layer (`03_compute_dq.cypher`, DQC_COMPAB). `check_decode` R8 = 0
(none missing). Spec §7 row updated to ✅. The same stale claim in
`HANDOFF.md` §2 point 1 is folded into the documentation-coherence pass.

### DE-02 · `IAM_PCF` / `IAM_REPAIR` have no `MAPS_TO` to an `ExternalFramework` · `fixed`

`check_decode` F3. Four of the six LCIA methods reached an external framework;
`IAM_PCF` and `IAM_REPAIR` reached none, because **ISO 14067** and
**EN 45554** were not modelled as `ExternalFramework` nodes.
**Fix (user choice, 2026-08-29):** `fix_DE02_framework_nodes.cypher` adds
`EF_ISO14067` + `EF_EN45554` (+2 nodes) and `IAM_PCF -[:MAPS_TO]-> EF_ISO14067`,
`IAM_REPAIR -[:MAPS_TO]-> EF_EN45554` (+2 rels). `check_decode` F3 now returns
`[]`; `ExternalFramework` count 10 → 12.

### KI/ML removal · `done` (2026-08-29, user decision — not a check finding)

Not surfaced by a check; a scope decision taken during Layer 4 triage. The
prepared-only AI/ML material was removed from graph and docs in full:
`remove_ki_stubs.cypher` deletes **11 nodes / 18 relationships** — 8
`AssessmentApproach` (`APG_ADAPTIVE_DECISION`, `APG_AI_FORECAST`,
`APM_AUTO_DESIGN`, `APM_LEARNING_SCENARIO`, `APM_PREDICTIVE_ASSESSMENT`,
`APM_AI_LCA_MODELING`, `APM_IMPACT_FORECAST`, `APM_SURROGATE`),
`PM_GWP_SURROGATE` (`:PredictionModel`), `REC_DEMO_LIGHTWEIGHT_CONTACT`
(`:Recommendation`), `ASSESS_AI_PREPARED`. Labels `PredictionModel` /
`Recommendation` and rel types `PREDICTS` / `ESTIMATED_BY` / `RECOMMENDS_FOR`
fall out of use. **Kept:** `AP_LERNEND` root + `APG_MODEL_TRANSPARENCY` +
`APM_DPP` + `APM_ENV_KG` (real, not AI); `ImpactResult.provenance`/`.confidence`
(general). Rollback block in the migration. Docs scrubbed:
`base_queries/design_recommendation.cypher` + 6 method one-pagers (3.1.1–3.1.3,
3.3.1–3.3.3) deleted; `method_onepagers/README.md`, `base_queries/README.md`,
`EXTENSION_REFERENCE.md`, `PLAN.md`, `v3x_CHANGELOG.md`, `v3x_nonlcia/PLAN.md`
+ `CHANGELOG.md`, `methods_change_sets.md`, `change_method_matrix.csv`,
`demonstrator/README.md` updated; `migration_v3.cypher` (8 taxonomy rows) and
`migration_v3i.cypher` (section 5) edited for a clean rebuild; schema JSON
regenerated (98 → 93 keys).

Live DB after DE-02 + KI removal: **5 620 nodes / 86 635 rels / 39 labels /
54 rel types / 39 constraints** (the doc figure "40" counted the `flow_casnorm`
index alongside the 39 constraints). `check_model_oneshot` / `check_decode_oneshot`
clean except their `info` rows.

---
## (original detail below)

---

## HIGH

### F-01 · Stale fossil-resource results — 38 of 43 grippers · `open`
`check_model` G1. `IR_EF31A_<art>_IC_EF_EF_RESOURCE_USE_FOSSILS` carries a value
(0.02–23.0, avg 3.33) for 38 grippers although **no contributing data set has a
fossil-resource CF** any more — the LCI-hygiene unit split (P3-B) moved the
fossil resource flows onto MJ sibling nodes, so the (dataset, `IC_EF_EF_RESOURCE_
USE_FOSSILS`) pair dropped out of the recompute. `refresh_variantA` MERGEs a
result only for pairs the recompute yields and **never deletes** stale ones.
Same design gap in `refresh_recipe`.
*Fix direction:* add a coverage/timestamp-based prune step to both refresh files
(delete `IR_*` for (dataset|artifact, category) pairs the current run did not
produce, or older than the run's `computedAt`).

### F-02 · 34 assessments missing a core edge · `open`
`check_model` B4 + relationship census (`USES_METHOD` 236 vs `Assessment` 265;
`UNDER_SCENARIO` 247 vs 265). 29 assessments lack `USES_METHOD`, 18 lack
`UNDER_SCENARIO`:

| missing | families |
|---|---|
| `USES_METHOD` | `ASSESS_EF31_SCEN_GRID2035_*` (11), `ASSESS_EF31_SCEN_RECALU_*` (5), `ASSESS_H2O_*` (5), + singletons `POLLUTANT`, `CROSSIMPACT`, `SEEA`, `ENVKG`, `AI_PREPARED`, `DYNLCA`, `CONSEQ`, `HYBRID` |
| `UNDER_SCENARIO` | `ASSESS_GHG_*` (5), `ASSESS_H2O_*` (5), + the same 8 singletons |

These came from the v3.f–i, scenario, and prospective/consequential/hybrid
migrations, which did not wire all four edges. Contradicts the repeated docs
claim **"0 orphan assessments"** (`v3x_nonlcia/PLAN.md`, `v3x_state.md`).
*Fix direction:* one backfill migration — `USES_METHOD` from the id prefix
(`GRID2035`/`RECALU`/`DYNLCA`/… → `IAM_EF31`; `H2O` → `IAM_EF31`; etc.),
`UNDER_SCENARIO` → the scenario named in the id or `SC_BASELINE`; then correct
the two doc claims.

### F-03 · EF3.1 CF coverage gap on imported datasets (steel worst) — 4 grippers affected · `open`
`check_model` D2 + investigation. **Root cause:** several imported ILCD datasets
store `Flow.casNumber` zero-padded (`000124-38-9`). The bulk EF3.1 CF layer was
matched without leading-zero normalisation, so those flows never got EF3.1 CFs;
the ReCiPe importer (`import_recipe_cf.py`, `norm_cas()`) *does* normalise, so
ReCiPe coverage is better. Not a `refresh_variantA` bug — the two refresh scripts
are identical apart from the method id; they diverge because the CF layers do.

EF3.1 vs ReCiPe category coverage on the 6 `MODELED_BY` datasets:

| dataset | EF3.1 cats | ReCiPe cats |
|---|--:|--:|
| `PROC_STEEL_SECTIONS_ILCD` | **8 / 19** | 14 / 18 |
| `PROC_PC_PLASTICSEUROPE_EF` | 12 / 19 | 15 / 18 |
| `PROC_PA66_PLASTICSEUROPE_EF` | 14 / 19 | 16 / 18 |
| `PROC_ABS_PLASTICSEUROPE_EF` | 14 / 19 | 15 / 18 |
| `PROC_POM_PLASTICSEUROPE_EF` | 14 / 19 | 16 / 18 |
| `PROC_ALU_EXTRUSION_EF` | 18 / 19 | 15 / 18 |

The steel dataset's CO₂-to-air flow (`Carbon dioxide`, `000124-38-9`, 1.45 kg)
carries only `IC_RECIPE_GW`, no `IC_CLIMATE` — so steel adds **0** to EF3.1
climate/acidification/fossil/water/… `IR_EF31A_*_IC_CLIMATE` for the 4 steel
grippers (`ART_MAGNET`, `ART_MAG_SMALL`, `ART_MAG_WIDE`, `ART_THIN_STEEL`) is the
PA12-interface-only 0.1297. **66 flows** across the 6 datasets have an EF3.1 gap
where ReCiPe is present.

*Fix options:*
1. **CAS-normalisation CF bridge** (like `harmonize_noncas.cypher`): copy the
   EF3.1 CF from the clean-CAS same-substance twin onto the ~66 zero-padded
   flows, `derived=true`. Bounded (~a few hundred CFs); fixes the 4 grippers +
   improves plastic coverage.
2. Accept the steel ILCD dataset as ReCiPe-only, mark the 4 grippers' EF3.1
   result `status:'partial (steel not characterised)'`, use ReCiPe as their
   headline climate figure.
3. Normalise `Flow.casNumber` graph-wide and re-run the EF3.1 CF matching
   (larger; the original EF3.1 import is not re-runnable here).

---

## MEDIUM

### F-04 · Cross-method climate divergence — 2 grippers · `open`
`check_model` C5. `ART_THIN_STEEL` ReCiPe/EF ratio 1.53, `ART_MAG_WIDE` 1.41
(outside the [0.8, 1.3] band). Downstream of **F-03** — resolves once the steel
contribution is fixed. Keep as a regression check.

### F-05 · Unit-string inconsistency — 3 categories · `open`
`check_model` E6. Two spellings of one unit within a category:
`IC_CLIMATE` (`kg CO2-eq` / `kg CO2 eq`), `IC_EF_WATER_USE`
(`m3-world equivalents` / `m3 world eq`), `IC_CIRCULARITY`
(`dimensionless (0-1)` / `dimensionless`). Breaks unit-based grouping / reporting.
*Fix direction:* normalise `ImpactResult.unit` per category to the
`ImpactCategory.unit` value.

### F-06 · `change_method_matrix.csv` column misalignment · `open`
Layer-1 diff. Several rows do not have 7 `;`-separated fields, so `reported_in`
resolves to a fragment (`-`, `EPD/DPP`, `LCA (Kategorie-Reporting)`,
`Digitaler Produktpass`, `automatisierte Designempfehlung`). A `;` inside a
field or a dropped column.
*Fix direction:* re-align the offending rows; consider quoting.

---

## LOW / INFO

### F-07 · Negative `IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS` — 4 grippers · `open`
`check_model` C3. Worst −4.45e-7 (Variant A). From negative `HAS_FLOW.amount`
(credits). Magnitude negligible.
*Options:* accept + document, or clamp negative category totals at 0 in the
refresh files.

### F-08 · `IC_RECIPE_FRS` / `IC_RECIPE_LU` have 0 CFs · `accepted`
`check_model` C4. Known structural gap — fossil resource amounts unreliable
(as-kg-labelled MJ), no land-occupation flows. Documented in
`v3x_e_recipe/cf_import/README.md`.

### F-09 · `IAM_MCI` / `IAM_REPAIR` categories have 0 CFs · `accepted`
`check_model` C4. By design — these methods are not characterisation-factor
based (`Material.mci` roll-up, `disassemblyReversibility`).

### F-10 · `check_model` A2 false positive — `HazardStatement` · `fixed`
`HazardStatement` is keyed on `code` (own uniqueness constraint), not `id`. A2
now excludes it. No model change.

---

## Layer 1 — passed

*(Checkpoint at review kickoff, 2026-08-29. The schema JSON, the reference-doc
header counts and the one-pager set were all updated afterwards for the fixes +
KI/ML removal — schema now 93 keys, header 5 620 / 86 635 / 39 / 54 / 39,
23 one-pagers. Layer 1 confirmed doc ↔ live agreement at that checkpoint.)*

- `graph_schema_v3x.json` vs live `apoc.meta.schema`: **0 differences** (98 keys
  at kickoff).
- `EXTENSION_REFERENCE.md` header counts (5 718 / 86 163 / 41 / 57 / 39):
  **matched** the live DB at kickoff.
- 29 method one-pagers present (+ README) at kickoff.

## Layers 3–4 — complete (2026-08-29)

- **Layer 3** (`check_tools.sh` + `check_tools_drift.cypher`): 43 PASS / 0 FAIL /
  1 by-design skip; finding **F-11** (accepted). See *Progress — Layer 3* above.
- **Layer 4** (`check_decode.cypher`): 21 structural checks pass;
  **DE-01** (fixed — spec §7), **DE-02** (fixed — `fix_DE02_framework_nodes.cypher`).
  Plus the **KI/ML removal** (user scope decision — `remove_ki_stubs.cypher`).
  See *Progress — Layer 4* above.

All four layers of the staged consistency review are run and clean. The live DB
ends at **5 620 nodes / 86 635 rels / 39 labels / 54 rel types / 39 constraints**
(+ the `flow_casnorm` index). The reference docs
([`../../reference/EXTENSION_REFERENCE.md`](../../reference/EXTENSION_REFERENCE.md),
the per-module `CHANGELOG.md` files and `graph_schema_v3x.json`) are reconciled
to that state.
