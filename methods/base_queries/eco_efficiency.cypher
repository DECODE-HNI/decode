// eco_efficiency.cypher  --  eco-efficiency assessment (ISO 14045), prototype.
// Environmental impact per product/system value. Uses Assessment.productSystemValue (v3.b)
// or, as a fallback, the material costs from the CostItem nodes.
// Parameters: $resultType (e.g. 'Climate change').
MATCH (as:Assessment)-[:ASSESSES]->(art:Artifact), (as)-[:HAS_RESULT]->(ir:ImpactResult)
WHERE ir.resultType = coalesce($resultType,'Climate change') AND ir.status = 'calculated'
OPTIONAL MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)-[:HAS_COST]->(ci:CostItem)
WITH art, ir, as, as.productSystemValue AS psv, sum(ci.amount) AS costSum
WITH art, ir,
     CASE WHEN psv IS NOT NULL AND psv <> 0 THEN psv
          WHEN costSum IS NOT NULL AND costSum <> 0 THEN costSum
          ELSE 1.0 END AS value,
     CASE WHEN psv IS NOT NULL AND psv <> 0 THEN 'productSystemValue'
          WHEN costSum IS NOT NULL AND costSum <> 0 THEN 'EUR (material costs)'
          ELSE 'placeholder 1.0' END AS valueBasis
RETURN art.name AS gripper, ir.resultType AS indicator,
       round(ir.value,4)          AS impact,
       round(value,4)             AS system_value,
       valueBasis,
       round(ir.value / value, 6) AS impact_per_value
ORDER BY impact_per_value DESC;
