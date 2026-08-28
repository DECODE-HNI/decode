# EA → Neo4j: Mapping-Spezifikation (RFLPV2_Extension_Profile_V006)

Dieses Dokument ist der verbindliche Vertrag zwischen dem Enterprise-Architect-Profil
(`RFLPV2_Extension_Profile_V006.xml`) und dem bestehenden Neo4j-Graphmodell
(`ned2_gripper_full_model_neo4j/`). Es beschreibt, wie `ea_xmi_extract.py` und
`ea_to_neo4j_load.py` zusammenspielen. Alle hier getroffenen Entscheidungen wurden
im Chat mit dem Nutzer abgestimmt; als "Offen" markierte Punkte sind Annahmen,
die noch bestätigt werden müssen.

## 1. Architektur

```
EA-Projekt (SysML, RFLPV2-Profil)
   │  Project ▸ Model Exchange ▸ Export Package as XMI  (Typ: XMI 2.1)
   ▼
<projekt>.xml  (EA-XMI-Export)
   │  ea_xmi_extract.py
   ▼
ea_extract/*.csv   (ein CSV je Ziel-Label bzw. je Beziehungstyp,
                     GUIDs bereits zu Business-Keys aufgelöst)
   │  ea_to_neo4j_load.py  (Bolt-Treiber, Zugangsdaten nur über Umgebungsvariablen)
   ▼
Neo4j (bestehende lokale Instanz)
```

**Status (28.08.2026): komplette Pipeline (Extraktor + Loader) end-to-end
gegen eine echte, frische Test-Neo4j-Instanz verifiziert.** `ea_to_neo4j_load.py`
lief fehlerfrei gegen `ea_extract/` (aus dem echten XMI-Testmodell) — alle 13
Knotentypen und 5 Beziehungstypen exakt in den erwarteten Stückzahlen
geladen, Constraints korrekt angelegt, die `materialRef`-Warnung korrekt
ausgelöst (Test-DB kennt `MAT_ALU_GENERIC` erwartungsgemäß nicht). Getestet
wurde bewusst gegen eine leere, separate Instanz statt der echten
Ned2-Datenbank, da die Testdaten Platzhalternamen (`Block1` etc.) tragen, die
beim Merge auf Bestandsknoten `name` überschreiben würden (siehe `SET n +=
row`-Hinweis oben) — der "Merge auf bestehenden Knoten"-Pfad ist damit noch
nicht separat getestet, nur der "neu anlegen"-Pfad.

`references_count = 0` in der Test-DB bestätigt zusätzlich: die
`processRef <> row.id`-Filterlogik in `PROCESS_REFERENCES_QUERY` funktioniert
korrekt (kein `:REFERENCES` angelegt, obwohl 1 Zeile durch die Query lief --
Neo4j meldet sogar "Relationship type does not exist", da der Typ nie
angelegt wurde). Damit ist die komplette Pipeline (Profil, Toolbox,
Extraktor, Loader) end-to-end gegen echte EA-Exportdaten verifiziert.

**Merge-auf-Bestand-Test (28.08.2026, gegen die echte Ned2-Instanz) bestanden.**
`rflpv2_merge_test.xml` (handgebaut im verifizierten Format, echte IDs:
`FUNC_GRASP`, `SP_PARALLEL`, `ART_CUSTOM`/`ASSY_CUSTOM`/`PART_CUSTOM_CONTACT`,
`REQ_COMPAT`) erfolgreich geladen: bestehende Knoten wurden angereichert statt
dupliziert (`FUNC_GRASP` behielt alle alten Properties + neue), bestehende
`REALIZES_FUNCTION`/`SATISFIES_REQUIREMENT`-Kanten wurden gemerged statt
verdoppelt (`count = 1`, nicht `2`).

