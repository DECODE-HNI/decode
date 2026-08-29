// ============================================================================
// refresh_recipe.cypher  --  persist ReCiPe 2016 Midpoint (H) results per
// gripper, mirroring refresh_variantA.cypher for EF3.1.  Run after
// import_recipe_cf.py has loaded the CHARACTERIZES factors.  Re-runnable.
//
// Same scope as Variant A: parts whose material has a real MODELED_BY dataset.
// 16 of 18 categories carry factors (fossil resource scarcity and land use are
// empty -- see cf_import/README.md), so the Assessment is status:'partial'.
// 2026-08-29
// ============================================================================
MATCH (rm:ImpactAssessmentMethod {id:'IAM_RECIPE'}),
      (apl:AssessmentApproach {id:'APM_LCA'}),
      (base:ModelScenario {id:'SC_BASELINE'})
CALL {
  MATCH (ds:Process)<-[:MODELED_BY]-(:Material)
  WITH DISTINCT ds
  MATCH (ds)-[hf:HAS_FLOW]->(f:Flow)
  WITH ds, f, sum(hf.amount) AS amt
  MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory)<-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_RECIPE'})
  WITH ds, ic, f, amt, collect(c) AS cs
  WITH ds, ic, f, amt,
       [x IN cs WHERE coalesce(x.location,'')=''][0].factor AS fN,
       reduce(s=0.0,x IN cs|s+x.factor)/size(cs) AS fA
  RETURN ds, ic, sum(amt*coalesce(fN,fA)) AS perKg
}
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
      -[:USES_MATERIAL]->(m:Material)-[:MODELED_BY]->(ds)
WHERE p.mass_g IS NOT NULL
WITH rm, apl, base, art, ic, ds, perKg, sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg
WITH rm, apl, base, art, ic, round(sum(mass_kg*perKg),12) AS value
MERGE (as:Assessment {id:'ASSESS_RECIPE_A_' + art.id})
  ON CREATE SET as.name='ReCiPe 2016 Midpoint (H) A1-A3 (real datasets) - ' + art.name,
                as.assessmentType='cradle-to-gate LCA (modelled materials only)',
                as.methodology='ReCiPe 2016 Midpoint (H) characterization of ILCD LCI via MODELED_BY',
                as.developmentPhase='Concept',
                as.systemBoundary='cradle-to-gate',
                as.functionalUnit='one gripper (modelled material parts)',
                as.referenceFlow='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper',
                as.characterizationLocationRule='global (non-regionalized) ReCiPe H factor'
SET as.status='partial', as.dataVariant='A-realdataset'
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:USES_METHOD]->(rm)
MERGE (as)-[:APPLIES_APPROACH]->(apl)
MERGE (as)-[:UNDER_SCENARIO]->(base)
MERGE (ir:ImpactResult {id:'IR_RECIPE_' + art.id + '_' + ic.id})
  ON CREATE SET ir.name=ic.name + ' (ReCiPe A) - ' + art.name, ir.resultType=ic.name, ir.unit=ic.unit
SET ir.value=value, ir.provenance='LCI-calculated', ir.dataVariant='A-realdataset',
    ir.computedAt='2026-08-29', ir.scenarioRef='SC_BASELINE',
    ir.coverage='A1-A3 material production; ReCiPe 2016 H CFs matched by CAS+compartment / resource name (openLCA LCIA pack). Fossil resource scarcity & land use not covered.',
    ir.status='calculated'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ic);

// --- prune stale results (consistency finding F-01) --------------------
// Mirror of the prune in refresh_variantA: delete any ReCiPe result whose
// category is no longer characterised by any contributing flow through the
// artifact's BOM (the MERGE above never removes fallen-away pairs).
MATCH (as:Assessment)-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_RECIPE'})
MATCH (as)-[:ASSESSES]->(art:Artifact)
MATCH (as)-[:HAS_RESULT]->(ir:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory)
WHERE NOT EXISTS {
  (art)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)
       -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(:Process)
       -[:HAS_FLOW]->(:Flow)-[:CHARACTERIZES]->(ic)
  WHERE p.mass_g IS NOT NULL
}
DETACH DELETE ir;

// --- verification --------------------------------------------------------
MATCH (as:Assessment)-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_RECIPE'})
RETURN count(DISTINCT as) AS recipeAssessments;
MATCH (as:Assessment)-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_RECIPE'}),
      (as)-[:HAS_RESULT]->(ir:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory)
RETURN ic.id AS category, count(*) AS grippers,
       round(min(ir.value),10) AS vmin, round(max(ir.value),10) AS vmax
ORDER BY category;

// --- rollback ----------------------------------------------------------
// MATCH (as:Assessment)-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_RECIPE'})
// OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir:ImpactResult) DETACH DELETE as, ir;
