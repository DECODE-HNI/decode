// ============================================================================
// check_decode.cypher   --  consistency review, Layer 4 (logical DECODE embedding)
// ----------------------------------------------------------------------------
// Read-only. Not a software-integration test -- it checks that the graph is a
// faithful LOGICAL target for the RFLPV2 SysML profile and the external
// reporting frameworks: every mapping row in RFLPV2_Extension_Spec.md sec.7
// resolves, the verification chain is reachable end to end for the demonstrator
// slice, every ExternalFramework is connected, the DPP/EPD path is intact, and
// the DQ / demonstrator / consistency work stayed additive.
//
// Each statement returns: check id, a count, the expected value. n <> expect
// (unless expect = 'info') is a finding. Run: CQ_FMT=verbose ./cq.sh check_decode.cypher
// ============================================================================

// ---- R. RFLPV2 spec sec.7 mapping rows resolve in the graph ----------

// R1  Product Element.materialRef  ->  Material.id
MATCH (:Part)-[:USES_MATERIAL]->(m:Material) WHERE m.id IS NULL
RETURN 'R1 USES_MATERIAL target without Material.id' AS check, count(m) AS n, '0' AS expect;

// R2  Process Element.processRef  ->  Process.id
MATCH (p:Process) WHERE p.id IS NULL
RETURN 'R2 Process without id' AS check, count(p) AS n, '0' AS expect;

// R3  Process Element.processType  ->  Process.processType
MATCH (p:Process) WHERE coalesce(p.processType,'') = ''
RETURN 'R3 Process without processType' AS check, count(p) AS n, '0' AS expect;

// R4  System Requirement.sustainabilityIndicatorRef  ->  ImpactCategory.id
MATCH (r:Requirement) WHERE r.sustainabilityIndicatorRef IS NOT NULL
  AND NOT EXISTS { (ic:ImpactCategory) WHERE ic.id = r.sustainabilityIndicatorRef }
RETURN 'R4 sustainabilityIndicatorRef -> missing ImpactCategory' AS check, count(r) AS n, '0' AS expect;

// R5  the four sustainability tags form a fully evaluable expression (spec sec.3)
MATCH (r:Requirement) WHERE r.sustainabilityIndicatorRef IS NOT NULL
  AND (r.sustainabilityThreshold IS NULL OR coalesce(r.sustainabilityOperator,'') = '')
RETURN 'R5 sustainability Requirement missing threshold/operator' AS check, count(r) AS n, '0' AS expect;

// R6  Test Case.sustainabilityResult / -Status  (spec sec.6 semantics)
MATCH (tc:TestCase)
WHERE NOT coalesce(tc.sustainabilityStatus,'') IN ['passed','failed','inconclusive','notEvaluated']
   OR (tc.sustainabilityStatus IN ['passed','failed'] AND tc.sustainabilityResult IS NULL)
RETURN 'R6 TestCase status not in enum / decided without result' AS check, count(tc) AS n, '0' AS expect;

// R7  concrete test run chain: TestCase -HAS_ASSESSMENT-> Assessment -HAS_RESULT->
//     ImpactResult -FOR_CATEGORY-> ImpactCategory  (spec sec.7, four rows)
MATCH (tc:TestCase) WHERE tc.sustainabilityStatus IN ['passed','failed']
  AND NOT EXISTS {
    (tc)-[:HAS_ASSESSMENT]->(:Assessment)-[:HAS_RESULT]->(:ImpactResult)-[:FOR_CATEGORY]->(:ImpactCategory)
  }
RETURN 'R7 decided TestCase without a full assessment->category chain' AS check, count(tc) AS n, '0' AS expect;

// R8  Process.lifecycleModule -- spec sec.7 marks this row still open; the graph
//     has carried it on every Process since v2. 0 here => the spec row is stale
//     and should read live/done, not open (finding DE-01).
MATCH (p:Process) WHERE p.lifecycleModule IS NULL
RETURN 'R8 Process without lifecycleModule (spec sec.7 says not-yet-in-schema)' AS check, count(p) AS n, '0' AS expect;

