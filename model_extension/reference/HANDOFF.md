# Projektkontext: Niryo-Ned2-Greifer Nachhaltigkeits-Wissensgraph

Stand: 2026-08-29. Alle Dateipfade sind relativ zur Wurzel dieses Repositorys.

---

## 1. Worum es geht

PhD-Fallstudie: ein Neo4j-Wissensgraph modelliert einen Niryo-Ned2-Robotergreifer
(Produktstruktur, Funktionen, Material, Prozesse) und verknüpft ihn mit
Ökobilanzdaten (ILCD/EF3.1, ReCiPe 2016), um Nachhaltigkeitsbewertungen
durchführbar und **methodenagnostisch** zu machen. Zwei parallele Arbeitsstränge:

- **Neo4j-Seite** — das Wissensgraph-Modell selbst (Knoten/Kanten, Datenimport
  aus ILCD-Quellen, gestufte Ausbaustufen, Bewertungs-Layer).
- **MBSE-Seite** — eine SysML-Profilerweiterung (RFLPV²) in Enterprise Architect,
  die definiert, wie Produktentwickler die nötigen Nachhaltigkeitsdaten
  strukturiert erfassen, damit sie später ins Neo4j-Modell einfließen.

Die systematisch ausgearbeiteten Lösungen liegen in diesem Repository (Layout
siehe Abschnitt 6).

## 2. Aktueller Neo4j-Modellstand

**Live-DB (Neo4j Desktop, 2026-08-29, nach allen Stufen + Konsistenzprüfung
Ebene 1–4 + KI-Entfernung):**

| Kennzahl | Wert |
|---|---:|
| Knoten | **5 620** |
| Beziehungen | **86 635** |
| Knoten-Labels | 39 |
| Beziehungstypen | 54 |
| Uniqueness-Constraints | 39 (+ `flow_casnorm`-Index, 42 Indizes gesamt) |

0 label-lose Knoten · 0 Duplikat-Knoten · 0 verwaiste/wertlose `ImpactResult` ·
alle Teile mit Masse. Autoritativer Ist-Stand ist immer die Live-DB; die
konsolidierte Referenz dazu ist
[`model_extension/reference/EXTENSION_REFERENCE.md`](EXTENSION_REFERENCE.md),
das maschinenlesbare Schema
[`model_extension/reference/graph_schema_v3x.json`](graph_schema_v3x.json)
(93 Keys).

### Ausbaustufen (streng additiv, nicht-brechend — das *ist* der Flexibilitätsnachweis)

| Stufe | Box | Kern | Migration |
|---|---|---|---|
| **v1** | black | Produktmodell + konkrete Indikatoren + Reparierbarkeit formalisiert | `model_extension/migrations/v1_blackbox/` |
| **v2** | grey | ILCD/EF3.1-Inventar + Rechenkern `ImpactResult.value`; Aluminium-A1-Pfad | `model_extension/migrations/v2_greybox/` |
| **v3** | white | `lca_generic($methodId)`, funktionale Einheit, EN-15804-Module, `AssessmentApproach`-Taxonomie | `model_extension/migrations/v3_whitebox/` |
| **v3.a–e** | Module | Zirkularität (MCI) · Kosten/MFCA · Szenario/Unsicherheit · Provenienz + EPD/DPP · ReCiPe 2016 (2. LCIA-Methode) | `model_extension/migrations/v3x_{a..e}_*/` |
| **v3.f–i** | Module | THG-Scopes · Schadstoff-Screening · Cross-Impact · fortgeschrittene LCA-Haken · externe Rahmenwerke · selbstbeschreibender KG | `model_extension/migrations/v3x_nonlcia/` |
| **v2-data** | Daten | Part-Massen (86), Fertigungsenergie, Werkstoff-GWP; Varianten A (reale ILCD-Datensätze, Standard ab v3) / B (Literale) | `model_extension/migrations/v2_data/` |
| **PRE-5 / LCI-Hygiene** | Datenpflege | ImpactCategory-Kanonisierung, CAS-/Einheiten-/Kompartiment-Bereinigung | `model_extension/migrations/v3_followup_pre5/`, `v2_data/lci_hygiene/` |
| **DQ-Konzept** | Methodik | Datenqualitätskriterien inhärent/systembezogen (0..4), `DQPhase`-Gates, auto-DQ aus Kanten-Metadaten | `model_extension/migrations/dq_concept/` (01–03) |
| **Demonstrator** | Artefakte | Nachhaltigkeits-`Requirement`s + `TestCase`-Verifikationskette (RFLPV² §6) + EPD/DPP-Statuslebenszyklus + Szenario-Abdeckung, 8-Greifer-Scheibe | `model_extension/migrations/demonstrator/` (00–04) |
| **Konsistenzprüfung** | QS | 4 Ebenen, read-only Harness, jede Änderung dokumentiert | `model_extension/migrations/consistency/` |

