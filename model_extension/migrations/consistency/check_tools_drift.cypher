// ============================================================================
// check_tools_drift.cypher  --  consistency review, Layer 3 (tool <-> DB)
// ----------------------------------------------------------------------------
// refresh_variantA.cypher, refresh_recipe.cypher and the base query
// v3_whitebox/lca_generic.cypher all share ONE core CALL{} block (per-kg
// characterised amount over every MODELED_BY dataset, then mass-weighted over
// the BOM). This file reproduces that block verbatim and diffs the live
// recompute against the persisted ImpactResults.
//
//   Any returned row is a finding: a tool and the database disagree, i.e. the
//   persisted value is stale relative to the current CF layer / BOM, or a
//   MERGE key drifted. An empty result for a statement = pass.
//
// Read-only. Run:  CQ_FMT=verbose ./cq.sh check_tools_drift.cypher
// ============================================================================

// ---- 1. EF3.1 Variant A : live recompute vs IR_EF31A_* ------------------
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
      -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(ds)
WHERE p.mass_g IS NOT NULL
WITH art, ic, ds, perKg, sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg
WITH art, ic, round(sum(mass_kg*perKg),12) AS computed
OPTIONAL MATCH (ir:ImpactResult {id:'IR_EF31A_' + art.id + '_' + ic.id})
WITH art, ic, computed, ir.value AS persisted
WHERE persisted IS NULL OR abs(coalesce(persisted,0.0) - computed) > 0.000001
RETURN 'D3.1 EF31A recompute <> IR_EF31A_*' AS check,
       art.id AS artifact, ic.id AS category,
       round(computed,9) AS computed, round(coalesce(persisted,0.0),9) AS persisted,
       CASE WHEN persisted IS NULL THEN 'recompute yields a value with no persisted IR'
            ELSE 'value drift (persisted stale vs current CF layer)' END AS issue
ORDER BY abs(coalesce(persisted,0.0)-computed) DESC;

// ---- 2. EF3.1 Variant A : persisted IR_EF31A_* the recompute drops -----
MATCH (as:Assessment {dataVariant:'A-realdataset'})-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_EF31'}),
      (as)-[:ASSESSES]->(art:Artifact),
      (as)-[:HAS_RESULT]->(ir:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory)
WHERE NOT EXISTS {
  MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)
        -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(:Process)
        -[:HAS_FLOW]->(:Flow)-[:CHARACTERIZES]->(ic)
  WHERE p.mass_g IS NOT NULL
}
RETURN 'D3.2 IR_EF31A_* with no live recompute (stale, F-01 prune missed)' AS check,
       art.id AS artifact, ic.id AS category, ir.value AS persisted, '' AS x, 'delete on next refresh' AS issue
ORDER BY artifact, category;

// ---- 3. ReCiPe 2016 (H) : live recompute vs IR_RECIPE_* ----------------
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
      -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(ds)
WHERE p.mass_g IS NOT NULL
WITH art, ic, ds, perKg, sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg
WITH art, ic, round(sum(mass_kg*perKg),12) AS computed
OPTIONAL MATCH (ir:ImpactResult {id:'IR_RECIPE_' + art.id + '_' + ic.id})
WITH art, ic, computed, ir.value AS persisted
WHERE persisted IS NULL OR abs(coalesce(persisted,0.0) - computed) > 0.000001
RETURN 'D3.3 ReCiPe recompute <> IR_RECIPE_*' AS check,
       art.id AS artifact, ic.id AS category,
       round(computed,9) AS computed, round(coalesce(persisted,0.0),9) AS persisted,
       CASE WHEN persisted IS NULL THEN 'recompute yields a value with no persisted IR'
            ELSE 'value drift (persisted stale vs current CF layer)' END AS issue
ORDER BY abs(coalesce(persisted,0.0)-computed) DESC;

// ---- 4. ReCiPe : persisted IR_RECIPE_* the recompute drops -------------
MATCH (as:Assessment)-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_RECIPE'}),
      (as)-[:ASSESSES]->(art:Artifact),
      (as)-[:HAS_RESULT]->(ir:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory)
WHERE NOT EXISTS {
  MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)
        -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(:Process)
        -[:HAS_FLOW]->(:Flow)-[:CHARACTERIZES]->(ic)
  WHERE p.mass_g IS NOT NULL
}
RETURN 'D3.4 IR_RECIPE_* with no live recompute (stale, F-01 prune missed)' AS check,
       art.id AS artifact, ic.id AS category, ir.value AS persisted, '' AS x, 'delete on next refresh' AS issue
ORDER BY artifact, category;

// ---- 5. lca_generic core vs refresh core : identical row set -----------
// Both derive the same (artifact, category) universe. If lca_generic (6 dp) and
// the persisted IR (12 dp) disagree on which pairs exist, the shared block has
// diverged between the base query and the two refresh files.
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
      -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(ds)
WHERE p.mass_g IS NOT NULL
WITH DISTINCT art.id AS artifact, ic.id AS category
WHERE NOT EXISTS { (:ImpactResult {id:'IR_EF31A_' + artifact + '_' + category}) }
RETURN 'D3.5 lca_generic(IAM_EF31) pair with no IR_EF31A_*' AS check,
       artifact, category, 0.0 AS computed, 0.0 AS persisted, 'shared CALL block drift' AS issue
ORDER BY artifact, category;