**Wichtige Lehre dabei gefunden:** `PART_USES_MATERIAL_QUERY` MERGEd eine
`USES_MATERIAL`-Kante zum in `materialRef` genannten Material, **ersetzt aber
keine bereits vorhandene** — `PART_CUSTOM_CONTACT` hatte schon real
`MAT_PA12`, der Test mit `materialRef=MAT_ALU_GENERIC` erzeugte eine
**zweite, parallele, fachlich falsche** Kante (mein Fehler: ungeprüfter
Test-Wert statt vorher das echte Material nachzuschauen). Nach dem Vorfall
manuell bereinigt (falsche Kante gelöscht, erfundene Testwerte wie
`sustainabilityThreshold=3.0` auf `REQ_COMPAT` entfernt, `sourceStereotype`-
Provenienz-Properties bewusst belassen). **Entschieden und umgesetzt (28.08.2026):** `materialRef` ersetzt jetzt die
Material-Zuordnung, statt nur zu ergänzen — ein Part besteht nicht aus zwei
Materialien gleichzeitig. `PART_USES_MATERIAL_QUERY` löscht vor dem Anlegen
der neuen Kante alle bestehenden `:USES_MATERIAL`-Kanten des Parts zu einem
ANDEREN Material als dem in `materialRef` genannten.

