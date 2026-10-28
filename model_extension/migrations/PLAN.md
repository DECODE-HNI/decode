# Ausbaustufen des Nachhaltigkeits-Wissensgraphen — Plan

Stand: 2026-08-27. Pfade relativ zur Wurzel des Repositorys bzw. zu diesem Ordner.

Der Greifer-Wissensgraph wird in gestuften Fassungen entwickelt und dokumentiert.
Leitachse ist **black / grey / white-box-Transparenz der Nachhaltigkeitsbewertung**
(nicht des Produktmodells — das ist schon detailliert). Jede Stufe hat eine eigene
Wertaussage für die Entwicklung; jede Stufe ist **streng additiv und nicht-brechend**
gegenüber der vorigen (das ist der Flexibilitätsnachweis).

---

## 1. Stufen im Überblick

| Stufe | Box | Leistung in der Entwicklung | Grenze der Stufe |
|---|---|---|---|
| **v1** | black | Umweltwirkung **früh und leichtgewichtig** bewerten; erzeugt direkt **Nachweisdaten** (koppelt an die RFLPV²-Verifikationsschicht: `sustainabilityResult` / `sustainabilityStatus` am Test Case) | Kennzahlen sind gesetzt, nicht zerlegbar → keine Lieferketten-Vergleichbarkeit |
| **v2** | grey | **echte Vergleichbarkeit über die Lieferkette** — Ergebnisse aus `Process→Flow`-Ketten gerechnet, Varianten / Zulieferer auf gleicher Basis vergleichbar (EF3.1) | eine Methode, feste Systemgrenze; ILCD-Daten importiert, aber nicht semantisch offen |
| **v3** | white | **Interpretierbarkeit + Austauschfähigkeit**: das ILCD-Format wird im Graphen interpretierbar — methodenagnostische Query, funktionale Einheit, Lebenszyklusmodule, bereinigte Kategorien, zweite LCIA-Methode als reine Daten | — |
| **v3.x** | white + Module | **weitergehende Aussagen** (Zirkularität, Kosten, Szenario/Unsicherheit, Provenienz) klinken sich additiv ein | je Modul eigene Doku + Snapshot |

### Flexibilitätsnachweis in drei Ebenen

1. **v1 → v2** — ein neues *Paradigma* (inventarbasierte LCA) klinkt sich additiv ein.
2. **innerhalb v3** — eine neue *Metrik / Methode* ist reine Daten (Methoden-Knoten +
   Kategorien + Charakterisierungsfaktoren), **null Schemaänderung**.
3. **v3 → v3.x** — ganze *Methodenfamilien* hängen als orthogonale, nicht-kollidierende
   Module an.

---

## 2. Präzise Stufen-Definition

### v1 — Black box: Produktmodell + konkrete Indikatoren

**Enthält** (20 Labels, 431 Knoten / 1 392 Beziehungen, Stand 2026-08-27):
Product, Artifact, Assembly, Part, Material, Feature, Form, Geometry, Function,
Behavior, SolutionPrinciple, Requirement, Specification, Scenario (Greifszenarien),
CoreProperty, DataItem, DataSource, DataQuality, DataQualityCriterion, ProcessPlan
(als Plan-Kopf — Prozessschritte kommen erst in v2).

**Enthält *nicht*** die ILCD-/Inventar-LCIA-Typen: Flow, FlowProperty, Process,
ImpactCategory, ImpactAssessmentMethod, Assessment, ImpactResult (und deren Kanten
HAS_FLOW, CHARACTERIZES, CONTAINS_PROCESS, HAS_CATEGORY, USES_METHOD, ASSESSES,
HAS_RESULT, FOR_CATEGORY, DERIVED_FROM, APPLIES_TO, HAS_FLOW_PROPERTY).