// R9  REALIZES / AFFECTS -- spec sec.5/7 deliberately defer these to the next
//     rebuild; 0 means the graph still matches that documented state.
MATCH ()-[r:REALIZES|AFFECTS]->()
RETURN 'R9 REALIZES/AFFECTS present (spec sec.5: deferred to rebuild)' AS check, count(r) AS n, 'info' AS expect;

// ---- V. verification-chain reachability -- demonstrator slice --------
// slice = every Artifact that SATISFIES_REQUIREMENT a REQ_SUS_* requirement

// V1  each slice artifact is exercised by at least one TestCase (Test Item link)
MATCH (art:Artifact)-[:SATISFIES_REQUIREMENT]->(:Requirement {})
WHERE EXISTS { (art)-[:SATISFIES_REQUIREMENT]->(rr:Requirement) WHERE rr.id STARTS WITH 'REQ_SUS_' }
WITH DISTINCT art
WHERE NOT EXISTS { (art)<-[:TESTS]-(:TestCase) }
RETURN 'V1 slice artifact with no TestCase' AS check, count(art) AS n, '0' AS expect;

// V2  the loop closes: SATISFIES_REQUIREMENT(art->req) has a matching
//     TestCase that both -TESTS-> art and -VERIFIES-> req
MATCH (art:Artifact)-[:SATISFIES_REQUIREMENT]->(req:Requirement)
WHERE req.id STARTS WITH 'REQ_SUS_'
  AND NOT EXISTS { (art)<-[:TESTS]-(tc:TestCase)-[:VERIFIES]->(req) }
RETURN 'V2 SATISFIES_REQUIREMENT pair with no TESTS+VERIFIES TestCase' AS check, count(*) AS n, '0' AS expect;

// V3  logical embedding: the category the TestCase actually evaluated equals the
//     RFLPV2 requirement's declared sustainabilityIndicatorRef
MATCH (tc:TestCase)-[:VERIFIES]->(req:Requirement)
WHERE req.sustainabilityIndicatorRef IS NOT NULL
  AND tc.sustainabilityStatus IN ['passed','failed']
  AND NOT EXISTS {
    (tc)-[:HAS_ASSESSMENT]->(:Assessment)-[:HAS_RESULT]->(:ImpactResult)
        -[:FOR_CATEGORY]->(ic:ImpactCategory)
    WHERE ic.id = req.sustainabilityIndicatorRef
  }
RETURN 'V3 decided TestCase evaluated a category != requirement indicatorRef' AS check, count(tc) AS n, '0' AS expect;

// V4  status write-back onto SATISFIES_REQUIREMENT (slice)
MATCH (art:Artifact)-[sr:SATISFIES_REQUIREMENT]->(req:Requirement)<-[:VERIFIES]-(tc:TestCase)-[:TESTS]->(art)
WHERE req.id STARTS WITH 'REQ_SUS_'
  AND coalesce(sr.verificationStatus,'') <> coalesce(tc.sustainabilityStatus,'')
RETURN 'V4 SATISFIES_REQUIREMENT.verificationStatus != TestCase status' AS check, count(*) AS n, '0' AS expect;

// ---- F. ExternalFramework coverage --------------------------------

// F1  every ExternalFramework has at least one inbound MAPS_TO
MATCH (fw:ExternalFramework) WHERE NOT EXISTS { ( )-[:MAPS_TO]->(fw) }
RETURN 'F1 ExternalFramework with no inbound MAPS_TO' AS check, count(fw) AS n, '0' AS expect;

// F2  no MAPS_TO points anywhere other than an ExternalFramework
MATCH (x)-[:MAPS_TO]->(t) WHERE NOT t:ExternalFramework
RETURN 'F2 MAPS_TO target is not an ExternalFramework' AS check, count(*) AS n, '0' AS expect;

// F3  LCIA methods tied to an external framework (direct or via a mapped
//     AssessmentApproach). Info: IAM_PCF / IAM_REPAIR have no framework node
//     (ISO 14067 / EN 45554 are not modelled) -- finding DE-02.
MATCH (m:ImpactAssessmentMethod)
WHERE NOT EXISTS { (m)-[:MAPS_TO]->(:ExternalFramework) }
  AND NOT EXISTS { (m)<-[:USES_METHOD]-(:Assessment)-[:APPLIES_APPROACH]->(:AssessmentApproach)-[:MAPS_TO]->(:ExternalFramework) }