**Status (28.08.2026): `ea_xmi_extract.py` ist gegen einen echten EA-Export
verifiziert.** Testmodell mit einem Element je Stereotyp + Komposition +
5 Beziehungen wurde in EA gebaut (`rflpv2_package.xml`, Export über "Export
Package to Native/XMI File", Format XMI 2.1) und vollständig korrekt
extrahiert — alle 13 Knotentypen, alle 5 Beziehungen mit korrekt aufgelösten
Business-Keys, Artifact/Assembly/Part korrekt per Kompositionstiefe getrennt.
Die tatsächliche Struktur unterschied sich vom ursprünglich angenommenen
XMI-2.1-Extension-Format erheblich (siehe unten) — der Extraktor wurde
deshalb komplett neu geschrieben, nicht nur nachgebessert.

**Tatsächliche Struktur (verifiziert, nicht mehr Annahme):**
- Stereotyp-Anwendungen sind eigene Elemente im Profil-eigenen XML-Namespace
  (`xmlns:RFLPV2_Sustainability_Process_Extension="http://www.sparxsystems.com/profiles/RFLPV2_Sustainability_Process_Extension/1.0"`),
  direkt als Geschwister der `packagedElement`s in `<uml:Model>`:
  `<RFLPV2_..:Logical_Element base_Class="EAID_.." __EAStereoName="Logical Element" logicalID="SP_PARALLEL"/>`.
  Kein `<xmi:Extension>` nötig für Stereotypen/Tags.
- Dependencies: normale `<packagedElement xmi:type="uml:Dependency" client=".." supplier="..">`, client=Source, supplier=Target.
- Komposition: `<uml:Association>` mit zwei Enden (`memberEnd`-Idrefs) — **wichtige
  Korrektur einer falschen Annahme**: das Ende mit `aggregation="composite"`
  zeigt auf das **Kind** (Part), nicht den Elternteil. Das andere Ende zeigt
  auf den Elternteil (Whole). Empirisch verifiziert.

**⚠️ Wichtigster EA-Workflow-Fund dieser Session (27.08.2026): MDG-Technology-
Reimport reicht NICHT.** Ein `RFLPV2_MDG_v0XX.xml`-Import über
`Settings ▸ MDG Technologies ▸ Manage MDG Technologies` aktualisiert die
Toolbox, aber **nicht zuverlässig die darin gebündelte UML-Profile-
Registrierung** (`RFLPV2_Sustainability_Process_Extension`). Stundenlange
Fehlersuche bei `Customer Need`/`Derives` (Connector ließ sich nicht ziehen,
obwohl das Profil inhaltlich längst korrekt war) stellte sich am Ende als genau
dieses Problem heraus. **Nach jedem Profil-Update immer BEIDES separat neu
laden:** (1) die MDG Technology (für die Toolbox) UND (2) das UML-Profile
selbst über `Resources ▸ UML Profiles ▸ RFLPV2_Sustainability_Process_Extension
▸ Import Profile` (derselbe Weg, über den ihr die Profil-Stereotypen-Liste
schon einmal angeschaut habt). Nur ein MDG-Reimport reicht nicht, auch nicht
nach vollständigem Entfernen+Neuinstallieren der Technology.

## 2. Knoten-Mapping

| EA-Stereotyp | `AppliesTo` | Neo4j-Label | Business-Key (EA-Tag → Neo4j `id`) | Merge-Verhalten |
|---|---|---|---|---|
| `Customer Need` | Class | **`:CustomerNeed`** (neu, kein Bestand) | `needID` | Neuer Knotentyp |
| `Customer Requirement` | Class | `:Requirement` (bestehend) | `customerRequirementID` | MERGE auf `id`; setzt `level = 'customer'` |
| `System Requirement` | Class | `:Requirement` (bestehend) | `systemRequirementID` | MERGE auf `id`; setzt `level = 'system'` |
| `Function` | Class | `:Function` (bestehend) | `functionID` | MERGE auf `id` — reichert ggf. bestehende Knoten (z.B. `FUNC_GRASP`) mit neuen Properties an |
| `Logical Element` | Class | `:SolutionPrinciple` (bestehend) | `logicalID` | MERGE auf `id` |
| `Process Element` | Class | `:Process` (bestehend) | `processID` | MERGE auf `id`; siehe Sonderregel `processRef` (Abschnitt 4) |
| `Product Element` | Class | `:Artifact` / `:Assembly` / `:Part` (bestehend, per Komposition abgeleitet) | `productID` | MERGE auf `id`; siehe Sonderregel Ebenen-Ableitung (Abschnitt 4) |
| `Test Case` | Activity/Operation | **`:TestCase`** (neu) | `testCaseID` (ergänzt 28.08.2026) | Neuer Knotentyp |
| `Test Case Description` | Class | **`:TestCaseDescription`** (neu) | `testCaseDescriptionID` (ergänzt 28.08.2026) | Neuer Knotentyp |
| `Test Scenario` | Activity/Operation | **`:TestScenario`** (neu) | `testScenarioID` (ergänzt 28.08.2026) | Neuer Knotentyp |
| `Validation` | Behavior/Operation | **`:Validation`** (neu) | `validationID` | Neuer Knotentyp |
| `Verification` | Behavior/Operation | **`:Verification`** (neu) | `verificationID` | Neuer Knotentyp |
| `Analysis`/`Demonstration`/`Inspection`/`Simulation`/`Test` | (generalisieren `Validation`) | **kein eigener Knoten** | — | Setzen nur `method = '<Stereotypname>'` auf dem :Validation/:Verification-Knoten, der dieses Element trägt (siehe Abschnitt 4) |

Tag→Property-Mapping ist grundsätzlich 1:1 (gleicher Name), mit einer Ausnahme:
das Profil-Tag `Mainfeature` (Groß-M, Ausreißer in der sonst durchgängigen
lowerCamelCase-Konvention) wird beim Import auf `mainFeature` normalisiert.

## 3. Beziehungs-Mapping

| EA-Dependency-Stereotyp | Zielregel | Fallback |
|---|---|---|
| `Satisfies` | Ziel-Stereotyp ∈ {`Customer Requirement`, `System Requirement`} → **`:SATISFIES_REQUIREMENT`** (bestehend, Richtung Source→Requirement) | sonst neuer Typ `:SATISFIES`, mit Log-Warnung (unerwartete Stereotyp-Kombination) |
| `Realizes` | Source=`Logical Element` & Ziel=`Function` → **`:REALIZES_FUNCTION`** (bestehend); Source=`Product Element` & Ziel=`Logical Element` → **`:REALIZES_PRINCIPLE`** (bestehend) | sonst neuer Typ `:REALIZES`, mit Log-Warnung |
| `Affects` | — | neuer Typ `:AFFECTS` |
| `Derives` | — | neuer Typ `:DERIVES` |
| `Refines` | — | neuer Typ `:REFINES` |
| `Requires` | — | neuer Typ `:REQUIRES` |
| `Specifies` | — | neuer Typ `:SPECIFIES` (bewusst **nicht** dasselbe wie das bestehende `SPECIFIED_BY` Requirement→Specification, andere Richtung/Semantik) |
| `Validates` | — | neuer Typ `:VALIDATES` |
| `Verifies` | — | neuer Typ `:VERIFIES` |

Alle neuen Relationship-Typen tragen `sourceStereotype`/`targetStereotype` als
Properties mit, damit unerwartete Kombinationen (Fallback-Fälle) im Graphen selbst
nachvollziehbar bleiben, ohne die Ladeskripte durchsuchen zu müssen.

**EA-seitiger Fund (27.08.2026): generisches `SysML1.4::trace` ist in EAs
Implementierung stark eingeschränkt.** Empirisch in EA bestätigt: Connectors,
die `trace` generalisieren, ließen sich zwischen zwei block-generalisierten
Elementen (z.B. `Logical Element` → `Function`) nicht ziehen
(„Invalid combination of source and target types for this connector type"),
während `SysML1.4::allocate`-generalisierende Connectors (`Refines`, `Requires`)
dort anstandslos funktionierten. Das betraf nicht nur Product-Element-Paare,
sondern zog sich auch durch bei eigentlich Requirement-nahen Paaren mit
`Customer Need`. Fix: `Derives`, `Satisfies`, `Verifies` generalisieren jetzt
die spezifischeren, semantisch passenderen nativen SysML-Stereotypen
`SysML1.4::deriveReqt`, `SysML1.4::satisfy`, `SysML1.4::verify` statt des
generischen `trace` — das entspricht auch der eigentlichen OMG-SysML-Intention
(diese drei sind speziell für Requirements-Traceability gedacht, `trace` ist
der unspezifische Catch-all). Für `Affects`, `Realizes`, `Specifies`,
`Validates` gibt es keine 1:1-native SysML-Entsprechung — die bleiben vorerst
auf `trace` bzw. dem bisherigen Stand, bis das Testmodell zeigt, ob sie
überhaupt in den gewünschten Kombinationen gebraucht werden. Für die
EA→Neo4j-Extraktion ändert dieser Fund nichts, da `ea_xmi_extract.py`
ausschließlich auf den Stereotyp-**Namen** (`Derives`, `Satisfies`, ...)
matcht, nicht auf deren SysML-Generalisierung.

**Nachtrag (27.08.2026):** Nach korrektem Zwei-Schritt-Reimport (siehe
Abschnitt 1) bestätigte sich: das eigentliche Problem war überwiegend der
fehlende Profil-Reimport, nicht `trace` an sich — `Derives`
(Customer Need → Customer Requirement) funktionierte, sobald das Profil
sauber neu geladen wurde. `Realizes` (Logical Element → Function, block-zu-
block, kein Requirement beteiligt) scheiterte aber weiterhin, selbst in einem
komplett frischen EA-Projekt. Zusätzlicher Befund dabei: der Stereotyp
`Function` wird von EA visuell abweichend dargestellt (fx-Icon statt
Block-Notation mit Stereotyp-Label) — betrifft ausschließlich `Function`,
nicht `Logical Element`/`Process Element`/`Product Element`, obwohl alle vier
strukturell identisch aufgebaut sind (`generalizes="SysML1.4::block"`).
Vermutlich behandelt EA den Namen „Function" intern speziell (z. B. Rest einer
klassischen Structured-Analysis/DFD-Notation), unabhängig von der aktiven
Technology-Liste. Pragmatischer Fix statt Ursachenforschung: `Realizes`
generalisiert jetzt ebenfalls `SysML1.4::allocate` statt `trace` (wie schon
`Refines`/`Requires`), da `allocate` nachweislich zuverlässig block-zu-block
funktioniert. `Affects`, `Specifies`, `Validates` stehen noch auf `trace` und
sind nach dem Zwei-Schritt-Reimport-Fix noch nicht neu getestet — könnten
durchaus schon funktionieren, falls sie einen Requirement-Endpunkt haben.

**Update:** `Realizes`/`allocate` bestätigt funktionierend, sowohl bei aus dem
Profil als auch aus der Toolbox gezogenen Elementen (Function ↔ Logical
Element) — die Toolbox war also nie das Problem, der `allocate`-Fix war der
entscheidende. Die `Function`-Optik (fx-Icon statt Block-Notation) bleibt
bestehen, auch profil-gezogen, ist also EA-intern und unabhängig von unserem
Profil/Toolbox — bewusst als kosmetisch akzeptiert, blockiert nichts.

**Abschluss (27.08.2026): alle 9 Dependency-Stereotypen bestätigt
funktionsfähig.** `Affects`, `Specifies`, `Validates` (weiterhin `trace`)
wurden nachgetestet und funktionieren zwischen Function ↔ Logical Element,
sowohl toolbox- als auch profilseitig erzeugt. Die komplette
`SysML1.4::trace`-Restriktionstheorie war also überwiegend ein Artefakt des
fehlenden Zwei-Schritt-Reimports (Abschnitt 1) — nur `Derives`/`Satisfies`/
`Verifies`/`Realizes` brauchten tatsächlich eine andere SysML-Basis, der Rest
funktionierte von Anfang an korrekt, sobald richtig importiert wurde. Damit
ist die Beziehungsseite des Profils vollständig verifiziert.

**`Customer Need` bleibt Class (nicht Note).** War kurzzeitig auf `Note`
zurückgestellt (reiner Freitext), wurde aber wieder verworfen: da
`Customer Need` weiterhin Quelle/Ziel von `Derives`/`Affects`-Kanten sein soll,
muss es ein `NamedElement` bleiben — ein `Comment` (UML-Note) ist das laut
Metamodell nicht, eine `Dependency` kann also nicht daran hängen. `Class` ist
damit die einzige der beiden Optionen, die die geplante Ableitungskette
`Customer Need → Customer Requirement` überhaupt modellierbar macht.

## 4. Sonderregeln

**Artifact/Assembly/Part-Ableitung (`Product Element`).** Es gibt im Profil keinen
eigenen Stereotyp für Komposition — das ist beabsichtigt, da SysML-Blockkomposition
(Assoziation mit `aggregation="composite"`) bereits Bordmittel ist und keine eigene
Stereotypisierung braucht. Der Extraktor liest alle `uml:Association`-Elemente
zwischen zwei `Product Element`-Knoten mit `aggregation="composite"` auf einem
Ende, baut daraus einen gerichteten Komponentenbaum und weist Labels nach Tiefe
zu: Tiefe 0 (keine eingehende Komposition) → `:Artifact`, Tiefe 1 → `:Assembly`,
Tiefe ≥2 → `:Part`. Bei Tiefe >2 wird eine Warnung geloggt, da das bestehende
Schema strikt dreistufig ist (`Artifact → Assembly → Part`).

**`materialRef` (Product Element).** Nur sinnvoll auf Knoten, die als `:Part`
eingestuft werden. Erzeugt zusätzlich zum Knoten eine `:USES_MATERIAL`-Kante auf
den referenzierten `:Material`-Knoten (muss bereits existieren — kein
Auto-Anlegen). Taucht `materialRef` auf einem `:Artifact`/`:Assembly`-Knoten auf,
wird das als Datenqualitätswarnung geloggt statt stillschweigend eine
möglicherweise falsche Kante zu erzeugen.

**`processRef` (Process Element).** Da `Process Element` direkt auf das
bestehende `:Process`-Label mergt (`processID` = `id`), ist `processRef` nur
relevant, wenn es sich vom eigenen `processID` unterscheidet — dann legt der
Loader zusätzlich eine `:REFERENCES`-Kante vom neuen/aktualisierten
`:Process`-Knoten auf den referenzierten `:Process`-Knoten an (z.B. für
Prozess-Gruppierungsknoten, die auf einen Detail-Prozess aus dem
LCA-Bestand verweisen, ohne ihn zu ersetzen). ⚠ Offen: bewusste Annahme, noch
nicht mit echten Daten geprüft.

**Verifikationsmethode (`Analysis`/`Demonstration`/`Inspection`/`Simulation`/`Test`).**
Diese fünf Stereotypen (plus `Test Case`/`Test Scenario`) hatten ursprünglich kein
eigenes `AppliesTo` — dadurch tauchten sie in EAs Ressourcenbaum unter „UML
Profiles" gar nicht als eigenständig nutzbare Elemente auf. Das wurde behoben:
alle sieben haben jetzt dasselbe `AppliesTo` (Behavior + Operation) wie
`Validation`/`Verification` und wurden am 27.08.2026 live in EA verifiziert
(Ressourcenbaum zeigt jetzt korrekt je zwei Varianten pro Stereotyp). Der
Extraktor ordnet sie dem Label `:Validation` zu (passend zum
`generalizes="Validation"` im Profil) und schreibt den konkreten Stereotypnamen in
die Property `method`. ⚠ Weiterhin offen: das Profil erlaubt laut
`baseStereotypes` theoretisch auch eine Zuordnung zu `Verification` — falls in
der Praxis Elemente mit z.B. `Simulation` als Verifikationsnachweis (nicht
Validierung) gedacht sind, muss diese Regel im Extraktor angepasst werden. Das
ist eine fachliche Zuordnungsfrage, keine EA-Importfrage mehr, und bleibt bis
zum ersten echten XMI-Testexport offen.

**Requirement.level bei Bestandsdaten.** Die 40 bestehenden `:Requirement`-Knoten
haben aktuell kein `level`-Property (weder 'customer' noch 'system'). Die Pipeline
setzt `level` nur auf Knoten, die tatsächlich über eine EA-Requirement-Stereotyp
gemerged werden — Bestandsdaten bleiben unangetastet, bis sie entweder manuell
nachgepflegt oder durch einen künftigen EA-Merge berührt werden.

## 5. Neue Uniqueness-Constraints

Siehe `ea_new_labels_constraints.cypher` — je ein `IS UNIQUE`-Constraint auf `id`
für `CustomerNeed`, `TestCase`, `TestCaseDescription`, `TestScenario`,
`Validation`, `Verification`.

## 6. Testexport für die Parser-Verifikation

Um `ea_xmi_extract.py` gegen echte EA-Ausgabe zu prüfen, reicht ein kleines
Testpaket in EA mit z.B.:

- je einem Element mit Stereotyp `Customer Need`, `System Requirement`,
  `Function`, `Logical Element`, `Product Element` (idealerweise 3 Stück in
  einer Komposition, um die Artifact/Assembly/Part-Ableitung zu testen),
  `Process Element`
- 2–3 Dependency-Relationships dazwischen, z.B. `Derives`
  (Customer Need → System Requirement), `Satisfies` (Product Element →
  System Requirement), `Realizes` (Logical Element → Function)
- ein Element mit Stereotyp `Verification` oder `Simulation`

Export über *Project ▸ Model Exchange ▸ Export Package as XMI*, Format
"XMI 2.1", auf das Testpaket angewendet. Datei einfach hier reinladen — ich
gleiche den Parser dagegen ab und melde konkret, was noch fehlt.

## 7. Rücklauf: Neo4j → EA (Bootstrap-Export)

**Skript:** `neo4j_to_ea_export.py` (28.08.2026). Liest den Neo4j-Graphen rein
lesend aus und erzeugt eine XMI-2.1-Datei im selben, verifizierten Dialekt wie
`ea_xmi_extract.py` ihn einliest — zum Import in EA über *Project ▸ Model
Exchange ▸ Import Package from XMI*. Kein Rücklauf im Sinne der Umkehrung von
`ea_to_neo4j_load.py` — es wird nichts in Neo4j verändert.

**Umfang (im Chat entschieden):** voller Graph, keine Filterung. Damit werden
alle aktuell 267 Basiselemente exportiert: 43 Artifact + 43 Assembly + 86 Part
(alle über `HAS_COMPONENT` zu einer dreistufigen Komposition verkettet), 8
Function, 8 SolutionPrinciple, 55 Process, 24 Requirement. Dazu 131
Kompositionskanten sowie 333 Beziehungen (26 `REALIZES_FUNCTION`, 44
`REALIZES_PRINCIPLE`, 263 `SATISFIES_REQUIREMENT`). `CustomerNeed`, `TestCase`,
`TestCaseDescription`, `TestScenario`, `Validation`, `Verification` sind im
Skript vorbereitet, liefern aber aktuell 0 Zeilen (kein Bestand — diese Labels
wurden erst diese Session für die EA-Anbindung eingeführt).

**Requirement-Level (strukturell hergeleitet, nicht geraten):** alle 24
bestehenden `:Requirement`-Knoten werden als **System Requirement** exportiert.
Begründung: jeder einzelne hat eine `SPECIFIED_BY`-Kante zu einer
`:Specification` mit quantifiziertem Wert (`valueNumber`/`unit`/
`toleranceMin`/`toleranceMax`) bzw. einem Rollentext wie „engineering target
(unvalidated)"/„engineering criterion (unvalidated)". Das ist die strukturelle
Signatur bereits formalisierter, technisch abgeleiteter Requirements — nicht
die roher, unformalisierter Kundenwünsche. Es gibt im Bestand ohnehin noch
keinen einzigen `:CustomerNeed`-Knoten, der als Gegenprobe dienen könnte, und
kein Requirement weicht strukturell von diesem Muster ab (kein Fall mit
fehlender oder rein qualitativer `SPECIFIED_BY`-Verknüpfung) — die Zuordnung
ist also für den kompletten aktuellen Bestand einheitlich und nicht
grenzwertig. `requirementType` (z.B. „performance", „sustainability") und
`priority` (must/should) wurden geprüft und liefern **kein** brauchbares
Unterscheidungsmerkmal customer/system, da sie eine andere Klassifikationsachse
abbilden.

**Bekannte, bewusste Lücken (Neo4j-Properties ohne Tag im RFLPV2-Profil):**
Function.input/output/constraintText, SolutionPrinciple.physicalPrinciple/
status, Process.technology/geographicalLocation/dataAcquisition/status/source/
sourceDatabase/referenceYear, Artifact/Assembly/Part.variant(Family)/
manufacturer/mass_g/opening_mm/tcp_mm/evidenceLevel/validationRequired/
description/status, Requirement.requirementType/statement/priority/status.
Diese Properties bleiben unverändert in Neo4j, tauchen aber im EA-Modell nicht
auf. Sonderfall `priority`: Neo4j führt es als String-Enum („must"/„should"),
das Profil-Tag `requirementPriority` ist aber vom Typ `Real` — ohne erfundene
Skala keine verlustfreie 1:1-Umwandlung, deshalb bewusst leer gelassen.
Freitext wie `Requirement.statement` hat aktuell kein verifiziertes Ziel im
XMI-Dialekt (EA-Notes-Encoding beim **Schreiben** wurde in dieser Pipeline noch
nie empirisch geprüft, nur beim Lesen war es nie nötig) — bewusst ausgelassen
statt eine ungetestete XML-Struktur zu raten.

**Selbsttest (28.08.2026, ohne Neo4j-Verbindung):** `build_xmi()` wurde offline
mit der bereits verifizierten `rflpv2_merge_test.xml`-Szenario (FUNC_GRASP,
SP_PARALLEL, ART_CUSTOM→ASSY_CUSTOM→PART_CUSTOM_CONTACT mit `materialRef`,
REQ_COMPAT, Realizes, Satisfies) als Mock-Daten aufgerufen. Ergebnis: (1) XML
wohlgeformt (`ElementTree.fromstring` erfolgreich), (2) die erzeugte Datei
danach durch `ea_xmi_extract.py` selbst gejagt — korrekte
Artifact/Assembly/Part-Tiefenableitung, korrektes `materialRef`, korrektes
`level=system`, beide Dependencies korrekt aufgelöst. Damit ist die
XMI-Erzeugung strukturell in sich konsistent mit dem Rest der Pipeline
verifiziert. **Noch nicht verifiziert:** ein echter Import der erzeugten Datei
in EA selbst (steht noch aus, siehe Warnung unten).

**⚠️ Wichtig vor dem echten Import:** EAs XMI-Import matched Elemente nur über
ihre GUID (`xmi:id`), nicht über Business-Keys. Das Skript vergibt
deterministische IDs (`EAID_<BusinessKey>`), aber `rflpv2.qea` hat FUNC_GRASP,
SP_PARALLEL, ART_CUSTOM/ASSY_CUSTOM/PART_CUSTOM_CONTACT, REQ_COMPAT bereits von
Hand angelegt, mit eigenen zufälligen GUIDs — ein Import in dasselbe Projekt
würde für diese Elemente Duplikate anlegen statt zu mergen. Empfehlung: Import
in ein **neues, leeres EA-Projekt** (mit importiertem RFLPV2-Profil), um den
Ist-Zustand des Graphen sauber zu spiegeln; `rflpv2.qea` bleibt das separate
Hand-Testprojekt.

**Diagramm-Erzeugung (28.08.2026, auf ausdrücklichen Wunsch ergänzt).** Der
Export bringt jetzt zusätzlich ein einziges EA-Diagramm mit — jeder Knoten
und jede Kante ist darauf platziert, kein Filtern/Kuratieren. Layout: pro
Stereotyp-Kategorie ein eigenes Zeilen-Raster ("Band"), Bänder untereinander
gestapelt; bewusst kein Anspruch auf hübsches Layout, nur ein reproduzierbarer
Ausgangspunkt (in EA per "Layout Diagram" weiter verfeinerbar). Format
(`<xmi:Extension>`/`<diagrams>`, `DUID`-basierte Verknüpfung von Shape zu
Kante über `EOID`/`SOID`) wurde Zeichen für Zeichen gegen `rflpv2_package.xml`
verifiziert, inklusive der Kantenrichtung (`SOID`=Start, `EOID`=Ende — bei
Komposition zeigt `SOID` auf das Kind, `EOID` auf den Elternteil, exakt
dieselbe Regel wie beim `aggregation="composite"`-Ende in `<uml:Model>`,
dort ebenfalls empirisch bestätigt). **Noch offen:** ob der `<diagrams>`-Block
auch *ohne* die begleitenden, stark redundanten `<elements>`/`<connectors>`-
Bookkeeping-Blöcke, die EAs eigener Exporter zusätzlich schreibt, beim Import
genügt — bloße Elementerzeugung ganz ohne `<xmi:Extension>` funktioniert
nachweislich (`rflpv2_merge_test.xml`), das Diagramm ist der noch ungetestete
Teil. Abschaltbar über `--no-diagram`, falls der Import mit Diagramm-Block
Probleme macht.
