# v3.x Module — Änderungsprotokoll

## 2026-08-27 — Module a–d in einem Lauf, mit Reparaturpass

Alle vier v3.x-Module additiv angewendet und verifiziert. Ein Reparaturpass
(`v3x_repair.cypher`) hat zwei Migrationsfehler behoben (s. u.). Live-DB danach
**2 917 Knoten / 80 298 Beziehungen**, 36 Constraints, keine label-losen Knoten,
keine Duplikat-Knoten.

---

### v3.a — Zirkularität (vereinfachter MCI) · `v3x_a_circularity/`

`migration_v3a.cypher` · Basisquery: MCI ist als `Material.mci` + `ImpactResult` abgelegt.

| Neu | |
|---|---|
| `ImpactAssessmentMethod` `IAM_MCI` + `ImpactCategory` `IC_CIRCULARITY` (`indicator:'MCI'`) | + `HAS_CATEGORY`, `APPLIES_APPROACH → APM_CIRCULARITY` |
| `EndOfLifeRoute` (Label) | 4 Knoten: Recycling, Reuse, Energy recovery, Landfill |
| `(:Material)-[:HAS_EOL_ROUTE {fraction, basis}]->(:EndOfLifeRoute)` | 60 Kanten (Klassen-Defaults) |
| `Material` +`recyclingRate`, `reusability`, `recycledContentAssumed`, `circularityBasis`, `mci`, `mciMethod` | alle 23 |
| `Artifact` +`designLifetime`, `referenceLifetime`, `lifetimeBasis` | alle 43 (neutral: 5 y = 5 y → Nutzenfaktor 1) |
| `Assessment` `ASSESS_MCI_<art>` + `ImpactResult` `IR_MCI_<art>` | je 5 (Aluminium-Gripper mit Part-Massen) |

**Ergebnis (Material-MCI, vereinfacht linear):** Metall 0,65 · Polymer 0,33 · Elastomer 0,16 · Verbund 0,14.
Formel dokumentiert im Migrationskopf (Reuse-Feedstock 0, Nutzenfaktor 1, Recyclingeffizienz 0,9). Alle Eingangswerte **Klassen-Defaults** (`basis`-Property).

---

### v3.b — Kostendimension + MFCA/Ökoeffizienz (Prototyp) · `v3x_b_cost/`

`migration_v3b.cypher` · `mfca.cypher` (Query am 2026-08-27 korrigiert: kartesische
Vervielfachung der Kostensumme durch die Verlust-Fluss-`OPTIONAL MATCH` behoben →
`FLAT_AL` 0,078 EUR statt fälschlich 0,70)

| Neu | |
|---|---|
| `CostItem` (Label) + `(:Part)-[:HAS_COST]->(:CostItem)` | 5 Material-Kostenpositionen (Aluminium-Pfad) |
| `Material` +`unitCost`, `costUnit`, `costBasis` | 18 reale Materialien, **Platzhalter** EUR/kg nach Klasse (Metall 4 / Polymer 6 / Elastomer 12 / Verbund 40) |
| `Flow` +`mfcaClass` | `FLOW_COMPONENT`=product, `FLOW_WASTE`=material-loss |
| `Assessment` +`productSystemValue`, `productSystemValueUnit`, `productSystemValueBasis` | 5 EF3.1-Assessments (Platzhalter) |

Alle monetären Werte sind ausdrücklich Prototyp-Platzhalter.

---

### v3.c — Parameter-/Szenario-Layer + Unsicherheit · `v3x_c_scenario/`

`migration_v3c.cypher` · `hotspot.cypher`

