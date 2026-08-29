# Basisqueries je Bewertungsmethode

Read-only Cypher-Queries, die je Verfahren ein Ergebnis aus dem Graphen ziehen.
Alle gegen die Live-DB (Stand 2026-08-27) getestet. Parameter über `:param` setzen.

| Datei | Verfahren (Code) | Kurz | Status |
|---|---|---|---|
| `../model_versions/v1_blackbox/repairability.cypher` | 2.3.1 | Demontage-/Reparaturindex | rechnet (43) |
| `../model_versions/v2_greybox/lca_computed_ef31.cypher` | 1.1.1 | EF3.1 A1, fest verdrahtet (v2-Beleg) | rechnet (5) |
| `../model_versions/v3_whitebox/lca_generic.cypher` | 1.1.1 / 1.1.2 | **methodenagnostische LCIA** (`$methodId`) | rechnet (EF31 19 Kat., PCF, ReCiPe) |
| `../model_versions/v2_data/lca_from_literals.cypher` | 1.1.1 | EF3.1 A1-A3 aus Literalen, alle 43 Gripper (`$electricityCF`) | rechnet (Variante B) |
| `water_footprint.cypher` | 1.1.3 | H₂O-Fußabdruck über `IC_EF_WATER_USE` | rechnet (Teilmenge; Al/Stahl ohne AWARE-Faktor — s. v3.f) |
| `ghg_inventory.cypher` | 1.1.4 | GWP nach EN-15804-Modul | rechnet |
| `ghg_by_scope.cypher` | 1.1.4 | THG nach GHG-Protocol-Scope 1/2/3 (v3.f); S2+S3up == Variante B | rechnet (43) |
| `mfa_balance.cypher` | 1.2.1 | Massenbilanz je Prozess (Input/Produkt/Verlust) | rechnet |
| `pollutant_inventory.cypher` | 1.2.2 | charakt. Emissionsflüsse + `hazardClass` + GHS-`hCodes` (v3.f) | rechnet |
| `ced.cypher` | 1.2.3 | kumulierter Energieverbrauch A1 + A3 (MJ) | rechnet |
| `../model_versions/v3x_a_circularity/` (in Migration) | 1.2.4 | MCI je Material/Artefakt | rechnet (5 + 23 Material) |
| `../model_versions/v3x_b_cost/mfca.cypher` | 1.3.1 | Materialkosten Produkt-/Verlustpfad | rechnet (Prototyp) |
| `eco_efficiency.cypher` | 1.3.2 | Wirkung ÷ Systemwert (Materialkosten) | rechnet (Prototyp) |
| `cross_impact.cypher` | 2.2.2 | Wirk-/Trade-off-Matrix `INFLUENCES` (v3.g); `$mode` lever\|tradeoff | rechnet |
| `scenario_compare.cypher` | 2.2.1 | Indikator je Greifer über `ModelScenario` (Baseline vs. SC_RECYCLED_ALU) | rechnet |
| `robustness.cypher` | 2.2.3 | Streuung eines Indikators über Datenvarianten/Szenarien | rechnet |
| `../model_versions/v3x_c_scenario/hotspot.cypher` | 2.3.3 | Beitrags-Ranking der Datensatzflüsse | rechnet |
| `sensitivity_oat.cypher` | 2.3.2 | One-at-a-time-Sensitivität auf den Klimawert (`$delta`) | rechnet |
| `impact_chain.cypher` | 2.3.1 | Nachvollziehbarkeitskette (BASED_ON + LCI + Requirement) | rechnet |
| `dpp_view.cypher` | 3.2.1 | Digitaler Produktpass: alle Aussagen je Greifer | rechnet |
| `design_recommendation.cypher` | 3.3.3 | Varianten-Ranking gegen Requirement-Schwelle (`$resultType`, `$dataVariant`) | rechnet |

## Noch als Skizze / kein eigenes File

- **2.1.x prospektive/dynamische/konsequenzielle/hybride LCA** — Modul **v3.h** geplant
  (`SUBSTITUTES`, `AVOIDS`, `CHARACTERIZES_DYNAMIC`, `EEIOSector`); siehe
  `../model_versions/v3x_nonlcia/PLAN.md` und `method_onepagers/2.1.*`.
- **1.3.3 SEEA / 3.2.2 Umwelt-KG / 3.1.x KI** — Modul **v3.i** geplant
  (`ExternalFramework` + `MAPS_TO`; `PredictionModel`/`Recommendation` nur `status:'prepared'`).

## Bereits umgesetzt (Module v3.f / v3.g, 2026-08-28)

- **1.1.4** `ghg_by_scope.cypher` · **1.2.2** `pollutant_inventory.cypher` (jetzt mit `hazardClass`+`hCodes`)
- **2.2.2** `cross_impact.cypher` · **2.2.1** `scenario_compare.cypher`

## Aufruf-Beispiel

```
:param methodId => 'IAM_RECIPE';
:param artifactId => 'ART_V_AL';
// dann Inhalt von v3_whitebox/lca_generic.cypher
```
