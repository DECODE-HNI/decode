// ============================================================================
// v2_data/4B_full_coverage.cypher  --  VARIANT B: full 43-gripper EF3.1 A1-A3
// from the per-kg literals (ASSUMPTIONS.md). Mixed data quality, flagged.
// Creates Assessment/ImpactResult with dataVariant='B-literal'.
// Additive. Rollback at bottom. 2026-08-27
// ============================================================================

// --- A3 climate (electricity) per gripper ---------------------------
CALL {
  MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
  WHERE p.mass_g IS NOT NULL
  OPTIONAL MATCH (mp:Process {processType:'Manufacturing'})-[:APPLIES_TO]->(p)
  WITH art, sum( (p.mass_g * hc.quantity)/1000.0
                 * coalesce(mp.energyIntensity_kWh_per_kg, 20.0) * 0.38 ) AS a3_climate
  RETURN art AS a3art, a3_climate
}
WITH collect({art:a3art, a3:a3_climate}) AS a3rows

// --- A1 per gripper per EF3.1 category -----------------------------
UNWIND a3rows AS a3
WITH a3.art AS art, a3.a3 AS a3_climate
MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(m:Material)
WHERE m.ef31_factors_A1 IS NOT NULL AND p.mass_g IS NOT NULL
WITH art, a3_climate, m,
     (p.mass_g * hc.quantity)/1000.0 AS pm_kg
UNWIND range(0, size(m.ef31_categories)-1) AS i
WITH art, a3_climate, m.ef31_categories[i] AS catId,
     sum(pm_kg * m.ef31_factors_A1[i]) AS a1
WITH art, catId,
     a1 + CASE WHEN catId = 'IC_CLIMATE' THEN a3_climate ELSE 0.0 END AS value

// --- write assessment + results ---------------------------------
MATCH (efm:ImpactAssessmentMethod {id:'IAM_EF31'}),
      (apl:AssessmentApproach {id:'APM_LCA'}),
      (base:ModelScenario {id:'SC_BASELINE'}),
      (ic:ImpactCategory {id:catId})
MERGE (as:Assessment {id:'ASSESS_EF31B_' + art.id})
  ON CREATE SET as.name='EF3.1 A1-A3 (literal data) - ' + art.name,
                as.assessmentType='cradle-to-gate LCA (A1-A3)',
                as.methodology='EF3.1 from per-kg literals + manufacturing energy',
                as.developmentPhase='Concept', as.status='partial',
                as.dataVariant='B-literal',
                as.systemBoundary='cradle-to-gate',
                as.systemBoundaryNote='A1 raw material + A3 manufacturing energy (climate only for A3)',
                as.functionalUnit='one gripper as delivered',
                as.referenceFlow='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper',
                as.characterizationLocationRule='literal per-kg factors (ASSUMPTIONS.md)'
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:USES_METHOD]->(efm)
MERGE (as)-[:APPLIES_APPROACH]->(apl)
MERGE (as)-[:UNDER_SCENARIO]->(base)
MERGE (ir:ImpactResult {id:'IR_EF31B_' + art.id + '_' + catId})
  ON CREATE SET ir.name=ic.name + ' (B) - ' + art.name, ir.resultType=ic.name, ir.unit=ic.unit
SET ir.value = round(value, 6),
    ir.provenance = 'LCI-calculated',
    ir.dataVariant = 'B-literal',
    ir.computedAt = '2026-08-27',
    ir.scenarioRef = 'SC_BASELINE',
    ir.coverage = 'A1 all materials (literal) + A3 electricity (climate); excludes use, transport, EoL',
    ir.status = 'calculated'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ic);

// --- verification -------------------------------------------------
MATCH (as:Assessment {dataVariant:'B-literal'})-[:ASSESSES]->(art)
MATCH (as)-[:HAS_RESULT]->(ir:ImpactResult {resultType:'Climate change'})
RETURN 'Variant B climate (kg CO2e / gripper)' AS check,
       count(*) AS grippers, round(min(ir.value),3) AS minV, round(max(ir.value),3) AS maxV,
       round(avg(ir.value),3) AS avgV;

// --- rollback ---------------------------------------------------
// MATCH (as:Assessment {dataVariant:'B-literal'}) OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir) DETACH DELETE as, ir;
