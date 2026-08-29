// eco_efficiency.cypher  --  Ökoeffizienz-Bewertung (ISO 14045), Prototyp.
// Umweltwirkung je Produkt-/Systemwert. Nutzt Assessment.productSystemValue (v3.b)
// bzw. ersatzweise die Materialkosten aus den CostItem-Knoten.
// Parameter: $resultType (z.B. 'Climate change').
MATCH (as:Assessment)-[:ASSESSES]->(art:Artifact), (as)-[:HAS_RESULT]->(ir:ImpactResult)
WHERE ir.resultType = coalesce($resultType,'Climate change') AND ir.status = 'calculated'
OPTIONAL MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)-[:HAS_COST]->(ci:CostItem)
WITH art, ir, as, as.productSystemValue AS psv, sum(ci.amount) AS costSum
WITH art, ir,
     CASE WHEN psv IS NOT NULL AND psv <> 0 THEN psv
          WHEN costSum IS NOT NULL AND costSum <> 0 THEN costSum
          ELSE 1.0 END AS value,
     CASE WHEN psv IS NOT NULL AND psv <> 0 THEN 'productSystemValue'
          WHEN costSum IS NOT NULL AND costSum <> 0 THEN 'EUR (Materialkosten)'
          ELSE 'Platzhalter 1.0' END AS valueBasis
RETURN art.name AS gripper, ir.resultType AS indikator,
       round(ir.value,4)          AS wirkung,
       round(value,4)             AS systemwert,
       valueBasis,
       round(ir.value / value, 6) AS wirkung_je_wert
ORDER BY wirkung_je_wert DESC;
