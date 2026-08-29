# v3.x — Nicht-LCIA-Methodenfamilie (Module f–i)

Stand: 2026-08-28. Ziel: die Verfahren aus dem Methodendiagramm, die **nicht** über
`lca_generic` rechnen, bekommen echtes Schema + eine getestete Basisquery, additiv
und non-breaking wie alle v3.x-Module. KI-Verfahren (Paradigma 3) werden nur
*vorbereitet* — Andockpunkte, keine ML-Logik im Graphen.

Parallel dazu (Nutzer): reale ILCD/EPD-Datensätze für die restlichen Werkstoffe.
Diese verändern die Zahlenbasis von v2-data, **nicht** die hier gebaute Struktur.

## Ausgangslage (Live-DB, 2026-08-28)

Rechnen bereits: 1.1.1 LCA, 1.1.2 CO₂-Fußabdruck, 1.2.4 Zirkularität, 2.3.1 Wirkkette
(+ Query-Ebene für 1.2.1 MFA, 1.2.3 CED, 1.3.1 MFCA, 1.3.2 Ökoeffizienz, 2.2.3
Robustheit, 2.3.2 Sensitivität, 2.3.3 Hotspot, 3.2.1 DPP, 3.3.3 Designempfehlung).

Offen (Schema fehlt / nur Skizze): **1.1.3** Wasser, **1.1.4** THG-Scopes,
**1.2.2** Schadstoff, **1.3.3** SEEA, **2.1.1–2.1.4** prospektiv/dynamisch/
konsequenziell/hybrid, **2.2.1** Szenario-Bewertung, **2.2.2** Cross-Impact,
**3.1.x / 3.2.2 / 3.3.1–2** KI (nur vorbereiten).

## Module

| Modul | Verfahren | Neues Schema | Basisqueries |
|---|---|---|---|
| **v3.f** Emissions- & Schadstoffbilanzierung | 1.1.4, 1.2.2, 1.1.3 | `Process.ghgScope`, `Flow.ghgSpecies`, `Flow.hazardClass`, `HazardStatement` (+`HAS_HAZARD`), `IAM_GHG` (nutzt `IC_CLIMATE`), Demonstrator-Assessments GHG/H₂O/Schadstoff | `ghg_by_scope.cypher`, `pollutant_inventory.cypher` (Update), `water_footprint.cypher` (Update) |
| **v3.g** Cross-Impact & Szenario-Bewertung | 2.2.2, 2.2.1 | `INFLUENCES {sign,strength,mechanism,evidenceLevel}` (Lever→Kategorie, Kategorie→Kategorie), `SC_RECYCLED_ALU`-Ergebnisse, Demonstrator-Assessments | `cross_impact.cypher`, `scenario_compare.cypher` |
| **v3.h** Prospektive / dynamische / konsequenzielle / hybride Ökobilanz | 2.1.1–2.1.4 | `Process.marketType/timeValidFrom/Until`, `SC_GRID_2035`, `SUBSTITUTES` (Process→Process), `AVOIDS` (EndOfLifeRoute→Process), `CHARACTERIZES_DYNAMIC {timeHorizon,factor,metric}`, `EEIOSector` (+`COVERED_BY_EEIO`) | `dynamic_gwp.cypher`, `avoided_burden.cypher`, `prospective_grid.cypher`, `hybrid_eeio.cypher` |
| **v3.i** Externe Rahmenwerke + selbstbeschreibender KG + KI-Andockpunkte | 1.3.3, 3.2.2, 3.1.x, 3.3.1–2 | `ExternalFramework` (+`MAPS_TO`), `PredictionModel` (+`PREDICTS`, `ESTIMATED_BY`), `Recommendation` — alle `status:'prepared'` / `provenance:'illustrative'` | `framework_coverage.cypher`, `kg_self_description.cypher` |

## Kaskaden auf andere Ebenen

- **Importer-Modell**: keine CSV-Änderung; alle Ergänzungen sind Migrations-Cypher.
- **`graph_schema_v3x.json`**: nach jedem Modul neu exportieren.
- **`change_method_matrix.csv`**: je atomare Änderung eine Zeile, betroffene Methoden beidseitig.
- **Method-One-Pager**: die ~14 berührten Verfahren aktualisieren.
- **Demonstrator-Artefakte**: verschieben sich — erst nach v3.i einfrieren.

## Regeln (unverändert)

Strikt additiv · je Modul Verifikations-`RETURN` + Rollback-Block · je Modul
CHANGELOG mit berührten Artefakten + Änderungs→Methoden-Matrix · kleinste
lauffähige Scheibe (5 v2-Greifer als Demonstrator, Rest „data incomplete").

## Status

| Modul | Stand |
|---|---|
| **v3.f** | ✅ angewendet + verifiziert (2026-08-28). `IAM_GHG`, `Process.ghgScope`, `Flow.ghgSpecies`, `HazardStatement`+`HAS_HAZARD`+`Flow.hazardClass`, `ASSESS_GHG/H2O/POLLUTANT_*`. Queries `ghg_by_scope.cypher`, `pollutant_inventory.cypher` (erweitert). 1.1.3 Wasser: Struktur, Zahl blockiert (Datenlücke). |
| **v3.g** | ✅ angewendet + verifiziert (2026-08-28). `INFLUENCES`-Matrix (60), `ASSESS_CROSSIMPACT_*`, `ASSESS_EF31_SCEN_RECALU_*` unter `SC_RECYCLED_ALU`. Queries `cross_impact.cypher`, `scenario_compare.cypher`. |
| **v3.h** | offen — schema-schwerstes Modul (marginale Prozesse, `SUBSTITUTES`/`AVOIDS`, `CHARACTERIZES_DYNAMIC` GWP20, `EEIOSector`). Vor Bau Rücksprache wg. Modellannahmen. |
| **v3.i** | offen — `ExternalFramework`+`MAPS_TO`, KI-Andockpunkte (`status:'prepared'`). Klein. |

Live-DB nach v3.g: 3 707 Knoten / 82 415 Beziehungen / 37 Constraints · 0 label-los ·
0 Duplikate · 6 Methoden · 9 / 29 Verfahren mit Assessments.
