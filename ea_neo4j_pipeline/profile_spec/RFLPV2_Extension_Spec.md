# RFLPV² – Erweiterung um Product Element, Process Element und Testfälle

Konsolidierte Spezifikation aller abgestimmten Änderungen am RFLPV²-Profil
(Ausgangsbasis: `RFLPV²-Profil.mdzip`, Cameo Systems Modeler 2024x, HNI Paderborn).
Diese Datei ist die werkzeugneutrale Referenz — die beigelegte `.xml` ist nur ein
Best-Effort-Exportversuch daraus (siehe Abschnitt 9 zu den Grenzen in Enterprise Architect).

**Geltungsbereich:** Nur geänderte/neue Elemente + die unveränderten Elemente, die als
Generalisierungs- oder Beziehungsziel gebraucht werden. NICHT enthalten (weil unverändert und
bereits im bestehenden Cameo-Projekt korrekt vorhanden): Customer Need/Requirement, Function,
Logical Element, Test/Inspection/Demonstration/Simulation, MBSE Role Model, ECR, Architecture
Candidate.

**Statuskennzeichnung:** ✅ bestätigt und in der beigelegten XMI umgesetzt · 🕓 bestätigt,
aber nur als Zielzustand dokumentiert (kein Eingriff am laufenden Neo4j-Modell/der Pipeline) ·
💡 offener Vorschlag, noch nicht entschieden.

---

## 1. Umbenennung: Physical Element → Product Element ✅

**Begründung:** "Physical" suggeriert Materialität und passt bei CPS mit hohem Softwareanteil
nicht mehr zum Inhalt der Schicht (Steuergeräte, Regelsoftware sind keine physischen Objekte).
Technisch unkritisch: in Cameo/EA hängt die Stereotyp-Identität an der internen ID, nicht am
Namen — bestehende Modellinhalte migrieren automatisch mit.

| Alt (Physical Element) | Neu (Product Element) |
|---|---|
| `physicalID` | `productID` |
| `physicalType` | `productType` |
| `physicalParameter` | `productParameter` |
| `physicalParameterType` | `productParameterType` |
| `variantTag`, `elementOwner`, `discipline`, `costs` | unverändert |

Paket `04_Physical Element` → `04_Product Element` (Diagrammname, Icon-Datei entsprechend
nachziehen — kosmetisch, kein Modellrisiko).

## 2. Neue Tags an Product Element ✅

| Tag | Typ | Zweck |
|---|---|---|
| `materialRef` | String **[0..\*]** | Referenz-ID(s), matcht `Material.id` im Neo4j-Graphen. Mehrfachbezug zulässig, da ein Product Element mehrere Materialien enthalten kann. Mengenanteile (`fraction`/`mass_g`) werden bewusst NICHT auf SysML-Seite dupliziert — die bleiben exklusiv in Neo4j (`USES_MATERIAL.fraction`). |
| `realizationType` | **`RealizationType`** (Enum) | löst das eigentliche Unterscheidungsproblem, das die Umbenennung motiviert hat |

### Enumeration `RealizationType`
`hardware` · `software` · `hybrid`

## 3. Neue Tags an System Requirement ✅

Kein eigener Stereotyp für Nachhaltigkeit — nur zusätzliche Tags, analog zu
`requirementPriority`/`requirementParameter`, die schon heute ohne eigenen Stereotyp auskommen:

| Tag | Typ | Beispiel |
|---|---|---|
| `sustainabilityIndicatorRef` | String | `GWP100` (referenziert eine `ImpactCategory` in Neo4j) |
| `sustainabilityThreshold` | Real | `120` |
| `sustainabilityOperator` | **`SustainabilityOperator`** (Enum) | `lessOrEqual` |
| `sustainabilityUnit` | String | `kgCO2eq` |
| `sustainabilityScope` | String | `A1-A3` |

Die vier Felder zusammen ergeben einen vollständig auswertbaren Ausdruck:
`sustainabilityIndicatorRef sustainabilityOperator sustainabilityThreshold [sustainabilityUnit], Geltungsbereich sustainabilityScope`.

`sustainabilityScope` bleibt bewusst String statt Enum, auch wenn `Process Element.lifecycleModule`
enumeriert ist (s. u.): Anforderungen beziehen sich oft auf Modul-**Bereiche** ("A1-A3",
"A1-C4"), die sich nicht als einzelner Enum-Literal abbilden lassen.

### Enumeration `SustainabilityOperator`
`lessThan` · `lessOrEqual` · `equal` · `greaterOrEqual` · `greaterThan`

## 4. Process Element — Tag-Semantik präzisiert ✅

Keine strukturelle Änderung an den Tags selbst, nur Klarstellung:

| Tag | Bedeutung |
|---|---|
| `processID` | persistenter Identifier des Process Elements **im SysML-Modell** |
| `processRef` | Referenz auf **`Process.id` im Neo4j-Graphen** |
| `lifecycleModule` | EN-15804-Modul: `A1`–`A3` (Herstellung), `A4`–`A5` (Transport/Montage), `B1`–`B7` (Nutzung), `C1`–`C4` (End-of-Life), `D` (Gutschriften) |

