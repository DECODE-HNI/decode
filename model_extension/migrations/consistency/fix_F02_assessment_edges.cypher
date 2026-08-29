// ============================================================================
// fix_F02_assessment_edges.cypher   --  consistency review, finding F-02
// ----------------------------------------------------------------------------
// 34 Assessments lacked a core edge. Root cause: the v3.f-i, scenario and
// prospective/consequential/hybrid migrations did not wire all four edges.
//
// Rule applied here:
//   * every Assessment that persists >=1 ImpactResult MUST have USES_METHOD
//   * every Assessment MUST have UNDER_SCENARIO (default SC_BASELINE)
//   * the 8 approach-marker Assessments (no persisted result -- CONSEQ,
//     CROSSIMPACT, DYNLCA, HYBRID, POLLUTANT, SEEA, ENVKG, AI_PREPARED) keep
//     APPLIES_APPROACH only and are exempt from USES_METHOD -- check_model B4
//     is tightened to match.
//
// Idempotent. Rollback at the foot.
// ============================================================================

// ---- USES_METHOD -> IAM_EF31 for the EF3.1-result-bearing assessments ----
MATCH (efm:ImpactAssessmentMethod {id:'IAM_EF31'})
MATCH (a:Assessment)
WHERE (a.id STARTS WITH 'ASSESS_EF31_SCEN_GRID2035_'
    OR a.id STARTS WITH 'ASSESS_EF31_SCEN_RECALU_'
    OR a.id STARTS WITH 'ASSESS_H2O_')
  AND EXISTS { (a)-[:HAS_RESULT]->(:ImpactResult) }
  AND NOT EXISTS { (a)-[:USES_METHOD]->() }
MERGE (a)-[:USES_METHOD]->(efm);

// ---- UNDER_SCENARIO -> SC_BASELINE for everything still missing it -------
MATCH (base:ModelScenario {id:'SC_BASELINE'})
MATCH (a:Assessment) WHERE NOT EXISTS { (a)-[:UNDER_SCENARIO]->() }
MERGE (a)-[:UNDER_SCENARIO]->(base);

// ---- verification ------------------------------------------------------
MATCH (a:Assessment)
WHERE NOT EXISTS { (a)-[:ASSESSES]->() }
   OR NOT EXISTS { (a)-[:UNDER_SCENARIO]->() }
   OR NOT EXISTS { (a)-[:APPLIES_APPROACH]->() }
   OR (EXISTS { (a)-[:HAS_RESULT]->(:ImpactResult) } AND NOT EXISTS { (a)-[:USES_METHOD]->() })
RETURN 'assessments still missing a required edge (expect 0)' AS check, count(a) AS n;

MATCH (a:Assessment) WHERE NOT EXISTS { (a)-[:USES_METHOD]->() }
RETURN 'approach-marker assessments without USES_METHOD (expect 8, all result-free)' AS check,
       count(a) AS n, sum(CASE WHEN EXISTS { (a)-[:HAS_RESULT]->() } THEN 1 ELSE 0 END) AS withResult;

MATCH ()-[r:USES_METHOD]->() RETURN 'USES_METHOD total' AS check, count(r) AS n;
MATCH ()-[r:UNDER_SCENARIO]->() RETURN 'UNDER_SCENARIO total' AS check, count(r) AS n;

// ---- rollback -------------------------------------------------------
// MATCH (a:Assessment)-[r:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_EF31'})
//   WHERE a.id STARTS WITH 'ASSESS_EF31_SCEN_GRID2035_' OR a.id STARTS WITH 'ASSESS_EF31_SCEN_RECALU_'
//      OR a.id STARTS WITH 'ASSESS_H2O_' DELETE r;
// (UNDER_SCENARIO backfill is not safely reversible -- SC_BASELINE is the correct default.)
