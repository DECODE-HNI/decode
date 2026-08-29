// ghg_inventory.cypher  --  Treibhausgasbilanzierung.
// Bis Process.ghgScope gesetzt ist (siehe method_onepagers/1.1.4), gruppiert
// diese Query den Greifer-GWP ersatzweise nach EN-15804-Lebenszyklusmodul.
// Parameter: $artifactId (oder null), $dataVariant ('B-literal' | 'A-realdataset').
MATCH (as:Assessment)-[:ASSESSES]->(art:Artifact)
WHERE coalesce(as.dataVariant,'-') = coalesce($dataVariant,'B-literal')
  AND ($artifactId IS NULL OR art.id = $artifactId)
MATCH (as)-[:HAS_RESULT]->(ir:ImpactResult {resultType:'Climate change', status:'calculated'})
// A1 vs A3 aus der coverage-Property ableiten (Variante B trennt A1/A3 im a1_only-Feld
// der Basisquery -- hier nur der Gesamtwert plus der A3-Stromklima-Anteil als Schätzung)
OPTIONAL MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
OPTIONAL MATCH (mp:Process {processType:'Manufacturing'})-[:APPLIES_TO]->(p)
WITH art, ir, sum( (coalesce(p.mass_g,0)*coalesce(hc.quantity,0))/1000.0
                   * coalesce(mp.energyIntensity_kWh_per_kg,20.0) * 0.38 ) AS a3_climate
RETURN art.id AS artifactId, art.name AS gripper,
       round(ir.value,4)               AS gwp_total_kgCO2e,
       round(ir.value - a3_climate,4)  AS modul_A1_kgCO2e,
       round(a3_climate,4)             AS modul_A3_kgCO2e
ORDER BY gwp_total_kgCO2e DESC;
