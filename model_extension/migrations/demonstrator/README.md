# Demonstrator slice — sustainability verification chain

> **Status:** applied & verified on the live DB, 2026-08-29.
> An 8-gripper slice carries the full chain **Requirement → TestCase →
> Assessment → ImpactResult → ImpactCategory**, plus EPD/DPP declarations with a
> status lifecycle. The other 35 grippers keep only the base LCA (`status:
> 'data incomplete'` for the demonstrator layer), consistent with the earlier
> 5-gripper demonstrator principle.

## The slice (one per material archetype)

| gripper | jaw material | data | role in the demo |
|---|---|---|---|
| `ART_V_AL` | Al 6061 | real dataset | published EPD/DPP reference; GWP just over the ceiling |
| `ART_FLAT_AL` | Al 6061 | real dataset | 2nd metal point |
| `ART_PREC_POM` | POM | real dataset | engineering thermoplastic |
| `ART_FLAT_ABS` | ABS | real dataset | commodity thermoplastic |
| `ART_PREC_PC` | PC | real dataset | engineering thermoplastic |
| `ART_LONG_CFPA` | CF-PA | **no jaw dataset** | composite; GWP `inconclusive`, MCI fails |
| `ART_FINRAY_TPU` | TPU | **no jaw dataset** | compliant structure; GWP `inconclusive`, MCI fails |
| `ART_MAGNET` | steel + NdFeB | real dataset | GWP `passed` since the consistency review (F-03) bridged the steel EF3.1 CFs |

## What each file adds

| file | adds |
|---|---|
| `00_mci_rollup.cypher` | `ASSESS_MCI` + `IR_MCI` for the 6 slice members that lacked one (v3.a made them only for the 5 aluminium grippers). Mass-weighted mean of `Material.mci`. |
| `01_sustainability_requirements.cypher` | 3 `Requirement`s — `REQ_SUS_GWP` (IC_CLIMATE ≤ 0.50 kg CO₂-eq), `REQ_SUS_MCI` (IC_CIRCULARITY ≥ 0.30), `REQ_SUS_REPAIR` (IC_REPAIRABILITY ≥ 0.70) — attached to the 8 via `SATISFIES_REQUIREMENT`. Field set mirrors the pre-existing `REQ_COMPAT`. |
| `02_verification_layer.cypher` | New label **`TestCase`** (RFLPV² spec §6 Neo4j target state, until now documented but not applied). 24 test cases = 8 grippers × 3 requirements, each with `VERIFIES → Requirement`, `HAS_ASSESSMENT → Assessment`, `TESTS → Artifact`, and cached `sustainabilityResult` / `sustainabilityStatus` ∈ {`passed`, `failed`, `inconclusive`, `notEvaluated`}. Writes the verdict back onto `SATISFIES_REQUIREMENT.verificationStatus`. |
| `03_declarations.cypher` | `Declaration` status lifecycle (`draft` → `verified` → `published` → `expired`, `verifiedBy`, `issuedAt`, `expiresAt`). EPD + DPP for the other 7 slice members (`verified` for real-data, `draft` for partial); `ART_V_AL` set to `published`. EPD `REPORTS` the EF3.1 Variant-A category results, DPP additionally MCI + repairability. |
| `04_scenario_coverage.cypher` | Extends `SC_GRID_2035` (prospective 2035 grid, 0.15 kg CO₂e/kWh) from the 5 aluminium grippers to the rest of the slice — identical formula to `v3x_nonlcia/migration_v3h`. Now 11 grippers covered. |

## Result (24 test cases, after consistency review)

| | passed | failed | inconclusive |
|---|--:|--:|--:|
| `REQ_SUS_GWP` | 5 | 1 (`ART_V_AL`, 0.51 > 0.50) | 2 (`ART_LONG_CFPA`, `ART_FINRAY_TPU` — no jaw dataset) |
| `REQ_SUS_MCI` | 6 | 2 (`ART_LONG_CFPA` 0.26, `ART_FINRAY_TPU` 0.24) | – |
| `REQ_SUS_REPAIR` | 8 | – | – |

**19 passed / 3 failed / 2 inconclusive.** The chain exercises all four RFLPV²
status values on a realistic material spread: passing metals, a metal that just
misses the GWP ceiling, two composites/elastomers that fail circularity, and two
cases where the data is not yet good enough to decide. (`TC_MAG_GWP` was
`inconclusive` until the consistency review's F-03 fix gave the steel dataset its
EF3.1 CFs.)

## Read it

- Full traceability for one gripper:
  `MATCH (r:Requirement)<-[:VERIFIES]-(tc:TestCase)-[:HAS_ASSESSMENT]->(a)-[:HAS_RESULT]->(ir)-[:FOR_CATEGORY]->(ic) WHERE (tc)-[:TESTS]->(:Artifact {id:$id}) RETURN ...`
- Declarations per gripper: `base_queries/dpp_view.cypher`

## Known limits

- **`ART_MAGNET` GWP** — resolved by the consistency review (F-03): the steel
  dataset's zero-padded-CAS flows now carry bridged EF3.1 CFs, so `TC_MAG_GWP`
  evaluates (`passed`, 0.15 ≤ 0.50).
- The pre-existing `DECL_EPD_ART_V_AL` reports 7 category results; the new EPDs
  report the full EF3.1 Variant-A set (~18). Not harmonised — cosmetic.
- Repairability is 1.0 for every gripper (v1 `disassemblyReversibility`), so
  `REQ_SUS_REPAIR` passes trivially for the whole slice.
- Thresholds (0.50 / 0.30 / 0.70) are demonstrator targets, not derived
  requirements.
