# Data-quality concept — automated / semi-automated edge scoring

> **Status:** applied & verified on the live DB, 2026-08-29.
> 8 criteria restructured, 3 engineering phases + 24 target edges, 6 LCI data
> sets and 155 LCA assessments carry an auto-derived 0..4 DQ profile (the
> assessment count grew from 134 to 155 after the demonstrator slice added
> `IAM_EF31`/`IAM_RECIPE` assessments and `03_compute_dq.cypher` was re-run).
> Read it with [`../../base_queries/dq_radar.cypher`](../../base_queries/dq_radar.cypher).

Aligns the graph's data-quality layer with the published HNI concept
(Rarbach / Gräßler / Pottebaum — *"Data Quality in the Engineering of Circular
Products"*, Industry 4.0 Science 2025; *"Metadata-based assessment of Data
Quality"*, Procedia CIRP 142, 2026) and answers the standing question: **how much
of the assessment can be automated from metadata already on the edges?**

## What changed vs the old DQ layer

| Before | After |
|---|---|
| 8 `DataQualityCriterion` nodes, flat list, `scale` empty | + `class` (inherent / system), `derivation` (auto / semi-auto / manual), `scale='0..4'`, `isoRef`, `pedigreeIndicator` |
| 5 `DataQuality` presets on the Weidema `1..5` scale | rescaled to `0..4` (**4 = optimal**; `new = old − 1`); 23 hand-authored `EVALUATES_CRITERION` scores rescaled with them |
| DQ attached to 22 hand-picked `DataItem`s (artifact mass / geometry only) | DQ also computed for **every LCI data set** (`Material-[:MODELED_BY]->Process`) and rolled up onto **every LCA `Assessment`** |
| implicit single `overallScore` (looked like an average) | **no aggregation.** A data set's quality against a phase is the *worst* criterion vs that phase's `minScore`. `meanScoreInfo` is stored but never a pass criterion |
| no notion of "good enough for what" | `DQPhase` (screening / design / declaration) + `(:DQPhase)-[:TARGETS {minScore}]->(:DataQualityCriterion)` — a min-based gate per phase |

## Criteria (ISO 14044 6.3.6), split as published

| id | criterion | class | derivation | pedigree indicator |
|---|---|---|---|---|
| `DQC_TEMP` | Temporal representativeness | system | **auto** | temporal correlation |
| `DQC_GEO` | Geographical representativeness | system | **auto** | geographical correlation |
| `DQC_TECH` | Technological representativeness | system | **auto** | further technological correlation |
| `DQC_COMP` | Completeness | inherent | semi-auto | completeness |
| `DQC_CONS` | Methodological consistency | inherent | semi-auto | — |
| `DQC_COMPAB` | Comparability | inherent | semi-auto | — |
| `DQC_ACC` | Accuracy / precision | inherent | **manual** | reliability |
| `DQC_UNC` | Uncertainty | inherent | **manual** | reliability |

*Answer to "is automation realistic?"* — **yes for six of eight criteria.** The
three representativeness criteria come straight from node/edge metadata; three
more are semi-automatic from graph structure. Only accuracy/precision and
uncertainty need an expert at the gate — those edges are created once with
`score = null` and never overwritten by a re-run.

## How each score is derived (`03_compute_dq.cypher`)

Study frame: reference year **2026**, target geography **DE** (EU / RER counts as
"good", not optimal).

| criterion | source | banding |
|---|---|---|
| `DQC_TEMP` | `Process.referenceYear` vs 2026 | ≤3 y → 4, ≤6 → 3, ≤10 → 2, ≤15 → 1, else / null → 0 (Weidema temporal-correlation bands, inverted) |
| `DQC_GEO` | `Process.geographicalLocation` | DE → 4; EU/RER → 3; GLO/RoW → 2; other single country → 1; none → 0 |
| `DQC_TECH` | `MODELED_BY.proxy` / `.proxyRationale` (+ `HAS_FLOW.dataMaturity`) | real data set → 4; closest-real proxy → 3; generic / average → 2; cross-material surrogate → 1. −1 if any flow is `screening/reference` |
| `DQC_COMP` | EF3.1 impact-category coverage of the data set's characterised flows | ≥95 % → 4, ≥85 % → 3, ≥70 % → 2, ≥50 % → 1, else 0 (measures dataset breadth, **not** the LCIA method's missing trace-substance CFs) |
| `DQC_CONS` | share of the data set's CFs that are harmonised / proxy / low-confidence bridges | ≤2 % → 4, ≤10 % → 3, ≤25 % → 2, else 1 |
| `DQC_COMPAB` | `lifecycleModule` + `dataSetType` present (ILCD / EN 15804 shape) | both → 3, module only → 2, else 1. Capped at 3 — EN 15804 sub-type and functional-unit alignment stay manual |
| `DQC_ACC`, `DQC_UNC` | — | `score = null`, `rating = 'expert assessment required at gate'` |

