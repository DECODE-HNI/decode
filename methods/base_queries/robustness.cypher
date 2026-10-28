// robustness.cypher  --  robustness/resilience analysis.
// Spread of an indicator per gripper across the available data variants
// (A-realdataset vs. B-literal) or scenarios -- as an approximation of an ensemble.
// Parameters: $resultType (e.g. 'Climate change').
MATCH (as:Assessment)-[:ASSESSES]->(art:Artifact), (as)-[:HAS_RESULT]->(ir:ImpactResult)
WHERE ir.resultType = coalesce($resultType,'Climate change') AND ir.status = 'calculated'
WITH art, collect({variant:coalesce(as.dataVariant,'base'), scenario:coalesce(ir.scenarioRef,'-'), value:ir.value}) AS ens
WHERE size(ens) > 1
WITH art, ens,
     reduce(mn=999999.0, e IN ens | CASE WHEN e.value < mn THEN e.value ELSE mn END) AS lo,
     reduce(mx=-999999.0, e IN ens | CASE WHEN e.value > mx THEN e.value ELSE mx END) AS hi,
     reduce(s=0.0, e IN ens | s + e.value)/size(ens) AS mean
RETURN art.name AS gripper,
       size(ens)                    AS ensembleSize,
       round(lo,4)                  AS min,
       round(mean,4)                AS mean,
       round(hi,4)                  AS max,
       round(hi-lo,4)               AS spread,
       CASE WHEN mean>0 THEN round(100.0*(hi-lo)/mean,1) ELSE null END AS spread_pct
ORDER BY spread_pct DESC;
