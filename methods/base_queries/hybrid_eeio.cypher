// hybrid_eeio.cypher  --  hybrid LCA (2.1.4): process-LCA + EEIO monetary top-up.
// For cost items with no process-LCA dataset behind them, multiply the monetary
// value by the covering EEIOSector's kg CO2e / EUR intensity (v3.h). This is the
// classic tiered-hybrid top-up; here it is illustrative (few CostItem nodes).
// Parameters: $artifactId (or null).
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)-[:HAS_COST]->(ci:CostItem)
WHERE $artifactId IS NULL OR art.id = $artifactId
MATCH (ci)-[cov:COVERED_BY_EEIO]->(e:EEIOSector)
WITH art, e.name AS sector, e.gwpIntensity_kgCO2e_per_EUR AS intensity,
     sum(cov.monetaryValue) AS eur
RETURN art.id AS artifactId, art.name AS gripper, sector,
       round(eur, 4)                 AS monetary_EUR,
       intensity                     AS kgCO2e_per_EUR,
       round(eur * intensity, 4)     AS eeio_topup_kgCO2e
ORDER BY gripper, sector;
