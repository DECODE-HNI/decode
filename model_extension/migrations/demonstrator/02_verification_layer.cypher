// ============================================================================
// 02_verification_layer.cypher   (demonstrator slice -- RFLPV2 Test Case)
// ----------------------------------------------------------------------------
// Realises the RFLPV(2) extension spec section 6 Neo4j target state -- until
// now documented but deliberately not applied. First case in the extension
// where a SysML stereotype maps to a genuinely new Neo4j node type.
//
//   (:TestCase)-[:VERIFIES]->(:Requirement)
//   (:TestCase)-[:HAS_ASSESSMENT]->(:Assessment)-[:HAS_RESULT]->(:ImpactResult)-[:FOR_CATEGORY]->(:ImpactCategory)
//   (:TestCase)-[:TESTS]->(:Artifact)                       (Test Item)
//
// TestCase.sustainabilityResult = cached indicator value.
// TestCase.sustainabilityStatus in {passed, failed, inconclusive, notEvaluated}
//   (RFLPV2 spec 6.2). 'inconclusive' = the underlying assessment is partial
//   (jaw material lacks a working real dataset), so the number is not a valid
//   full result; 'notEvaluated' = no result at all.
//
// Idempotent. Rollback at the foot.
// ============================================================================

CREATE CONSTRAINT TestCase_id_unique IF NOT EXISTS FOR (n:TestCase) REQUIRE n.id IS UNIQUE;

UNWIND [
  // --- GWP (EF3.1 GWP100, Variant A) ---
  {tc:'TC_VAL_GWP',   art:'ART_V_AL',       req:'REQ_SUS_GWP',    as:'ASSESS_EF31A_ART_V_AL',       cat:'IC_CLIMATE',        complete:true},
  {tc:'TC_FAL_GWP',   art:'ART_FLAT_AL',    req:'REQ_SUS_GWP',    as:'ASSESS_EF31A_ART_FLAT_AL',    cat:'IC_CLIMATE',        complete:true},
  {tc:'TC_PPOM_GWP',  art:'ART_PREC_POM',   req:'REQ_SUS_GWP',    as:'ASSESS_EF31A_ART_PREC_POM',   cat:'IC_CLIMATE',        complete:true},
  {tc:'TC_FABS_GWP',  art:'ART_FLAT_ABS',   req:'REQ_SUS_GWP',    as:'ASSESS_EF31A_ART_FLAT_ABS',   cat:'IC_CLIMATE',        complete:true},
  {tc:'TC_PPC_GWP',   art:'ART_PREC_PC',    req:'REQ_SUS_GWP',    as:'ASSESS_EF31A_ART_PREC_PC',    cat:'IC_CLIMATE',        complete:true},
  {tc:'TC_LCFPA_GWP', art:'ART_LONG_CFPA',  req:'REQ_SUS_GWP',    as:'ASSESS_EF31A_ART_LONG_CFPA',  cat:'IC_CLIMATE',        complete:false},
  {tc:'TC_FTPU_GWP',  art:'ART_FINRAY_TPU', req:'REQ_SUS_GWP',    as:'ASSESS_EF31A_ART_FINRAY_TPU', cat:'IC_CLIMATE',        complete:false},
  {tc:'TC_MAG_GWP',   art:'ART_MAGNET',     req:'REQ_SUS_GWP',    as:'ASSESS_EF31A_ART_MAGNET',     cat:'IC_CLIMATE',        complete:true},
  // --- MCI (simplified) ---
  {tc:'TC_VAL_MCI',   art:'ART_V_AL',       req:'REQ_SUS_MCI',    as:'ASSESS_MCI_ART_V_AL',       cat:'IC_CIRCULARITY',   complete:true},
  {tc:'TC_FAL_MCI',   art:'ART_FLAT_AL',    req:'REQ_SUS_MCI',    as:'ASSESS_MCI_ART_FLAT_AL',    cat:'IC_CIRCULARITY',   complete:true},
  {tc:'TC_PPOM_MCI',  art:'ART_PREC_POM',   req:'REQ_SUS_MCI',    as:'ASSESS_MCI_ART_PREC_POM',   cat:'IC_CIRCULARITY',   complete:true},
  {tc:'TC_FABS_MCI',  art:'ART_FLAT_ABS',   req:'REQ_SUS_MCI',    as:'ASSESS_MCI_ART_FLAT_ABS',   cat:'IC_CIRCULARITY',   complete:true},
  {tc:'TC_PPC_MCI',   art:'ART_PREC_PC',    req:'REQ_SUS_MCI',    as:'ASSESS_MCI_ART_PREC_PC',    cat:'IC_CIRCULARITY',   complete:true},
  {tc:'TC_LCFPA_MCI', art:'ART_LONG_CFPA',  req:'REQ_SUS_MCI',    as:'ASSESS_MCI_ART_LONG_CFPA',  cat:'IC_CIRCULARITY',   complete:true},
  {tc:'TC_FTPU_MCI',  art:'ART_FINRAY_TPU', req:'REQ_SUS_MCI',    as:'ASSESS_MCI_ART_FINRAY_TPU', cat:'IC_CIRCULARITY',   complete:true},
  {tc:'TC_MAG_MCI',   art:'ART_MAGNET',     req:'REQ_SUS_MCI',    as:'ASSESS_MCI_ART_MAGNET',     cat:'IC_CIRCULARITY',   complete:true},
  // --- Repairability ---
  {tc:'TC_VAL_REP',   art:'ART_V_AL',       req:'REQ_SUS_REPAIR', as:'ASSESS_REPAIR_ART_V_AL',       cat:'IC_REPAIRABILITY', complete:true},
  {tc:'TC_FAL_REP',   art:'ART_FLAT_AL',    req:'REQ_SUS_REPAIR', as:'ASSESS_REPAIR_ART_FLAT_AL',    cat:'IC_REPAIRABILITY', complete:true},
  {tc:'TC_PPOM_REP',  art:'ART_PREC_POM',   req:'REQ_SUS_REPAIR', as:'ASSESS_REPAIR_ART_PREC_POM',   cat:'IC_REPAIRABILITY', complete:true},
  {tc:'TC_FABS_REP',  art:'ART_FLAT_ABS',   req:'REQ_SUS_REPAIR', as:'ASSESS_REPAIR_ART_FLAT_ABS',   cat:'IC_REPAIRABILITY', complete:true},
  {tc:'TC_PPC_REP',   art:'ART_PREC_PC',    req:'REQ_SUS_REPAIR', as:'ASSESS_REPAIR_ART_PREC_PC',    cat:'IC_REPAIRABILITY', complete:true},
  {tc:'TC_LCFPA_REP', art:'ART_LONG_CFPA',  req:'REQ_SUS_REPAIR', as:'ASSESS_REPAIR_ART_LONG_CFPA',  cat:'IC_REPAIRABILITY', complete:true},
  {tc:'TC_FTPU_REP',  art:'ART_FINRAY_TPU', req:'REQ_SUS_REPAIR', as:'ASSESS_REPAIR_ART_FINRAY_TPU', cat:'IC_REPAIRABILITY', complete:true},
  {tc:'TC_MAG_REP',   art:'ART_MAGNET',     req:'REQ_SUS_REPAIR', as:'ASSESS_REPAIR_ART_MAGNET',     cat:'IC_REPAIRABILITY', complete:true}
] AS d
MATCH (art:Artifact {id:d.art}), (r:Requirement {id:d.req})
OPTIONAL MATCH (a:Assessment {id:d.as})-[:HAS_RESULT]->(ir:ImpactResult)-[:FOR_CATEGORY]->(:ImpactCategory {id:d.cat})
WITH art, r, d, a, ir, CASE
    WHEN ir IS NULL OR a IS NULL                                                        THEN 'notEvaluated'
    WHEN d.complete = false                                                             THEN 'inconclusive'
    WHEN r.sustainabilityOperator = '<=' AND ir.value <= r.sustainabilityThreshold      THEN 'passed'
    WHEN r.sustainabilityOperator = '>=' AND ir.value >= r.sustainabilityThreshold      THEN 'passed'
    ELSE 'failed' END AS status
