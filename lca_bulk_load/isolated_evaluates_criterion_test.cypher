MATCH ()-[r:EVALUATES_CRITERION]->() DELETE r;

LOAD CSV WITH HEADERS FROM 'file:///r_6_EVALUATES_CRITERION_DataQuality_TO_DataQualityCriterion.csv' AS row
WITH row
CALL (row) {
  MATCH (source: `DataQuality` { `id`: row.`from_id` })
  MATCH (target: `DataQualityCriterion` { `id`: row.`to_id` })
  MERGE (source)-[r: `EVALUATES_CRITERION`]->(target)
  SET r.`score` = toFloat(trim(row.`score`))
  SET r.`rating` = row.`rating`
} IN TRANSACTIONS OF 10000 ROWS;

MATCH ()-[r:EVALUATES_CRITERION]->() RETURN count(r) AS evaluates_criterion_count;
