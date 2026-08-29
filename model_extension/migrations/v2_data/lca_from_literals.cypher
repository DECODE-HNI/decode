// ============================================================================
// lca_from_literals.cypher  --  Variant B base query (read-only).
// EF3.1 A1-A3 per gripper from Material.ef31_factors_A1 literals +
// Process.energyIntensity_kWh_per_kg * electricity CF.
// Parameters: $artifactId (or null), $electricityCF (default 0.38 = DE grid)
// ============================================================================
WITH coalesce($electricityCF, 0.38) AS eCF

// A3 electricity climate per gripper
CALL (eCF) {
  MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
  WHERE p.mass_g IS NOT NULL
  OPTIONAL MATCH (mp:Process {processType:'Manufacturing'})-[:APPLIES_TO]->(p)
  RETURN art AS a3art,
         sum( (p.mass_g*hc.quantity)/1000.0 * coalesce(mp.energyIntensity_kWh_per_kg,20.0) * eCF ) AS a3
}
WITH collect({art:a3art, a3:a3}) AS a3rows

UNWIND a3rows AS row
WITH row.art AS art, row.a3 AS a3
WHERE $artifactId IS NULL OR art.id = $artifactId
MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(m:Material)
WHERE m.ef31_factors_A1 IS NOT NULL AND p.mass_g IS NOT NULL
WITH art, a3, m, (p.mass_g*hc.quantity)/1000.0 AS pm_kg
UNWIND range(0, size(m.ef31_categories)-1) AS i
WITH art, a3, m.ef31_categories[i] AS catId, sum(pm_kg * m.ef31_factors_A1[i]) AS a1
RETURN art.id AS artifactId, art.name AS gripper, catId AS category,
       round(a1 + CASE WHEN catId='IC_CLIMATE' THEN a3 ELSE 0.0 END, 6) AS value,
       round(a1,6) AS a1_only,
       round(CASE WHEN catId='IC_CLIMATE' THEN a3 ELSE 0.0 END,6) AS a3_climate
ORDER BY gripper, category;
