// dpp_view.cypher  --  Digitaler Produktpass: alle vorliegenden Nachhaltigkeits-
// aussagen zu einem Greifer, gebündelt.  Parameter: $artifactId (Pflicht).
MATCH (art:Artifact {id:$artifactId})
// Stammdaten
OPTIONAL MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(m:Material)
WITH art, collect(DISTINCT m.name + ' (' + toString(round(m.recycledContentAssumed*100,0)) + '% Rezyklat)') AS materials,
     round(sum(p.mass_g*hc.quantity),1) AS mass_g
// Ergebnisse aller Methoden
OPTIONAL MATCH (as:Assessment)-[:ASSESSES]->(art), (as)-[:HAS_RESULT]->(ir:ImpactResult)
WHERE ir.status = 'calculated'
WITH art, materials, mass_g,
     collect(DISTINCT {method:as.methodology, variant:coalesce(as.dataVariant,'-'),
                       indicator:ir.resultType, value:ir.value, unit:ir.unit}) AS results
// Reparierbarkeit + Zirkularität direkt
OPTIONAL MATCH (art) WITH art, materials, mass_g, results, art.repairabilityClass AS repairClass, art.disassemblyReversibility AS reversibility
OPTIONAL MATCH (:Assessment {id:'ASSESS_MCI_'+art.id})-[:HAS_RESULT]->(mci:ImpactResult)
RETURN art.name AS gripper,
       mass_g AS masse_g,
       materials AS werkstoffe,
       repairClass AS reparierbarkeitsklasse,
       reversibility AS demontage_reversibilitaet,
       mci.value AS materialkreislauf_MCI,
       results AS wirkungsergebnisse;
