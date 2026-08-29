# v3 (white box) — model state 2026-08-27

A full `.cypher` dump is still pending until `apoc.export.file.enabled=true`
(PLAN.md §4). The authoritative delta from v2 is `migration_v3.cypher`.

> Historical milestone snapshot. Current state:
> [`../../reference/EXTENSION_REFERENCE.md`](../../reference/EXTENSION_REFERENCE.md).

## Counters

| | v2 | v3 | Δ |
|---|---:|---:|---:|
| Nodes | 2 761 | **2 802** | +41 |
| Relationships | 79 729 | **79 815** | +86 |

### New in v3

| Element | Count |
|---|---:|
| `AssessmentApproach` (label) | 41 (3 paradigms + 9 groups + 29 methods) |
| `BROADER` (relationship type) | 38 |
| `APPLIES_APPROACH` (relationship type) | 48 |

### Changed properties

| Element | Property | Scope |
|---|---|---|
| `Process` | `lifecycleModule`, `lifecycleModuleBasis` | 55 (A1=32, A1-A3=4, A3=13, B1=1, B4=1, C3=4) |
| `Process` | `processType` "End of Life"→"EndOfLife" | 2 |
| `Assessment` | `systemBoundary` (vocabulary), `referenceFlow`, `referenceQuantity`, `referenceUnit` | 48 |
| `Assessment` (EF3.1) | `systemBoundaryNote` (old free text) | 5 |
| `Assessment` (PCF) | `functionalUnit` | 43 |

## Base query

`lca_generic.cypher` — parameters `$methodId`, `$artifactId`. Replaces
`v2_greybox/lca_computed_ef31.cypher` (which stays as a historical reference).

Verified: `lca_generic('IAM_EF31')` = 35 rows, climate values identical to the
stored `ImpactResult.value` (v2). `lca_generic('IAM_PCF')` = 5 rows (climate),
same values — method switch with no schema change.

## Label / relationship inventory (v3)

Labels (28): Artifact, Assembly, Assessment, **AssessmentApproach**, Behavior,
CoreProperty, DataItem, DataQuality, DataQualityCriterion, DataSource, Feature,
Flow, FlowProperty, Form, Function, Geometry, ImpactAssessmentMethod,
ImpactCategory, ImpactResult, Material, Part, Process, ProcessPlan, Product,
Requirement, Scenario, SolutionPrinciple, Specification.

Relationship types new vs v1: `MODELED_BY` (v2), **`BROADER`**,
**`APPLIES_APPROACH`** (v3).
