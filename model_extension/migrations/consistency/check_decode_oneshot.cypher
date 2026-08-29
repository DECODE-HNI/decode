// ============================================================================
// check_decode_oneshot.cypher  --  consistency review, Layer 4, single query
// ----------------------------------------------------------------------------
// Same checks as check_decode.cypher, folded into ONE statement for Neo4j
// Browser. Returns ONLY the rows that need attention:
//   * an EMPTY result table  =  the logical DECODE embedding is intact.
//   * every row shown is a finding (n <> expect) or an 'info' row.
// Read-only. Paste the whole file, run once.
// ============================================================================
CALL {
  MATCH (:Part)-[:USES_MATERIAL]->(m:Material) WHERE m.id IS NULL
  RETURN 'R1 USES_MATERIAL target without Material.id' AS check, count(m) AS n, '0' AS expect
UNION ALL
  MATCH (p:Process) WHERE p.id IS NULL
  RETURN 'R2 Process without id' AS check, count(p) AS n, '0' AS expect
UNION ALL
  MATCH (p:Process) WHERE coalesce(p.processType,'') = ''
  RETURN 'R3 Process without processType' AS check, count(p) AS n, '0' AS expect
UNION ALL
  MATCH (r:Requirement) WHERE r.sustainabilityIndicatorRef IS NOT NULL
    AND NOT EXISTS { (ic:ImpactCategory) WHERE ic.id = r.sustainabilityIndicatorRef }
  RETURN 'R4 sustainabilityIndicatorRef -> missing ImpactCategory' AS check, count(r) AS n, '0' AS expect
UNION ALL
  MATCH (r:Requirement) WHERE r.sustainabilityIndicatorRef IS NOT NULL
    AND (r.sustainabilityThreshold IS NULL OR coalesce(r.sustainabilityOperator,'') = '')
  RETURN 'R5 sustainability Requirement missing threshold/operator' AS check, count(r) AS n, '0' AS expect
UNION ALL
  MATCH (tc:TestCase)
  WHERE NOT coalesce(tc.sustainabilityStatus,'') IN ['passed','failed','inconclusive','notEvaluated']
     OR (tc.sustainabilityStatus IN ['passed','failed'] AND tc.sustainabilityResult IS NULL)
  RETURN 'R6 TestCase status not in enum / decided without result' AS check, count(tc) AS n, '0' AS expect
UNION ALL
  MATCH (tc:TestCase) WHERE tc.sustainabilityStatus IN ['passed','failed']
    AND NOT EXISTS {
      (tc)-[:HAS_ASSESSMENT]->(:Assessment)-[:HAS_RESULT]->(:ImpactResult)-[:FOR_CATEGORY]->(:ImpactCategory)
    }
  RETURN 'R7 decided TestCase without a full assessment->category chain' AS check, count(tc) AS n, '0' AS expect
UNION ALL
  MATCH (p:Process) WHERE p.lifecycleModule IS NULL
  RETURN 'R8 Process without lifecycleModule (spec sec.7 said not-yet-in-schema; DE-01)' AS check, count(p) AS n, '0' AS expect
UNION ALL
  MATCH ()-[r:REALIZES|AFFECTS]->()
  RETURN 'R9 REALIZES/AFFECTS present (spec sec.5: deferred to rebuild)' AS check, count(r) AS n, 'info' AS expect
UNION ALL
  MATCH (art:Artifact)-[:SATISFIES_REQUIREMENT]->(r:Requirement) WHERE r.id STARTS WITH 'REQ_SUS_'
  WITH DISTINCT art WHERE NOT EXISTS { (art)<-[:TESTS]-(:TestCase) }
  RETURN 'V1 slice artifact with no TestCase' AS check, count(art) AS n, '0' AS expect
UNION ALL
  MATCH (art:Artifact)-[:SATISFIES_REQUIREMENT]->(req:Requirement)
  WHERE req.id STARTS WITH 'REQ_SUS_'
    AND NOT EXISTS { (art)<-[:TESTS]-(tc:TestCase)-[:VERIFIES]->(req) }
  RETURN 'V2 SATISFIES_REQUIREMENT pair with no TESTS+VERIFIES TestCase' AS check, count(*) AS n, '0' AS expect
UNION ALL
  MATCH (tc:TestCase)-[:VERIFIES]->(req:Requirement)
  WHERE req.sustainabilityIndicatorRef IS NOT NULL
    AND tc.sustainabilityStatus IN ['passed','failed']
    AND NOT EXISTS {
      (tc)-[:HAS_ASSESSMENT]->(:Assessment)-[:HAS_RESULT]->(:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory)
      WHERE ic.id = req.sustainabilityIndicatorRef
    }
  RETURN 'V3 decided TestCase evaluated a category != requirement indicatorRef' AS check, count(tc) AS n, '0' AS expect
UNION ALL
  MATCH (art:Artifact)-[sr:SATISFIES_REQUIREMENT]->(req:Requirement)<-[:VERIFIES]-(tc:TestCase)-[:TESTS]->(art)
  WHERE req.id STARTS WITH 'REQ_SUS_'
    AND coalesce(sr.verificationStatus,'') <> coalesce(tc.sustainabilityStatus,'')
  RETURN 'V4 SATISFIES_REQUIREMENT.verificationStatus != TestCase status' AS check, count(*) AS n, '0' AS expect
UNION ALL
  MATCH (fw:ExternalFramework) WHERE NOT EXISTS { ( )-[:MAPS_TO]->(fw) }
  RETURN 'F1 ExternalFramework with no inbound MAPS_TO' AS check, count(fw) AS n, '0' AS expect
UNION ALL
  MATCH (x)-[:MAPS_TO]->(t) WHERE NOT t:ExternalFramework
  RETURN 'F2 MAPS_TO target is not an ExternalFramework' AS check, count(*) AS n, '0' AS expect
UNION ALL
  MATCH (m:ImpactAssessmentMethod)
  WHERE NOT EXISTS { (m)-[:MAPS_TO]->(:ExternalFramework) }
    AND NOT EXISTS { (m)<-[:USES_METHOD]-(:Assessment)-[:APPLIES_APPROACH]->(:AssessmentApproach)-[:MAPS_TO]->(:ExternalFramework) }
  RETURN 'F3 ImpactAssessmentMethod with no path to an ExternalFramework (info: IAM_PCF/IAM_REPAIR)' AS check, count(m) AS n, 'info' AS expect
UNION ALL
  MATCH (art:Artifact)-[:SATISFIES_REQUIREMENT]->(rr:Requirement) WHERE rr.id STARTS WITH 'REQ_SUS_'
  WITH DISTINCT art
  WHERE NOT EXISTS { (:Declaration {type:'DPP'})-[:DECLARES]->(art) }
     OR NOT EXISTS { (:Declaration {type:'EPD'})-[:DECLARES]->(art) }
  RETURN 'D1 slice artifact missing a DPP or EPD Declaration' AS check, count(art) AS n, '0' AS expect
UNION ALL
  MATCH (d:Declaration)-[:DECLARES]->(art:Artifact), (d)-[:REPORTS]->(ir:ImpactResult)
  WHERE NOT EXISTS { (a:Assessment)-[:HAS_RESULT]->(ir) WHERE (a)-[:ASSESSES]->(art) }
  RETURN 'D2 Declaration REPORTS a result not belonging to its artifact' AS check, count(*) AS n, '0' AS expect
UNION ALL
  MATCH (d:Declaration) WHERE d.status IS NOT NULL AND NOT d.status IN ['draft','verified','published','expired']
  RETURN 'D3 Declaration.status unknown value' AS check, count(d) AS n, '0' AS expect
UNION ALL
  MATCH (d:Declaration) WHERE d.status IN ['verified','published']
    AND NOT EXISTS { (d)-[:REPORTS]->(:ImpactResult) }
  RETURN 'D4 verified/published Declaration with no REPORTS' AS check, count(d) AS n, '0' AS expect
UNION ALL
  UNWIND ['Artifact','Assembly','Part','Material','Process','Flow','ImpactCategory',
          'ImpactAssessmentMethod','Assessment','ImpactResult','Requirement','Feature',
          'ModelScenario','AssessmentApproach','Declaration'] AS need
  OPTIONAL MATCH (x) WHERE need IN labels(x)
  WITH need, count(x) AS c WHERE c = 0
  RETURN 'N1 pre-v3x core label missing or empty' AS check, count(need) AS n, '0' AS expect
UNION ALL
  CALL db.relationshipTypes() YIELD relationshipType WITH collect(relationshipType) AS present
  UNWIND ['HAS_COMPONENT','USES_MATERIAL','MODELED_BY','HAS_FLOW','CHARACTERIZES','HAS_CATEGORY',
          'USES_METHOD','ASSESSES','HAS_RESULT','FOR_CATEGORY','APPLIES_APPROACH','UNDER_SCENARIO',
          'SATISFIES_REQUIREMENT','MAPS_TO','DECLARES','REPORTS'] AS need
  RETURN 'N2 pre-v3x core relationship type missing' AS check,
         sum(CASE WHEN need IN present THEN 0 ELSE 1 END) AS n, '0' AS expect
UNION ALL
  MATCH (n) WHERE (n:TestCase OR n:DQPhase)
    AND any(l IN labels(n) WHERE l IN ['Artifact','Assembly','Part','Material','Process','Flow',
        'ImpactCategory','ImpactAssessmentMethod','Assessment','ImpactResult','Requirement'])
  RETURN 'N3 new label stacked on a core label' AS check, count(n) AS n, '0' AS expect
UNION ALL
  MATCH (n) WHERE n:TestCase OR n:DQPhase OR n:DataQualityCriterion
  RETURN 'N4 new-label node census (info)' AS check, count(n) AS n, 'info' AS expect
}
WITH check, n, expect
WHERE (expect = 'info' AND n > 0) OR (expect <> 'info' AND toString(n) <> expect)
RETURN check, n, expect ORDER BY check;
