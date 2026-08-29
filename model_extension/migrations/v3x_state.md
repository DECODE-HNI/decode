# v3.x Modellzustand 2026-08-27 (nach Modulen a–d + Reparaturpass)

Voller `.cypher`-Dump weiterhin ausstehend bis `apoc.export.file.enabled=true`
(PLAN.md §4). Autoritative Deltas: `v3x_a..d/migration_v3*.cypher` + `v3x_repair.cypher`.

## Zähler

| | v3 | v3.x | Δ |
|---|---:|---:|---:|
| Knoten | 2 802 | **2 917** | +115 |
| Beziehungen | 79 815 | **80 298** | +483 |
| Constraints | 29 | **36** | +7 |

## Neue Labels (v3.x)

| Label | n | Modul |
|---|---:|---|
| `AssessmentApproach` | 41 | v3 (hier: dedupliziert) |
| `EndOfLifeRoute` | 4 | v3.a |
| `CostItem` | 5 | v3.b |
| `ModelScenario` | 2 | v3.c |
| `Parameter` | 1 | v3.c |
| `ParameterValue` | 1 | v3.c |
| `Declaration` | 2 | v3.d |

`Assessment` 43 → **96** (+5 MCI, +5 EF3.1 waren v2, +43 Repairability).
`ImpactResult` 78 → **126** (+5 MCI, +43 Repairability).
`ImpactAssessmentMethod` 2 → **4** (`IAM_MCI`, `IAM_REPAIR`).
`ImpactCategory` 42 → **44** (`IC_CIRCULARITY`, `IC_REPAIRABILITY`).

## Neue Beziehungstypen (v3.x)

`HAS_EOL_ROUTE` (60) · `HAS_COST` (5) · `BASED_ON` (57) · `DECLARES` (2) ·
`REPORTS` (16) · `PARAM_OF` (1) · `SETS` (1) · `FOR` (1) · `UNDER_SCENARIO` (96)

## Bewertungsmethoden im Graphen

| Methode | Kategorien | berechnete Ergebnisse |
|---|---:|---|
| `IAM_EF31` (Environmental Footprint 3.1) | 22 | 35 (5 Alu-Gripper × 7 abgedeckte Kategorien, A1) |
| `IAM_PCF` (Product Carbon Footprint) | 1 | 0 gerechnet (43 Platzhalter `data incomplete`) |
| `IAM_MCI` (Material Circularity, vereinfacht) | 1 | 5 (Alu-Gripper, massengewichtet) + 23 `Material.mci` |
| `IAM_REPAIR` (Reparierbarkeit, v1) | 1 | 43 (`value = disassemblyReversibility`) |

## AssessmentApproach-Taxonomie

41 Knoten: 3 Paradigmen / 9 Gruppen / 29 Verfahren (aus dem Methodendiagramm).
Mit Assessments verknüpft (`APPLIES_APPROACH`): `APM_LCA` (5), `APM_CF_CO2` (43),
`APM_CIRCULARITY` (5), `APM_IMPACT_CHAIN` (43). Die übrigen 25 Verfahren sind als
Knoten vorhanden und adressierbar, aber (noch) ohne Assessment.

## Konsistenz

0 label-lose Knoten · 0 Duplikat-`AssessmentApproach` · 0 `ImpactResult` ohne
`FOR_CATEGORY`/`HAS_RESULT` · alle 96 Assessments mit `APPLIES_APPROACH` +
`UNDER_SCENARIO` · alle 23 `Material` mit `mci`.
