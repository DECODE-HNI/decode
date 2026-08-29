// kg_self_description.cypher  --  environmental knowledge graph (3.2.2).
// The graph is itself the transparency artefact; this query is its "result":
// a census of what the graph currently holds -- labels, relationship types,
// assessment methods, and how many of the 29 taxonomy methods are addressable
// vs. carry a real assessment. No parameters.
CALL {
  MATCH (n) UNWIND labels(n) AS l
  RETURN 'label' AS kind, l AS name, count(*) AS n
}
RETURN kind, name, n ORDER BY n DESC
UNION
CALL {
  MATCH ()-[r]->()
  RETURN 'relationshipType' AS kind, type(r) AS name, count(*) AS n
}
RETURN kind, name, n ORDER BY n DESC
UNION
CALL {
  MATCH (im:ImpactAssessmentMethod)
  OPTIONAL MATCH (im)-[:HAS_CATEGORY]->(ic:ImpactCategory)
  RETURN 'method' AS kind, im.id AS name, count(DISTINCT ic) AS n
}
RETURN kind, name, n ORDER BY name
UNION
CALL {
  MATCH (ap:AssessmentApproach {level:'method'})
  OPTIONAL MATCH (ap)<-[:APPLIES_APPROACH]-(as:Assessment)
  WITH ap, count(DISTINCT as) AS a
  RETURN 'taxonomyMethod' AS kind,
         CASE WHEN a > 0 THEN 'with assessment' ELSE 'addressable only' END AS name,
         count(*) AS n
}
RETURN kind, name, n ORDER BY name;
