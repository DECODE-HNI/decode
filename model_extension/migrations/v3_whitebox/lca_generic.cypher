// ============================================================================
// lca_generic.cypher  --  v3 white-box base query.
// Method-agnostic successor of v2's lca_computed_ef31: the LCIA method is a
// parameter, so a new method is pure data (method node + HAS_CATEGORY +
// CHARACTERIZES factors) with zero change to this query.
//
// Parameters:
//   $methodId    ImpactAssessmentMethod.id  (e.g. 'IAM_EF31', 'IAM_PCF')
//   $artifactId  Artifact.id or null (all wired grippers)
//
// Same scope limit as v2: only materials with (:Material)-[:MODELED_BY]->(:Process)
// and parts with a mass. v2/v3 wire this for aluminium (A1) only.
// ============================================================================
CALL {
  MATCH (ds:Process)<-[:MODELED_BY]-(:Material)
  WITH DISTINCT ds
  MATCH (ds)-[hf:HAS_FLOW]->(f:Flow)
  WITH ds, f, sum(hf.amount) AS amt
  MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory)<-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id: $methodId})
  WITH ds, ic, f, amt, collect(c) AS cs
  WITH ds, ic, f, amt,
       [x IN cs WHERE coalesce(x.location,'') = ''][0].factor       AS fNonReg,
       reduce(s = 0.0, x IN cs | s + x.factor) / size(cs)           AS fAvg
  RETURN ds, ic, sum(amt * coalesce(fNonReg, fAvg)) AS perKg
}
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
      -[:USES_MATERIAL]->(m:Material)-[:MODELED_BY]->(ds)
WHERE ($artifactId IS NULL OR art.id = $artifactId) AND p.mass_g IS NOT NULL
WITH art, ic, ds, perKg, sum(p.mass_g * hc.quantity) / 1000.0 AS mass_kg
RETURN art.id                         AS artifactId,
       art.name                       AS gripper,
       $methodId                      AS method,
       ic.id                          AS category,
       ic.unit                        AS unit,
       round(sum(mass_kg * perKg), 6) AS value
ORDER BY gripper, category;
