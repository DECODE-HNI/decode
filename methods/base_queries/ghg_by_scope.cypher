// ghg_by_scope.cypher  --  greenhouse gas accounting by GHG Protocol scope (1.1.4).
// Re-partitions the cradle-to-gate climate figure (Variant B: A1 materials +
// A3 electricity) into scope 1 / scope 2 / scope 3 upstream. Same system model as
// v2_data/lca_from_literals.cypher, hence  S2 + S3UP == Variant B climate figure.
// Scope 1 = 0 (no on-site fossil combustion modelled) -> gap.
// Parameters: $artifactId (or null), $electricityCF (default 0.38 = DE grid).
WITH coalesce($electricityCF, 0.38) AS eCF
MATCH (art:Artifact)-[:HAS_PROCESS_PLAN]->(:ProcessPlan)-[:CONTAINS_PROCESS]->(mp:Process {processType:'Manufacturing'})
WHERE $artifactId IS NULL OR art.id = $artifactId
MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(mat:Material)
WHERE p.mass_g IS NOT NULL
WITH art, eCF,
     sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg,
     coalesce(mp.energyIntensity_kWh_per_kg, 20.0) AS eInt,
     sum(p.mass_g*hc.quantity/1000.0 * coalesce(mat.gwp_A1_kgCO2e_per_kg,0.0)) AS s3up
WITH art, s3up,
     mass_kg * eInt * eCF AS s2
RETURN art.id AS artifactId, art.name AS gripper,
       0.0                         AS scope1_kgCO2e,
       round(s2, 4)                AS scope2_kgCO2e,
       round(s3up, 4)              AS scope3_upstream_kgCO2e,
       round(s2 + s3up, 4)         AS total_cradle_to_gate_kgCO2e,
       'Scope 1 excluded: no on-site fossil combustion modelled' AS note
ORDER BY total_cradle_to_gate_kgCO2e DESC;