**v1-Migration (noch offen)** — macht v1 zu einer *vollständigen* einfachen Bewertung,
nicht nur einem reduzierten Snapshot:
- Reparierbarkeit formalisieren: `connectionType` + `reversible` auf `HAS_COMPONENT`
  und/oder `Feature`; die heute in `DataItem.valueText` = „screw (reversible)"
  (an einem *Process* „Screw fastening" hängende) Verbindungsinfo **umhängen**, damit
  sie ohne die ILCD-Ebene überlebt.
- Reparierbarkeits-/Demontageindex als `CoreProperty` (propertyType `sustainability`)
  + Basisquery `repairability.cypher`.
- Weitere konkrete Indikatoren direkt attribuiert: Masse, Rezyklatanteil-Rollup,
  ausgewiesener GWP-Wert, Energie — als `CoreProperty` / `ImpactResult` mit
  **literalem** Wert (keine Herleitung).

### v2 — Grey box: ILCD/EF3.1-Inventar + Rechnung

Fügt hinzu: `Process`–`HAS_FLOW`–`Flow`, `FlowProperty`, `CHARACTERIZES`→`ImpactCategory`,
`ImpactAssessmentMethod` (EF3.1), die abgeleitete Assessment-Schicht.
**Rechnung wohnt hier:** `P ImpactResult.value` + `Q lca_computed_ef31` (fest auf EF3.1).
→ Vergleichbarkeit auf EF3.1-Kategorien. Vordergrund rückverfolgbar, Hintergrund
aggregiert.

### v3 — White box: ILCD interpretierbar machen

Kein neuer Rechenkern, nur öffnen und parametrisieren:
- `lca_computed_ef31` → `lca_generic($methodId)`
- `P Assessment.functionalUnit, .referenceFlow, .referenceQuantity, .referenceUnit,
  .systemBoundary` (+ `V systemBoundary`)
- `P Process.lifecycleModule` (+ `V` EN15804 A1..D) + Backfill
- ImpactCategory-Hygiene (~20 Waisen / Near-Duplikate zusammenführen,
  `indicator`/`unit` normalisieren)
- Methoden-Taxonomie: `N AssessmentApproach` + `R BROADER` + `R APPLIES_APPROACH`,
  3 Paradigmen / 9 Gruppen / 28 Methoden aus dem Methodendiagramm
- **zweite volle LCIA-Methode** (ReCiPe *oder* CML) als reine Daten geladen

### v3.x — Komponierbare Module (jeweils Migration + Basisqueries + Doku + Snapshot)

| Modul | Fügt hinzu | Belegt |
|---|---|---|
| **v3.a Zirkularität (MCI)** | Material-Kreislaufparameter, `EndOfLifeRoute`, `IC_CIRCULARITY` | nicht-inventarbasierte Metrik steckbar |
| **v3.b Kosten / MFCA** (Prototyp) | `CostItem` + `HAS_COST`, `Flow.mfcaClass`, `mfca`- + `eco_efficiency`-Query | ökonomische Dimension steckbar |
| **v3.c Szenario + Unsicherheit** | `ModelScenario` / `Parameter` / `ParameterValue`-Layer, Unsicherheitsverteilungen, Sensitivitäts- / Robustheits- / Hotspot-Query | analytische Verfahren steckbar |
| **v3.d Provenienz** | `Declaration` als Typ, `confidence`, EPD/DPP-Andockpunkte | Herkunfts-/Deklarationsdimension steckbar |
| *v3.z (optional)* | alle Module zugleich | Kompositionsnachweis — Module kollidieren nicht |

> Das Paradigma „lernende Ansätze" (KI/ML) war ursprünglich als reiner
> Andockpunkt in v3.d/v3.i vorgesehen; es wurde am 2026-08-29 vollständig aus
> Graph und Doku entfernt (außerhalb des Fallstudien-Umfangs) —
> `consistency/remove_ki_stubs.cypher`.

---

## 3. Dokumentationspflicht je Änderung

Jede Schemaänderung (Knoten, Kanten, Properties, Vokabulare, Datenladungen) wird
**nicht nur angewendet, sondern dokumentiert**:

- **welche bestehenden Artefakte** (Knoten/Kanten/Properties) berührt werden,
- **was die Änderung je betroffener Bewertungsmethode** bedeutet,
- **welche weiteren Methoden** durch dieselbe Änderung betroffen sind
  (Änderungs-→-Methoden-Matrix, möglichst bidirektional).

Zielartefakte:
```
model_extension/reference/methods_change_sets.md      ← Master-Spec: Änderungsmenge pro Methode (noch zu erstellen)
model_extension/reference/change_method_matrix.csv    ← Zeilen = atomare Änderungen, Spalten = Methoden
methods/onepagers/<methode>.md
```

---

## 4. Snapshot-Verfahren

Stream-Export über `cypher-shell --format plain` + Decoder funktioniert bis ~1 MB
sauber (v1: 426 Knoten). Ab v2 (voller Graph, ~27 MB) liefert der Stream **mehrere**
`cypherStatements`-Zeilen und lässt sich nicht verlustfrei zu einer Datei fügen.

**Erforderlich vor v3:** `apoc.export.file.enabled=true` in
`<DBMS-Verzeichnis>/conf/apoc.conf` (Datei neu anlegen) + DBMS-Neustart über
Neo4j Desktop. Danach `CALL apoc.export.cypher.all('v3_snapshot.cypher', {format:'plain'})`
→ schreibt in `<DBMS-Verzeichnis>/import/`, von dort mit Read einlesbar.

Die dafür verwendeten Hilfsskripte (Exportquery mit Label-Ausschlussfilter, Stream-Decoder,
`cypher-shell`-Wrapper) gehören nicht zum Repository.

Solange nicht umgestellt: Stufenzustand als `vN_state.md` (Schema + Zähler) +
`migration_vN.cypher` als autoritatives Delta.

---

## 5. Status

| Artefakt | Stand |
|---|---|
| `v1_blackbox/v1_snapshot.cypher` | **aktuell** (2026-08-27, nach Migration) — 426 Knoten / 1 397 Beziehungen, ILCD-Typen + `MAT_*_GENERIC` ausgeschlossen, verifiziert |
| `v1_blackbox/migration_v1.cypher` + `repairability.cypher` | **angewendet & verifiziert** — Reparierbarkeit formalisiert, `repairabilityClass` A=1 / B=12 / C=30. Doku: `v1_blackbox/CHANGELOG.md` |
| `_fixes/fix_generic_materials.cypher` | **angewendet** — CSV-Spaltenversatz der 5 generischen Materialien behoben |
| [`model_extension/reference/methods_change_sets.md`](../reference/methods_change_sets.md) | **erstellt** (2026-08-27) — Änderungsmenge pro Verfahren (29), PRE-Bausteine, Reihenfolge, Datenlücken |
| `v2_greybox/migration_v2.cypher` + `lca_computed_ef31.cypher` | **angewendet & verifiziert** (v2-minimal) — Rechenkern am Aluminium-A1-Pfad, 5 Gripper × 7 EF3.1-Kategorien berechnet. Doku: `v2_greybox/CHANGELOG.md`, `v2_state.md` |
| `v3_whitebox/migration_v3.cypher` + `lca_generic.cypher` | **angewendet & verifiziert** (v3-minimal) — PRE‑2 `lifecycleModule` (55), PRE‑3 funkt. Einheit (48), PRE‑4 `AssessmentApproach`-Taxonomie (41), methodenparametrisierte Query. Methodenwechsel EF31↔PCF ohne Schemaänderung. Doku: `v3_whitebox/CHANGELOG.md`, `v3_state.md` |
| `v3x_{a..d}/migration_v3*.cypher` + `v3x_repair.cypher` | **angewendet & verifiziert** — a Zirkularität (MCI, `IAM_MCI`), b Kosten/MFCA-Prototyp (`CostItem`), c Parameter-/Szenario-/Unsicherheits-Layer, d Provenienz + Reparierbarkeit als Ergebnis + EPD/DPP-Demonstrator. Ein Reparaturpass (48 Dup-Knoten, 2 verlorene Kanten). Doku: `v3x_CHANGELOG.md`, `v3x_state.md` |
| [`model_extension/reference/change_method_matrix.csv`](../reference/change_method_matrix.csv) | **erstellt** — atomare Änderungen v1…v3.x mit betroffenen Methoden |
| `v2_data/` (Varianten A + B) | **angewendet & verifiziert** — Part-Massen (alle 86), Fertigungsenergie, Werkstoff-GWP-Literale; **A** (nur reale ILCD-Datensätze: Al/Stahl/PA-Proxy) und **B** (Literale, alle 43 Gripper, A1-A3) parallel via `dataVariant`. Doku: `v2_data/CHANGELOG.md`, `ASSUMPTIONS.md` |
| `v3_followup_pre5/migration_pre5.cypher` | **angewendet & verifiziert** — ImpactCategory kanonisiert (44 → 29), EF3.1 rechnet nun **19** statt 7 Kategorien; Kernkategorien unangetastet. Doku: `v3_followup_pre5/CHANGELOG.md` |
| `v3x_e_recipe/migration_v3e.cypher` | **angewendet & verifiziert** — 2. LCIA-Methode `IAM_RECIPE` (18 Midpoint-Kategorien, Klima befüllt × 1,06). `lca_generic` unverändert. Doku: `v3x_e_recipe/CHANGELOG.md` |
| [`methods/onepagers/`](../../methods/onepagers/) | **erstellt** — 29 Verfahrens-Steckbriefe + README |
| [`model_extension/reference/graph_schema_v3x.json`](../reference/graph_schema_v3x.json) + `EXTENSION_REFERENCE.md` | **erstellt & laufend gepflegt** — vollständiges Ist-Schema (93 Keys) + konsolidierte Referenz |
| `dq_concept/`, `demonstrator/`, `v3x_e_recipe/cf_import/`, `v2_data/lci_hygiene/` | **angewendet & verifiziert** (2026-08-29) — Datenqualitätskonzept, Verifikationskette 8-Greifer-Scheibe, voller ReCiPe-CF-Import (16/18 rechnen), LCI-Hygiene (CAS/Einheiten/Kompartiment) |
| `consistency/` (Ebene 1–4) | **abgeschlossen** (2026-08-29) — read-only Prüfharness; 8 + 1 + 2 Befunde triagiert; `FINDINGS.md`, `CHANGELOG.md`. KI/ML-Paradigma entfernt (`remove_ki_stubs.cypher`) |
| Voll-Snapshots | **erledigt** (2026-08-29) — `apoc.conf` gesetzt + DBMS-Neustart; `snapshots/graph_full_2026-08-29.{cypher,graphml}` + `schema_2026-08-29.json` (nur in der Arbeitskopie des Maintainers; die 2 großen Dumps NICHT im Repository) |

Live-DB nach diesem Lauf (2026-08-27): 3 652 Knoten / 81 813 Beziehungen /
36 Constraints. **Danach weiter ausgebaut** — aktueller Ist-Stand
[`EXTENSION_REFERENCE.md`](../reference/EXTENSION_REFERENCE.md), Live-DB 2026-08-29:
**5 620 Knoten / 86 635 Beziehungen / 39 Constraints**, 0 label-lose Knoten,
0 Duplikate, 0 verwaiste Ergebnisse.
**6 Methoden** im Graphen: `IAM_EF31` (19 Kat., rechnet), `IAM_PCF` (Klima),
`IAM_RECIPE` (18 Kat., 16 rechnen), `IAM_MCI` (rechnet), `IAM_REPAIR` (rechnet),
`IAM_GHG` (THG nach Scope). Alle **23 Verfahren** des Diagramms (nach
KI-Entfernung) als `AssessmentApproach`-Knoten adressierbar.

### v2-Umfangsentscheidung (2026-08-27)

Schlankste umsetzbare Variante gewählt: **v2-minimal** — Rechenkern end-to-end an
**einem** sauberen Pfad (Aluminium, A1) als Mechanismusnachweis; volle LCI-Abdeckung
ist ein getrennter Daten-Arbeitsstrang `v2-data`. Systemgrenze **A1** (einzige Stufe
mit charakterisierten ILCD-Daten). Material→Datensatz über neue Kante `MODELED_BY`.
Details: `v2_greybox/CHANGELOG.md`.

### Offene Entscheidung (erledigt)

**Option 2** — v1 ohne ILCD-Typen; v2 ergänzt sie additiv. Umgesetzt.

### Datenvariante A vs. B — ENTSCHIEDEN (2026-08-28)

Beide Varianten liegen parallel im Graphen, unterscheidbar über
`Assessment.dataVariant` / `ImpactResult.dataVariant`:

- **A-realdataset** — `MODELED_BY` nur auf reale ILCD-Datensätze. Rigoros, ILCD-nah.
  Klima 0,16–0,54 kg CO₂-eq/Gripper.
- **B-literal** — Werkstoff-GWP-Literale für alle 18 Materialien, A1 + A3-Stromklima.
  Volle Abdeckung aller 43 Gripper, gemischte Datenqualität. Klima 0,34–1,01.

**Festlegung des Nutzers:** ab **v3** ist **Variante A** (ILCD-nahe reale Datensätze)
der **Fallstudien-Standard**. **Variante B** bleibt nur als Grundlage/Fallback.

**Stand 2026-08-28:** Import-Pipeline `v2_data/ilcd_import/` gebaut; **ABS, PC, POM,
PA 6.6** als reale PlasticsEurope-ILCD-Pakete eingespielt (GWP 3,1–6,5 kg CO₂e/kg,
`MODELED_BY` Variante A), `refresh_variantA.cypher` → Variante-A-Ergebnisse über
alle 43 Greifer. Offen: Elastomere, PETG, PLA, PA12-spezifisch, Kohlefaser
(Proxy/Literal bis Datensatz vorliegt). Sphera-Lizenz = nur Basisversion.

### Kostendimension — ENTSCHIEDEN (2026-08-28)

Bleibt **schlank**: nur `Material.unitCost`-Platzhalter (v3.b Variante A). Das
strukturierte `CostItem`/`HAS_COST`-Knotenmodell (v3.b Variante B) wird **nicht
weiterverfolgt**; die Knoten bleiben im Graphen, werden aber nicht ausgebaut.
`mfca.cypher` / `eco_efficiency.cypher` laufen weiter auf `unitCost`.