**Assessment roll-up:** for every `Assessment` that uses `IAM_EF31` or `IAM_RECIPE`
and whose artifact reaches a modelled data set (same `Artifact → Assembly → Part
(mass_g) → Material → MODELED_BY` join as `refresh_variantA` / `refresh_recipe`),
each criterion = **MIN** over the contributing data sets. `worstScore` on the DQ
node is the min across criteria — the number the gate reads.

## Phases & gate (`02_phase_targets.cypher`)

`minScore` matrix — **default values, to be tuned against the published phase
targets** (`TARGETS.basis = 'default'` on every edge):

| criterion | `PH_SCREENING` | `PH_DESIGN` | `PH_DECLARATION` |
|---|--:|--:|--:|
| DQC_TEMP | 1 | 2 | 3 |
| DQC_GEO | 1 | 2 | 3 |
| DQC_TECH | 1 | 2 | 3 |
| DQC_COMP | 1 | 2 | 3 |
| DQC_CONS | 1 | 3 | 4 |
| DQC_COMPAB | 0 | 2 | 3 |
| DQC_ACC | 1 | 2 | 3 |
| DQC_UNC | 0 | 1 | 2 |

A phase **passes** iff every criterion score ≥ its `minScore`. Manual criteria
with `null` score count as *not met* — a declaration gate cannot be passed
without the expert accuracy / uncertainty assessment.

## Result on the current demonstrator

| gate | passing / scored |
|---|---|
| `PH_SCREENING` | 121 / 155 |
| `PH_DESIGN` | 0 / 155 |
| `PH_DECLARATION` | 0 / 155 |

The single binding constraint is **`DQC_TEMP`**: the free PlasticsEurope / ILCD
eco-profiles are from 2007–2011, so every assessment scores 0–1 on recency and
none clears the design-freeze gate. This is the intended outcome — the layer
tells the engineer exactly what to fix (newer background data) to move up a gate,
rather than hiding it in an average.

## Files & run order

```
01_criteria_catalogue.cypher   criteria restructure + 1..5 -> 0..4 rescale
02_phase_targets.cypher         DQPhase (3) + TARGETS (24) + constraint
03_compute_dq.cypher            automated / semi-automated scoring + roll-up
../../base_queries/dq_radar.cypher   read: radar vector + phase gate (params)
```

All three are idempotent / re-runnable. `03` drops and recomputes auto edges
each run; manual edges are created once and preserved. Rollback blocks are at the
foot of each file.

## Known limits

- `DQC_COMP` / `DQC_CONS` are referenced to **EF3.1** (the case-study standard
  method); a ReCiPe-specific completeness view is not computed separately.
- `DQC_TECH` proxy-rationale banding uses keyword regexes on `proxyRationale`
  free text — robust for the six current data sets, review when new ones land.
- The `minScore` matrix and the temporal bands are defensible defaults, not the
  published numbers — tune both, then re-run `02` (matrix) only.
- Only the 6 `MODELED_BY` data sets get a node-level DQ profile; manufacturing
  processes with only `energyIntensity` (Variant B / CED) are out of scope.
