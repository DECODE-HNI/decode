// ============================================================================
// migration_v3i.cypher  --  Module v3.i: external frameworks + self-describing KG
//   1.3.3 SEEA / environmental-economic accounting   (ExternalFramework, MAPS_TO)
//   3.2.2 environmental knowledge graph              (self-describing; query only)
// Additive. Re-MATCH by id in every statement. Rollback at bottom. 2026-08-29
//
// NOTE 2026-08-29: this migration originally also created AI/ML "docking points"
// (section 5: PredictionModel PM_GWP_SURROGATE, Recommendation
// REC_DEMO_LIGHTWEIGHT_CONTACT, ASSESS_AI_PREPARED, PREDICTS / RECOMMENDS_FOR /
// ESTIMATED_BY). That branch is out of the case-study scope and has been removed
// here and from the live graph -- see model_versions/consistency/remove_ki_stubs.cypher.
// ============================================================================

// --- 1. External framework nodes ---------------------------------------
UNWIND [
  {id:'EF_SEEA',      name:'System of Environmental-Economic Accounting (SEEA-EA)', standard:'UN SEEA 2021',      domain:'macro accounting'},
  {id:'EF_GHGP',      name:'GHG Protocol Corporate + Scope 3 Standard',             standard:'WRI/WBCSD',          domain:'carbon accounting'},
  {id:'EF_EN15804',   name:'EN 15804+A2',                                           standard:'CEN',                domain:'EPD / construction products'},
  {id:'EF_ISO14040',  name:'ISO 14040 / 14044',                                     standard:'ISO',                domain:'LCA principles & requirements'},
  {id:'EF_ISO14046',  name:'ISO 14046',                                             standard:'ISO',                domain:'water footprint'},
  {id:'EF_ISO14051',  name:'ISO 14051',                                             standard:'ISO',                domain:'material flow cost accounting'},
  {id:'EF_ISO14045',  name:'ISO 14045',                                             standard:'ISO',                domain:'eco-efficiency assessment'},
  {id:'EF_ISO59020',  name:'ISO 59020',                                             standard:'ISO',                domain:'circularity measurement'},
  {id:'EF_PEF',       name:'Product Environmental Footprint / EF 3.1',              standard:'EC JRC',             domain:'LCIA method'},
  {id:'EF_ESPR',      name:'ESPR / Digital Product Passport',                       standard:'EU 2024/1781',       domain:'product data disclosure'}
] AS f
MERGE (x:ExternalFramework {id:f.id})
  SET x.name=f.name, x.standard=f.standard, x.domain=f.domain, x.module='v3.i';

// --- 2. MAPS_TO: methods / approaches / categories / declarations -> frameworks
UNWIND [
  {from:'IAM_EF31',   fw:'EF_PEF',      element:'LCIA method'},
  {from:'IAM_RECIPE', fw:'EF_ISO14040', element:'LCIA method (ReCiPe follows ISO 14040/44)'},
  {from:'IAM_GHG',    fw:'EF_GHGP',     element:'scoped inventory method'},
  {from:'IAM_MCI',    fw:'EF_ISO59020', element:'circularity indicator'}
] AS m
MATCH (src:ImpactAssessmentMethod {id:m.from}), (fw:ExternalFramework {id:m.fw})
MERGE (src)-[r:MAPS_TO]->(fw) SET r.element=m.element, r.module='v3.i';

UNWIND [
  {from:'APM_EEA',            fw:'EF_SEEA',     element:'method maps onto SEEA-EA ecosystem/asset accounts'},
  {from:'APM_LCA',            fw:'EF_ISO14040', element:'method family'},
  {from:'APM_CF_H2O',         fw:'EF_ISO14046', element:'method'},
  {from:'APM_MFCA',           fw:'EF_ISO14051', element:'method'},
  {from:'APM_ECO_EFFICIENCY', fw:'EF_ISO14045', element:'method'},
  {from:'APM_CIRCULARITY',    fw:'EF_ISO59020', element:'method'}
] AS m
MATCH (src:AssessmentApproach {id:m.from}), (fw:ExternalFramework {id:m.fw})
MERGE (src)-[r:MAPS_TO]->(fw) SET r.element=m.element, r.module='v3.i';