### Bewertungsmethoden im Graphen (6)

`IAM_EF31` (Environmental Footprint 3.1, 19 Kategorien, rechnet) ·
`IAM_PCF` (Product Carbon Footprint, Screening) ·
`IAM_RECIPE` (ReCiPe 2016 Midpoint H, 18 Kategorien, 16 rechnen) ·
`IAM_MCI` (Material Circularity, vereinfacht, rechnet) ·
`IAM_REPAIR` (Reparierbarkeit v1, rechnet) ·
`IAM_GHG` (THG-Bilanz nach Scope, GHG Protocol).

Alle **23 Verfahren** des Methodendiagramms (3 Paradigmen / 7 Gruppen) sind als
`AssessmentApproach`-Knoten adressierbar; Steckbriefe in
[`methods/onepagers/`](../../methods/onepagers/). Basisqueries je Verfahren in
[`methods/base_queries/`](../../methods/base_queries/).

### Flexibilitätsanalyse gegen vier Bewertungsverfahren

Volles Dokument:
[`model_extension/reference/Sustainability_Assessment_Flexibility_Analysis.md`](Sustainability_Assessment_Flexibility_Analysis.md).
Der Bewertungs-Layer
(`Assessment`→`USES_METHOD`→`ImpactAssessmentMethod`→`HAS_CATEGORY`→`ImpactCategory`)
ist methodenagnostisch — neue Verfahren brauchen keine Schemaänderung. Von den
fünf ursprünglich identifizierten additiven Lücken ist die größte umgesetzt, vier
bleiben als **dokumentierte Vorwärtsliste** (keine bricht Bestehendes):

1. ~~`Process.lifecycleModule` (EN-15804-Code)~~ — **live** auf allen 58
   `Process`-Knoten seit v2 (`A1`, `A1-A3`, `A3`, `B1`, `B4`, `C3`), von der
   DQ-Schicht ausgewertet. Die Konsistenzprüfung Ebene 4 (DE-01) hat die
   veraltete „nur dokumentiert"-Angabe in Spec und Handoff korrigiert.
2. Deklarierte funktionale Einheit als eigener Knoten (fehlt für LCA und EPD
   gleichermaßen; aktuell nur als `Assessment`-Property).
3. `Assessment --ASSESSES-->` von nur `Artifact` auf auch
   `Part`/`Material`/`Process`/`ProcessPlan` erweitern.
4. Generische Nachvollziehbarkeits-Kante `ImpactResult --BASED_ON-->
   (Feature|CoreProperty|DataItem)` — teils schon da (57 Kanten, v3.d), noch
   nicht durchgängig für nicht-LCI-basierte Ergebnisse.
5. Reine Property-Ergänzungen: Recyclingfähigkeit/Wiederverwendbarkeit
   (`Material`, teils da), Lebensdauer/Nutzungsintensität (`Artifact`),
   Verbindungstyp/Reversibilität (`Feature`/`HAS_COMPONENT`).

### KI/ML-Paradigma — entfernt (2026-08-29)

Das Paradigma „lernende Ansätze" war nur als Andockpunkt (Verfahren 3.1.x/3.3.x,
`PredictionModel`/`Recommendation`, `PREDICTS`/`ESTIMATED_BY`/`RECOMMENDS_FOR`,
`ASSESS_AI_PREPARED`) vorgesehen und wurde als außerhalb des Fallstudien-Umfangs
vollständig aus Graph und Doku entfernt —
`model_extension/migrations/consistency/remove_ki_stubs.cypher` (mit Rollback-Block).
Behalten: `AP_LERNEND`-Wurzel + `APG_MODEL_TRANSPARENCY` + `APM_DPP` + `APM_ENV_KG`
(real, nicht KI) sowie `ImpactResult.provenance`/`.confidence` (allgemein).

## 3. Konsistenzprüfung (4 Ebenen, abgeschlossen 2026-08-29)

Read-only Harness unter
[`model_extension/migrations/consistency/`](../migrations/consistency/). Jeder Befund
wird mit dem Nutzer triagiert (jetzt beheben / vertagen / akzeptieren +
dokumentieren) und in `FINDINGS.md` / `CHANGELOG.md` festgehalten.

