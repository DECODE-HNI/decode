// water_footprint.cypher  --  Umweltfußabdruck H2O (ISO 14046), Näherung.
// Nutzt die vorhandenen IC_EF_WATER_USE-Charakterisierungsfaktoren (AWARE-artig,
// regionalisiert via CHARACTERIZES.location) auf den MODELED_BY-Datensätzen.
// Parameter: $artifactId (oder null).
CALL {
  MATCH (ds:Process)<-[:MODELED_BY]-(:Material)
  WITH DISTINCT ds
  MATCH (ds)-[hf:HAS_FLOW]->(f:Flow)
  WITH ds, f, sum(hf.amount) AS amt
  MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory {id:'IC_EF_WATER_USE'})
  WITH ds, f, amt, collect(c) AS cs
  WITH ds, f, amt,
       [x IN cs WHERE coalesce(x.location,'')=''][0].factor AS fN,
       reduce(s=0.0,x IN cs|s+x.factor)/size(cs) AS fA
  RETURN ds, sum(amt*coalesce(fN,fA)) AS perKg
}
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
      -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(ds)
WHERE ($artifactId IS NULL OR art.id = $artifactId) AND p.mass_g IS NOT NULL
WITH art, ds, perKg, sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg
RETURN art.id AS artifactId, art.name AS gripper,
       round(sum(mass_kg*perKg),4) AS waterUse_m3worldEq
ORDER BY waterUse_m3worldEq DESC;
