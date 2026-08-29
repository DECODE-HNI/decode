# v3.x — Nicht-LCIA-Methodenfamilie · Änderungsprotokoll

Ziel: die Verfahren des Methodendiagramms, die **nicht** über `lca_generic`
rechnen, bekommen echtes Schema + getestete Basisquery. Additiv, non-breaking.
KI-Verfahren (Paradigma 3) nur *vorbereiten*. Struktur: siehe `PLAN.md`.

Parallel (Nutzer): reale ILCD/EPD-Datensätze für die restlichen Werkstoffe —
verändern die Zahlenbasis von v2-data, nicht die hier gebaute Struktur.

---

## v3.f — Emissions- & Schadstoffbilanzierung · `migration_v3f.cypher`

Verfahren: **1.1.4** THG-Bilanzierung nach Scope · **1.2.2** Schadstoffbilanzierung ·
**1.1.3** Wasser-Fußabdruck (Struktur).
Basisqueries: `base_queries/ghg_by_scope.cypher` (neu), `base_queries/pollutant_inventory.cypher` (erweitert).

### Berührte Artefakte

| Artefakt | Änderung |
|---|---|
| `Process` (alle 55) | +`ghgScope` ('1'/'2'/'3'), +`ghgScopeCategory` (GHG-Protocol-Kategorie-Text), +`ghgScopeBasis`. Regel: RawMaterialProduction/Use/EndOfLife/Service → Scope 3; Manufacturing/Postprocess → Scope 2 (Strom, Auftragsfertigung); Assembly → Scope 1 (≈0, keine standorteigene fossile Verbrennung modelliert). Verteilung 1 / 13 / 41. |
| `Flow` (38 klima-charakterisierte) | +`ghgSpecies` (CO₂, CH₄, N₂O, SF₆, NF₃, HFC/HCFC, PFC, other halocarbon) |
| `ImpactAssessmentMethod` `IAM_GHG` (neu) | `methodStandard='GHG Protocol Corporate Standard + Scope 3 Standard'`; `HAS_CATEGORY → IC_CLIMATE` (**wiederverwendet**, kein neuer Kategorieknoten); `APPLIES_APPROACH → APM_GHG` |
| `Assessment` `ASSESS_GHG_<art>` (5) | Aluminium-Demonstratorgreifer; `dataVariant='B-literal'`; `APPLIES_APPROACH → APM_GHG` |
| `ImpactResult` `IR_GHG_<art>_{S1,S2,S3UP}` (15) | S1 = 0 (`status='data incomplete'`), S2 = Werkstoff-unabh. Strom (mass·energyIntensity·0,38), S3UP = Werkstoff-A1-Literale. **S2 + S3UP == Variante-B-Klimazahl** (Delta 0,0 für alle 5 verifiziert) |
| `HazardStatement` (neues Label, 12) | GHS/CLP-H-Sätze: H314, H317, H330, H334, H340, H350, H351, H360, H372, H400, H410, H411 |
| `Flow.hazardClass` + `(:Flow)-[:HAS_HAZARD {basis}]->(:HazardStatement)` | Klassen: heavy-metal (106), CMR (22), acidifying-precursor (22), VOC (20); Klassen-basierte Screening-Zuordnung |
| `Assessment` `ASSESS_POLLUTANT_ART_V_AL` (1) | Register-Typ, kein `ImpactResult`; `APPLIES_APPROACH → APM_POLLUTANT` |
| `ImpactCategory` `IC_EF_WATER_USE` | +`referenceUnit='m3 world eq'` |
| `Assessment` `ASSESS_H2O_<art>` (5) + `ImpactResult` `IR_H2O_<art>` (5) | **Hüllen**, `status='data incomplete'`, `value=NULL`. Diagnose: Al-/Stahl-Datensätze haben keinen AWARE-Wasserfaktor; PA66-Proxy-Faktor (~165 m³/kg) unplausibel → echte Wasser-Inventardaten offen. `APPLIES_APPROACH → APM_CF_H2O` |

### Änderung → betroffene Methoden

