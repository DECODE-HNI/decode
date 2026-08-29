// dynamic_gwp.cypher  --  dynamic LCA (2.1.2): climate with a chosen time horizon.
// Uses CHARACTERIZES_DYNAMIC {timeHorizon} (v3.h, IPCC AR6 GWP20) alongside the
// GWP100 CHARACTERIZES. $timeHorizon 20 -> methane-heavy paths shift up vs 100.
// Parameters: $artifactId (or null), $timeHorizon (20 | 100, default 20).
WITH coalesce($timeHorizon, 20) AS th
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
      -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(ds:Process)
WHERE ($artifactId IS NULL OR art.id = $artifactId) AND p.mass_g IS NOT NULL
CALL (ds, th) {
  MATCH (ds)-[hf:HAS_FLOW]->(f:Flow)
  WITH ds, f, sum(hf.amount) AS amt, th
  OPTIONAL MATCH (f)-[cd:CHARACTERIZES_DYNAMIC {timeHorizon: th}]->(:ImpactCategory {id:'IC_CLIMATE'})
  OPTIONAL MATCH (f)-[c100:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
    WHERE coalesce(c100.location,'') = ''
  WITH ds, amt,
       CASE WHEN th = 100 THEN c100.factor
            ELSE coalesce(cd.factor, c100.factor) END AS fac
  RETURN sum(amt * coalesce(fac, 0.0)) AS perKg
}
WITH art, ds, perKg, th, sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg
WITH art, th, sum(mass_kg * perKg) AS climate
RETURN art.id AS artifactId, art.name AS gripper, th AS timeHorizon_years,
       round(climate, 4) AS climate_kgCO2e
ORDER BY gripper;
