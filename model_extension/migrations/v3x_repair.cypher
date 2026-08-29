// ============================================================================
// v3x_repair.cypher  --  Fixes two defects from the v3.a/v3.c/v3.d migrations:
//   (1) MERGE-path footgun: `MERGE (as)-[:APPLIES_APPROACH]->(:AssessmentApproach {id:...})`
//       re-created AssessmentApproach nodes instead of matching them
//       -> 48 duplicate approach nodes.
//   (2) cross-statement variable scoping: `MERGE (m)-[:HAS_CATEGORY]->(ic)` with
//       m/ic bound in a previous `;`-separated statement created label-less
//       nodes, later removed -> IAM_MCI / IAM_REPAIR lost their HAS_CATEGORY.
// Also adds the missing uniqueness constraints for the v3.x labels.
// Date: 2026-08-27
// ============================================================================

// --- 1. Merge duplicate AssessmentApproach nodes ------------------------
MATCH (ap:AssessmentApproach)
WITH ap.id AS id, collect(ap) AS ns
WHERE size(ns) > 1
WITH [n IN ns WHERE n.level IS NOT NULL] + [n IN ns WHERE n.level IS NULL] AS ordered
CALL apoc.refactor.mergeNodes(ordered, {properties:'discard', mergeRels:true}) YIELD node
RETURN node.id AS merged;

// --- 2. Re-establish HAS_CATEGORY for the new methods -----------------
MATCH (m:ImpactAssessmentMethod {id:'IAM_MCI'}), (ic:ImpactCategory {id:'IC_CIRCULARITY'})
MERGE (m)-[:HAS_CATEGORY]->(ic);
MATCH (m:ImpactAssessmentMethod {id:'IAM_REPAIR'}), (ic:ImpactCategory {id:'IC_REPAIRABILITY'})
MERGE (m)-[:HAS_CATEGORY]->(ic);

// --- 3. Uniqueness constraints for v3.x labels ----------------------
CREATE CONSTRAINT AssessmentApproach_id_unique IF NOT EXISTS FOR (n:AssessmentApproach) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT EndOfLifeRoute_id_unique     IF NOT EXISTS FOR (n:EndOfLifeRoute)     REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT CostItem_id_unique           IF NOT EXISTS FOR (n:CostItem)           REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT Declaration_id_unique        IF NOT EXISTS FOR (n:Declaration)        REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT ModelScenario_id_unique      IF NOT EXISTS FOR (n:ModelScenario)      REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT Parameter_id_unique          IF NOT EXISTS FOR (n:Parameter)          REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT ParameterValue_id_unique     IF NOT EXISTS FOR (n:ParameterValue)     REQUIRE n.id IS UNIQUE;

// --- verification -------------------------------------------------
MATCH (ap:AssessmentApproach) RETURN 'AssessmentApproach total' AS check, count(*) AS n;
MATCH (ap:AssessmentApproach) WITH ap.id AS id, count(*) AS n WHERE n>1 RETURN 'remaining dups' AS check, collect(id) AS ids;
MATCH (m:ImpactAssessmentMethod)-[:HAS_CATEGORY]->(ic) RETURN 'method HAS_CATEGORY' AS check, m.id, count(ic) AS categories ORDER BY m.id;
MATCH (as:Assessment)-[:APPLIES_APPROACH]->(ap) RETURN 'APPLIES_APPROACH by approach' AS check, ap.id, count(*) AS n ORDER BY ap.id;
MATCH (n) WHERE size(labels(n))=0 RETURN 'labelless (must be 0)' AS check, count(n) AS n;
