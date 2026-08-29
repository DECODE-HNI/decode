# Flexibilitätsanalyse: Neo4j-Modell für multiple Nachhaltigkeitsbewertungsverfahren

**Grundlage:** `neo4j_importer_model.json` (Export vom 27.08.2026, Kanal-A-Schema — `HAS_FLOW`/`CHARACTERIZES` laufen separat über Kanal B und sind hier bewusst nicht Teil des Data-Importer-Schemas).

**Ziel dieser Analyse:** prüfen, ob die aktuelle Datengrundlage vier Verfahrensfamilien gleichzeitig und ohne strukturellen Umbau tragen kann:
1. LCA-Verfahrensfamilie (ISO 14040/44, austauschbare Charakterisierungsmethoden)
2. Zirkularitäts-/EoL-Indikatoren (z.B. Material Circularity Indicator)
3. Strukturelle/qualitative Indizes (Reparierbarkeit, Demontierbarkeit)
4. EN 15804 / EPD-Berichtsformat (modulbasierte Aggregation)

Status-Markierung wie in den vorherigen Spezifikationsdokumenten: ✅ vorhanden · 🕓 teilweise/nur als Konvention nutzbar · ❌ fehlt strukturell.

---

## 1. Aktuelle Modellstruktur (Referenz)

| Bereich | Knotentypen | Kernbeziehungen |
|---|---|---|
| Produktstruktur | `Product`→`Artifact`→`Assembly`→`Part`, `Feature`, `Form`→`Geometry` | `HAS_ARTIFACT`, `HAS_COMPONENT` (rekursiv), `HAS_FEATURE`, `HAS_FORM`, `HAS_GEOMETRY` |
| Funktion/Verhalten | `Function`, `Behavior`, `SolutionPrinciple`, `CoreProperty` | `REALIZES_FUNCTION`, `HAS_BEHAVIOR`, `CHARACTERIZES_PROPERTY`, `HAS_PROPERTY` |
| Anforderungen | `Requirement`→`Specification` | `SATISFIES_REQUIREMENT`, `SPECIFIED_BY` |
| Material/Prozess | `Material`, `Process`, `ProcessPlan`, `Scenario` | `USES_MATERIAL`, `CONTAINS_PROCESS`, `APPLIES_TO` (Process→Part/Material, `role` als Diskriminator), `HAS_SCENARIO`, `SUITABLE_FOR` |
| **Bewertung** | `Assessment`, `ImpactAssessmentMethod`, `ImpactCategory`, `ImpactResult`, `Flow`, `FlowProperty` | `ASSESSES` (nur →`Artifact`), `USES_METHOD`, `HAS_CATEGORY`, `HAS_RESULT`, `FOR_CATEGORY`, `DERIVED_FROM` (nur →`Flow`) |
| Datengrundlage | `DataItem`, `DataSource`, `DataQuality`, `DataQualityCriterion` | `HAS_DATA` (Artifact/Material/Process/ImpactResult/Flow →`DataItem`), `FROM_SOURCE`, `HAS_DATA_QUALITY`, `EVALUATES_CRITERION` |

**Zentrale Beobachtung:** Der Bewertungs-Layer (`Assessment`→`USES_METHOD`→`ImpactAssessmentMethod`→`HAS_CATEGORY`→`ImpactCategory`) ist bereits methodenagnostisch gebaut — ein neues Verfahren erfordert **keine Schemaänderung**, nur einen neuen `ImpactAssessmentMethod`-Knoten mit eigenen `ImpactCategory`-Kindern. Das ist die wichtigste vorhandene Flexibilität und der Ausgangspunkt für alle vier Verfahren unten.

---

## 2. LCA-Verfahrensfamilie (ISO 14040/44, EF3.1/ReCiPe/CML/TRACI austauschbar)

