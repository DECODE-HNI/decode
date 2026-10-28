// impact_chain.cypher  --  impact chain analysis.
// For a result, shows the traceability chain backwards:
//   ImpactResult -[:BASED_ON]-> (Feature|CoreProperty|DataItem)      (v3.d, direct)
//   ImpactResult -[:FOR_CATEGORY]-> ImpactCategory <-[:CHARACTERIZES]- Flow
//              <-[:HAS_FLOW]- Process <-[:MODELED_BY]- Material <-[:USES_MATERIAL]- Part
//              <-[:HAS_COMPONENT*]- Artifact -[:SATISFIES_REQUIREMENT]-> Requirement
// Parameters: $artifactId.
MATCH (art:Artifact {id:$artifactId})

// direct BASED_ON chain (structural indicators)
OPTIONAL MATCH (as:Assessment)-[:ASSESSES]->(art), (as)-[:HAS_RESULT]->(ir:ImpactResult)-[:BASED_ON]->(basis)
WITH art, collect(DISTINCT ir.resultType + '  <-  ' + labels(basis)[0] + ':' + coalesce(basis.name,basis.id)) AS directChain

// LCI chain (inventory-based indicators)
OPTIONAL MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(m:Material)-[:MODELED_BY]->(ds:Process)
OPTIONAL MATCH (p)<-[:APPLIES_TO]-(mp:Process {processType:'Manufacturing'})
WITH art, directChain,
     collect(DISTINCT p.name + '  ->  ' + m.name + '  ->  dataset ' + ds.id +
             coalesce('  (+ ' + mp.id + ')','')) AS lciChain

// satisfied requirements with a sustainability reference
OPTIONAL MATCH (art)-[:SATISFIES_REQUIREMENT]->(req:Requirement)
WHERE req.sustainabilityIndicatorRef IS NOT NULL
WITH art, directChain, lciChain,
     collect(DISTINCT req.id + ': ' + req.sustainabilityIndicatorRef + ' ' + req.sustainabilityOperator + ' ' + toString(req.sustainabilityThreshold)) AS requirements

RETURN art.name AS gripper, directChain, lciChain, requirements;