| Änderung | direkt genutzt von | wirkt außerdem auf |
|---|---|---|
| `Process.ghgScope` | 1.1.4 THG-Bilanzierung | 1.1.1 LCA (Scope-Aufriss als Zusatzsicht), 3.2.1 DPP (Scope-Reporting), 2.1.3 konsequenzielle LCA (Scope-3-Fokus) |
| `Flow.ghgSpecies` | 1.1.4, 1.1.2 CO₂-Fußabdruck | 2.1.2 dynamische LCA (Gas-spezifische GWP20), 2.3.3 Hotspot (Gas-Beitrag) |
| `IAM_GHG` (nutzt `IC_CLIMATE`) | 1.1.4 | 1.1.2 (identische Zahl, andere Gliederung), 2.2.3 Robustheit (weitere Ergebnisreihe) |
| `HazardStatement` + `HAS_HAZARD` + `Flow.hazardClass` | 1.2.2 Schadstoffbilanzierung | 1.2.1 MFA (Verlustströme mit Gefahrenbezug), 3.2.1 DPP (Stoffdeklaration REACH/ESPR), 1.1.1 LCA (Human-/Ökotox-Interpretation) |
| `IC_EF_WATER_USE.referenceUnit` | 1.1.3 Wasser-Fußabdruck | 1.1.1 LCA (Kategorie-Reporting) |

### Rollback

Kommentarblock am Dateiende von `migration_v3f.cypher` (löscht `ASSESS_GHG_*`,
`ASSESS_H2O_*`, `ASSESS_POLLUTANT_*`, `IAM_GHG`, `HAS_HAZARD`, `HazardStatement`;
entfernt `Process.ghgScope*`, `Flow.ghgSpecies`, `Flow.hazardClass`).

---

## v3.g — Cross-Impact & Szenario-Bewertung · `migration_v3g.cypher`

Verfahren: **2.2.2** Cross-Impact-Wirkungsanalyse · **2.2.1** Szenario-gestützte Umweltbewertung.
Basisqueries: `base_queries/cross_impact.cypher` (neu), `base_queries/scenario_compare.cypher` (neu).

### Berührte Artefakte

| Artefakt | Änderung |
|---|---|
| `(:Feature\|:CoreProperty\|:Material)-[:INFLUENCES {sign,strength,mechanism,evidenceLevel,source,module}]->(:ImpactCategory)` (neuer Beziehungstyp) | **60 Kanten**, 30 `+` / 30 `-`. `sign '+'` = verbessert Zielkategorie, `'-'` = verschlechtert; `strength` 1..3. 14 Hebel→Kategorie (Feature/CoreProperty), 42 Werkstoff→Kategorie (nach `materialType` ausgefächert), 4 Kategorie→Kategorie (Trade-offs). Alle `evidenceLevel='engineering-reasoned'`/`'LCA-textbook'`. |
| `Assessment` `ASSESS_CROSSIMPACT_ART_V_AL` (1) | Cross-Impact-Demonstrator, kein `ImpactResult` (qualitativ); `APPLIES_APPROACH → APM_CROSS_IMPACT` |
| `Assessment` `ASSESS_EF31_SCEN_RECALU_<art>` (5) | `assessmentType='scenario assessment'`, `scenarioRef='SC_RECYCLED_ALU'`, `dataVariant='B-literal'`; `APPLIES_APPROACH → APM_SCENARIO_ASSESSMENT`; `UNDER_SCENARIO → SC_RECYCLED_ALU` |
| `ImpactResult` `IR_EF31_SCEN_RECALU_<art>_IC_CLIMATE` (5) | Klima mit recyclat-angepasstem Al-A1-Faktor (rc = 0,75 → 2,83 kg CO₂e/kg statt 9,67). Ersparnis 12–27 % ggü. Baseline (V_AL: 1,009 → 0,741). |
| `ModelScenario` `SC_RECYCLED_ALU` | erhält damit erstmals berechnete Ergebnisse (vorher nur Parameter-Setzung aus v3.c) |

### Änderung → betroffene Methoden

| Änderung | direkt genutzt von | wirkt außerdem auf |
|---|---|---|
| `INFLUENCES`-Matrix | 2.2.2 Cross-Impact | 3.3.3 Designempfehlung (Hebel→Wirkung als Regelbasis), 2.3.1 Wirkkette (qualitative Ebene über der LCI-Kette), 1.2.4 Zirkularität + 2.3.1 Reparierbarkeit (deren Zielgrößen sind Knoten der Matrix) |
| `ASSESS_EF31_SCEN_RECALU_*` + `IR_*` unter `SC_RECYCLED_ALU` | 2.2.1 Szenario-Bewertung | 2.2.3 Robustheit (Streuung Baseline↔Szenario), 2.1.1 prospektive LCA (Szenario-Mechanik wiederverwendet), 1.1.1/1.1.4 (zweite Klimazahl je Greifer) |
| `scenario_compare.cypher` | 2.2.1 | 2.2.3, 3.2.1 DPP (Szenario-Sicht) |

### Rollback

Kommentarblock am Dateiende von `migration_v3g.cypher` (löscht alle
`INFLUENCES {module:'v3.g'}`, `ASSESS_CROSSIMPACT_*`, `ASSESS_EF31_SCEN_RECALU_*` + Ergebnisse).
