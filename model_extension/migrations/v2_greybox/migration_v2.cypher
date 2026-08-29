// ============================================================================
// migration_v2.cypher  --  Grey box: wire ONE clean LCI -> LCIA -> result path
//                          end to end and prove the computation mechanism.
//
// DECISIONS (most-implementable scope; see PLAN.md section v2):
//   1. Material -> ILCD dataset link: new additive rel  (:Material)-[:MODELED_BY]->(:Process)
//   2. Mass model: Part.mass_g estimated from bounding-box geometry x 0.5 fill x density
//   3. Scope: v2-minimal -- aluminium contact parts of 5 grippers only; rest = data incomplete
//   4. System boundary: A1 (cradle-to-gate raw material) only -- the only stage with
//      characterized ILCD data. Manufacturing/Use/EoL flows are placeholders.
//   Location rule: use the non-regionalized characterization factor; where a
//      (flow,category) pair has only regionalized factors, use their average.
//
// All changes additive/reversible. Rollback at bottom.
// Date: 2026-08-27
// ============================================================================

// ----------------------------------------------------------------------------
// 1. Material -> ILCD dataset proxy link (A1). Only wrought aluminium alloys;
//    PROC_ALU_EXTRUSION_EF is the validated EN15804 A1-A3 dataset (Sphera).
// ----------------------------------------------------------------------------
MATCH (ds:Process {id:'PROC_ALU_EXTRUSION_EF'})
UNWIND ['MAT_AL6061','MAT_AL7075'] AS mid
MATCH (m:Material {id: mid})
MERGE (m)-[r:MODELED_BY]->(ds)
SET r.proxy          = true,
    r.lifecycleModule = 'A1-A3',
    r.proxyRationale  = 'wrought Al alloy modelled with generic EN15804 A1-A3 aluminium extrusion profile (Sphera); alloy-specific burden not distinguished at v2',
    r.addedBy         = 'migration_v2 2026-08-27';

// ----------------------------------------------------------------------------
// 2. Part.mass_g for the aluminium contact parts (geometry-based estimate).
// ----------------------------------------------------------------------------
MATCH (p:Part)-[:USES_MATERIAL]->(mm:Material)
WHERE mm.id IN ['MAT_AL6061','MAT_AL7075']
MATCH (p)-[:HAS_FORM]->(:Form)-[:HAS_GEOMETRY]->(g:Geometry)
WITH p, mm,
     coalesce(g.length_mm,0) * coalesce(g.width_mm,0) * coalesce(g.height_mm,0) AS bbox_mm3
SET p.mass_g    = round(bbox_mm3 * 0.5 * mm.density_kg_m3 * 1e-6, 2),
    p.massBasis = 'v2 estimate: bounding-box volume x 0.5 fill factor x material density';

// ----------------------------------------------------------------------------
// 3. Compute EF3.1 A1 results for the aluminium grippers and store them.
//    value = (aluminium contact mass in kg) x (per-kg impact of the dataset).
// ----------------------------------------------------------------------------
MATCH (efm:ImpactAssessmentMethod {id:'IAM_EF31'})

// 3a. per-kg impact of PROC_ALU_EXTRUSION_EF per EF3.1 category
CALL {
  MATCH (ds:Process {id:'PROC_ALU_EXTRUSION_EF'})-[hf:HAS_FLOW]->(f:Flow)
  WITH f, sum(hf.amount) AS amt
  MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory)<-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_EF31'})
  WITH ic, f, amt, collect(c) AS cs
  WITH ic, f, amt,
       [x IN cs WHERE coalesce(x.location,'') = ''][0].factor           AS fNonReg,
       reduce(s = 0.0, x IN cs | s + x.factor) / size(cs)               AS fAvg
  RETURN ic, sum(amt * coalesce(fNonReg, fAvg)) AS perKg
}

// 3b. aluminium contact mass per gripper
CALL {
  MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(mm:Material)
  WHERE mm.id IN ['MAT_AL6061','MAT_AL7075'] AND p.mass_g IS NOT NULL
  RETURN art, sum(p.mass_g * hc.quantity) / 1000.0 AS alMass_kg
}

WITH efm, art, ic, perKg, alMass_kg, round(alMass_kg * perKg, 6) AS val

MERGE (as:Assessment {id: 'ASSESS_EF31_' + art.id})
  ON CREATE SET as.name                        = 'EF3.1 A1 aluminium screening - ' + art.name,
                as.assessmentType              = 'cradle-to-gate LCA (A1, aluminium parts only)',
                as.methodology                 = 'EF3.1 characterization of ILCD LCI',
                as.developmentPhase            = 'Concept',
                as.systemBoundary              = 'cradle-to-gate, A1 raw material, aluminium contact parts only',
                as.functionalUnit              = 'one gripper jaw set (aluminium contact parts)',
                as.characterizationLocationRule = 'non-regionalized factor; average of regionalized where none',
                as.status                      = 'partial'
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:USES_METHOD]->(efm)

MERGE (ir:ImpactResult {id: 'IR_EF31_' + art.id + '_' + ic.id})
  ON CREATE SET ir.name       = ic.name + ' - ' + art.name,
                ir.resultType = ic.name,
                ir.unit       = ic.unit
SET ir.value      = val,
    ir.provenance = 'LCI-calculated',
    ir.computedAt = '2026-08-27',
    ir.datasetRef = 'PROC_ALU_EXTRUSION_EF',
    ir.coverage   = 'A1 aluminium contact parts only; excludes interface part, manufacturing, use, end-of-life',
    ir.status     = 'calculated'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ic);

// ----------------------------------------------------------------------------
// 4. Make v2's coverage limit explicit on every result that is NOT computed.
// ----------------------------------------------------------------------------
MATCH (r:ImpactResult)
WHERE r.value IS NULL
SET r.status   = 'data incomplete',
    r.coverage = 'no wired LCI path: material has no ILCD dataset (MODELED_BY) and/or no mass';

// ----------------------------------------------------------------------------
// Verification
// ----------------------------------------------------------------------------
MATCH (as:Assessment)-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_EF31'})
MATCH (as)-[:ASSESSES]->(art)
MATCH (as)-[:HAS_RESULT]->(ir:ImpactResult {resultType:'Climate change'})
RETURN art.name AS gripper, ir.value AS gwp_kgCO2e, ir.coverage AS coverage
ORDER BY gwp_kgCO2e;

MATCH (ir:ImpactResult)
RETURN ir.status AS status, count(*) AS results
ORDER BY status;

MATCH (:Material)-[r:MODELED_BY]->(ds:Process)
RETURN 'MODELED_BY' AS rel, count(r) AS links, collect(startNode(r).id) AS materials, ds.id AS dataset;

// ----------------------------------------------------------------------------
// Rollback
// ----------------------------------------------------------------------------
// MATCH (as:Assessment)-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_EF31'})
//   OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir:ImpactResult)
//   DETACH DELETE as, ir;
// MATCH (:Material)-[r:MODELED_BY]->() DELETE r;
// MATCH (p:Part) WHERE p.massBasis STARTS WITH 'v2 estimate'
//   REMOVE p.mass_g, p.massBasis;
// MATCH (r:ImpactResult) REMOVE r.status, r.coverage, r.value, r.provenance,
//   r.computedAt, r.datasetRef;   // (restores pre-v2 placeholder state)