## 5. Beziehungen Process Element ↔ Product Element

SysML-seitig unverändert, vollständig wiederverwendet (keine neue Relation im Profil):

| Lebenszyklusphase (EN 15804) | Relation |
|---|---|
| A1–A3 (Herstellung) | `Process Element --Realizes--> Product Element` |
| A4–A5, B1–B7, C1–C4, D | `Process Element --Affects--> Product Element` |

**🕓 Neo4j-Zielzustand (dokumentiert, nicht umgesetzt):** `Realizes`/`Affects` sollen im Graphen
als eigene Relationstypen `REALIZES`/`AFFECTS` erscheinen statt beide unter `APPLIES_TO`
mitzulaufen — begründet durch einen bereits real existierenden Fall: der Abfallverbrennungs-
prozess (`PROC_WASTE_INCINERATION_MSW`, ein C-Modul/"Affects"-Fall) ist heute über `APPLIES_TO`
nicht von den A-Modul/"Realizes"-Fertigungsprozessen unterscheidbar. Umsetzung erfordert eine
Reklassifizierung der bestehenden Kanten (17 Fertigungsprozesse → `REALIZES`, der eine
EoL-Prozess → `AFFECTS`) sowie Anpassungen am Data-Importer-Schema/den Pipeline-Skripten —
bewusst erst beim nächsten vollen Rebuild, nicht jetzt am laufenden Modell.

## 6. Verification-Schicht: Test Case, Test Case Description, Test Scenario ✅

(nach Ebel/Pottebaum/Graessler 2024, "Model-based planning of test cases and test scenarios...",
ISSE 2024). Alle drei generalisieren das bestehende `Verification` (bzw. `Class`), keine
Änderung an `Test`/`Inspection`/`Demonstration`/`Simulation`.

| Stereotyp | generalisiert | Tags |
|---|---|---|
| `Test Case` | `Verification` (erbt `base_Behavior`, `base_Operation`, `verificationID`, `verificationParameter`) | `testCaseOwner`, `systemLevel`, `dataAnalysisType`, `testMethod`, `sustainabilityResult`, `sustainabilityStatus` |
| `Test Case Description` | `Class` | `environmentalConditions`, `systemState`, `user`, `expectedResults` |
| `Test Scenario` | `Verification` | `testScenarioOwner`, `testItems`, `testScenarioEnvironmentalParameters` |

`verificationID` wird als Test-Case-ID weiterverwendet, kein separates `testCaseID`.

### Semantik `sustainabilityResult`/`sustainabilityStatus` ✅ (Tags bleiben, Bedeutung präzisiert)

| Tag | Typ | Bedeutung |
|---|---|---|
| `sustainabilityResult` | Real | Ergebnis der aktuell bzw. zuletzt durchgeführten Nachhaltigkeitsbewertung dieses Test Case |
| `sustainabilityStatus` | String | aktueller Verifikationsstatus. Empfohlene Werte: `passed`, `failed`, `inconclusive`, `notEvaluated` |

Beziehungen (alle wiederverwendet, keine neue Relation): `Test Case --Verifies--> System
Requirement`, `Test Case --(einfache Dependency)--> Product Element` (Test Item), `Test Case
*-- Test Case Description` (Komposition), `Test Scenario --(einfache Dependency)--> Test Case`
(≥2, bildet die Verifikationsmatrix).

**✅ Neo4j-Zielzustand (umgesetzt 2026-08-29, `model_extension/migrations/demonstrator/`):** Die
Nachhaltigkeitsbewertung bleibt fachlich das Ergebnis eines Test Case; Neo4j speichert die
konkreten Durchführungen separat:

```
TestCase --[:VERIFIES]--> Requirement
TestCase --[:HAS_ASSESSMENT]--> Assessment --[:HAS_RESULT]--> ImpactResult --[:FOR_CATEGORY]--> ImpactCategory
TestCase --[:TESTS]--> Artifact        (Test Item)
```

`sustainabilityResult`/`sustainabilityStatus` im SysML-Modell = aktueller Cache-Wert;
`Assessment` in Neo4j = vollständige Bewertungsausführung. Der neue Knotentyp `TestCase`
(`verificationID`, `testCaseOwner`, `systemLevel`, `dataAnalysisType`, `testMethod`,
`sustainabilityResult`, `sustainabilityStatus` ∈ {`passed`,`failed`,`inconclusive`,
`notEvaluated`}) trägt zusätzlich die Constraint `TestCase_id_unique`. Umgesetzt zunächst für
eine 8-Greifer-Demonstrator-Scheibe (24 Test Cases). Der Test-Case-Status wird auf
`SATISFIES_REQUIREMENT.verificationStatus` zurückgeschrieben.

## 7. Neo4j-Gesamtübersicht

