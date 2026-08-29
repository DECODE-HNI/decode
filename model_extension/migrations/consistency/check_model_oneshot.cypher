// ============================================================================
// check_model_oneshot.cypher  --  consistency review, Layer 2, single query
// ----------------------------------------------------------------------------
// Same checks as check_model.cypher, folded into ONE statement so it runs in
// Neo4j Browser with no "multi statement" setting. Returns ONLY the rows that
// need attention:
//   * an EMPTY result table  =  everything is clean.
//   * every row shown is either a finding (n <> expect) or an 'info' row.
// Read-only. Paste the whole file, run once.
// ============================================================================
CALL {
  MATCH (n) WHERE size(labels(n)) = 0
  RETURN 'A1 label-less nodes' AS check, count(n) AS n, '0' AS expect
UNION ALL
  MATCH (n) WHERE size(labels(n)) > 0 AND n.id IS NULL AND NOT labels(n)[0] IN ['HazardStatement']
  RETURN 'A2 nodes without id (id-keyed labels)' AS check, count(n) AS n, '0' AS expect
UNION ALL
  MATCH (n) WHERE n.id IS NOT NULL
  WITH labels(n)[0] AS lbl, n.id AS id, count(*) AS c WHERE c > 1
  RETURN 'A3 duplicate id within label' AS check, count(*) AS n, '0' AS expect
UNION ALL
  MATCH (x) WHERE x.scenarioRef IS NOT NULL AND NOT EXISTS { (ms:ModelScenario) WHERE ms.id = x.scenarioRef }
  RETURN 'B1 scenarioRef -> missing ModelScenario' AS check, count(x) AS n, '0' AS expect
UNION ALL
  MATCH (r:Requirement) WHERE r.sustainabilityIndicatorRef IS NOT NULL
    AND NOT EXISTS { (ic:ImpactCategory) WHERE ic.id = r.sustainabilityIndicatorRef }
  RETURN 'B2 sustainabilityIndicatorRef -> missing ImpactCategory' AS check, count(r) AS n, '0' AS expect
UNION ALL
  MATCH (ir:ImpactResult)
  WHERE NOT (ir)-[:FOR_CATEGORY]->(:ImpactCategory) OR NOT (:Assessment)-[:HAS_RESULT]->(ir)
  RETURN 'B3 ImpactResult missing FOR_CATEGORY or HAS_RESULT' AS check, count(ir) AS n, '0' AS expect
UNION ALL
  MATCH (a:Assessment)
  WHERE NOT EXISTS { (a)-[:ASSESSES]->() }
     OR NOT EXISTS { (a)-[:APPLIES_APPROACH]->() }
     OR NOT EXISTS { (a)-[:UNDER_SCENARIO]->() }
     OR (EXISTS { (a)-[:HAS_RESULT]->(:ImpactResult) } AND NOT EXISTS { (a)-[:USES_METHOD]->() })
  RETURN 'B4 Assessment missing a core edge' AS check, count(a) AS n, '0' AS expect
UNION ALL
  MATCH ()-[c:CHARACTERIZES]->() WHERE c.factor IS NULL
  RETURN 'B5 CHARACTERIZES without factor' AS check, count(c) AS n, '0' AS expect
UNION ALL
  MATCH (m:Material)-[:MODELED_BY]->(p:Process) WHERE NOT (p)-[:HAS_FLOW]->()
  RETURN 'B6 MODELED_BY dataset without HAS_FLOW' AS check, count(*) AS n, '0' AS expect
UNION ALL
  MATCH (tc:TestCase)
  WHERE NOT (tc)-[:VERIFIES]->(:Requirement)
     OR (tc.sustainabilityStatus IN ['passed','failed'] AND NOT (tc)-[:HAS_ASSESSMENT]->(:Assessment))
  RETURN 'B7 TestCase missing VERIFIES / HAS_ASSESSMENT' AS check, count(tc) AS n, '0' AS expect
UNION ALL
  MATCH (ir:ImpactResult) WHERE coalesce(ir.status,'') = 'calculated' AND ir.value IS NULL
  RETURN 'C1 calculated ImpactResult without value' AS check, count(ir) AS n, '0' AS expect
UNION ALL
  MATCH (ir:ImpactResult) WHERE ir.value IS NOT NULL AND NOT (ir.value = ir.value)
  RETURN 'C2 ImpactResult value is NaN' AS check, count(ir) AS n, '0' AS expect
UNION ALL
  MATCH (ir:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory) WHERE ir.value < 0
  RETURN 'C3 negative ImpactResult values (info)' AS check, count(ir) AS n, 'info' AS expect
UNION ALL
  MATCH (iam:ImpactAssessmentMethod)-[:HAS_CATEGORY]->(ic:ImpactCategory)
  WHERE NOT EXISTS { (:Flow)-[:CHARACTERIZES]->(ic) }
  RETURN 'C4 method category with 0 CFs (info: RECIPE FRS/LU expected)' AS check, count(*) AS n, 'info' AS expect
UNION ALL
  MATCH (aE:Assessment)-[:USES_METHOD]->(:ImpactAssessmentMethod {id:'IAM_EF31'})
  MATCH (aE)-[:ASSESSES]->(art:Artifact), (aE)-[:HAS_RESULT]->(irE:ImpactResult)-[:FOR_CATEGORY]->(:ImpactCategory {id:'IC_CLIMATE'})
  WHERE aE.dataVariant = 'A-realdataset' AND irE.value > 0
  MATCH (aR:Assessment {id:'ASSESS_RECIPE_A_' + art.id})-[:HAS_RESULT]->(irR:ImpactResult)-[:FOR_CATEGORY]->(:ImpactCategory {id:'IC_RECIPE_GW'})
  WITH art, irE.value AS ef, irR.value AS re, irR.value / irE.value AS ratio
  WHERE ratio < 0.8 OR ratio > 1.3
  RETURN 'C5 EF3.1-A vs ReCiPe-A climate ratio outside [0.8,1.3]' AS check, count(art) AS n, '0' AS expect
UNION ALL
  MATCH (aA:Assessment {dataVariant:'A-realdataset'})-[:ASSESSES]->(art:Artifact),
        (aA)-[:HAS_RESULT]->(irA:ImpactResult {resultType:'Climate change'})
  MATCH (aB:Assessment {id:'ASSESS_EF31B_' + art.id})-[:HAS_RESULT]->(irB:ImpactResult {resultType:'Climate change'})
  WHERE irA.value > irB.value + 1e-9
  RETURN 'C6 Variant-A climate > Variant-B climate' AS check, count(art) AS n, '0' AS expect
UNION ALL
  MATCH (art:Artifact)
  WHERE EXISTS { (:Assessment {id:'ASSESS_EF31A_' + art.id}) } <> EXISTS { (:Assessment {id:'ASSESS_RECIPE_A_' + art.id}) }
  RETURN 'D1 artifact has EF31A xor RECIPE_A assessment' AS check, count(art) AS n, '0' AS expect
UNION ALL
  MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(m:Material)-[:MODELED_BY]->(ds:Process)
  WHERE m.id <> 'MAT_PA12' AND p.mass_g IS NOT NULL
  WITH DISTINCT art
  MATCH (:Assessment {id:'ASSESS_EF31A_' + art.id})-[:HAS_RESULT]->(irE:ImpactResult)-[:FOR_CATEGORY]->(:ImpactCategory {id:'IC_CLIMATE'})
  MATCH (:Assessment {id:'ASSESS_RECIPE_A_' + art.id})-[:HAS_RESULT]->(irR:ImpactResult)-[:FOR_CATEGORY]->(:ImpactCategory {id:'IC_RECIPE_GW'})
  WHERE abs(irE.value - 0.129650184523) < 1e-6 AND irR.value > 0.129650184523 + 1e-4
  RETURN 'D2 EF31A drops a real-dataset contribution that ReCiPe keeps' AS check, count(art) AS n, '0' AS expect
UNION ALL
  MATCH (dqa:DataQuality {subject:'assessment'})-[er:EVALUATES_CRITERION]->(c:DataQualityCriterion)
  WHERE er.derivation = 'auto-rollup' AND er.score IS NOT NULL
  MATCH (a:Assessment)-[:HAS_DATA_QUALITY]->(dqa)
  MATCH (a)-[:ASSESSES]->(art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)
        -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(ds:Process)
  WHERE p.mass_g IS NOT NULL
  MATCH (ds)-[:HAS_DATA_QUALITY]->(:DataQuality {subject:'lci-dataset'})-[ep:EVALUATES_CRITERION]->(c)
  WHERE ep.derivation IN ['auto','semi-auto'] AND ep.score IS NOT NULL
  WITH dqa, c, er.score AS rollup, min(ep.score) AS trueMin
  WHERE rollup > trueMin
  RETURN 'D3 DQ rollup score > MIN of contributing datasets' AS check, count(*) AS n, '0' AS expect
UNION ALL
  MATCH (p:Process) WHERE EXISTS { (:Material)-[:MODELED_BY]->(p) }
    AND NOT (p)-[:HAS_DATA_QUALITY]->(:DataQuality {subject:'lci-dataset'})
  RETURN 'D4 LCI dataset without an auto DQ node' AS check, count(p) AS n, '0' AS expect
UNION ALL
  MATCH (:Process)-[hf:HAS_FLOW]->() WHERE NOT coalesce(hf.direction,'') IN ['input','output']
  RETURN 'E1 HAS_FLOW.direction not in {input,output}' AS check, count(hf) AS n, '0' AS expect
UNION ALL
  MATCH (:Process)-[hf:HAS_FLOW]->()
  WHERE hf.dataMaturity IS NOT NULL
    AND NOT hf.dataMaturity IN ['background_LCI_secondary_ILCD','screening/reference','measured','estimated']
  RETURN 'E2 HAS_FLOW.dataMaturity unknown value' AS check, count(hf) AS n, '0' AS expect
UNION ALL
  MATCH (tc:TestCase)
  WHERE NOT coalesce(tc.sustainabilityStatus,'') IN ['passed','failed','inconclusive','notEvaluated']
  RETURN 'E4 TestCase.sustainabilityStatus unknown value' AS check, count(tc) AS n, '0' AS expect
UNION ALL
  MATCH (d:Declaration)
  WHERE d.status IS NOT NULL AND NOT d.status IN ['draft','verified','published','expired']
  RETURN 'E5 Declaration.status unknown value' AS check, count(d) AS n, '0' AS expect
UNION ALL
  MATCH (ir:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory)
  WITH ic, count(DISTINCT coalesce(ir.unit,'')) AS units WHERE units > 1
  RETURN 'E6 ImpactCategory with >1 result unit' AS check, count(*) AS n, '0' AS expect
UNION ALL
  MATCH (tc:TestCase)-[:VERIFIES]->(r:Requirement)
  WHERE tc.sustainabilityStatus IN ['passed','failed'] AND tc.sustainabilityResult IS NOT NULL
  WITH tc, r, CASE
      WHEN r.sustainabilityOperator = '<=' AND tc.sustainabilityResult <= r.sustainabilityThreshold THEN 'passed'
      WHEN r.sustainabilityOperator = '>=' AND tc.sustainabilityResult >= r.sustainabilityThreshold THEN 'passed'
      ELSE 'failed' END AS recomputed
  WHERE recomputed <> tc.sustainabilityStatus
  RETURN 'F1 TestCase status <> recomputed threshold check' AS check, count(tc) AS n, '0' AS expect
UNION ALL
  MATCH (art:Artifact)-[sr:SATISFIES_REQUIREMENT]->(r:Requirement)<-[:VERIFIES]-(tc:TestCase)-[:TESTS]->(art)
  WHERE coalesce(sr.verificationStatus,'') <> coalesce(tc.sustainabilityStatus,'')
  RETURN 'F2 SATISFIES_REQUIREMENT.verificationStatus <> TestCase status' AS check, count(*) AS n, '0' AS expect
UNION ALL
  MATCH (d:Declaration)-[:DECLARES]->(art:Artifact), (d)-[:REPORTS]->(ir:ImpactResult)
  WHERE NOT EXISTS { (a:Assessment)-[:HAS_RESULT]->(ir) WHERE (a)-[:ASSESSES]->(art) }
  RETURN 'F3 Declaration REPORTS a result not belonging to its artifact' AS check, count(*) AS n, '0' AS expect
UNION ALL
  MATCH (ir:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory {id:'IC_EF_EF_RESOURCE_USE_FOSSILS'})
  MATCH (a:Assessment {dataVariant:'A-realdataset'})-[:HAS_RESULT]->(ir)
  MATCH (a)-[:ASSESSES]->(art:Artifact)
  WHERE ir.value > 0
    AND NOT EXISTS {
      (art)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(ds:Process)
      WHERE p.mass_g IS NOT NULL AND EXISTS { (ds)-[:HAS_FLOW]->(:Flow)-[:CHARACTERIZES]->(ic) }
    }
  RETURN 'G1 EF31A fossil-resource result with no contributing fossil CF (stale)' AS check, count(ir) AS n, '0' AS expect
UNION ALL
  MATCH (ir:ImpactResult) WHERE ir.computedAt IS NOT NULL AND ir.computedAt < '2026-08-01'
  RETURN 'G2 ImpactResult computedAt older than 2026-08 (info)' AS check, count(ir) AS n, 'info' AS expect
}
WITH check, n, expect
WHERE (expect = 'info' AND n > 0) OR (expect <> 'info' AND toString(n) <> expect)
RETURN check, n, expect ORDER BY check;
