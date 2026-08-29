// design_recommendation.cypher  --  automatisierte Designempfehlung.
// Rankt Greifer-Varianten nach einem Indikator und prüft gegen eine
// Requirement-Nachhaltigkeitsschwelle (v3.d).
// Parameter: $resultType (z.B. 'Climate change'), $dataVariant (z.B. 'B-literal').
MATCH (req:Requirement) WHERE req.sustainabilityThreshold IS NOT NULL
WITH req LIMIT 1
MATCH (as:Assessment)-[:ASSESSES]->(art:Artifact), (as)-[:HAS_RESULT]->(ir:ImpactResult)
WHERE ir.resultType = coalesce($resultType,'Climate change')
  AND coalesce(as.dataVariant,'-') = coalesce($dataVariant,'B-literal')
  AND ir.status = 'calculated'
WITH req, art, ir
ORDER BY ir.value ASC
WITH req, collect({gripper:art.name, family:art.variantFamily, value:ir.value, unit:ir.unit}) AS ranked
UNWIND range(0, size(ranked)-1) AS i
WITH req, ranked[i] AS row, i+1 AS rank
RETURN rank,
       row.gripper                          AS gripper,
       row.family                           AS variantenfamilie,
       round(row.value,4)                   AS wert,
       row.unit                             AS einheit,
       req.sustainabilityOperator + ' ' + toString(req.sustainabilityThreshold) + ' ' + req.sustainabilityUnit AS schwelle,
       CASE WHEN row.value <= req.sustainabilityThreshold THEN 'erfüllt' ELSE 'überschritten' END AS status
ORDER BY rank;
