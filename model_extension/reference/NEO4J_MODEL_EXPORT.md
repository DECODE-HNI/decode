# Neo4j model exports

| File | Content | As of |
|---|---|---|
| `neo4j_importer_model.json` | **Data Importer schema** for the initial CSV import of the core model (v1/v2 level: 27 node types, 32 relationship types). `HAS_FLOW`/`CHARACTERIZES` deliberately run separately through a Python/Bolt channel (the Data Importer does not support composite relationship keys). **Not in this repository** — the early version (242 kB) is superseded by the later full-model variant under `lca_bulk_load/ned2_gripper_full_model_neo4j/neo4j_importer_model.json`. | before the v3 extension |
| `graph_schema_v3x.json` | **Complete as-built schema** of the live DB after v1 → v2 → v3 → v3.x → v2-data → PRE-5 → ReCiPe → LCI hygiene → DQ concept → demonstrator → consistency review → AI removal. `apoc.meta.schema` export: **39 node labels, 54 relationship types** with properties, cardinalities, indexes (93 keys). Machine-readable. | 2026-08-29 |

## How the extension is reproduced

The Data Importer only covers the CSV-importable core. The entire extension is
defined as versioned `.cypher` migrations and is applied to the core model **in
this order**:

```
model_extension/migrations/
  v1_blackbox/migration_v1.cypher              + _fixes/fix_generic_materials.cypher
  v2_greybox/migration_v2.cypher
  v3_whitebox/migration_v3.cypher
  v3x_a_circularity/migration_v3a.cypher
  v3x_b_cost/migration_v3b.cypher
  v3x_c_scenario/migration_v3c.cypher
  v3x_d_provenance/migration_v3d.cypher
  v3x_repair.cypher                            (fix for the MERGE path trap)
  v2_data/1_masses.cypher · 1b_masses_fix_cups.cypher · 2_manufacturing_energy.cypher
          · 3_material_gwp_literals.cypher · 4A_realonly.cypher | 4B_full_coverage.cypher
  v3_followup_pre5/migration_pre5.cypher
  v3x_e_recipe/migration_v3e.cypher            (+ cf_import/ for the full ReCiPe CF import)
  v3x_nonlcia/migration_v3f.cypher … v3i.cypher
  v2_data/lci_hygiene/                         (CAS/unit/compartment clean-up)
  dq_concept/01_… 02_… 03_compute_dq.cypher
  demonstrator/00_… … 04_scenario_coverage.cypher
  consistency/fix_F02_… fix_F03_… fix_F05_… fix_DE02_framework_nodes.cypher
  consistency/remove_ki_stubs.cypher           (AI/ML branch removed)
```

Every migration is additive, has a verification `RETURN` and a rollback comment
block. Change logs: `model_extension/migrations/*/CHANGELOG.md` or
`v3x_CHANGELOG.md`. Consolidated reference:
`model_extension/reference/EXTENSION_REFERENCE.md`.

## Creating a new full dump

`apoc.export.file.enabled=true` is set in `conf/apoc.conf` of the DBMS instance
(takes effect after a DBMS restart). Then, for example:

```cypher
CALL apoc.export.cypher.all('file:.../snapshots/graph_full_2026-08-29.cypher',
  {format:'cypher-shell', useOptimizations:{type:'unwind_batch', unwindBatchSize:200}});
```

The full dump exists only in the maintainer's working copy under
`snapshots/graph_full_2026-08-29.{cypher,graphml}` (⚠️ not in the repository — it
contains the inventory data base derived from licensed ILCD data).