MERGE (tc:TestCase {id:d.tc})
  SET tc.name='Verify ' + r.name + ' -- ' + art.name,
      tc.verificationID=d.tc,
      tc.testCaseOwner='sustainability engineering',
      tc.systemLevel='product',
      tc.dataAnalysisType='quantitative threshold check',
      tc.testMethod='analysis (indicator computation in the knowledge graph)',
      tc.sustainabilityResult=ir.value,
      tc.sustainabilityStatus=status,
      tc.evaluatedAt='2026-08-29',
      tc.note=CASE WHEN status='inconclusive'
                   THEN 'Underlying assessment is partial -- jaw material lacks a working real dataset; result covers the PA12 interface only. Flagged for the consistency review.'
                   ELSE null END
MERGE (tc)-[:VERIFIES]->(r)
MERGE (tc)-[:TESTS]->(art)
WITH tc, a WHERE a IS NOT NULL
MERGE (tc)-[:HAS_ASSESSMENT]->(a);

// sync the SATISFIES_REQUIREMENT edge with the Test Case verdict
MATCH (tc:TestCase)-[:VERIFIES]->(r:Requirement), (tc)-[:TESTS]->(art:Artifact)
MATCH (art)-[sr:SATISFIES_REQUIREMENT]->(r)
SET sr.verificationStatus=tc.sustainabilityStatus, sr.verifiedByTestCase=tc.id;

// verification
MATCH (tc:TestCase)
RETURN tc.sustainabilityStatus AS status, count(*) AS testCases ORDER BY status;
MATCH (tc:TestCase)-[:VERIFIES]->(r:Requirement)
RETURN r.id AS requirement,
       collect(tc.id + '=' + tc.sustainabilityStatus) AS verdicts ORDER BY requirement;

// rollback
// MATCH (tc:TestCase) DETACH DELETE tc;
// MATCH (:Artifact)-[sr:SATISFIES_REQUIREMENT]->(:Requirement) WHERE sr.verifiedByTestCase IS NOT NULL
//   REMOVE sr.verifiedByTestCase SET sr.verificationStatus='notEvaluated';
