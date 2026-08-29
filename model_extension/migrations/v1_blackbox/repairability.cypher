// ============================================================================
// repairability.cypher  --  v1 black-box base query.
// Read-only. Recomputes the disassembly / repairability indicator from the
// HAS_COMPONENT connection data and the design features, independent of the
// literal values stored on the Artifact by migration_v1.cypher.
// Parameter: $artifactId (optional; omit / null for all artifacts).
// ============================================================================
MATCH (a:Artifact)
WHERE $artifactId IS NULL OR a.id = $artifactId
CALL {
  WITH a
  MATCH (a)-[hc:HAS_COMPONENT]->(:Assembly) RETURN hc
  UNION
  WITH a
  MATCH (a)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(:Part) RETURN hc
}
WITH a, collect(hc) AS hcs
OPTIONAL MATCH (a)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(pt:Part)
OPTIONAL MATCH (pt)-[:USES_MATERIAL]->(m:Material)
WITH a, hcs, collect(DISTINCT pt) AS parts, collect(DISTINCT m.id) AS mats
OPTIONAL MATCH (a)-[:HAS_FEATURE]->(f:Feature)
WITH a, hcs, parts, mats, collect(DISTINCT f.id) AS feats
WITH a,
     size(hcs)                                  AS connections,
     size([r IN hcs WHERE r.reversible = true]) AS reversibleConnections,
     [r IN hcs | r.connectionType]              AS connectionTypes,
     size(parts)                                AS componentCount,
     size(mats)                                 AS distinctMaterialCount,
     ('FEAT_EASY'      IN feats)                AS toollessRobotInterface,
     ('FEAT_PRINTABLE' IN feats)                AS replaceableContactElement
WITH a, connections, reversibleConnections, connectionTypes,
     componentCount, distinctMaterialCount,
     toollessRobotInterface, replaceableContactElement,
     CASE WHEN connections = 0 THEN null
          ELSE round(toFloat(reversibleConnections) / connections, 3) END AS disassemblyReversibility
RETURN a.id                        AS artifactId,
       a.name                      AS artifact,
       disassemblyReversibility,
       reversibleConnections, connections,
       connectionTypes,
       componentCount, distinctMaterialCount,
       toollessRobotInterface, replaceableContactElement,
       CASE
         WHEN disassemblyReversibility = 1.0 AND toollessRobotInterface AND replaceableContactElement THEN 'A'
         WHEN disassemblyReversibility = 1.0 AND (toollessRobotInterface OR replaceableContactElement) THEN 'B'
         WHEN disassemblyReversibility = 1.0                                                           THEN 'C'
         WHEN disassemblyReversibility >= 0.5                                                          THEN 'D'
         ELSE 'E'
       END                         AS repairabilityClass
ORDER BY repairabilityClass, artifact;
