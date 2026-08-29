// ============================================================================
// lca_computed_ef31.cypher  --  v2 grey-box base query.
// Read-only. Recomputes EF3.1 A1 impact per gripper from the ILCD LCI and the
// characterization factors, independent of the values stored on ImpactResult.
// Parameter: $artifactId (optional; null = all grippers with a wired path).
//
// Scope note: only materials with a (:Material)-[:MODELED_BY]->(:Process) link
// and parts with a mass contribute. v2 wires this for aluminium only.
// ============================================================================

// per-kg impact of each modelled dataset, per EF3.1 category
CALL {
  MATCH (ds:Process)<-[:MODELED_BY]-(:Material)
  WITH DISTINCT ds
  MATCH (ds)-[hf:HAS_FLOW]->(f:Flow)
  WITH ds, f, sum(hf.amount) AS amt
  MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory)<-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_EF31'})
  WITH ds, ic, f, amt, collect(c) AS cs
  WITH ds, ic, f, amt,
       [x IN cs WHERE coalesce(x.location,'') = ''][0].factor         AS fNonReg,
       reduce(s = 0.0, x IN cs | s + x.factor) / size(cs)             AS fAvg
  RETURN ds, ic, sum(amt * coalesce(fNonReg, fAvg)) AS perKg
}

// mass of each modelled material per gripper
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(m:Material)-[:MODELED_BY]->(ds)
WHERE ($artifactId IS NULL OR art.id = $artifactId) AND p.mass_g IS NOT NULL
WITH art, ic, ds, perKg, sum(p.mass_g * hc.quantity) / 1000.0 AS mass_kg

RETURN art.id                       AS artifactId,
       art.name                     AS gripper,
       ic.id                        AS category,
       ic.unit                      AS unit,
       round(sum(mass_kg * perKg), 6) AS value,
       round(sum(mass_kg), 4)       AS modelledMass_kg
ORDER BY gripper, category;
