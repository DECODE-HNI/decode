// ============================================================================
// check_meta.cypher   --  consistency review, Layer 1 (meta / docs vs reality)
// ----------------------------------------------------------------------------
// Read-only census of the live DB. Diff the output against:
//   - EXTENSION_REFERENCE.md   (the "Live-DB" header counts, label/rel tables)
//   - neo4j_model_export/graph_schema_v3x.json   (regenerate + diff)
//   - change_method_matrix.csv / method_onepagers / base_queries/README.md
// Run:  CQ_FMT=verbose ./cq.sh check_meta.cypher
// ============================================================================

// M1 headline counts
MATCH (n) WITH count(n) AS nodes
MATCH ()-[r]->() WITH nodes, count(r) AS rels
CALL db.labels() YIELD label WITH nodes, rels, count(*) AS labels
CALL db.relationshipTypes() YIELD relationshipType WITH nodes, rels, labels, count(*) AS relTypes
CALL { SHOW CONSTRAINTS YIELD name RETURN count(*) AS constraints }
RETURN nodes, rels, labels, relTypes, constraints;

// M2 label census
MATCH (n) WITH labels(n)[0] AS label, count(*) AS n
RETURN label, n ORDER BY label;

// M3 relationship-type census
MATCH ()-[r]->() WITH type(r) AS relType, count(*) AS n
RETURN relType, n ORDER BY relType;

// M4 per method: categories, categories with >=1 CF, assessments, artifacts
MATCH (iam:ImpactAssessmentMethod)
OPTIONAL MATCH (iam)-[:HAS_CATEGORY]->(ic:ImpactCategory)
WITH iam, count(DISTINCT ic) AS categories,
     count(DISTINCT CASE WHEN EXISTS { (:Flow)-[:CHARACTERIZES]->(ic) } THEN ic END) AS categoriesWithCF
OPTIONAL MATCH (a:Assessment)-[:USES_METHOD]->(iam)
OPTIONAL MATCH (a)-[:ASSESSES]->(art:Artifact)
RETURN iam.id AS method, categories, categoriesWithCF,
       count(DISTINCT a) AS assessments, count(DISTINCT art) AS artifacts
ORDER BY method;

// M5 constraint list
SHOW CONSTRAINTS YIELD name, labelsOrTypes, properties
RETURN name, labelsOrTypes, properties ORDER BY name;

// M6 ImpactResult inventory by id prefix
MATCH (ir:ImpactResult)
WITH CASE
  WHEN ir.id STARTS WITH 'IR_EF31A_'            THEN 'IR_EF31A_*'
  WHEN ir.id STARTS WITH 'IR_EF31B_'            THEN 'IR_EF31B_*'
  WHEN ir.id STARTS WITH 'IR_EF31_SCEN_'        THEN 'IR_EF31_SCEN_*'
  WHEN ir.id STARTS WITH 'IR_EF31_'             THEN 'IR_EF31_*'
  WHEN ir.id STARTS WITH 'IR_RECIPE_'           THEN 'IR_RECIPE_*'
  WHEN ir.id STARTS WITH 'IR_MCI_'              THEN 'IR_MCI_*'
  WHEN ir.id STARTS WITH 'IR_REPAIR_'           THEN 'IR_REPAIR_*'
  WHEN ir.id STARTS WITH 'IR_GHG_'              THEN 'IR_GHG_*'
  ELSE 'other' END AS bucket, count(*) AS n
RETURN bucket, n ORDER BY bucket;

// M7 assessment inventory by id prefix + method
MATCH (a:Assessment)-[:USES_METHOD]->(iam:ImpactAssessmentMethod)
WITH split(a.id,'_ART')[0] + '_ART*' AS family, iam.id AS method, count(*) AS n
RETURN family, method, n ORDER BY family, method;

// M8 vocab domains actually in use (for the enum checks in check_model)
MATCH (:Process)-[hf:HAS_FLOW]->() WITH DISTINCT hf.dataMaturity AS v RETURN 'dataMaturity' AS field, collect(v) AS values;
MATCH (p:Process) WITH DISTINCT p.lifecycleModule AS v RETURN 'lifecycleModule' AS field, collect(v) AS values;
MATCH (p:Process) WITH DISTINCT p.processType AS v RETURN 'processType' AS field, collect(v) AS values;
