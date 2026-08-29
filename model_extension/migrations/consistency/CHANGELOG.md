# Consistency review — change log

## 2026-08-29 — Layer 4 follow-up (DE-02 + KI/ML removal)

- **DE-02 fixed** — `fix_DE02_framework_nodes.cypher`: `ExternalFramework`
  `EF_ISO14067` + `EF_EN45554` created, `IAM_PCF -[:MAPS_TO]-> EF_ISO14067`
  and `IAM_REPAIR -[:MAPS_TO]-> EF_EN45554`. `check_decode` F3 now `[]`;
  frameworks 10 → 12.
- **KI/ML removed** (user decision, not a check finding) —
  `remove_ki_stubs.cypher`: 11 nodes / 18 relationships deleted (8
  `AssessmentApproach` nodes of the 3.1.x/3.3.x branches, `PM_GWP_SURROGATE`,
  `REC_DEMO_LIGHTWEIGHT_CONTACT`, `ASSESS_AI_PREPARED`). Labels
  `PredictionModel`/`Recommendation` and relationship types `PREDICTS`/
  `ESTIMATED_BY`/`RECOMMENDS_FOR` fall out of use. Kept: `AP_LERNEND` +
  `APG_MODEL_TRANSPARENCY` + `APM_DPP`/`APM_ENV_KG`. Rollback block in the file.
  Docs updated throughout; `design_recommendation.cypher` + 6 one-pagers
  (3.1.1–3.1.3, 3.3.1–3.3.3) deleted; `migration_v3.cypher` /
  `migration_v3i.cypher` cleaned for the rebuild; schema JSON 98 → 93 keys.
- **Live DB after: 5 620 nodes / 86 635 relationships / 39 labels /
  54 relationship types / 39 constraints** (+ `flow_casnorm` index). Both
  one-shot checks clean apart from their `info` rows.

## 2026-08-29 — Layer 4: logical DECODE embedding

New: `check_decode.cypher` — 21 structural checks + 2 info rows. **Not** a
software-integration test: it checks whether the graph is a sound *logical*
target for the RFLPV² profile (`RFLPV2_Extension_Spec.md` §7) and the external
reporting frameworks. **All 21 structural checks pass.**

- **R** — RFLPV² §7 rows resolve in the graph (`materialRef`→`Material.id`,
  `processRef`→`Process.id`, `processType`, `sustainabilityIndicatorRef`→
  `ImpactCategory.id`, the 4-tag evaluable expression, the `TestCase` status
  enum, the `HAS_ASSESSMENT`→…→`ImpactCategory` chain). R9 confirms
  `REALIZES`/`AFFECTS` still absent — matches the documented 🕓.
- **V** — verification-chain reachability for the 8-gripper slice, both
  directions, incl. V3 (the category a `TestCase` actually evaluated ==
  the `sustainabilityIndicatorRef` of the `Requirement` it verifies). 0 breaks.
- **F** — every `ExternalFramework` has an inbound `MAPS_TO` (F1=0), no dangling
  `MAPS_TO` (F2=0). **F3 (info) → DE-02.**
- **D** — each slice gripper has a DPP + an EPD; declarations report only their
  own results; status vocabulary; verified/published declarations carry content.
- **N** — 15 pre-v3x core labels populated, 16 pre-v3x core relationship types
  present, no new label stacked on a core label. N4: 35 new-label nodes
  (`TestCase` 24 + `DQPhase` 3 + `DataQualityCriterion` 8).

### Findings

- **DE-01** (`fixed`) — `RFLPV2_Extension_Spec.md` §7 listed
  `Process.lifecycleModule` as 🕓 "not yet in the schema". It is in fact live
  on all 58 `Process` nodes since v2 (`A1`/`A1-A3`/`A3`/`B1`/`B4`/`C3`), read by
  the DQ layer. §7 row corrected to ✅; the same stale claim in `HANDOFF.md`
  (working copy) folded into the documentation-coherence pass.
- **DE-02** (`open — triage`) — `IAM_PCF` / `IAM_REPAIR` have no `MAPS_TO` path
  to an `ExternalFramework` (ISO 14067 / EN 45554 were not modelled as framework
  nodes). The other 4 methods are covered. Options: add two framework nodes +
  `MAPS_TO`, or accept. → fixed, see the section above.

## 2026-08-29 — Layer 3: tool consistency

New: `check_tools.sh` (idempotency + output stability + drift + importer re-run
+ base-query smoke test, with a headline-count guard bracketing the re-runs) and
`check_tools_drift.cypher` (reproduces the shared `CALL{}` block of
`refresh_variantA` / `refresh_recipe` / `lca_generic` and diffs it against
`IR_EF31A_*` / `IR_RECIPE_*`).

**Result: 43 PASS / 0 FAIL / 1 skip (by design).** Section 4 surfaces F-11 but
is scored PASS against the pinned 2013 / 35 / 17 baseline.

