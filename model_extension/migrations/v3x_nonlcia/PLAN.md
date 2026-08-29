# v3.x — non-LCIA method family (modules f–i)

As of 2026-08-28. Goal: the methods from the method diagram that do **not**
compute via `lca_generic` get a real schema + a tested base query, additive and
non-breaking like every v3.x module.

> **Addendum 2026-08-29:** the "learning approaches" paradigm (KI/ML) was carried
> here only as docking points and has been removed entirely from graph and docs
> — out of the case-study scope. `../consistency/remove_ki_stubs.cypher`.
> Mentions of 3.1.x / 3.3.1–3 below are historical.

In parallel (user): real ILCD/EPD datasets for the remaining materials. Those
change the number base of v2-data, **not** the structure built here.

## Starting point (live DB, 2026-08-28)

Already computing: 1.1.1 LCA, 1.1.2 carbon footprint, 1.2.4 circularity, 2.3.1
impact chain (+ a query layer for 1.2.1 MFA, 1.2.3 CED, 1.3.1 MFCA, 1.3.2
eco-efficiency, 2.2.3 robustness, 2.3.2 sensitivity, 2.3.3 hotspot, 3.2.1 DPP).

Open (schema missing / only a sketch): **1.1.3** water, **1.1.4** GHG scopes,
**1.2.2** pollutant, **1.3.3** SEEA, **2.1.1–2.1.4** prospective/dynamic/
consequential/hybrid, **2.2.1** scenario assessment, **2.2.2** cross-impact,
**3.1.x / 3.2.2 / 3.3.1–2** KI (prepare only — since removed).

## Modules

| Module | Methods | New schema | Base queries |
|---|---|---|---|
| **v3.f** emissions & pollutant accounting | 1.1.4, 1.2.2, 1.1.3 | `Process.ghgScope`, `Flow.ghgSpecies`, `Flow.hazardClass`, `HazardStatement` (+`HAS_HAZARD`), `IAM_GHG` (uses `IC_CLIMATE`), demonstrator assessments GHG/H₂O/pollutant | `ghg_by_scope.cypher`, `pollutant_inventory.cypher` (update), `water_footprint.cypher` (update) |
| **v3.g** cross-impact & scenario assessment | 2.2.2, 2.2.1 | `INFLUENCES {sign,strength,mechanism,evidenceLevel}` (lever→category, category→category), `SC_RECYCLED_ALU` results, demonstrator assessments | `cross_impact.cypher`, `scenario_compare.cypher` |
| **v3.h** prospective / dynamic / consequential / hybrid LCA | 2.1.1–2.1.4 | `Process.marketType/timeValidFrom/Until`, `SC_GRID_2035`, `SUBSTITUTES` (Process→Process), `AVOIDS` (EndOfLifeRoute→Process), `CHARACTERIZES_DYNAMIC {timeHorizon,factor,metric}`, `EEIOSector` (+`COVERED_BY_EEIO`) | `dynamic_gwp.cypher`, `avoided_burden.cypher`, `scenario_compare.cypher` (prospective), `hybrid_eeio.cypher` |
| **v3.i** external frameworks + self-describing KG | 1.3.3, 3.2.2 | `ExternalFramework` (+`MAPS_TO`). _(The KI docking points `PredictionModel`/`Recommendation`/`PREDICTS`/`ESTIMATED_BY`/`RECOMMENDS_FOR` originally included here were removed on 2026-08-29.)_ | `framework_coverage.cypher`, `kg_self_description.cypher` |

## Cascades to other layers

- **Importer model**: no CSV change; all additions are migration Cypher.
- **`graph_schema_v3x.json`**: re-export after each module.
- **`change_method_matrix.csv`**: one row per atomic change, affected methods
  both ways.
- **Method one-pagers**: update the ~14 touched methods.
- **Demonstrator artifacts**: shift — freeze only after v3.i.

## Rules (unchanged)

