// ============================================================================
// migration_v3d.cypher  --  Module v3.d: provenance (ImpactResult.confidence,
//   BASED_ON) + repairability as a result + EPD/DPP Declaration +
//   sustainability thresholds. Additive. Date: 2026-08-27
//   (The AI/ML prediction-hook sketch that was in sections 3 & 5 is dropped --
//    out of scope, 2026-08-29, see consistency/remove_ki_stubs.cypher.)
// ============================================================================

// --- 1. Provenance property + BASED_ON edge -----------------------------
//   ImpactResult.confidence ; (ImpactResult)-[:BASED_ON]->(Feature|CoreProperty|DataItem)

// --- 2. Repairability as a first-class assessment result (uses v1 data) --
// NOTE: statements are independent -> always re-MATCH by id; never leave an
// AssessmentApproach / method / category as an inline MERGE node pattern.
MERGE (m:ImpactAssessmentMethod {id:'IAM_REPAIR'})
  SET m.name='Disassembly / repairability index (v1)', m.methodFamily='structural index', m.version='v1';
MERGE (ic:ImpactCategory {id:'IC_REPAIRABILITY'})
  SET ic.name='Repairability', ic.indicator='disassembly reversibility', ic.unit='ratio';
MATCH (m:ImpactAssessmentMethod {id:'IAM_REPAIR'}), (ic:ImpactCategory {id:'IC_REPAIRABILITY'})
MERGE (m)-[:HAS_CATEGORY]->(ic);
MATCH (m:ImpactAssessmentMethod {id:'IAM_REPAIR'}), (ap:AssessmentApproach {id:'APM_IMPACT_CHAIN'})
MERGE (m)-[:APPLIES_APPROACH]->(ap);

MATCH (art:Artifact)
MATCH (mth:ImpactAssessmentMethod {id:'IAM_REPAIR'}), (ric:ImpactCategory {id:'IC_REPAIRABILITY'}),
      (apic:AssessmentApproach {id:'APM_IMPACT_CHAIN'})
MERGE (as:Assessment {id:'ASSESS_REPAIR_' + art.id})
  ON CREATE SET as.name='Repairability - ' + art.name, as.assessmentType='structural index',
                as.methodology='v1 connection reversibility + quick-change + modular jaws',
                as.status='calculated', as.systemBoundary='n/a', as.functionalUnit='one gripper',
                as.referenceFlow='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper'
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:USES_METHOD]->(mth)
MERGE (as)-[:APPLIES_APPROACH]->(apic)
MERGE (ir:ImpactResult {id:'IR_REPAIR_' + art.id})
  ON CREATE SET ir.name='Repairability - ' + art.name, ir.resultType='Repairability', ir.unit='ratio'
SET ir.value = art.disassemblyReversibility,
    ir.provenance = 'expert-estimate', ir.confidence = 0.6, ir.computedAt = '2026-08-27',
    ir.status = 'calculated',
    ir.coverage = 'class ' + art.repairabilityClass
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ric)
WITH ir, art
MATCH (art)-[:HAS_PROPERTY]->(cp:CoreProperty {id:'CP_DISASSEMBLY'})
MERGE (ir)-[:BASED_ON]->(cp);

// link repairability result also to the enabling features where present
MATCH (ir:ImpactResult)-[:FOR_CATEGORY]->(:ImpactCategory {id:'IC_REPAIRABILITY'})
MATCH (as:Assessment)-[:HAS_RESULT]->(ir), (as)-[:ASSESSES]->(art)
MATCH (art)-[:HAS_FEATURE]->(f:Feature) WHERE f.id IN ['FEAT_EASY','FEAT_PRINTABLE']
MERGE (ir)-[:BASED_ON]->(f);

// --- 3. (was: prediction-model type sketch) --------------------------
//   The AI/ML docking-point design (PredictionModel / PREDICTED_BY /
//   ml-model vocabulary) is out of the case-study scope and was dropped
//   2026-08-29 -- see model_versions/consistency/remove_ki_stubs.cypher.

