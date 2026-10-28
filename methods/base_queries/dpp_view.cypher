// dpp_view.cypher  --  digital product passport: all available sustainability
// statements about one gripper, bundled.  Parameters: $artifactId (required).
MATCH (art:Artifact {id:$artifactId})
// master data
OPTIONAL MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(m:Material)
WITH art, collect(DISTINCT m.name + ' (' + toString(round(m.recycledContentAssumed*100,0)) + '% recycled content)') AS materials,
     round(sum(p.mass_g*hc.quantity),1) AS mass_g
// results of all methods
OPTIONAL MATCH (as:Assessment)-[:ASSESSES]->(art), (as)-[:HAS_RESULT]->(ir:ImpactResult)
WHERE ir.status = 'calculated'
WITH art, materials, mass_g,
     collect(DISTINCT {method:as.methodology, variant:coalesce(as.dataVariant,'-'),
                       indicator:ir.resultType, value:ir.value, unit:ir.unit}) AS results
// repairability + circularity directly
OPTIONAL MATCH (art) WITH art, materials, mass_g, results, art.repairabilityClass AS repairClass, art.disassemblyReversibility AS reversibility
OPTIONAL MATCH (:Assessment {id:'ASSESS_MCI_'+art.id})-[:HAS_RESULT]->(mci:ImpactResult)
RETURN art.name AS gripper,
       mass_g,
       materials,
       repairClass AS repairability_class,
       reversibility AS disassembly_reversibility,
       mci.value AS circularity_MCI,
       results AS impact_results;
