// ============================================================================
// v2_data/4A_realonly.cypher  --  VARIANT A: MODELED_BY only to REAL ILCD
// datasets that exist in the graph. No synthetic data. Grippers whose material
// has no dataset stay "data incomplete".
// Coverage after this: aluminium (v2), steel, polyamide (PA66 proxy).
// Additive. Rollback at bottom. 2026-08-27
// ============================================================================

// --- steel: MAT_STEEL, MAT_SPRING -> steel sections (ILCD) -------------
MATCH (ds:Process {id:'PROC_STEEL_SECTIONS_ILCD'})
UNWIND ['MAT_STEEL','MAT_SPRING'] AS mid
MATCH (m:Material {id:mid})
MERGE (m)-[r:MODELED_BY]->(ds)
SET r.proxy=true, r.lifecycleModule='A1',
    r.proxyRationale='structural steel modelled with ILCD steel sections dataset; alloy (spring) not distinguished',
    r.addedBy='v2_data/4A 2026-08-27';

// --- polyamide: MAT_PA12, MAT_PA11 -> PA 6.6 granulate mix ------------
MATCH (ds:Process {id:'PROC_PA66_GRANULATE_MIX'})
UNWIND ['MAT_PA12','MAT_PA11'] AS mid
MATCH (m:Material {id:mid})
MERGE (m)-[r:MODELED_BY]->(ds)
SET r.proxy=true, r.lifecycleModule='A1',
    r.proxyRationale='polyamide 12/11 modelled with nearest available polyamide dataset (PA 6.6 granulate mix); chemistry differs',
    r.addedBy='v2_data/4A 2026-08-27';

// --- recompute lca_generic results for the now-wired grippers --------
//   (aluminium already has ASSESS_EF31_*; add steel + PA analogues)
MATCH (efm:ImpactAssessmentMethod {id:'IAM_EF31'}),
      (apl:AssessmentApproach {id:'APM_LCA'}),
      (base:ModelScenario {id:'SC_BASELINE'})
CALL {
  MATCH (ds:Process)<-[:MODELED_BY]-(:Material)
  WITH DISTINCT ds
  MATCH (ds)-[hf:HAS_FLOW]->(f:Flow)
  WITH ds, f, sum(hf.amount) AS amt
  MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory)<-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_EF31'})
  WITH ds, ic, f, amt, collect(c) AS cs
  WITH ds, ic, f, amt,
       [x IN cs WHERE coalesce(x.location,'')=''][0].factor AS fN,
       reduce(s=0.0,x IN cs|s+x.factor)/size(cs) AS fA
  RETURN ds, ic, sum(amt*coalesce(fN,fA)) AS perKg
}
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
      -[:USES_MATERIAL]->(m:Material)-[:MODELED_BY]->(ds)
WHERE p.mass_g IS NOT NULL
WITH efm, apl, base, art, ic, ds, perKg, sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg
WITH efm, apl, base, art, ic, round(sum(mass_kg*perKg),6) AS value
MERGE (as:Assessment {id:'ASSESS_EF31A_' + art.id})
  ON CREATE SET as.name='EF3.1 A1 (real datasets) - ' + art.name,
                as.assessmentType='cradle-to-gate LCA (A1, modelled materials only)',
                as.methodology='EF3.1 characterization of ILCD LCI via MODELED_BY',
                as.developmentPhase='Concept', as.status='partial',
                as.dataVariant='A-realdataset',
                as.systemBoundary='cradle-to-gate',
                as.functionalUnit='one gripper (modelled material parts)',
                as.referenceFlow='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper',
                as.characterizationLocationRule='non-regionalized factor; average of regionalized where none'
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:USES_METHOD]->(efm)
MERGE (as)-[:APPLIES_APPROACH]->(apl)
MERGE (as)-[:UNDER_SCENARIO]->(base)
MERGE (ir:ImpactResult {id:'IR_EF31A_' + art.id + '_' + ic.id})
  ON CREATE SET ir.name=ic.name + ' (A) - ' + art.name, ir.resultType=ic.name, ir.unit=ic.unit
SET ir.value=value, ir.provenance='LCI-calculated', ir.dataVariant='A-realdataset',
    ir.computedAt='2026-08-27', ir.scenarioRef='SC_BASELINE',
    ir.coverage='A1, only parts whose material has a MODELED_BY dataset (Al, steel, PA-proxy)',
    ir.status='calculated'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ic);

// --- verification -------------------------------------------------
MATCH (:Material)-[r:MODELED_BY]->(ds:Process)
RETURN 'MODELED_BY' AS check, startNode(r).id AS material, ds.id AS dataset ORDER BY material;
MATCH (as:Assessment {dataVariant:'A-realdataset'})-[:HAS_RESULT]->(ir:ImpactResult {resultType:'Climate change'})
RETURN 'Variant A climate (kg CO2e / gripper, A1 modelled parts only)' AS check,
       count(*) AS grippers, round(min(ir.value),3) AS minV, round(max(ir.value),3) AS maxV;

// --- rollback ---------------------------------------------------
// MATCH (m:Material)-[r:MODELED_BY]->() WHERE r.addedBy='v2_data/4A 2026-08-27' DELETE r;
// MATCH (as:Assessment {dataVariant:'A-realdataset'}) OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir) DETACH DELETE as, ir;
