// sensitivity_oat.cypher  --  One-at-a-time-Sensitivität auf den Klimawert.
// Variiert je Werkstoff-GWP-Literal um +-$delta und zeigt die Wirkung auf den
// Greifer-Klimawert (Variante-B-Logik).  Parameter: $artifactId, $delta (z.B. 0.1).
WITH coalesce($delta, 0.1) AS delta
MATCH (art:Artifact {id:$artifactId})-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
      -[:USES_MATERIAL]->(m:Material)
WHERE m.gwp_A1_kgCO2e_per_kg IS NOT NULL AND p.mass_g IS NOT NULL
WITH delta, m, sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg
WITH delta, m.name AS material, mass_kg * m.gwp_A1_kgCO2e_per_kg AS base
WITH collect({material:material, base:base}) AS rows, delta, sum(base) AS total
UNWIND rows AS r
RETURN r.material                              AS material,
       round(r.base, 4)                        AS base_kgCO2e,
       round(r.base * delta, 4)                AS plusminus_kgCO2e,
       round(100.0 * r.base / total, 1)        AS share_of_total_pct
ORDER BY base_kgCO2e DESC;
