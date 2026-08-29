# Base queries per assessment method

Read-only Cypher queries that pull one result per method out of the graph.
All tested against the live DB (as of 2026-08-29). Set parameters with `:param`.

| File | Method (code) | Short | Status |
|---|---|---|---|
| `../../model_extension/migrations/v1_blackbox/repairability.cypher` | 2.3.1 | disassembly / repair index | computes (43) |
| `../../model_extension/migrations/v2_greybox/lca_computed_ef31.cypher` | 1.1.1 | EF3.1 A1, hardwired (v2 reference) | computes (5) |
| `../../model_extension/migrations/v3_whitebox/lca_generic.cypher` | 1.1.1 / 1.1.2 | **method-agnostic LCIA** (`$methodId`) | computes (EF31 19 cats, PCF, ReCiPe) |
| `../../model_extension/migrations/v2_data/lca_from_literals.cypher` | 1.1.1 | EF3.1 A1-A3 from literals, all 43 grippers (`$electricityCF`) | computes (Variant B) |
| `water_footprint.cypher` | 1.1.3 | H₂O footprint via `IC_EF_WATER_USE` | computes (subset; Al/steel have no AWARE factor — see v3.f) |
| `ghg_inventory.cypher` | 1.1.4 | GWP by EN 15804 module | computes |
| `ghg_by_scope.cypher` | 1.1.4 | GHG by GHG-Protocol scope 1/2/3 (v3.f); S2+S3up == Variant B | computes (43) |
| `mfa_balance.cypher` | 1.2.1 | mass balance per process (input/product/loss) | computes |
| `pollutant_inventory.cypher` | 1.2.2 | characterised emission flows + `hazardClass` + GHS `hCodes` (v3.f) | computes |
| `ced.cypher` | 1.2.3 | cumulative energy demand A1 + A3 (MJ) | computes |
| `../../model_extension/migrations/v3x_a_circularity/` (in the migration) | 1.2.4 | MCI per material/artifact | computes (5 + 23 material) |
| `../../model_extension/migrations/v3x_b_cost/mfca.cypher` | 1.3.1 | material cost product/loss path | computes (prototype) |
| `eco_efficiency.cypher` | 1.3.2 | impact ÷ system value (material cost) | computes (prototype) |
| `framework_coverage.cypher` | 1.3.3 | which `ExternalFramework` each method/approach maps to (v3.i + DE-02) | computes |
| `cross_impact.cypher` | 2.2.2 | influence / trade-off matrix `INFLUENCES` (v3.g); `$mode` lever\|tradeoff | computes |
| `scenario_compare.cypher` | 2.2.1 / 2.1.1 | indicator per gripper across `ModelScenario` (baseline vs SC_RECYCLED_ALU / SC_GRID_2035) | computes |
| `robustness.cypher` | 2.2.3 | spread of an indicator across data variants/scenarios | computes |
| `avoided_burden.cypher` | 2.1.3 | consequential module-D credit via `AVOIDS` / `SUBSTITUTES` | computes (demonstrator) |
| `dynamic_gwp.cypher` | 2.1.2 | GWP20 via `CHARACTERIZES_DYNAMIC` | computes (demonstrator) |
| `hybrid_eeio.cypher` | 2.1.4 | hybrid €-uplift via `EEIOSector` / `COVERED_BY_EEIO` | computes (demonstrator) |
| `../../model_extension/migrations/v3x_c_scenario/hotspot.cypher` | 2.3.3 | contribution ranking of the dataset flows | computes |
| `sensitivity_oat.cypher` | 2.3.2 | one-at-a-time sensitivity on the climate value (`$delta`) | computes |
| `impact_chain.cypher` | 2.3.1 | traceability chain (BASED_ON + LCI + Requirement) | computes |
| `dpp_view.cypher` | 3.2.1 | Digital Product Passport: every statement per gripper | computes |
| `kg_self_description.cypher` | 3.2.2 | the graph describing itself (labels, rel types, method coverage) | computes |
| `dq_radar.cypher` | — (DQ concept) | 8-axis radar vector + `DQPhase` gate per assessment (`$assessmentId`, `$phase`) | computes |

## Call example

```
:param methodId => 'IAM_RECIPE';
:param artifactId => 'ART_V_AL';
// then the content of v3_whitebox/lca_generic.cypher
```
