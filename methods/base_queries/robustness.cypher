// robustness.cypher  --  Robustheits-/Resilienzanalyse.
// Streuung eines Indikators je Greifer über die verfügbaren Datenvarianten
// (A-realdataset vs. B-literal) bzw. Szenarien -- als Näherung eines Ensembles.
// Parameter: $resultType (z.B. 'Climate change').
MATCH (as:Assessment)-[:ASSESSES]->(art:Artifact), (as)-[:HAS_RESULT]->(ir:ImpactResult)
WHERE ir.resultType = coalesce($resultType,'Climate change') AND ir.status = 'calculated'
WITH art, collect({variant:coalesce(as.dataVariant,'base'), scenario:coalesce(ir.scenarioRef,'-'), value:ir.value}) AS ens
WHERE size(ens) > 1
WITH art, ens,
     reduce(mn=999999.0, e IN ens | CASE WHEN e.value < mn THEN e.value ELSE mn END) AS lo,
     reduce(mx=-999999.0, e IN ens | CASE WHEN e.value > mx THEN e.value ELSE mx END) AS hi,
     reduce(s=0.0, e IN ens | s + e.value)/size(ens) AS mean
RETURN art.name AS gripper,
       size(ens)                    AS ensembleGroesse,
       round(lo,4)                  AS min,
       round(mean,4)                AS mittel,
       round(hi,4)                  AS max,
       round(hi-lo,4)               AS spannweite,
       CASE WHEN mean>0 THEN round(100.0*(hi-lo)/mean,1) ELSE null END AS spannweite_pct
ORDER BY spannweite_pct DESC;
