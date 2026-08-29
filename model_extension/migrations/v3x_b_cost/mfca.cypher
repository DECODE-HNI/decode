// mfca.cypher -- v3.b base query (prototype).
// Per gripper on the wired path: material input cost, split product vs loss.
// FLOW_WASTE.amount is currently 0 -> loss = 0 (honest; fill it to see a split).
CALL {
  OPTIONAL MATCH (:Process)-[hw:HAS_FLOW]->(:Flow {mfcaClass:'material-loss'})
  RETURN coalesce(avg(hw.amount), 0.0) AS lossFraction
}
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)-[:HAS_COST]->(ci:CostItem {category:'material'})
WITH art, lossFraction, sum(ci.amount) AS materialCostEUR
RETURN art.id AS artifactId, art.name AS gripper,
       round(materialCostEUR, 4)                     AS materialCostEUR,
       round(materialCostEUR * (1 - lossFraction), 4) AS productCostEUR,
       round(materialCostEUR * lossFraction, 4)       AS materialLossCostEUR
ORDER BY gripper;

// eco_efficiency.cypher -- EF3.1 climate result / product-system value
// MATCH (as:Assessment)-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_EF31'})
// MATCH (as)-[:ASSESSES]->(art), (as)-[:HAS_RESULT]->(ir:ImpactResult {resultType:'Climate change'})
// RETURN art.name, ir.value AS gwp_kgCO2e, as.productSystemValue,
//        round(ir.value / as.productSystemValue, 4) AS gwp_per_value;
