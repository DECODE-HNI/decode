// ============================================================================
// 04_scenario_coverage.cypher   (demonstrator slice -- prospective grid 2035)
// ----------------------------------------------------------------------------
// v3.h computed SC_GRID_2035 only for the 5 aluminium grippers. Extend it to
// the rest of the demonstrator slice with the identical formula
// (A1 material literals + A3 electricity at a 0.15 kg CO2e/kWh 2035 grid
// factor, Variant-B basis). ART_V_AL and ART_FLAT_AL are already covered.
// Idempotent. Rollback at the foot.
// ============================================================================
MATCH (art:Artifact)-[:HAS_PROCESS_PLAN]->(:ProcessPlan)-[:CONTAINS_PROCESS]->(mp:Process {processType:'Manufacturing'})
WHERE art.id IN ['ART_PREC_POM','ART_FLAT_ABS','ART_PREC_PC','ART_LONG_CFPA','ART_FINRAY_TPU','ART_MAGNET']
MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(mat:Material)
WHERE p.mass_g IS NOT NULL
WITH art,
     sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg,
     coalesce(mp.energyIntensity_kWh_per_kg,20.0) AS eInt,
     sum(p.mass_g*hc.quantity/1000.0 * coalesce(mat.gwp_A1_kgCO2e_per_kg,0.0)) AS a1
WITH art, a1 + mass_kg*eInt*0.15 AS climate2035
MATCH (ms:ModelScenario {id:'SC_GRID_2035'}), (ap:AssessmentApproach {id:'APM_PROSPECTIVE_LCA'}),
      (ic:ImpactCategory {id:'IC_CLIMATE'})
MERGE (as:Assessment {id:'ASSESS_EF31_SCEN_GRID2035_'+art.id})
  ON CREATE SET as.name='EF3.1 climate under DE grid 2035 - '+art.id,
                as.assessmentType='prospective LCA', as.status='partial',
                as.methodology='Variant-B climate with a 2035 grid emission factor (0.15)',
                as.systemBoundary='cradle-to-gate', as.functionalUnit='one gripper',
                as.referenceQuantity=1.0, as.referenceUnit='gripper',
                as.dataVariant='B-literal', as.scenarioRef='SC_GRID_2035'
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:APPLIES_APPROACH]->(ap)
MERGE (as)-[:UNDER_SCENARIO]->(ms)
MERGE (ir:ImpactResult {id:'IR_EF31_SCEN_GRID2035_'+art.id+'_IC_CLIMATE'})
  ON CREATE SET ir.name='Climate (grid 2035) - '+art.id, ir.resultType='Climate change', ir.unit='kg CO2 eq'
SET ir.value=round(climate2035,4), ir.provenance='LCI-calculated', ir.computedAt='2026-08-29',
    ir.status='calculated', ir.scenarioRef='SC_GRID_2035', ir.dataVariant='B-literal',
    ir.coverage='A1 material literals + A3 electricity at a 2035 grid factor (0.15)'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ic);

// verification
MATCH (a:Assessment)-[:UNDER_SCENARIO]->(:ModelScenario {id:'SC_GRID_2035'})
MATCH (a)-[:ASSESSES]->(art:Artifact)
MATCH (a)-[:HAS_RESULT]->(ir:ImpactResult)
RETURN art.id AS gripper, round(ir.value,4) AS climate2035 ORDER BY climate2035 DESC;

// rollback
// MATCH (as:Assessment) WHERE as.id IN ['ASSESS_EF31_SCEN_GRID2035_ART_PREC_POM',
//   'ASSESS_EF31_SCEN_GRID2035_ART_FLAT_ABS','ASSESS_EF31_SCEN_GRID2035_ART_PREC_PC',
//   'ASSESS_EF31_SCEN_GRID2035_ART_LONG_CFPA','ASSESS_EF31_SCEN_GRID2035_ART_FINRAY_TPU',
//   'ASSESS_EF31_SCEN_GRID2035_ART_MAGNET']
//   OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir) DETACH DELETE as, ir;
