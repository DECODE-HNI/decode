# v2 (grey box) — Änderungsprotokoll

## 2026-08-27 — Rechenkern verdrahtet (v2-minimal, Aluminium-A1-Pfad)

Migration: `migration_v2.cypher` · Basisquery: `lca_computed_ef31.cypher`

### Entscheidungen (schlankste umsetzbare Variante)

| # | Entscheidung | Begründung |
|---|---|---|
| 1 | Material→ILCD-Datensatz über neue additive Kante `(:Material)-[:MODELED_BY]->(:Process)` | eigene, klar benannte Kante statt `APPLIES_TO` zu überladen; Doku-tauglich |
| 2 | Massenmodell: `Part.mass_g` = Bounding-Box-Volumen × 0,5 Füllfaktor × Dichte | einzige durchgängig verfügbare Quelle (14 `Geometry`-Knoten mit L/B/H); als Schätzung markiert |
| 3 | Umfang: nur Aluminium-Kontaktteile von 5 Grippern; Rest `status:"data incomplete"` | nur `MAT_AL6061`/`MAT_AL7075` haben einen verteidigbaren ILCD-Proxy; Polymere/Elastomere haben keinen Datensatz |
| 4 | Systemgrenze A1 (cradle-to-gate Rohmaterial) | einzige Stufe mit charakterisierten ILCD-Daten; Manufacturing/Use/EoL-Flüsse sind Platzhalter |
| — | Regionalisierung: nicht-regionalisierter Faktor; wo nur regionalisierte existieren, deren Mittelwert | `CHARACTERIZES.location` ist bei 99 Fluss-Kategorie-Paaren 213-fach besetzt |

### Berührte / neue Artefakte

| Artefakt | Änderung | Umfang |
|---|---|---|
| `ImpactResult` (Knoten) | neue Properties `value`, `provenance`, `computedAt`, `datasetRef`, `coverage`, `status` | alle 78: 35 `status:"calculated"`, 43 `status:"data incomplete"` |
| `(:Material)-[:MODELED_BY]->(:Process)` | **neuer Beziehungstyp** | 2 Kanten (`MAT_AL6061`, `MAT_AL7075` → `PROC_ALU_EXTRUSION_EF`), `proxy=true`, `lifecycleModule='A1-A3'` |
| `Part` (Knoten) | `mass_g`, `massBasis` | 5 Aluminium-Kontaktteile (Schätzung). *Hinweis: `Part.mass_g` ist eigentlich v1-Produktdaten, hier im Zuge von v2 befüllt.* |
| `Assessment` (Knoten) | 5 neue: `ASSESS_EF31_<art>`, `USES_METHOD → IAM_EF31`, `systemBoundary`, `functionalUnit`, `characterizationLocationRule`, `status='partial'` | + `ASSESSES`, `USES_METHOD` |
| `ImpactResult` (Knoten) | 35 neue: `IR_EF31_<art>_<cat>` mit `value` | 5 Gripper × 7 abgedeckte EF3.1-Kategorien |

**Live-DB:** 2 761 Knoten (+40) / 79 729 Beziehungen (+82).

### Ergebnis (Klimawandel, EF3.1, A1 Aluminium-Kontaktteile)

| Gripper | GWP [kg CO₂-eq] | Al-Masse [kg] |
|---|---|---|
| Precision jaws / Al7075 / CNC | 0,078 | 0,0081 |
| Internal-expansion fingers / Al6061 | 0,172 | 0,0178 |
| Flat jaws / Al6061 / CNC | 0,188 | 0,0194 |
| V-groove jaws / Al6061 / CNC | 0,345 | 0,0356 |
| Long-reach fingers / Al6061 / CNC | 0,347 | 0,0359 |

Per-kg-Wert des Datensatzes: **9,67 kg CO₂-eq/kg** — Literaturbereich für Alu-Strangpressprofil A1–A3.
Abgedeckte EF3.1-Kategorien: Klimawandel, Versauerung, Eutrophierung marin, Landnutzung,
Ozonabbau, Feinstaub, Photochem. Ozon (7 von 22 — nur diese haben CF-Abdeckung im Datensatz).
Basisquery reproduziert alle gespeicherten Werte unabhängig.

### Betroffene Methoden (Änderungs-→-Methoden-Matrix)

| Änderung | benötigt von | genutzt von |
|---|---|---|
| `ImpactResult.value` (+ `provenance`, `status`) | **jede** quantitative Methode (LCA, CF, H₂O, THG, CED, Hotspot, Ökoeffizienz …) | alle Downstream-Analysen (Robustheit, Sensitivität, Designempfehlung) |
| `(:Material)-[:MODELED_BY]->(:Process)` | LCA/EF3.1, CF, CED, MFA (Materialbezug zum Inventar) | Zirkularität (Datensatz-Recyclatanteil), hybride LCA |
| `Part.mass_g` + `massBasis` | jede massenbasierte Rechnung (LCA A1, MFA, MCI) | Ökoeffizienz (Wert pro Masse) |
| `Assessment.systemBoundary` / `functionalUnit` | LCA, EPD, alle bilanzierenden | Vergleichbarkeitsprüfung zwischen Assessments |

### Offener Arbeitsstrang: `v2-data` (LCI-Vervollständigung)

Getrennt von der Schemamigration. Nötig für volle v2-Abdeckung:
- `MODELED_BY`-Proxys für die übrigen ~16 realen Materialien (PA12, PETG, POM, Silikon, TPU, Stahl …) — LCA-Modellentscheidung je Material
- Part-Massen für alle 86 Teile (nicht nur die 5 Aluminium-Teile)
- Manufacturing-LCI (A3): die 4 Template-Flüsse je Prozess mit echten Mengen + Faktoren, oder ILCD-Fertigungsdatensätze
- EF3.1-CF-Abdeckung für die fehlenden 15 Kategorien

### Rollback

Kommentarblock am Ende von `migration_v2.cypher`.
