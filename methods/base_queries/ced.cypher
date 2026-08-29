// ced.cypher  --  kumulierter Energieverbrauch (CED), Näherung.
// A3-Anteil: Fertigungsstrom (Process.energyIntensity_kWh_per_kg x Bauteilmasse).
// A1-Anteil: fossiler Ressourceneinsatz aus IC_EF_EF_RESOURCE_USE_FOSSILS (MJ)
// auf den MODELED_BY-Datensätzen, wo Faktoren vorhanden sind.
// Parameter: $artifactId (oder null).  1 kWh = 3.6 MJ.
MATCH (art:Artifact)
WHERE ($artifactId IS NULL OR art.id = $artifactId)

CALL (art) {
  MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
  OPTIONAL MATCH (mp:Process {processType:'Manufacturing'})-[:APPLIES_TO]->(p)
  RETURN sum( (p.mass_g*hc.quantity)/1000.0 * coalesce(mp.energyIntensity_kWh_per_kg,20.0) ) * 3.6 AS a3_MJ
}
CALL (art) {
  OPTIONAL MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
        -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(ds:Process)
  OPTIONAL MATCH (ds)-[hf:HAS_FLOW]->(f:Flow)-[c:CHARACTERIZES]->(:ImpactCategory {id:'IC_EF_EF_RESOURCE_USE_FOSSILS'})
  WITH p, hc, sum(hf.amount * c.factor) AS perKg_MJ
  RETURN sum( coalesce(perKg_MJ,0) * (coalesce(p.mass_g,0)*coalesce(hc.quantity,0))/1000.0 ) AS a1_MJ
}
RETURN art.id AS artifactId, art.name AS gripper,
       round(a1_MJ,2) AS ced_A1_MJ, round(a3_MJ,2) AS ced_A3_MJ,
       round(a1_MJ + a3_MJ,2) AS ced_total_MJ
ORDER BY ced_total_MJ DESC;