MATCH (d:Declaration)
MATCH (fw:ExternalFramework {id: CASE WHEN d.type='EPD' THEN 'EF_EN15804' ELSE 'EF_ESPR' END})
MERGE (d)-[r:MAPS_TO]->(fw) SET r.element='declaration conforms to', r.module='v3.i';

// --- 3. SEEA (1.3.3) demonstrator -- register type, no ImpactResult -------
MERGE (as:Assessment {id:'ASSESS_SEEA_ART_V_AL'})
  ON CREATE SET as.name='SEEA mapping - V-groove jaws',
                as.assessmentType='environmental-economic accounting mapping',
                as.methodology='map gripper impact results onto SEEA-EA account structure (no national-accounts computation in the KG)',
                as.status='prepared', as.systemBoundary='n/a (framework mapping)',
                as.functionalUnit='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper';
MATCH (as:Assessment {id:'ASSESS_SEEA_ART_V_AL'}), (art:Artifact {id:'ART_V_AL'}),
      (ap:AssessmentApproach {id:'APM_EEA'})
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:APPLIES_APPROACH]->(ap);

// --- 4. environmental knowledge graph (3.2.2) demonstrator --------------
// The graph itself is the artefact; base_queries/kg_self_description.cypher is the "result".
MERGE (as:Assessment {id:'ASSESS_ENVKG'})
  ON CREATE SET as.name='Environmental knowledge graph - self description',
                as.assessmentType='knowledge-graph transparency',
                as.methodology='the Ned2 graph is itself the environmental-transparency artefact; see kg_self_description.cypher',
                as.status='calculated', as.systemBoundary='n/a';
MATCH (as:Assessment {id:'ASSESS_ENVKG'}), (p:Product), (ap:AssessmentApproach {id:'APM_ENV_KG'})
MERGE (as)-[:ASSESSES]->(p)
MERGE (as)-[:APPLIES_APPROACH]->(ap);

// --- 5. AI docking points -- REMOVED 2026-08-29 (out of case-study scope).
//        Was: PredictionModel PM_GWP_SURROGATE (+PREDICTS), Recommendation
//        REC_DEMO_LIGHTWEIGHT_CONTACT (+RECOMMENDS_FOR), ASSESS_AI_PREPARED
//        (+APPLIES_APPROACH to the five 3.1.x/3.3.1-2 taxonomy nodes), and one
//        illustrative ESTIMATED_BY edge. See consistency/remove_ki_stubs.cypher
//        for the exact prior content and its rollback.

// --- verification ---------------------------------------------------
MATCH (x:ExternalFramework) OPTIONAL MATCH ()-[m:MAPS_TO]->(x)
RETURN x.id AS framework, count(m) AS incomingMaps ORDER BY framework;
MATCH (ap:AssessmentApproach {level:'method'})
OPTIONAL MATCH (ap)<-[:APPLIES_APPROACH]-(as:Assessment)
WITH ap, count(DISTINCT as) AS n
RETURN sum(CASE WHEN n>0 THEN 1 ELSE 0 END) AS methodsWithAssessments, count(ap) AS totalMethods;
MATCH (pm:PredictionModel) RETURN pm.id, pm.status;
MATCH (rec:Recommendation) RETURN rec.id, rec.status;

// --- rollback -----------------------------------------------------
// MATCH ()-[r:MAPS_TO {module:'v3.i'}]->() DELETE r;
// MATCH (x:ExternalFramework {module:'v3.i'}) DETACH DELETE x;
// MATCH (as:Assessment) WHERE as.id IN ['ASSESS_SEEA_ART_V_AL','ASSESS_ENVKG'] DETACH DELETE as;
// (the AI docking-point rollback moved to consistency/remove_ki_stubs.cypher)