- **§1 idempotency** — the 9 MERGE-only migrations (`refresh_variantA`,
  `refresh_recipe`, `dq_concept/01`+`02`, `demonstrator/00`–`04`) run twice: the
  2nd run makes no structural change (only `SET` on existing properties).
  `dq_concept/03_compute_dq` rebuilds its derived edges by design → judged by
  section 2 only.
- **§2 output stability** — the verification `RETURN` blocks of
  `refresh_variantA` / `refresh_recipe` / `03_compute_dq` are identical across
  two runs.
- **§3 drift** — every persisted `IR_EF31A_*` / `IR_RECIPE_*` equals the live
  recompute (0 rows); `lca_generic(IAM_EF31)` yields the same
  (artifact, category) set as the persisted results.
- **§4 ReCiPe CF importer re-run** → **F-11** (`accepted`): 2013 / 2048 ReCiPe
  CFs reconcile exactly; 35 `IC_RECIPE_IR` CFs (radionuclide flows, `kBq`,
  `HAS_FLOW.compartment` now `NULL`) are no longer reproducible by the current
  importer, and 17 CFs (incl. 5 × `IC_RECIPE_FRS` on the hygiene-split `#u=kg`
  siblings) would be newly added on a `--load`. Root cause as F-01/F-03: the
  LCI-hygiene unit split post-dates the CF layer. Decision: accept + document
  (`cf_import/README.md`, *Reproducibility note*); baseline 2013 / 35 / 17
  pinned in `check_tools.sh` §4; pipeline fix folded into the next full rebuild.
- **§5 base-query smoke test** — all 21 `base_queries/*.cypher` + `lca_generic`
  run without error under representative parameters.
- **§0** — headline 5 629 / 86 651 unchanged by the re-runs.

## 2026-08-29 — Layers 1–2: harness + eight findings

Check harness `check_meta.cypher` (Layer 1, meta / docs) + `check_model.cypher`
(Layer 2, ~40 model checks) created, baseline in `FINDINGS.md`. All eight
Layer 1–2 findings closed out.

### Fixes

| finding | file | effect |
|---|---|---|
| **F-01** stale `ImpactResult` | prune step in `v2_data/ilcd_import/refresh_variantA.cypher` + `v3x_e_recipe/cf_import/refresh_recipe.cypher` | Deletes a result whose category is no longer characterised via the BOM by any flow. Re-run: **−110 stale `ImpactResult`** (incl. 38 wrong fossil-resource values after the unit split). |
| **F-02** assessments missing a core edge | `fix_F02_assessment_edges.cypher` | +21 `USES_METHOD` (`GRID2035`/`RECALU`/`H2O`), +18 `UNDER_SCENARIO` → `SC_BASELINE`. The 8 result-free method markers stay methodless by design; `check_model` B4 tightened accordingly. `v3x_nonlcia/PLAN.md` corrected. |
| **F-03/F-04** EF3.1 CF gap (zero-padded CAS) | `fix_F03_cas_bridge.cypher` | `Flow.casNumberNorm` (leading zeros stripped) on 1 759 flows + index. **530 EF3.1 CFs** bridged from the clean-CAS twin (same normalised CAS + same substance name) onto the zero-padded flows, `derived=true`. Steel dataset 8 → 14 EF3.1 categories; the 4 steel grippers' climate 0.13 → 0.15–0.19; EF3.1/ReCiPe ratio 1.4–1.5 → **1.02–1.03**. `refresh_variantA` re-run. |
| **F-05** unit-string spellings | `fix_F05_units.cypher` | 444 `ImpactResult.unit` set from `ImpactCategory.unit` (one source of truth). |
| **F-06** `change_method_matrix.csv` column misalignment | — | 2 rows with a `;` inside a field re-delimited. |

### Accepted (documented, no change)

- **F-07** — 8 negative results (MINERALS, human tox. non-cancer), worst
  −4.3e-7 (~10⁷× below the real values; credit amounts in the aggregated
  datasets). Not worth clamping.
- **F-08/F-09** — `IC_RECIPE_FRS`/`LU` without CF (structural gap),
  `IAM_MCI`/`IAM_REPAIR` without CF (not CF-based).

### Live DB after

**5 629 nodes / 86 651 relationships / 41 labels / 57 relationship types /
40 constraints** (+ `flow_casnorm` index). `check_model` clean apart from the two
accepted `info` rows. Demonstrator verification chain: **19 passed / 3 failed /
2 inconclusive** (`TC_MAG_GWP` from `inconclusive` → `passed`, steel now
characterised).

### Open (as of Layers 1–2)

Layer 3 (re-run tools + diff, idempotency, base-query smoke test), Layer 4
(DECODE embedding: RFLPV² §7 mapping, verification chain, framework coverage).
— **Both now done**, see the sections above (2026-08-29). Final live DB:
5 620 / 86 635 / 39 / 54 / 39.
