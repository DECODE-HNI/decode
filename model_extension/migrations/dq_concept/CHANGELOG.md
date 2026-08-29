# Data-quality concept — change log

## 2026-08-29 — First cut: published DQ concept + automated edge scoring

Aligns the data-quality layer with the published HNI models
(Rarbach / Gräßler / Pottebaum) and answers the open question of how far the
scoring can be automated from metadata already on the edges and nodes:
**six of eight criteria** are computed automatically or semi-automatically,
only accuracy and uncertainty stay manual at the gate.

Strictly additive apart from two points that rescale existing values
(`01`, result-neutral): the 5 `DataQuality` presets and their 23
`EVALUATES_CRITERION` edges move from the Weidema scale `1..5` to `0..4`
(4 = optimal, `new = old − 1`). Rollback blocks at the foot of each file.

### Parts

| File | Effect | Scope |
|---|---|---|
| **`01_criteria_catalogue.cypher`** | 8 `DataQualityCriterion` given `class` (inherent / system), `derivation` (auto / semi-auto / manual), `scale='0..4'`, `isoRef`, `pedigreeIndicator`. 5 `DataQuality` presets + 23 edges rescaled to `0..4`. | 8 criteria, 5 nodes, 23 edges |
| **`02_phase_targets.cypher`** | `DQPhase` (`PH_SCREENING` / `PH_DESIGN` / `PH_DECLARATION`) + `(:DQPhase)-[:TARGETS {minScore}]->(:DataQualityCriterion)`. Constraint `DQPhase_id_unique`. The target matrix is a **default**, to be tuned against the published phase target values (`TARGETS.basis='default'`). | 3 nodes, 24 edges, 1 constraint |
| **`03_compute_dq.cypher`** | Per LCI dataset (`Material-[:MODELED_BY]->Process`, 6 of them) a `DQ_AUTO_<procId>` node with `EVALUATES_CRITERION` edges per criterion; roll-up per LCA `Assessment` as **MIN** over the contributing datasets. `worstScore`/`meanScoreInfo` per node — only `worstScore` drives the gate. Re-runnable: auto edges are recomputed each run, manual edges (`DQC_ACC`/`DQC_UNC`, `score=null`) are created once and never overwritten. | 6 + N `DataQuality` nodes, matching `HAS_DATA_QUALITY`, `EVALUATES_CRITERION` |
| **`../../../methods/base_queries/dq_radar.cypher`** | Read query: 8-axis radar vector + phase target vector + pass/fail per axis + overall `gatePass` (AND over all axes), plus a progress view across all three phases. Parameters `$assessmentId`, `$phase`. | — |

### Derivation rules (study frame: reference year 2026, target geography DE)

| Criterion | Source | Bands |
|---|---|---|
| `DQC_TEMP` | `Process.referenceYear` vs 2026 | ≤3 y → 4, ≤6 → 3, ≤10 → 2, ≤15 → 1, else / null → 0 |
| `DQC_GEO` | `Process.geographicalLocation` | DE → 4; EU/RER → 3; GLO/RoW → 2; other single country → 1; none → 0 |
| `DQC_TECH` | `MODELED_BY.proxy` / `.proxyRationale` (+ `HAS_FLOW.dataMaturity`) | real dataset → 4; nearest real proxy → 3; generic/average → 2; cross-material surrogate → 1; −1 on `screening/reference` flows |
| `DQC_COMP` | EF3.1 impact-category coverage of the characterised flows | ≥95 % → 4, ≥85 % → 3, ≥70 % → 2, ≥50 % → 1, else 0 |
| `DQC_CONS` | share of harmonised / proxy / low-confidence CFs | ≤2 % → 4, ≤10 % → 3, ≤25 % → 2, else 1 |
| `DQC_COMPAB` | `lifecycleModule` + `dataSetType` present | both → 3, module only → 2, else 1 (capped at 3) |
| `DQC_ACC`, `DQC_UNC` | — | `score=null`, manual at the gate |

### Result on the current demonstrator

| Gate | passing / scored | binding constraint |
|---|---|---|
| `PH_SCREENING` | 121 / 155 | `DQC_TEMP` (pure-plastic grippers whose dataset age → 0) |
| `PH_DESIGN` | 0 / 155 | `DQC_TEMP` (all) |
| `PH_DECLARATION` | 0 / 155 | `DQC_TEMP` + manual criteria open |

The free PlasticsEurope / ILCD eco-profiles are from 2007–2011, so the data
is good enough for a screening estimate, not for a design-freeze decision or
an EPD. That is the intended behaviour — the layer names the gap (newer
background data) rather than hiding it in an average.

*(The assessment count rose from 134 to 155 after the demonstrator slice added
`IAM_EF31`/`IAM_RECIPE` assessments and `03_compute_dq.cypher` was re-run
during the Layer-3 tool-consistency check.)*

### Live DB after (this run, before the demonstrator + consistency review)

**5 653 nodes · 85 846 relationships · 40 labels · 54 relationship types ·
38 constraints** · 0 label-less · LCA core results unchanged
(`IC_RECIPE_GW` 0.134–0.536; `IC_CLIMATE` unchanged).

### Open / for the consistency review

- Tune the target matrix and the temporal bands against the published phase
  target values (re-run `02` only).
- `DQC_COMP` / `DQC_CONS` are EF3.1-based; ReCiPe-specific completeness is not
  computed separately.
- `DQC_TECH` proxy bands use a keyword regex on the `proxyRationale` free text —
  check on new datasets.
- Manual criteria (`DQC_ACC`/`DQC_UNC`) are still unscored (`null`) for the 6
  datasets — expert entry at the respective engineering gate.