| Anforderung | Status | Begründung |
|---|---|---|
| Mehrere Charakterisierungsmethoden parallel nutzbar | ✅ | Jede Methode = eigener `ImpactAssessmentMethod`-Knoten mit eigenem `ImpactCategory`-Satz. `Flow --CHARACTERIZES{factor,location}--> ImpactCategory` (Kanal B) erlaubt, dass ein Flow mehrere Faktoren für mehrere Methoden gleichzeitig trägt — genau dafür wurde die Kanal-B-Trennung ja eingeführt. |
| Inventardaten-Rückverfolgung (Flow → Ergebnis) | ✅ | `ImpactResult --DERIVED_FROM{contribution,exchangeId}--> Flow` bildet die LCI-Beitragskette sauber ab. |
| Prozess-Herkunft/Provenienz | ✅ | `Process.source`/`sourceDatabase`/`referenceYear`, `Flow.source`/`sourceDatabase`, plus `FROM_SOURCE`→`DataSource` — aus dem ILCD-Rebuild bereits vorhanden. |
| Funktionale Einheit / Referenzgröße | ❌ | Weder `Product`/`Artifact` noch `Assessment` haben ein Feld für die funktionale Einheit (z.B. "1 Greifzyklus", "1 kg gegriffenes Teil"). ISO 14044 verlangt das explizit für Vergleichbarkeit — aktuell nur implizit/undokumentiert. |
| Systemgrenze / Cut-off je Assessment | 🕓 | `Assessment.developmentPhase` beschreibt etwas anderes (Konzept-/Detailphase). Keine Property für "cradle-to-gate" vs. "cradle-to-grave". Hängt eng mit Punkt 4 (`lifecycleModule`) zusammen. |
| Allokationsmethode bei Multi-Output-Prozessen | ❌ | `Process` hat kein Feld für die verwendete Allokationsregel (Masse/ökonomisch/keine). Falls ihr das je Assessment variieren wollt, fehlt der Hook komplett. |
| Unsicherheit (quantitativ) | 🕓 | `DataQuality`/`DataQualityCriterion` deckt eine Pedigree-Matrix-artige *qualitative* Bewertung ab, aber `ImpactResult`/`Flow` haben kein Feld für Verteilungsparameter (min/max/stdev). Im Rebuild-Plan als optionale Spalte vorgesehen, aber nicht garantiert befüllt. |

**Fazit LCA:** Kernarchitektur trägt bereits Methodenwechsel gut. Die zwei Lücken mit echtem Effekt sind die fehlende funktionale Einheit und die fehlende Systemgrenzen-Angabe — beide nötig, sobald ihr zwei Assessments (z.B. EF3.1 vs. ReCiPe, oder zwei Szenarien) tatsächlich vergleichen wollt.

---

## 3. Zirkularitäts-/EoL-Indikatoren (z.B. Material Circularity Indicator)

| Anforderung | Status | Begründung |
|---|---|---|
| Rezyklatanteil im Input | ✅ | `Material.recycledContent_pct` existiert bereits — deckt die Eingangsseite von MCI (V, Anteil Rezyklat/Feedstock) ab. |
| Recyclingfähigkeit/Wiederverwendbarkeit am Output/EoL | ❌ | Kein Gegenstück auf `Material` oder `Part` für die Ausgangsseite (Sammelquote, Recyclingfähigkeit, Wiederverwendungsquote). MCI braucht beide Seiten, aktuell nur eine. |
| Nutzungsintensität/Lebensdauer (Utility-Faktor) | ❌ | Kein Feld auf `Product`/`Artifact` für erwartete/tatsächliche Lebensdauer oder Nutzungsintensität — MCI's Utility-Faktor braucht genau das. |
| Eindeutige Identifikation von EoL-Prozessen | ❌ | `Process.processType`/`technology` sind Freitext ohne kontrolliertes Vokabular. Ohne `lifecycleModule` (siehe Abschnitt 4) lässt sich "gib mir alle Entsorgungs-/Recycling-Prozesse" nicht zuverlässig abfragen. |
| Zusammengesetzte Indexstruktur (mehrere gewichtete Teilterme) | 🕓 | Kein Schemabruch nötig — jeder MCI-Teilterm (Utility-Faktor, Linear-Flow-Index, V, W) ließe sich als eigener `ImpactResult` mit `resultType='MCI_utility_factor'` etc. unter einem `Assessment` modellieren. Funktioniert, aber nur als Namenskonvention, nicht als Struktur. |

