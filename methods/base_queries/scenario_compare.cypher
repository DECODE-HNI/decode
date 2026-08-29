// scenario_compare.cypher  --  Szenario-gestützte Umweltbewertung (2.2.1).
// Vergleicht einen Indikator je Greifer über die ModelScenario-Knoten.
// Baseline = die Variante-B-Ergebnisse (scenarioRef IS NULL / 'SC_BASELINE'),
// Szenarien = ImpactResult mit gesetztem scenarioRef.
// Parameter: $resultType (default 'Climate change'), $artifactId (oder null).
MATCH (as:Assessment)-[:ASSESSES]->(art:Artifact)
MATCH (as)-[:HAS_RESULT]->(ir:ImpactResult)
WHERE ir.resultType = coalesce($resultType,'Climate change')
  AND ir.status = 'calculated'
  AND ($artifactId IS NULL OR art.id = $artifactId)
  AND (ir.id STARTS WITH 'IR_EF31B_' OR ir.id STARTS WITH 'IR_EF31_SCEN_')
WITH art,
     coalesce(ir.scenarioRef,'SC_BASELINE') AS scenario,
     ir.value AS value
WITH art,
     collect({scenario:scenario, value:value}) AS rows,
     [x IN collect({scenario:scenario, value:value}) WHERE x.scenario='SC_BASELINE'][0].value AS baseline
UNWIND rows AS row
WITH art.id AS artifactId, art.name AS gripper, row.scenario AS scenario,
     round(row.value,4) AS value,
     CASE WHEN baseline IS NULL OR baseline=0 THEN null
          ELSE round(100.0*(row.value-baseline)/baseline,1) END AS pct_vs_baseline
RETURN artifactId, gripper, scenario, value, pct_vs_baseline
ORDER BY gripper, scenario;
