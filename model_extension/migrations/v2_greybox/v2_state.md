# v2 (grey box) — Modellzustand 2026-08-27

Vollständiger `.cypher`-Dump steht aus, bis `apoc.export.file.enabled=true` gesetzt
und das DBMS neu gestartet ist (siehe PLAN.md §4). Der Stream-Export über
`cypher-shell --format plain` liefert bei dieser Größe (~27 MB) mehrere
`cypherStatements`-Zeilen und lässt sich nicht sauber zu einer einzelnen Datei
zusammenfügen. Autoritatives Delta gegenüber v1 ist `migration_v2.cypher`.

## Knoten (2 761)

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

## Beziehungen (79 729)

Unverändert gegenüber v1 außer:

| Typ | v1 | v2 | Δ |
|---|---:|---:|---:|
| ASSESSES | 43 | 48 | +5 |
| FOR_CATEGORY | 43 | 78 | +35 |
| HAS_PROPERTY | 259 | 264 | +5 *(v1-Migration Nachtrag CP_DISASSEMBLY)* |
| HAS_RESULT | 43 | 78 | +35 |
| **MODELED_BY** | – | **2** | +2 (neuer Typ) |
| USES_METHOD | 43 | 48 | +5 |

Große unveränderte Bestände: CHARACTERIZES 27 768 · HAS_FLOW 49 672 ·
SATISFIES_REQUIREMENT 262 · APPLIES_TO 219 · CONTAINS_PROCESS 215 · DERIVED_FROM 166.

## Neue / geänderte Properties

- `ImpactResult`: `value`, `valueLow`, `valueHigh`, `computedAt`, `provenance`,
  `datasetRef`, `coverage`, `status`
- `Assessment` (die 5 neuen): `systemBoundary`, `functionalUnit`,
  `characterizationLocationRule`, `assessmentType`, `methodology`, `status`
- `Part` (5 Aluminium-Teile): `mass_g`, `massBasis`
- `MODELED_BY`: `proxy`, `lifecycleModule`, `proxyRationale`, `addedBy`