**Fazit Zirkularität:** Größere inhaltliche Lücke als bei LCA. Drei neue Properties (Recyclingfähigkeit/Wiederverwendbarkeit auf `Material`, Lebensdauer auf `Artifact`/`Product`) plus `lifecycleModule` auf `Process` würden die Familie vollständig abdecken.

---

## 4. Strukturelle/qualitative Indizes (Reparierbarkeit, Demontierbarkeit, Modularität)

| Anforderung | Status | Begründung |
|---|---|---|
| Demontage-/Baustruktur | ✅ | `Assembly`→`Part` (rekursiv über `HAS_COMPONENT`) bildet die Demontagehierarchie bereits ab — Grundlage für Tiefe/Anzahl-Metriken. |
| Verbindungsart/Reversibilität pro Verbindung | ❌ | Weder `Feature` noch die `HAS_COMPONENT`-Relation selbst tragen ein Feld für Verbindungstyp (Schraube/Schnappverbindung/Kleben/Schweißen) oder Reversibilität — genau das, was ein Reparierbarkeits-/Demontage-Index typischerweise braucht (Werkzeugbedarf, Zerstörungsfreiheit). |
| Zugänglichkeit einzelner Teile | ❌ | Kein Feld dafür auf `Part`/`Feature`. |
| Gewichtete Mehrkriterien-Bewertung | ✅ | `DataQuality`(method, overallScore, scale) + `DataQualityCriterion`(category, definition, weight, direction) via `EVALUATES_CRITERION{score,rating}` ist bereits ein generisches, methodenunabhängiges Gerüst für genau so einen gewichteten Index — direkt wiederverwendbar, auch wenn es ursprünglich für Datenqualität gedacht war. |
| Bewertung auf Part-/Assembly-Ebene statt nur Artifact | ❌ | `Assessment --ASSESSES--> Artifact` ist die einzige erlaubte Zielrichtung. Ein struktureller Index wird aber typischerweise pro Bauteil/Baugruppe berechnet ("wie leicht ist *dieses* Verschleißteil zu tauschen"), nicht pro gesamtem Artifact — aktuell nur über Überaggregation auf Artifact-Ebene möglich. |
| Nachvollziehbarkeit: welche Strukturelemente führten zum Ergebnis | ❌ | `DERIVED_FROM` zeigt fest auf `Flow` — für nicht-LCI-basierte Ergebnisse (z.B. "dieser Score basiert auf diesen 4 Feature-Verbindungen") gibt es kein äquivalentes Pendant. |

**Fazit Struktur:** Die Demontagehierarchie und das Datenqualitäts-Gerüst (wiederverwendbar als Gewichtungsschema) sind gute Bausteine. Die eigentliche Lücke ist doppelt: (a) fehlende Verbindungstyp-/Reversibilitäts-Properties und (b) die auf `Artifact` fixierte `ASSESSES`-Kante plus die auf `Flow` fixierte `DERIVED_FROM`-Kante, die beide zu granular/eng für strukturelle Indizes sind.

---

## 5. EN 15804 / EPD-Berichtsformat (A1-A3, A4-A5, B1-B7, C1-C4, D)

| Anforderung | Status | Begründung |
|---|---|---|
| Indikatorenkatalog abbildbar | ✅ | `ImpactCategory`(indicator, unit) ist generisch genug, um 1:1 die EN15804-Indikatorliste (GWP-total/-fossil/-biogenic, ODP, AP, EP-freshwater, ...) aufzunehmen — reine Dateninhalt-Frage, kein Strukturproblem. |
| Modul-Zuordnung (A1-A3/B/C/D) je Prozess | ❌ | `Process.lifecycleModule` existiert nicht im Live-Modell. War bereits in der SysML-Profilerweiterung als Zielzustand vorgesehen (`Process Element.lifecycleModule`), aber per eurer Entscheidung "Nur dokumentieren" bewusst nicht ins Neo4j übernommen. |
| Modulweise Aggregation von Ergebnissen | ❌ | Ohne `lifecycleModule` lässt sich ein `ImpactResult` nicht sauber nach A1-A3/C/D aufschlüsseln — Voraussetzung für ein normkonformes EPD-Ergebnistabellenformat. |
| Deklarierte Einheit | ❌ | Gleiche Lücke wie die funktionale Einheit bei LCA (Abschnitt 2), bei EN15804 aber verpflichtend statt optional. |

