// impact_chain.cypher  --  Wirkkettenanalyse.
// Zeigt für ein Ergebnis die Nachvollziehbarkeitskette rückwärts:
//   ImpactResult -[:BASED_ON]-> (Feature|CoreProperty|DataItem)      (v3.d, direkt)
//   ImpactResult -[:FOR_CATEGORY]-> ImpactCategory <-[:CHARACTERIZES]- Flow
//              <-[:HAS_FLOW]- Process <-[:MODELED_BY]- Material <-[:USES_MATERIAL]- Part
//              <-[:HAS_COMPONENT*]- Artifact -[:SATISFIES_REQUIREMENT]-> Requirement
// Parameter: $artifactId.
MATCH (art:Artifact {id:$artifactId})

// direkte BASED_ON-Kette (strukturelle Indikatoren)
OPTIONAL MATCH (as:Assessment)-[:ASSESSES]->(art), (as)-[:HAS_RESULT]->(ir:ImpactResult)-[:BASED_ON]->(basis)
WITH art, collect(DISTINCT ir.resultType + '  <-  ' + labels(basis)[0] + ':' + coalesce(basis.name,basis.id)) AS direkteKette

// LCI-Kette (inventarbasierte Indikatoren)
OPTIONAL MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(m:Material)-[:MODELED_BY]->(ds:Process)
OPTIONAL MATCH (p)<-[:APPLIES_TO]-(mp:Process {processType:'Manufacturing'})
WITH art, direkteKette,
     collect(DISTINCT p.name + '  ->  ' + m.name + '  ->  Datensatz ' + ds.id +
             coalesce('  (+ ' + mp.id + ')','')) AS lciKette

// erfüllte Anforderungen mit Nachhaltigkeitsbezug
OPTIONAL MATCH (art)-[:SATISFIES_REQUIREMENT]->(req:Requirement)
WHERE req.sustainabilityIndicatorRef IS NOT NULL
WITH art, direkteKette, lciKette,
     collect(DISTINCT req.id + ': ' + req.sustainabilityIndicatorRef + ' ' + req.sustainabilityOperator + ' ' + toString(req.sustainabilityThreshold)) AS anforderungen

RETURN art.name AS gripper, direkteKette, lciKette, anforderungen;