// --- 4. EPD / DPP Declaration for a wired gripper ---------------------
MATCH (art:Artifact {id:'ART_V_AL'})
MERGE (epd:Declaration {id:'DECL_EPD_ART_V_AL'})
  SET epd.type='EPD', epd.standard='EN 15804+A2', epd.functionalUnit='one gripper aluminium jaw set',
      epd.validFrom='2026-08-27', epd.validUntil='2031-08-27', epd.scope='A1 (partial)',
      epd.note='demonstrator built on the v2 aluminium A1 EF3.1 results'
MERGE (epd)-[:DECLARES]->(art);
MATCH (epd:Declaration {id:'DECL_EPD_ART_V_AL'})
MATCH (as:Assessment {id:'ASSESS_EF31_ART_V_AL'})-[:HAS_RESULT]->(ir:ImpactResult)
MERGE (epd)-[:REPORTS]->(ir);

MATCH (art:Artifact {id:'ART_V_AL'})
MERGE (dpp:Declaration {id:'DECL_DPP_ART_V_AL'})
  SET dpp.type='DPP', dpp.standard='ESPR (draft)', dpp.functionalUnit='one gripper',
      dpp.validFrom='2026-08-27', dpp.scope='material composition, recycled content, EoL routes, PCF, repairability',
      dpp.note='demonstrator: pulls MCI, repairability and EF3.1 A1 results'
MERGE (dpp)-[:DECLARES]->(art);
MATCH (dpp:Declaration {id:'DECL_DPP_ART_V_AL'}), (art:Artifact {id:'ART_V_AL'})
MATCH (as:Assessment)-[:ASSESSES]->(art), (as)-[:HAS_RESULT]->(ir:ImpactResult)
WHERE as.id IN ['ASSESS_EF31_ART_V_AL','ASSESS_MCI_ART_V_AL','ASSESS_REPAIR_ART_V_AL']
MERGE (dpp)-[:REPORTS]->(ir);

// --- 5. (was: recommendation type sketch) ---------------------------
//   Dropped 2026-08-29 with the rest of the AI/ML branch --
//   see model_versions/consistency/remove_ki_stubs.cypher.

// --- 6. Sustainability threshold on a Requirement (demonstrator) -----
MATCH (r:Requirement)
WITH r LIMIT 1
SET r.sustainabilityIndicatorRef = 'IC_CLIMATE',
    r.sustainabilityThreshold    = 0.5,
    r.sustainabilityOperator     = '<=',
    r.sustainabilityUnit         = 'kg CO2-eq',
    r.sustainabilityScope        = 'A1 aluminium contact parts',
    r.sustainabilityBasis        = 'v3.d demonstrator';

// --- verification --------------------------------------------------
MATCH (ir:ImpactResult {resultType:'Repairability'}) RETURN 'repairability results' AS c, count(*) AS n, round(avg(ir.value),3) AS avgVal;
MATCH (ir:ImpactResult)-[:BASED_ON]->(x) RETURN 'BASED_ON edges' AS c, count(*) AS n, collect(DISTINCT labels(x)[0]) AS targets;
MATCH (d:Declaration) OPTIONAL MATCH (d)-[:REPORTS]->(ir) RETURN d.id, d.type, count(ir) AS reports;
MATCH (r:Requirement) WHERE r.sustainabilityThreshold IS NOT NULL RETURN r.id, r.sustainabilityIndicatorRef, r.sustainabilityOperator, r.sustainabilityThreshold;

// --- rollback ---------------------------------------------------
// MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASSESS_REPAIR_' OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir) DETACH DELETE as, ir;
// MATCH (m:ImpactAssessmentMethod {id:'IAM_REPAIR'}) DETACH DELETE m;
// MATCH (ic:ImpactCategory {id:'IC_REPAIRABILITY'}) DETACH DELETE ic;
// MATCH (d:Declaration) DETACH DELETE d;
// MATCH (r:Requirement) REMOVE r.sustainabilityIndicatorRef, r.sustainabilityThreshold, r.sustainabilityOperator, r.sustainabilityUnit, r.sustainabilityScope, r.sustainabilityBasis;
