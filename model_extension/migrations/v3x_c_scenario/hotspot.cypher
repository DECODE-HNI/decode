// hotspot.cypher -- v3.c base query. No schema change.
// Ranks the elementary flows of the modelled dataset by contribution to one
// EF3.1 category, for the wired (aluminium A1) path.
// Parameters: $categoryId (e.g. 'IC_CLIMATE'), $topN
CALL {
  MATCH (ds:Process)<-[:MODELED_BY]-(:Material)
  WITH DISTINCT ds
  MATCH (ds)-[hf:HAS_FLOW]->(f:Flow)
  WITH f, sum(hf.amount) AS amt
  MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory {id:$categoryId})<-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_EF31'})
  WITH f, amt, collect(c) AS cs
  WITH f, amt,
       [x IN cs WHERE coalesce(x.location,'')=''][0].factor AS fN,
       reduce(s=0.0,x IN cs|s+x.factor)/size(cs) AS fA
  RETURN f, amt * coalesce(fN,fA) AS contribution
}
WITH collect({flow:f.name, contribution:contribution}) AS rows,
     sum(contribution) AS total
UNWIND rows AS r
WITH r, total WHERE r.contribution <> 0
RETURN r.flow AS flow,
       round(r.contribution,8) AS contribution,
       round(100.0 * r.contribution / total, 2) AS pct
ORDER BY abs(contribution) DESC
LIMIT coalesce($topN, 15);
