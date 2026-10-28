# Neo4j-Modellexporte

| Datei | Inhalt | Stand |
|---|---|---|
| `neo4j_importer_model.json` | **Data-Importer-Schema** für den CSV-Erstimport des Kernmodells (v1/v2-Ebene: 27 Knoten-, 32 Beziehungstypen). `HAS_FLOW`/`CHARACTERIZES` laufen bewusst separat über einen Python/Bolt-Kanal (Data Importer unterstützt keine zusammengesetzten Relationship-Keys). **Nicht in diesem Repository** — die frühe Fassung (242 kB) ist durch die spätere Voll-Modell-Variante unter `lca_bulk_load/ned2_gripper_full_model_neo4j/neo4j_importer_model.json` abgelöst. | vor der v3-Erweiterung |
| `graph_schema_v3x.json` | **Vollständiges Ist-Schema** der Live-DB nach v1 → v2 → v3 → v3.x → v2-data → PRE-5 → ReCiPe → LCI-Hygiene → DQ-Konzept → Demonstrator → Konsistenzprüfung → KI-Entfernung. `apoc.meta.schema`-Export: **39 Knoten-Labels, 54 Beziehungstypen** mit Properties, Kardinalitäten, Indizes (93 Keys). Maschinenlesbar. | 2026-08-29 |

## Wie die Erweiterung reproduziert wird

Der Data Importer bildet nur den CSV-importierbaren Kern ab. Die gesamte
Erweiterung ist als versionierte `.cypher`-Migrationen definiert und wird
**in dieser Reihenfolge** auf das Kernmodell angewendet:

```
model_extension/migrations/
  v1_blackbox/migration_v1.cypher              + _fixes/fix_generic_materials.cypher
  v2_greybox/migration_v2.cypher
  v3_whitebox/migration_v3.cypher
  v3x_a_circularity/migration_v3a.cypher
  v3x_b_cost/migration_v3b.cypher
  v3x_c_scenario/migration_v3c.cypher
  v3x_d_provenance/migration_v3d.cypher
  v3x_repair.cypher                            (Korrektur MERGE-Pfad-Falle)
  v2_data/1_masses.cypher · 1b_masses_fix_cups.cypher · 2_manufacturing_energy.cypher
          · 3_material_gwp_literals.cypher · 4A_realonly.cypher | 4B_full_coverage.cypher
  v3_followup_pre5/migration_pre5.cypher
  v3x_e_recipe/migration_v3e.cypher            (+ cf_import/ für den vollen ReCiPe-CF-Import)
  v3x_nonlcia/migration_v3f.cypher … v3i.cypher
  v2_data/lci_hygiene/                         (CAS/Einheiten/Kompartiment-Bereinigung)
  dq_concept/01_… 02_… 03_compute_dq.cypher
  demonstrator/00_… … 04_scenario_coverage.cypher
  consistency/fix_F02_… fix_F03_… fix_F05_… fix_DE02_framework_nodes.cypher
  consistency/remove_ki_stubs.cypher           (KI-/ML-Zweig entfernt)
```

Jede Migration ist additiv, hat einen Verifikations-`RETURN` und einen
Rollback-Kommentarblock. Änderungsprotokolle: `model_extension/migrations/*/CHANGELOG.md`
bzw. `v3x_CHANGELOG.md`. Konsolidierte Referenz:
`model_extension/reference/EXTENSION_REFERENCE.md`.

## Neuen Voll-Dump erzeugen

`apoc.export.file.enabled=true` steht in `conf/apoc.conf` der DBMS-Instanz (wirkt
nach DBMS-Neustart). Dann z. B.:

```cypher
CALL apoc.export.cypher.all('file:.../snapshots/graph_full_2026-08-29.cypher',
  {format:'cypher-shell', useOptimizations:{type:'unwind_batch', unwindBatchSize:200}});
```

Der Voll-Dump liegt nur in der Arbeitskopie des Maintainers unter
`snapshots/graph_full_2026-08-29.{cypher,graphml}` (⚠️ nicht im Repository — enthält die
aus lizenzierten ILCD-Daten abgeleitete Inventardatenbasis).
