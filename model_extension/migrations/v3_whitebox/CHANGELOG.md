# v3 (white box) — Änderungsprotokoll

## 2026-08-27 — ILCD interpretierbar & methodenaustauschbar (v3-minimal, erste Scheibe)

Migration: `migration_v3.cypher` · Basisquery: `lca_generic.cypher`
(ersetzt das fest verdrahtete `lca_computed_ef31.cypher` aus v2)

### Umfang dieser Scheibe

| Baustein | Inhalt |
|---|---|
| **PRE‑2** | `Process.lifecycleModule` (EN 15804) auf allen 55 Prozessen + Casing-Normalisierung `processType` |
| **PRE‑3** | funktionale Einheit / Referenzfluss / Systemgrenze auf allen 48 `Assessment` formalisiert |
| **PRE‑4** | `AssessmentApproach`-Taxonomie: 3 Paradigmen / 9 Gruppen / 29 Verfahren + `BROADER` + `APPLIES_APPROACH` |
| **`lca_generic($methodId)`** | methodenparametrisierte Basisquery — neue Methode = reine Daten, null Schemaänderung |

### Aufgeschoben auf v3-Folgescheibe

- **PRE‑5** ImpactCategory-Hygiene (~20 Waisen / Near-Duplikate, Kanten-Remapping) — blockiert die aktuelle Rechnung nicht (die 7 berechneten Kategorien sind sauber verlinkt), aber riskanteste Änderung → separat.
- **Zweite volle LCIA-Methode** (ReCiPe/CML) — keine Charakterisierungsdaten vorhanden. Methodenaustausch stattdessen mit den bestehenden `IAM_EF31` ↔ `IAM_PCF` über `lca_generic` nachgewiesen.

### Berührte / neue Artefakte

| Artefakt | Änderung | Umfang |
|---|---|---|
| `Process` (Knoten) | `lifecycleModule` + `lifecycleModuleBasis` | 55: A1=32, A1-A3=4, A3=13, B1=1, B4=1, C3=4 |
| `Process.processType` | `~` „End of Life" → „EndOfLife" (Casing) | 2 Knoten |
| `Assessment` (5 EF3.1) | `systemBoundary` → Vokabelwert `cradle-to-gate`, Freitext nach `systemBoundaryNote`; + `referenceFlow`, `referenceQuantity`, `referenceUnit` | 5 |
| `Assessment` (43 PCF) | `functionalUnit`, `systemBoundary`, `referenceFlow`, `referenceQuantity`, `referenceUnit` (Intentsdeklaration) | 43 |
| **`AssessmentApproach`** (Label) | **neu** — 41 Knoten (3+9+29), `{id,name,level,code}` | 41 |
| **`BROADER`** (Beziehungstyp) | **neu** — Methode→Gruppe→Paradigma | 38 |
| **`APPLIES_APPROACH`** (Beziehungstyp) | **neu** — Assessment→Verfahren | 48 (5→„Ökobilanzierung", 43→„Umweltfußabdruck CO2") |

**Live-DB:** 2 802 Knoten (+41) / 79 815 Beziehungen (+86).

### Nachweis: Methodenaustausch (White-box-Kern)

Gleiches Aluminium-A1-Inventar, `$methodId` als Parameter:

| `lca_generic($methodId)` | Ergebnis |
|---|---|
| `'IAM_EF31'` | 35 Zeilen (5 Gripper × 7 Kategorien), Klimawerte identisch zu den in v2 gespeicherten `ImpactResult.value` |
| `'IAM_PCF'` | 5 Zeilen (nur Klimawandel), Werte identisch — **null Schemaänderung** beim Methodenwechsel |

Beispiel V-groove jaws / Al6061: Klima 0,345 · Versauerung 1,86·10⁻³ · Eutroph. marin 3,69·10⁻⁴ · Landnutzung 0,307 · Photochem. Ozon 1,09·10⁻³ (Ozonabbau, Feinstaub ≈ 0).
*Landnutzung bleibt mit Vorsicht zu genießen (regionalisierte Faktoren gemittelt).*

### Betroffene Methoden (Änderungs-→-Methoden-Matrix)

| Änderung | benötigt von | genutzt von |
|---|---|---|
| `Process.lifecycleModule` | EPD/EN 15804, THG-Bilanz (Modulgliederung), MFA | konsequenzielle LCA (Stufenzuordnung), Digitaler Produktpass |
| `Assessment.functionalUnit` / `systemBoundary` | LCA, CF, alle bilanzierenden; EPD | Vergleichbarkeitsprüfung zwischen Assessments; Ökoeffizienz (Bezugsgröße) |
| `AssessmentApproach`-Taxonomie + `APPLIES_APPROACH` | **alle 29 Verfahren** (macht jedes explizit im Graphen adressierbar) | Reporting/Navigation, automatisierte Designempfehlung |
| `lca_generic($methodId)` | LCA, CF, H₂O, THG, CED (alle über Methoden-Filter) | Hotspot, Szenario-/Sensitivitätsanalyse (rechnen auf derselben Query) |

### Rollback

Kommentarblock am Ende von `migration_v3.cypher`. Additiv bis auf die
`processType`-Casing-Normalisierung (2 Knoten, teil-reversibel).
