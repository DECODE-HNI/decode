# v2 (grey box) — model state 2026-08-27

A full `.cypher` dump is pending until `apoc.export.file.enabled=true` is set and
the DBMS restarted (see PLAN.md §4). At this size (~27 MB) the stream export via
`cypher-shell --format plain` yields several `cypherStatements` lines and cannot
be reassembled cleanly into a single file. The authoritative delta from v1 is
`migration_v2.cypher`.

> This is a historical milestone snapshot. Current state:
> [`../../reference/EXTENSION_REFERENCE.md`](../../reference/EXTENSION_REFERENCE.md).

## Nodes (2 761)

| Label | v1 | v2 | Δ |
|---|---:|---:|---:|
| Artifact | 43 | 43 | |
| Assembly | 43 | 43 | |
| **Assessment** | 43 | **48** | +5 |
| Behavior | 7 | 7 | |
| CoreProperty | 10 | 10 | |
| DataItem | 22 | 22 | |
| DataQuality / DataQualityCriterion | 5 / 8 | 5 / 8 | |
| DataSource | 15 | 15 | |
| Feature | 14 | 14 | |
| Flow | 2102 | 2102 | |
| FlowProperty | 3 | 3 | |
| Form / Geometry | 14 / 14 | 14 / 14 | |
| Function | 8 | 8 | |
| ImpactAssessmentMethod | 2 | 2 | |
| ImpactCategory | 42 | 42 | |
| **ImpactResult** | 43 | **78** | +35 |
| Material | 23 | 23 | |
| Part | 86 | 86 | |
| Process | 55 | 55 | |
| ProcessPlan | 43 | 43 | |
| Product | 1 | 1 | |
| Requirement | 24 | 24 | |
| Scenario | 17 | 17 | |
| SolutionPrinciple | 8 | 8 | |
| Specification | 26 | 26 | |

## Relationships (79 729)

Unchanged from v1 except:

| Type | v1 | v2 | Δ |
|---|---:|---:|---:|
| ASSESSES | 43 | 48 | +5 |
| FOR_CATEGORY | 43 | 78 | +35 |
| HAS_PROPERTY | 259 | 264 | +5 *(v1-migration addendum CP_DISASSEMBLY)* |
| HAS_RESULT | 43 | 78 | +35 |
| **MODELED_BY** | – | **2** | +2 (new type) |
| USES_METHOD | 43 | 48 | +5 |

Large unchanged stocks: CHARACTERIZES 27 768 · HAS_FLOW 49 672 ·
SATISFIES_REQUIREMENT 262 · APPLIES_TO 219 · CONTAINS_PROCESS 215 ·
DERIVED_FROM 166.

## New / changed properties

- `ImpactResult`: `value`, `valueLow`, `valueHigh`, `computedAt`, `provenance`,
  `datasetRef`, `coverage`, `status`
- `Assessment` (the 5 new): `systemBoundary`, `functionalUnit`,
  `characterizationLocationRule`, `assessmentType`, `methodology`, `status`
- `Part` (5 aluminium parts): `mass_g`, `massBasis`
- `MODELED_BY`: `proxy`, `lifecycleModule`, `proxyRationale`, `addedBy`