| Ebene | Datei | Ergebnis |
|---|---|---|
| **1 methodische Bausteine** | `check_meta.cypher` | erledigt — Live-Zählung vs. Referenzdoku/Schema |
| **2 Modellkonsistenz** | `check_model.cypher` (+ `_oneshot`) | erledigt — 8 Befunde (F-01…F-10); Fixe `fix_F02/F03/F05_*.cypher`, Rest akzeptiert |
| **3 Tool-Konsistenz** | `check_tools.sh` + `check_tools_drift.cypher` | erledigt — 43 PASS / 0 FAIL / 1 by-design-skip; 1 Befund **F-11** (ReCiPe-CF-Importer nicht idempotent gegen den Post-Hygiene-Graphen — akzeptiert + dokumentiert, Baseline gepinnt) |
| **4 logische DECODE-Einbettung** | `check_decode.cypher` (+ `_oneshot`) | erledigt — 21 strukturelle Checks bestehen; **DE-01** (Spec §7 zu `lifecycleModule` korrigiert), **DE-02** (2 `ExternalFramework`-Knoten ergänzt, `fix_DE02_framework_nodes.cypher`) |

Ebene 4 ist **kein** Software-Integrationstest — sie prüft, dass der Graph ein
faithful **logisches** Ziel für das RFLPV²-Profil (`RFLPV2_Extension_Spec.md` §7)
und die Berichtsrahmenwerke ist.

Die beiden `*_oneshot.cypher`-Varianten laufen ohne Browser-Multi-Statement-
Einstellung: ganze Datei einfügen, einmal ausführen — leere Ergebnistabelle =
sauber.

## 4. Snapshots

`snapshots/` (nur in der Arbeitskopie des Maintainers, nicht im Repository) —
Endzustand als restore-fähiger Export:

- `graph_full_2026-08-29.cypher` (~34 MB, `apoc.export.cypher.all`, Format
  `cypher-shell`) — nur gegen **leere** DB einspielbar.
- `graph_full_2026-08-29.graphml` (~48 MB) — für Gephi / yEd / `neo4j-admin import`.
- `schema_2026-08-29.json` (~130 KB) — reine Struktur, keine Werte.

⚠️ Die beiden großen Dumps re-exprimieren die aus lizenzierten ILCD-Datensätzen
abgeleitete Inventardatenbasis und **dürfen nicht ins Git-Repo** (Lizenz). Für die APOC-Datei-Exporte liegt
`conf/apoc.conf` (`apoc.export.file.enabled=true`) in der DBMS-Instanz; wirkt
nach DBMS-Neustart.

Echte Stufen-Dumps je Baustufe gibt es nicht nachträglich — der reproduzierbare
Stufenpfad ist die Migrationskette (jede Stufe mit eigenem `CHANGELOG.md`).
Einziger echter Zwischen-Dump: `model_extension/migrations/v1_blackbox/v1_snapshot.cypher`.

## 5. RFLPV²-SysML-Profilerweiterung (Enterprise Architect)

Ziel: RFLPV² (Requirements-Functional-Logical-Physical/Product-Verification,
HNI-Ansatz für CPS-Engineering) um Nachhaltigkeitsbezug erweitern — Materialien/
Prozesse als leichte Properties statt neuer Stereotypen, Prozess-Element als Anker
fürs Lebenszykluskonzept, EN-15804-Modulbezug, Testfall-Konzepte aus dem
Ebel/Pottebaum/Graessler-Paper (ISSE 2024).

Vollständige, finale Spezifikation:
[`ea_neo4j_pipeline/profile_spec/RFLPV2_Extension_Spec.md`](../../ea_neo4j_pipeline/profile_spec/RFLPV2_Extension_Spec.md).

Kerninhalte:
- Physical Element → **Product Element** umbenannt; neues Tag `realizationType`
  (hardware/software/hybrid).
- `materialRef` als **String[0..*]**.
- System Requirement + `sustainabilityIndicatorRef`, `sustainabilityThreshold`,
  `sustainabilityOperator` (Enum), `sustainabilityUnit`, `sustainabilityScope`.
- Process Element: `processID` (SysML-ID) vs. `processRef` (Neo4j-`Process.id`)
  getrennt, `lifecycleModule` (EN-15804-Code) als Tag.
- Verifikationsschicht + Test Case/Test Case Description/Test Scenario, mit
  `sustainabilityResult`/`sustainabilityStatus`.
- §7 Mapping-Tabelle: ✅ live vs. 🕓 nur dokumentiert. Die eine noch offene
  🕓-Zeile ist `REALIZES`/`AFFECTS` (dedizierte Relationship-Typen statt
  `APPLIES_TO` + Diskriminator) — bewusst vertagt in den nächsten Rebuild.

### EA-Implementierungsstand (letzter erfasster Stand 2026-08-27)