| SysML | Neo4j | Status |
|---|---|---|
| `Product Element.materialRef` | `Material.id` | ✅ |
| `Process Element.processRef` | `Process.id` | ✅ |
| `Process Element.processType` | `Process.processType` | ✅ |
| `Process Element.lifecycleModule` | `Process.lifecycleModule` | ✅ live auf allen 58 `Process`-Knoten seit v2 (Werte `A1`, `A1-A3`, `A3`, `B1`, `B4`, `C3`), von der DQ-Schicht ausgewertet — Korrektur aus der Konsistenzprüfung Ebene 4 (DE-01), Stand 2026-08-29 |
| `Process Element --Realizes--> Product Element` | `Process -[:REALIZES]-> Part` | 🕓 s. Abschnitt 5 |
| `Process Element --Affects--> Product Element` | `Process -[:AFFECTS]-> Part` | 🕓 s. Abschnitt 5 |
| `System Requirement.sustainabilityIndicatorRef` | `ImpactCategory.id` | ✅ |
| `System Requirement.sustainabilityThreshold` | `Specification.valueNumber` | ✅ (bereits vorhandenes Feld) |
| `System Requirement.sustainabilityUnit` | `Specification.unit` | 💡 bereits vorhandenes Feld, keine neue Property nötig |
| `System Requirement.sustainabilityOperator` | `Specification.comparator` (neu) *oder* aus `toleranceMin`/`toleranceMax` ableitbar | 💡 offen, siehe unten |
| `Test Case.sustainabilityResult`/`-Status` | bleibt SysML-seitiger Cache-Wert; in Neo4j auf `TestCase` gespiegelt | ✅ |
| konkrete Testdurchführung | `TestCase -[:HAS_ASSESSMENT]-> Assessment` | ✅ umgesetzt 2026-08-29 (`demonstrator/`) |
| Bewertungsergebnis | `Assessment -[:HAS_RESULT]-> ImpactResult` | ✅ bereits vorhanden |
| Wirkungskategorie | `ImpactResult -[:FOR_CATEGORY]-> ImpactCategory` | ✅ bereits vorhanden |

## 8. Offene Vorschläge (noch nicht entschieden) 💡

Diese drei Punkte wurden in der Diskussion aufgeworfen, aber nicht bestätigt — bewusst nicht in
die beigelegte XMI übernommen:

1. **`lifecycleModule` als Enum `EN15804Module`** (`A1`…`A5`, `B1`…`B7`, `C1`…`C4`, `D`) statt
   String — konsistent zur Entscheidung bei `realizationType`, da EN 15804 ein geschlossenes
   Normvokabular ist.
2. **`sustainabilityStatus` als Enum `TestVerificationStatus`** (`passed`/`failed`/
   `inconclusive`/`notEvaluated`) statt String — aus demselben Konsistenzgrund.
3. **`Specification.unit` für `sustainabilityUnit` wiederverwenden**, statt eine neue Property
   anzulegen; für `sustainabilityOperator` ggf. die bestehende `toleranceMin`/`toleranceMax`-
   Struktur nutzen statt eines neuen `comparator`-Felds.

## 9. Grenzen des beigelegten XMI-Exports für Enterprise Architect

EA und Cameo sind beide XMI-2.1-konform, aber **strukturell unterschiedlich** im Umgang mit
Stereotyp-Tags: Cameo bildet Tags als reguläre `uml:Property`-Elemente am Stereotyp ab (so wie in
der beigelegten Datei), EA verwaltet Tags dagegen intern über ein eigenes "Tagged Value Types"-
Verzeichnis, das nicht 1:1 aus einer rohen UML2-Profil-XMI befüllt wird. Die beigelegte
`RFLPV2_Extension_Profile.xml` ist deshalb ein **Best-Effort-Gerüst**, kein garantierter
Ein-Klick-Import — sie wurde nicht gegen eine echte EA-Instanz getestet.

Zwei Wege, je nach Ergebnis des Imports:
1. **Import versuchen**: `Extensions > Import Reference Data` (oder je nach EA-Version `Publish
   > Technology > Import Technology`) mit der `.xml`. Falls Stereotypen ohne Tags oder ohne
   funktionierende Metaklassen-Zuordnung ankommen: das Profil ist trotzdem als Rohgerüst nutzbar,
   Tags müssen dann manuell im Profile Helper nachgezogen werden.
2. **Direkt in EA nachbauen** (sicherer Weg, ca. 30–45 Min. für die 9 Stereotypen dieser
   Erweiterung): `Configure > Reference Data > UML Profiles > New Profile`, je Stereotyp einen
   Klassifizierer mit `«stereotype»` anlegen, per Extend-Beziehung an die Metaklasse (`Class`,
   `Block`, `TestCase`, `Dependency`, `Behavior`+`Operation`) hängen, Tags über die dortige
   "Tagged Value Types"-Verwaltung anlegen (Name + Typ aus den Tabellen oben, inkl. der beiden
   Enumerationen `RealizationType` und `SustainabilityOperator`). Diese Spezifikation ist dafür
   die vollständige Quelle.

Die Generalisierungen auf SysML-Stereotypen (`Block`, `Requirement`, `TestCase`, `Trace`) setzen
zusätzlich voraus, dass in EA die SysML-Technologie aktiviert ist — sonst lassen sich die
`generalization`-Kanten dort manuell auf `Class` umbiegen, ohne dass Tags oder Relationen davon
betroffen sind.
