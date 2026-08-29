# ILCD package import (Variant A, v3 standard)

Pipeline that takes an **ILCD `_dependencies.zip`** downloaded from
PlasticsEurope / a soda4LCA node (one process dataset plus every referenced
flow, unit and source) and loads it additively into the gripper knowledge
graph, made computable through the EF3.1 `CHARACTERIZES` factors already in the
graph.

> **Status:** applied 2026-08-29. Four real PlasticsEurope datasets loaded
> (ABS, PC, POM, PA6.6). No licensed dataset content is committed here — only
> the pipeline; the generated `import_<MAT>.cypher` files are `.gitignore`d.
> Numbers verified against a running Neo4j 5 instance.

## Flow

```bash
# 1. unpack
unzip -q <uuid>_dependencies.zip -d pkg_dir

# 2. parse  ->  pkg_dir/_parsed/{meta,exchanges,flowdefs}.tsv
perl extract_package.pl pkg_dir

# 3. generate import Cypher
bash gen_import.sh pkg_dir <MATERIAL_ID> <true|false proxy> "<rationale>" <PROC_ID> \
   > import_<MATERIAL_ID>.cypher

# 4. apply (cypher-shell), then
#    harmonize_noncas.cypher  -> bridge non-CAS alias flows to EF3.1
#    refresh_variantA.cypher  -> rebuild ASSESS_EF31A_* / IR_EF31A_* over all grippers
```

`gen_import.sh` runs the non-CAS bridging itself as step 5b; the standalone
`harmonize_noncas.cypher` is for already-imported datasets (retrofit) and is
re-runnable.

## What the import does

| Step | Effect |
|---|---|
| 1 | `Process` node with **ILCD metadata** (`datasetUuid`, `dataSetVersion`, `referenceYear`, `geographicalLocation`, `dataSetOwner='PlasticsEurope'`, `lifecycleModule='A1-A3'`, `provenance='ILCD-package-import'`) |
| 2 | create missing `Flow` nodes (`name`, `casNumber`, `flowType`) — existing ones are reused by UUID |
| 3 | `HAS_FLOW {amount, direction, compartment, unit}` per exchange (reference product skipped); `compartment` parsed from the short description (`emission/air`, `resource/ground`, …) |
| 4 | **characterisation harmonisation:** for emission flows with a CAS but no `CHARACTERIZES`, factors are copied from a same-CAS, same-compartment flow that is already characterised (`biogenic ↔ biogenic` protected, land-use CO₂ excluded); `nc.derived=true` |
| 5 | **override** for unspecific fossil greenhouse gases: CO₂ (124-38-9) and CH₄ (74-82-8) → fossil variant |
| 5b | **non-CAS alias bridging** (name + compartment, fixed UUID pairs): `particles (PM2.5 - PM10)`→`particles (PM10)`, `volatile organic compound`→`non-methane VOC`; `Particulates/Dust (unspecified)`→`particles (PM10)` as `proxy`/`confidence:'low'`. `> PM10` and COD/BOD deliberately left out (EF3.1 CF is 0 / no EF3.1 category) |
| 6 | `(:Material)-[:MODELED_BY {proxy, proxyRationale, datasetUuid, dataVariant:'A-realdataset', lifecycleModule:'A1-A3'}]->(:Process)` |
| 7/8 | verification `RETURN`: GWP per kg + every EF3.1 category per kg |

## Why the harmonisation is needed

Older eco-profile packages (e.g. ABS EU-27 2010, PC EU-25 2007) name the
impact-driving emissions `carbon dioxide (Emissions to air, unspecified)` etc. —
the `CHARACTERIZES` factors in the graph hang off the canonical variant
`carbon dioxide (fossil)`. Steps 4/5 bridge that by CAS + compartment. Newer
re-exports (POM, PA 6.6, both 2010/2011 but freshly pulled) already use the
canonical names/UUIDs → steps 4/5 are then a no-op.

## Known limits

- **Non-CAS flows**: the impact-relevant cases (particulate fraction 2.5–10 µm,
  generic "VOC", unspecific particulates) have been bridged via step 5b since
  2026-08-29 (see `CHANGELOG.md`). Coarse particulates > 10 µm have an EF3.1 CF
  of 0; COD/BOD drive **no** EF3.1/ReCiPe category — both stay correctly
  unassessed. Remaining "unspecified" groups (GaBi) are marginal by mass.
- **EF3.1 chloride characterisation**: chloride discharges to fresh water carry
  a high CTUe (freshwater ecotoxicity) in EF3.1. That is method-inherent, not an
  import error, but it stands out on the polymer datasets.
- **System boundary**: Variant A computes **material cradle-to-gate (A1-A3 of
  the polymer/metal)**; the gripper's part shaping (CNC/FFF/MJF electricity) is
  **not** included — use Variant B for that.