Profil als eigenständige SysML-Erweiterung in EA nachgebaut (25 Stereotypen,
gegen das Original-Cameo-Profil abgeglichen), 2 Enumerationen, 3 lokale
PrimitiveTypes, alle 5 Generalisierungsgruppen manuell gezogen. Dateien:
`ea_neo4j_pipeline/profile_spec/RFLPV2_Extension_Profile.xml` (finale Version),
`RFLPV2_Example_Model.xml` (Instanz-Beispiel, Kopfkommentar markiert reale vs.
Platzhalter-IDs).

**Zuletzt offener Blocker:** das über `Resources → UML Profiles → Import Profile`
registrierte Profil erschien nicht im `Profile:`-Dropdown des
Stereotyp-Zuweisungsdialogs; das Beispielmodell ließ sich importieren, aber ohne
Stereotyp-Zuweisung. Pragmatischer Fallback (noch nicht bestätigt): Stereotyp-Name
direkt ins Textfeld „Stereotype" im Properties-Fenster tippen. Die
Pipeline-Seite (`ea_neo4j_pipeline/`) ist davon unabhängig und verifiziert.

## 6. Repository-Layout und Konventionen

| Repo-Pfad | Inhalt |
|---|---|
| `model_extension/migrations/` | geordnete, additive Cypher-Migrationen (v1 … v3.x, DQ-Konzept, Demonstrator, Konsistenzprüfung) |
| `model_extension/reference/` | Referenzdokumentation, Annahmen, Schema, Änderungs-Methoden-Matrix, Flexibilitätsanalyse, dieses Dokument |
| `methods/onepagers/`, `methods/base_queries/` | Steckbrief und Basisquery je Bewertungsverfahren |
| `lca_bulk_load/` | ILCD/Sphera-Bulk-Load (Kanal A/B), Einzelpaket-Importer |
| `ea_neo4j_pipeline/` | RFLPV²-/EA-Pipeline, inkl. `profile_spec/` (Spezifikation, Profilentwurf, Beispielmodell) |
| `aas_interface/`, `dashboards/` | AAS-Austausch (White/Grey/Black Box), NeoDash-Dashboards |

**Konventionen:**
- Keine personenbezogenen Angaben, Secrets, Tokens, persönlichen E-Mail-Adressen,
  maschinenspezifischen Pfade oder Instanz-IDs.
- Skripte lesen den Neo4j-Zugang nur aus `NEO4J_URI` / `NEO4J_USER` /
  `NEO4J_PASSWORD`, nie als Argument.
- **Keine** konkreten ILCD-Datensätze aus lizenzierten Produkten — auch nicht als
  generiertes Import-Cypher (`import_MAT_*.cypher`) oder als
  `snapshots/graph_full_*`-Dump. Nur die Pipeline + ein synthetisches Beispiel;
  die Pipeline läuft lokal gegen eigene Downloads.
- Ordner-`README.md` je Verzeichnis, Englisch (Konzept → Datenform → Reproduktion,
  mit `> **Status:**`-Blockquote, dessen Zahlen gegen eine laufende Instanz
  geprüft sind).
- Der gesamte Repo-Inhalt ist am Ende vollständig Englisch.

## 7. Zugriff auf die Live-DB

Direkt über die mit Neo4j Desktop gebündelte `cypher-shell`
(`bolt://localhost:7687`), nicht über einen MCP-Server. Zugangsdaten nur über
die Umgebungsvariablen `NEO4J_URI` / `NEO4J_USER` / `NEO4J_PASSWORD`, nie auf
Platte. Beispiel:

```bash
export NEO4J_URI=bolt://localhost:7687 NEO4J_USER=neo4j NEO4J_PASSWORD=...
cypher-shell -a "$NEO4J_URI" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" -f some_query.cypher
```

APOC 2026.07.1 (`apoc.meta.schema`, `apoc.export.cypher.all`,
`apoc.export.graphml.all`); `apoc.config.get`/`apoc.config.list` sind in dieser
Version **nicht** verfügbar.

## 8. Weitere Dokumente

- `model_extension/reference/EXTENSION_REFERENCE.md` — konsolidierte Schema-/Query-/Status-Referenz
- `model_extension/reference/methods_change_sets.md` — Änderungsmenge pro Verfahren
- `model_extension/migrations/PLAN.md` — Stufenplan, Snapshot-Verfahren, Status
- `model_extension/migrations/RUN_2026-08-27.md` — Log des ersten autonomen Arbeitslaufs (Teilstand)
- `ea_neo4j_pipeline/profile_spec/RFLPV2_Extension_Spec.md` — RFLPV²-Spezifikation
