// ============================================================================
// 00_mci_rollup.cypher   (demonstrator slice -- circularity roll-up)
// ----------------------------------------------------------------------------
// v3.a created ASSESS_MCI only for the 5 aluminium grippers. The demonstrator
// slice needs a gripper-level MCI for its non-aluminium members too. Same
// method as v3.a: mass-weighted mean of Material.mci over the mass-bearing
// parts (class-default circularity inputs). Idempotent. Rollback at the foot.
// ============================================================================
MATCH (mcm:ImpactAssessmentMethod {id:'IAM_MCI'}),
      (apc:AssessmentApproach {id:'APM_CIRCULARITY'}),
      (base:ModelScenario {id:'SC_BASELINE'}),
      (icc:ImpactCategory {id:'IC_CIRCULARITY'})
UNWIND ['ART_PREC_POM','ART_FLAT_ABS','ART_PREC_PC','ART_LONG_CFPA','ART_FINRAY_TPU','ART_MAGNET'] AS aid
MATCH (art:Artifact {id:aid})-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
      -[:USES_MATERIAL]->(m:Material)
WHERE p.mass_g IS NOT NULL AND m.mci IS NOT NULL
WITH mcm, apc, base, icc, art,
     sum(p.mass_g * hc.quantity)          AS totMass,
     sum(p.mass_g * hc.quantity * m.mci)  AS weighted
WITH mcm, apc, base, icc, art, round(weighted / totMass, 4) AS mci
MERGE (as:Assessment {id:'ASSESS_MCI_' + art.id})
  ON CREATE SET as.name='Material circularity (simplified MCI) - ' + art.name,
                as.assessmentType='circularity indicator',
                as.methodology='mass-weighted mean of Material.mci (v3.a formula), demonstrator slice',
                as.developmentPhase='Concept',
                as.systemBoundary='cradle-to-grave (material loops)',
                as.functionalUnit='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper'
SET as.status='partial', as.scenarioRef='SC_BASELINE'
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:USES_METHOD]->(mcm)
MERGE (as)-[:APPLIES_APPROACH]->(apc)
MERGE (as)-[:UNDER_SCENARIO]->(base)
MERGE (ir:ImpactResult {id:'IR_MCI_' + art.id})
  ON CREATE SET ir.name='MCI - ' + art.name, ir.resultType='Material circularity', ir.unit='dimensionless (0-1)'
SET ir.value=mci, ir.provenance='rollup-calculated', ir.computedAt='2026-08-29',
    ir.scenarioRef='SC_BASELINE', ir.status='calculated',
    ir.coverage='mass-weighted Material.mci; class-default circularity inputs (v3.a)'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(icc);

// verification
MATCH (as:Assessment)-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_MCI'}),
      (as)-[:HAS_RESULT]->(ir:ImpactResult)
RETURN as.id AS assessment, round(ir.value,4) AS mci ORDER BY assessment;

// rollback
// MATCH (as:Assessment) WHERE as.id IN ['ASSESS_MCI_ART_PREC_POM','ASSESS_MCI_ART_FLAT_ABS',
//   'ASSESS_MCI_ART_PREC_PC','ASSESS_MCI_ART_LONG_CFPA','ASSESS_MCI_ART_FINRAY_TPU','ASSESS_MCI_ART_MAGNET']
//   OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir) DETACH DELETE as, ir;
