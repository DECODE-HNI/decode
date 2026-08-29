// pollutant_inventory.cypher  --  Schadstoffbilanzierung (1.2.2), Naeherung.
// Aggregiert charakterisierte Emissionsfluesse aus den MODELED_BY-Datensaetzen,
// gruppiert nach Stoff, skaliert auf den Greifer, und haengt die v3.f-
// Gefahrenklassifikation (Flow.hazardClass + HAS_HAZARD -> HazardStatement) an.
// Parameter: $artifactId (oder null), $topN, $hazardOnly (true -> nur klassifizierte).
CALL {
  MATCH (ds:Process)<-[:MODELED_BY]-(:Material)
  WITH DISTINCT ds
  MATCH (ds)-[hf:HAS_FLOW]->(f:Flow)
  WHERE f.casNumber IS NOT NULL AND hf.direction = 'output'
  RETURN ds, f AS flow, f.name AS substance, f.casNumber AS cas, sum(hf.amount) AS perKg
}
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
      -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(ds)
WHERE ($artifactId IS NULL OR art.id = $artifactId) AND p.mass_g IS NOT NULL
WITH art, flow, substance, cas, perKg, sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg
WITH art, flow, substance, cas, sum(perKg * mass_kg) AS amount_kg
WHERE amount_kg <> 0
OPTIONAL MATCH (flow)-[:HAS_HAZARD]->(hs:HazardStatement)
WITH art, substance, cas, amount_kg,
     flow.hazardClass AS hazardClass,
     collect(DISTINCT hs.code) AS hCodes
WHERE coalesce($hazardOnly,false) = false OR hazardClass IS NOT NULL
RETURN art.name AS gripper, substance, cas,
       round(amount_kg, 10) AS emission_kg,
       hazardClass, hCodes
ORDER BY gripper, hazardClass IS NULL, abs(amount_kg) DESC
LIMIT coalesce($topN, 25);