| Neu | |
|---|---|
| `HAS_FLOW` +`uncertaintyDistribution` (=`lognormal`), `uncertaintyBasis` | 40 671 Kanten (dort wo `uncertainty` gesetzt) |
| `Parameter`, `ParameterValue`, `ModelScenario` (Labels) | 1 / 1 / 2 (`SC_BASELINE`, `SC_RECYCLED_ALU`) |
| `(:Parameter)-[:PARAM_OF]->`, `(:ModelScenario)-[:SETS]->(:ParameterValue)-[:FOR]->(:Parameter)` | je 1 — illustratives Szenario „Recyclat-Aluminium 0,35→0,75" auf `MAT_AL6061` |
| `(:Assessment)-[:UNDER_SCENARIO]->(:ModelScenario)` + `Assessment.scenarioRef` + `ImpactResult.scenarioRef` | alle 96 Assessments → `SC_BASELINE` |
| `hotspot.cypher` | Beitrags-Ranking der Datensatzflüsse je Kategorie (reine Query) |

---

### v3.d — Provenienz / Prognose-Andockpunkte + EPD/DPP · `v3x_d_provenance/`

`migration_v3d.cypher`

| Neu | |
|---|---|
| `ImpactAssessmentMethod` `IAM_REPAIR` + `ImpactCategory` `IC_REPAIRABILITY` | Reparierbarkeit wird erstklassiges Assessment-Ergebnis |
| `Assessment` `ASSESS_REPAIR_<art>` + `ImpactResult` `IR_REPAIR_<art>` | je 43, `value = disassemblyReversibility` (aus v1), `provenance:'expert-estimate'`, `confidence:0.6` |
| `(:ImpactResult)-[:BASED_ON]->(:CoreProperty\|:Feature)` | 57 Kanten (→ `CP_DISASSEMBLY`, `FEAT_EASY`/`FEAT_PRINTABLE`) — Nachvollziehbarkeits-Kante (Gap 4) |
| `Declaration` (Label) + `[:DECLARES]`, `[:REPORTS]` | `DECL_EPD_ART_V_AL` (EN 15804+A2, 7 Ergebnisse) + `DECL_DPP_ART_V_AL` (ESPR-Entwurf, 9 Ergebnisse) für `ART_V_AL` |
| `Requirement` +`sustainabilityIndicatorRef/Threshold/Operator/Unit/Scope/Basis` | 1 Demonstrator (`REQ_COMPAT`: GWP ≤ 0,5 kg CO₂-eq) |
| **nur als Typ definiert, keine Instanzen** | `PredictionModel`, `Recommendation`; Vokabel `DataSource.sourceType += ml-model/surrogate-model` (dokumentiert) |

KI-Verfahren sind damit **vorbereitet**, nicht ausgeführt — wie vereinbart.

---

## Reparaturpass · `v3x_repair.cypher`

Zwei Fehler in v3.a/v3.c/v3.d, entstanden weil `;`-getrennte Cypher-Statements
**unabhängig** sind (Variablen aus vorherigen Statements nicht gebunden):

1. **MERGE-Pfad-Falle:** `MERGE (as)-[:APPLIES_APPROACH]->(:AssessmentApproach {id:...})` hat den
   Approach-Knoten **neu erzeugt** statt zu matchen → 48 Duplikat-`AssessmentApproach`.
   Behoben mit `apoc.refactor.mergeNodes` (zurück auf 41), fehlende
   `AssessmentApproach_id_unique`-Constraint nachgezogen.
2. **Scoping:** `MERGE (m)-[:HAS_CATEGORY]->(ic)` mit `m`/`ic` aus vorigem Statement
   erzeugte label-lose Knoten (später entfernt) → `IAM_MCI`/`IAM_REPAIR` ohne
   `HAS_CATEGORY`. Neu verknüpft.

Zusätzlich 7 Uniqueness-Constraints für die neuen v3.x-Labels ergänzt
(`AssessmentApproach`, `EndOfLifeRoute`, `CostItem`, `Declaration`, `ModelScenario`,
`Parameter`, `ParameterValue`). Die Migrationsdateien v3.a/v3.d wurden auf das
sichere Muster (immer per id re-`MATCH`en) korrigiert.

**Lehre für künftige Migrationen:** in `.cypher`-Dateien nie eine Variable über ein
`;` hinweg verwenden und nie einen bestehenden Knoten als Inline-Pattern in `MERGE`
eines Pfades stehen lassen — immer vorher separat `MATCH`en.