RETURN 'F3 ImpactAssessmentMethod with no path to an ExternalFramework (info)' AS check, count(m) AS n, 'info' AS expect;

// ---- D. Digital Product Passport / EPD path ----------------------

// D1  each slice artifact has both a DPP and an EPD Declaration via DECLARES
MATCH (art:Artifact)-[:SATISFIES_REQUIREMENT]->(rr:Requirement) WHERE rr.id STARTS WITH 'REQ_SUS_'
WITH DISTINCT art
WHERE NOT EXISTS { (:Declaration {type:'DPP'})-[:DECLARES]->(art) }
   OR NOT EXISTS { (:Declaration {type:'EPD'})-[:DECLARES]->(art) }
RETURN 'D1 slice artifact missing a DPP or EPD Declaration' AS check, count(art) AS n, '0' AS expect;

// D2  a Declaration only REPORTS results that belong to the artifact it DECLARES
MATCH (d:Declaration)-[:DECLARES]->(art:Artifact), (d)-[:REPORTS]->(ir:ImpactResult)
WHERE NOT EXISTS { (a:Assessment)-[:HAS_RESULT]->(ir) WHERE (a)-[:ASSESSES]->(art) }
RETURN 'D2 Declaration REPORTS a result not belonging to its artifact' AS check, count(*) AS n, '0' AS expect;

// D3  Declaration.status vocabulary
MATCH (d:Declaration) WHERE d.status IS NOT NULL
  AND NOT d.status IN ['draft','verified','published','expired']
RETURN 'D3 Declaration.status unknown value' AS check, count(d) AS n, '0' AS expect;

// D4  a verified/published Declaration actually carries content
MATCH (d:Declaration) WHERE d.status IN ['verified','published']
  AND NOT EXISTS { (d)-[:REPORTS]->(:ImpactResult) }
RETURN 'D4 verified/published Declaration with no REPORTS' AS check, count(d) AS n, '0' AS expect;

// ---- N. additive & non-breaking ---------------------------------

// N1  every pre-v3x core label still populated
CALL db.labels() YIELD label WITH collect(label) AS present
UNWIND ['Artifact','Assembly','Part','Material','Process','Flow','ImpactCategory',
        'ImpactAssessmentMethod','Assessment','ImpactResult','Requirement','Feature',
        'ModelScenario','AssessmentApproach','Declaration'] AS need
WITH need, present, need IN present AS ok
WITH need, ok CALL (need, ok) {
  WITH need, ok MATCH (n) WHERE ok AND need IN labels(n) RETURN count(n) AS c
}
WITH sum(CASE WHEN ok AND c > 0 THEN 0 ELSE 1 END) AS missing
RETURN 'N1 pre-v3x core label missing or empty' AS check, missing AS n, '0' AS expect;

// N2  every pre-v3x core relationship type still present
CALL db.relationshipTypes() YIELD relationshipType WITH collect(relationshipType) AS present
UNWIND ['HAS_COMPONENT','USES_MATERIAL','MODELED_BY','HAS_FLOW','CHARACTERIZES','HAS_CATEGORY',
        'USES_METHOD','ASSESSES','HAS_RESULT','FOR_CATEGORY','APPLIES_APPROACH','UNDER_SCENARIO',
        'SATISFIES_REQUIREMENT','MAPS_TO','DECLARES','REPORTS'] AS need
RETURN 'N2 pre-v3x core relationship type missing' AS check,
       sum(CASE WHEN need IN present THEN 0 ELSE 1 END) AS n, '0' AS expect;

// N3  no node got a NEW label stacked onto a pre-existing core label
MATCH (n) WHERE (n:TestCase OR n:DQPhase)
  AND any(l IN labels(n) WHERE l IN ['Artifact','Assembly','Part','Material','Process','Flow',
      'ImpactCategory','ImpactAssessmentMethod','Assessment','ImpactResult','Requirement'])
RETURN 'N3 new label stacked on a core label' AS check, count(n) AS n, '0' AS expect;

// N4  new-label census (info)
MATCH (n) WHERE n:TestCase OR n:DQPhase OR n:DataQualityCriterion
RETURN 'N4 new-label node census (info)' AS check, count(n) AS n, 'info' AS expect;
