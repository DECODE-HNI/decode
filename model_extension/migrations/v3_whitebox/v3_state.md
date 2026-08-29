# v3 (white box) — Modellzustand 2026-08-27

Voller `.cypher`-Dump weiterhin ausstehend bis `apoc.export.file.enabled=true`
(PLAN.md §4). Autoritatives Delta gegenüber v2: `migration_v3.cypher`.

## Zähler

| | v2 | v3 | Δ |
|---|---:|---:|---:|
| Knoten | 2 761 | **2 802** | +41 |
| Beziehungen | 79 729 | **79 815** | +86 |

### Neu in v3

| Element | Anzahl |
|---|---:|
| `AssessmentApproach` (Label) | 41 (3 Paradigmen + 9 Gruppen + 29 Verfahren) |
| `BROADER` (Beziehungstyp) | 38 |
| `APPLIES_APPROACH` (Beziehungstyp) | 48 |

### Geänderte Properties

| Element | Property | Umfang |
|---|---|---|
| `Process` | `lifecycleModule`, `lifecycleModuleBasis` | 55 (A1=32, A1-A3=4, A3=13, B1=1, B4=1, C3=4) |
| `Process` | `processType` „End of Life"→„EndOfLife" | 2 |
| `Assessment` | `systemBoundary` (Vokabel), `referenceFlow`, `referenceQuantity`, `referenceUnit` | 48 |
| `Assessment` (EF3.1) | `systemBoundaryNote` (alter Freitext) | 5 |
| `Assessment` (PCF) | `functionalUnit` | 43 |

## Basisquery

`lca_generic.cypher` — Parameter `$methodId`, `$artifactId`. Ersetzt
`v2_greybox/lca_computed_ef31.cypher` (dieses bleibt als historischer Beleg).

Verifiziert: `lca_generic('IAM_EF31')` = 35 Zeilen, Klimawerte identisch zu den
gespeicherten `ImpactResult.value` (v2). `lca_generic('IAM_PCF')` = 5 Zeilen
(Klima), gleiche Werte — Methodenwechsel ohne Schemaänderung.

## Label-/Beziehungs-Inventar (v3)

Labels (28): Artifact, Assembly, Assessment, **AssessmentApproach**, Behavior,
CoreProperty, DataItem, DataQuality, DataQualityCriterion, DataSource, Feature,
Flow, FlowProperty, Form, Function, Geometry, ImpactAssessmentMethod,
ImpactCategory, ImpactResult, Material, Part, Process, ProcessPlan, Product,
Requirement, Scenario, SolutionPrinciple, Specification.

Beziehungstypen neu ggü. v1: `MODELED_BY` (v2), **`BROADER`**, **`APPLIES_APPROACH`** (v3).
