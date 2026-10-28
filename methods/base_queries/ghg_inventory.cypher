// ghg_inventory.cypher  --  greenhouse gas accounting.
// Until Process.ghgScope is set (see methods/onepagers/1.1.4), this query
// groups the gripper GWP by EN 15804 life cycle module instead.
// Parameters: $artifactId (or null), $dataVariant ('B-literal' | 'A-realdataset').
MATCH (as:Assessment)-[:ASSESSES]->(art:Artifact)
WHERE coalesce(as.dataVariant,'-') = coalesce($dataVariant,'B-literal')
  AND ($artifactId IS NULL OR art.id = $artifactId)
MATCH (as)-[:HAS_RESULT]->(ir:ImpactResult {resultType:'Climate change', status:'calculated'})
// derive A1 vs A3 from the coverage property (Variant B separates A1/A3 in the a1_only field
// of the base query -- here only the total plus the A3 electricity climate share as an estimate)
OPTIONAL MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
OPTIONAL MATCH (mp:Process {processType:'Manufacturing'})-[:APPLIES_TO]->(p)
WITH art, ir, sum( (coalesce(p.mass_g,0)*coalesce(hc.quantity,0))/1000.0
                   * coalesce(mp.energyIntensity_kWh_per_kg,20.0) * 0.38 ) AS a3_climate
RETURN art.id AS artifactId, art.name AS gripper,
       round(ir.value,4)               AS gwp_total_kgCO2e,
       round(ir.value - a3_climate,4)  AS module_A1_kgCO2e,
       round(a3_climate,4)             AS module_A3_kgCO2e
ORDER BY gwp_total_kgCO2e DESC;
