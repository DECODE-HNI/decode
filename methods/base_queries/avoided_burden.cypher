// avoided_burden.cypher  --  consequential LCA (2.1.3): EN 15804 module D credit.
// Uses (:EndOfLifeRoute)-[:AVOIDS {ratio, avoidedGwp_kgCO2e_per_kg}]->(:Process)
// from v3.h. Credits avoided PRIMARY production for the recyclable material mass
// in each gripper. Reported separately from the cradle-to-gate result (module D).
// Parameters: $artifactId (or null).
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
      -[:USES_MATERIAL]->(m:Material)-[:MODELED_BY]->(ds:Process)
WHERE ($artifactId IS NULL OR art.id = $artifactId) AND p.mass_g IS NOT NULL
MATCH (route:EndOfLifeRoute {id:'EOL_RECYCLING'})-[av:AVOIDS]->(ds)
OPTIONAL MATCH (m)-[hr:HAS_EOL_ROUTE]->(route)
WITH art, m,
     sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg,
     coalesce(hr.fraction, av.ratio) AS recycledFraction,
     av.avoidedGwp_kgCO2e_per_kg AS creditPerKg
WITH art,
     round(sum(mass_kg), 5)                                   AS recyclable_mass_kg,
     round(sum(mass_kg * recycledFraction * creditPerKg), 4)  AS moduleD_credit_kgCO2e
RETURN art.id AS artifactId, art.name AS gripper,
       recyclable_mass_kg,
       -moduleD_credit_kgCO2e AS moduleD_kgCO2e   // negative = credit
ORDER BY moduleD_kgCO2e;
