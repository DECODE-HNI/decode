// mfa_balance.cypher  --  substance and material flow analysis (MFA).
// Mass balance per manufacturing/assembly process of the gripper foreground:
// input mass (material) vs. output mass (part + scrap).
// Uses Part.mass_g (v2-data) and Process.materialFactor.
// Parameters: $artifactId (or null).
MATCH (art:Artifact)-[:HAS_PROCESS_PLAN]->(:ProcessPlan)-[:CONTAINS_PROCESS]->(pr:Process)
WHERE ($artifactId IS NULL OR art.id = $artifactId)
OPTIONAL MATCH (pr)-[:APPLIES_TO]->(p:Part)<-[:HAS_COMPONENT]-(:Assembly)<-[:HAS_COMPONENT]-(art)
WITH art, pr, sum(coalesce(p.mass_g,0)) AS partOut_g
WITH art, pr, partOut_g,
     partOut_g * coalesce(pr.materialFactor, 1.0) AS matIn_g
RETURN art.name AS gripper, pr.id AS process, pr.processType AS type,
       round(matIn_g,2)               AS input_g,
       round(partOut_g,2)             AS product_g,
       round(matIn_g - partOut_g,2)   AS loss_g,
       CASE WHEN matIn_g > 0 THEN round(100.0*(matIn_g-partOut_g)/matIn_g,1) ELSE null END AS lossPct
ORDER BY gripper, process;
