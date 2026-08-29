// ============================================================================
// refresh_variant_a.cypher -- recompute the Variant-A (real-dataset) EF3.1
// results after one or more ILCD packages were imported via import_ilcd_package.py.
// Generic over every (:Material)-[:MODELED_BY]->(:Process). Re-runnable.
// 2026-08-28
// ============================================================================
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
  ON CREATE SET as.name='EF3.1 A1-A3 (real datasets) - ' + art.name,
                as.assessmentType='cradle-to-gate LCA (modelled materials only)',
                as.methodology='EF3.1 characterization of ILCD LCI via MODELED_BY',
                as.developmentPhase='Concept',
                as.systemBoundary='cradle-to-gate',
                as.functionalUnit='one gripper (modelled material parts)',
                as.referenceFlow='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper',
                as.characterizationLocationRule='non-regionalized factor; average of regionalized where none'
SET as.status='partial', as.dataVariant='A-realdataset'
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:USES_METHOD]->(efm)
MERGE (as)-[:APPLIES_APPROACH]->(apl)
MERGE (as)-[:UNDER_SCENARIO]->(base)
MERGE (ir:ImpactResult {id:'IR_EF31A_' + art.id + '_' + ic.id})
  ON CREATE SET ir.name=ic.name + ' (A) - ' + art.name, ir.resultType=ic.name, ir.unit=ic.unit
SET ir.value=value, ir.provenance='LCI-calculated', ir.dataVariant='A-realdataset',
    ir.computedAt='2026-08-28', ir.scenarioRef='SC_BASELINE',
    ir.coverage='A1-A3 material production; parts whose material has a real ILCD MODELED_BY dataset (Al, steel, PA6.6, ABS, PC, POM)',
    ir.status='calculated'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ic);

// --- verification ------------------------------------------------------
MATCH (as:Assessment {dataVariant:'A-realdataset'})-[:HAS_RESULT]->(ir:ImpactResult {resultType:'Climate change'})
RETURN count(*) AS grippersVariantA,
       round(min(ir.value),3) AS minClimate, round(max(ir.value),3) AS maxClimate;
MATCH (as:Assessment {dataVariant:'A-realdataset'})-[:ASSESSES]->(a:Artifact),
      (as)-[:HAS_RESULT]->(ir:ImpactResult {resultType:'Climate change'})
RETURN a.id AS gripper, round(ir.value,4) AS climate_A_kgCO2e ORDER BY climate_A_kgCO2e DESC LIMIT 15;