Strictly additive · verification `RETURN` + rollback block per module · a
CHANGELOG per module with touched artifacts + a change-→-method matrix ·
smallest runnable slice (5 v2 grippers as the demonstrator, rest "data
incomplete").

## Status

| Module | State |
|---|---|
| **v3.f** | ✅ applied + verified (2026-08-28). `IAM_GHG`, `Process.ghgScope`, `Flow.ghgSpecies`, `HazardStatement`+`HAS_HAZARD`+`Flow.hazardClass`, `ASSESS_GHG/H2O/POLLUTANT_*`. Queries `ghg_by_scope.cypher`, `pollutant_inventory.cypher` (extended). 1.1.3 water: structure, number blocked (data gap). |
| **v3.g** | ✅ applied + verified (2026-08-28). `INFLUENCES` matrix (60), `ASSESS_CROSSIMPACT_*`, `ASSESS_EF31_SCEN_RECALU_*` under `SC_RECYCLED_ALU`. Queries `cross_impact.cypher`, `scenario_compare.cypher`. |
| **v3.h** | ✅ applied + verified (2026-08-29), *light* stage: per method a schema hook + 1 worked example. `SC_GRID_2035` (prospective), `CHARACTERIZES_DYNAMIC` GWP20 (dynamic), `AVOIDS`/`SUBSTITUTES`/`marketType` (consequential, module D), `EEIOSector`+`COVERED_BY_EEIO` (hybrid). Queries `dynamic_gwp`, `avoided_burden`, `hybrid_eeio`. |
| **v3.i** | ✅ applied + verified (2026-08-29). `ExternalFramework` (now 12) + `MAPS_TO`; `ASSESS_SEEA`/`ASSESS_ENVKG`. Queries `framework_coverage`, `kg_self_description`. _The KI docking points originally shipped with it (`PredictionModel`/`Recommendation`/`ASSESS_AI_PREPARED` + the 5 taxonomy nodes) were removed on 2026-08-29 — `../consistency/remove_ki_stubs.cypher`._ |

**The module set is thereby complete.** The inventory, data- and
scenario-based methods of the method diagram are addressable; the KI/ML paradigm
is not part of the case study, per the user's decision.

Final live-DB state (2026-08-29, after v3.i + ILCD imports + non-CAS
harmonisation + ReCiPe CF import + LCI hygiene + cleanup + DQ concept +
demonstrator slice + consistency review Layers 1–4 + KI removal + snapshot):
**5 620 nodes / 86 635 relationships / 39 labels / 54 relationship types / 39
constraints** · 0 label-less · 0 valueless results · 6 `ImpactAssessmentMethod`
(EF3.1 19 cats, ReCiPe 2016 H 16 cats, PCF/GHG/MCI/Repair 1 each).
(Interim state before the KI removal: 5 718 / 86 202 / 41 / 57 / 39.)
Consolidated reference: [`../../reference/EXTENSION_REFERENCE.md`](../../reference/EXTENSION_REFERENCE.md).

Assessment core edges: every assessment carries `ASSESSES` + `APPLIES_APPROACH` +
`UNDER_SCENARIO`; `USES_METHOD` is carried only by those that persist an
`ImpactResult` (the result-free method markers `CONSEQ`/`CROSSIMPACT`/
`DYNLCA`/`HYBRID`/`POLLUTANT`/`SEEA`/`ENVKG` are methodless by design;
`AI_PREPARED` fell away with the KI removal). Corrected 2026-08-29 — see
`../consistency/FINDINGS.md` F-02.

## Still open (not part of the module set)

- ~~Non-CAS flow harmonisation (particulate matter / NMVOC / COD) for the
  imported datasets.~~ → done 2026-08-29 (`ilcd_import/harmonize_noncas.cypher` +
  a precision fix in `refresh_variantA.cypher`; COD/BOD deliberately unassessed,
  no EF3.1/ReCiPe category). See `ilcd_import/CHANGELOG.md`.
- ~~ReCiPe factors for the 17 non-climate categories.~~ → done 2026-08-29 (full
  CF import from the free openLCA LCIA pack, `v3x_e_recipe/cf_import/`;
  16/18 categories compute, 43 `ASSESS_RECIPE_A_*`; fossil resources + land use
  stay structural due to a unit/data gap).
- LCI hygiene: first pass done 2026-08-29 (`v2_data/lci_hygiene/`, casNumber
  cleanup, unit split, compartment backfill, fragment quarantine). Open:
  EF3.1 fossil-resource CF review (`uranium` as fossil, ABS/PC fossil amounts as
  MJ labelled kg); `IC_EF_..._MINERALS` negative value; ~18 900 non-backfillable
  blank compartments.
- ~~Data quality: align the concept with the user's published models (0–4
  pedigree scale, inherent/system, phase target values); compute DQ from edge
  metadata as far as possible.~~ → done 2026-08-29 (`dq_concept/`): 8 criteria
  inherent/system + 0..4, `DQPhase` gates (screening/design/declaration,
  min-based, no aggregation), auto-DQ from `referenceYear`/
  `geographicalLocation`/`MODELED_BY`/CF provenance on 6 LCI datasets, roll-up
  as MIN over 155 assessments; read query `../../../methods/base_queries/dq_radar.cypher`.
  Open: tune the target matrix + temporal bands against the published phase
  values; `DQC_ACC`/`DQC_UNC` manual.
- ~~Demonstrator artifacts (further EPD/DPP instances, RFLPV² linkage).~~
  → done 2026-08-29 (`demonstrator/`): 8-gripper slice with sustainability
  `Requirement`s (`REQ_SUS_GWP`/`MCI`/`REPAIR`), new node type `TestCase`
  (RFLPV² spec §6 Neo4j target state applied) + chain
  `Requirement → TestCase → Assessment → ImpactResult`, EPD/DPP status
  lifecycle, `SC_GRID_2035` on 11 grippers. 24 test cases: 19 passed / 3 failed
  / 2 inconclusive.
- ~~Freeze + full snapshots per stage (`apoc.export.file.enabled`).~~ → done
  2026-08-29 (`../../../snapshots/`, big dumps not committed).
- ~~English translation + Git batch (PR #1).~~ → in progress.
