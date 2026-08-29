# v3.x model state 2026-08-27 (after modules a–d + repair pass)

> **Historical milestone (modules a–d).** No longer the current model state.
> The graph was extended substantially afterwards (v3.e ReCiPe, v3.f–i, v2-data
> imports, LCI hygiene, DQ concept, demonstrator slice, consistency review
> Layers 1–4, KI removal). **Current state:
> [`../reference/EXTENSION_REFERENCE.md`](../reference/EXTENSION_REFERENCE.md)** —
> live DB 2026-08-29: **5 620 nodes / 86 635 relationships / 39 labels /
> 54 relationship types / 39 constraints**. Full snapshot: generated locally,
> not committed (see the repository README on the snapshots). Per-module
> history: [`v3x_CHANGELOG.md`](v3x_CHANGELOG.md).

A full `.cypher` dump was still pending at the time of this state (done since,
see above). Authoritative deltas: `v3x_a..d/migration_v3*.cypher` +
`v3x_repair.cypher`.

## Counters

| | v3 | v3.x | Δ |
|---|---:|---:|---:|
| Nodes | 2 802 | **2 917** | +115 |
| Relationships | 79 815 | **80 298** | +483 |
| Constraints | 29 | **36** | +7 |

## New labels (v3.x)

| Label | n | Module |
|---|---:|---|
| `AssessmentApproach` | 41 | v3 (here: deduplicated) |
| `EndOfLifeRoute` | 4 | v3.a |
| `CostItem` | 5 | v3.b |
| `ModelScenario` | 2 | v3.c |
| `Parameter` | 1 | v3.c |
| `ParameterValue` | 1 | v3.c |
| `Declaration` | 2 | v3.d |

`Assessment` 43 → **96** (+5 MCI, +5 EF3.1 were v2, +43 repairability).
`ImpactResult` 78 → **126** (+5 MCI, +43 repairability).
`ImpactAssessmentMethod` 2 → **4** (`IAM_MCI`, `IAM_REPAIR`).
`ImpactCategory` 42 → **44** (`IC_CIRCULARITY`, `IC_REPAIRABILITY`).

## New relationship types (v3.x)

`HAS_EOL_ROUTE` (60) · `HAS_COST` (5) · `BASED_ON` (57) · `DECLARES` (2) ·
`REPORTS` (16) · `PARAM_OF` (1) · `SETS` (1) · `FOR` (1) · `UNDER_SCENARIO` (96)

## Assessment methods in the graph

| Method | Categories | Computed results |
|---|---:|---|
| `IAM_EF31` (Environmental Footprint 3.1) | 22 | 35 (5 Al grippers × 7 covered categories, A1) |
| `IAM_PCF` (Product Carbon Footprint) | 1 | 0 computed (43 placeholders `data incomplete`) |
| `IAM_MCI` (Material Circularity, simplified) | 1 | 5 (Al grippers, mass-weighted) + 23 `Material.mci` |
| `IAM_REPAIR` (repairability, v1) | 1 | 43 (`value = disassemblyReversibility`) |

## AssessmentApproach taxonomy

41 nodes: 3 paradigms / 9 groups / 29 methods (from the method diagram).
*(Later reduced to 33 = 3 / 7 / 23 by the KI/ML removal.)* Linked to assessments
(`APPLIES_APPROACH`): `APM_LCA` (5), `APM_CF_CO2` (43), `APM_CIRCULARITY` (5),
`APM_IMPACT_CHAIN` (43). The other methods are present as nodes and addressable,
but (as of this state) without an assessment.

## Consistency

0 label-less nodes · 0 duplicate `AssessmentApproach` · 0 `ImpactResult` without
`FOR_CATEGORY`/`HAS_RESULT` · all 96 assessments with `APPLIES_APPROACH` +
`UNDER_SCENARIO` · all 23 `Material` with `mci`.