**Fazit EN15804:** Das ist die Verfahrensfamilie mit dem am klarsten bereits identifizierten und einzigen wirklichen Blocker: `lifecycleModule` auf `Process`. Alles andere ist Dateninhalt, kein Strukturproblem.

---

## 6. Synthese: gemeinsame Lücken über alle vier Verfahren

Bemerkenswert ist, dass sich die Einzellücken auf **fünf** additive, nicht-brechende Änderungen verdichten — keine der 32 bestehenden Beziehungstypen müsste geändert werden:

| # | Änderung | Betrifft Verfahren | Aufwand |
|---|---|---|---|
| 1 | `Process.lifecycleModule` (EN15804-Code A1-A3 etc.) | EN15804/EPD, Zirkularität (EoL-Prozesse filterbar), teilweise LCA (Systemgrenze) | Eine neue Property, bereits spezifiziert (RFLPV²-Dokument), nur bislang nicht ins Neo4j übernommen |
| 2 | Deklarierte funktionale Einheit (`Assessment.functionalUnit`/`referenceQuantity`/`referenceUnit` oder auf `Product`) | LCA, EN15804/EPD | Eine bis drei neue Properties auf `Assessment` oder `Product` |
| 3 | `Assessment --ASSESSES-->` auf `Part`/`Material`/`Process`/`ProcessPlan` erweitern (nicht nur `Artifact`) | Zirkularität (materialbezogen), Struktur (bauteilbezogen) | Erweiterung einer bestehenden Relationship auf weitere Zielknoten — kein neuer Typ nötig |
| 4 | Generische Nachvollziehbarkeits-Kante `ImpactResult --BASED_ON--> (Feature\|CoreProperty\|DataItem)` parallel zu `DERIVED_FROM--> Flow` | Struktur, Zirkularität | Ein neuer, zusätzlicher Relationship-Typ |
| 5 | Recyclingfähigkeit/Wiederverwendbarkeit (`Material`), Lebensdauer/Nutzungsintensität (`Artifact`/`Product`), Verbindungstyp/Reversibilität (`Feature` oder auf `HAS_COMPONENT`) | Zirkularität, Struktur | Reine Property-Ergänzungen, keine Strukturänderung |

Keiner dieser fünf Punkte bricht etwas Bestehendes — sie sind rein additiv. Punkt 1 ist der mit Abstand am stärksten wiederverwendete (3 von 4 Verfahrensfamilien profitieren direkt) und war ohnehin schon spezifiziert, nur bisher als "nur dokumentieren" zurückgestellt.

**Empfehlung:** Diese Analyse zunächst genau wie die RFLPV²-Erweiterung als Zielzustand dokumentieren, nicht sofort ins Live-Modell einspielen — konsistent mit eurer bisherigen Entscheidung, Neo4j-wirksame Änderungen erst nach expliziter Freigabe umzusetzen. Falls ihr direkt einsteigen wollt: Punkt 1 (`lifecycleModule`) hätte den größten Hebel für den geringsten Aufwand, weil er bereits vollständig spezifiziert ist und nur noch der Schema-Migration + Befüllung aus den ILCD-Quelldaten bedarf (die Rohdaten haben das EN15804-Modul in der Regel als Prozessmetadatum).

---

## 7. Offene Fragen für die nächste Runde

- Sollen die fünf additiven Änderungen jetzt spezifiziert (Schema-Draft, Migrations-Cypher, Befüllungslogik aus den ILCD-Quellen) oder erstmal nur als Kandidatenliste stehen bleiben?
- Falls `lifecycleModule` zuerst umgesetzt wird: Befüllung rückwirkend für die bereits importierten 24 Prozesse (aus den ILCD-Rohdaten ableitbar) oder nur für künftige Importe?
- Für die strukturellen Indizes: gibt es bereits eine konkrete Zielmetrik (z.B. französischer Indice de Réparabilité, IEC 62309, eigene Gewichtung), damit die Verbindungstyp-Properties exakt auf deren Kriterienkatalog zugeschnitten werden können, statt generisch zu raten?
