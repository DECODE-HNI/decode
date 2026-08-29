// ============================================================================
// remove_ki_stubs.cypher  --  consistency review follow-up, 2026-08-29
// ----------------------------------------------------------------------------
// User decision: take the AI / ML ("KI") material out of the graph and the
// docs -- it is not part of the case study's scope. This removes the prepared-
// only prediction/learning taxonomy in full (graph + docs), including the
// rule-based 3.3.3 automated-design-recommendation branch.
//
// KEPT on purpose:
//   * AP_LERNEND (root)            -- still parents APG_MODEL_TRANSPARENCY
//   * APG_MODEL_TRANSPARENCY + APM_DPP + APM_ENV_KG  -- real, backed by
//     dpp_view.cypher / kg_self_description.cypher, not AI
//   * ImpactResult.provenance / .confidence properties -- general, not AI-only
//
// Removed: 11 nodes, 19 relationships.
//   AssessmentApproach: APG_ADAPTIVE_DECISION, APG_AI_FORECAST,
//     APM_AUTO_DESIGN, APM_LEARNING_SCENARIO, APM_PREDICTIVE_ASSESSMENT,
//     APM_AI_LCA_MODELING, APM_IMPACT_FORECAST, APM_SURROGATE
//   PredictionModel: PM_GWP_SURROGATE      (label becomes empty)
//   Recommendation:  REC_DEMO_LIGHTWEIGHT_CONTACT   (label becomes empty)
//   Assessment:      ASSESS_AI_PREPARED
//   -> relationship types PREDICTS, ESTIMATED_BY, RECOMMENDS_FOR fall out of use.
//
// Idempotent (DETACH DELETE of ids that may already be gone). Rollback block
// at the end restores the exact prior state.
// ============================================================================

MATCH (n)
WHERE n.id IN [
  'APG_ADAPTIVE_DECISION','APG_AI_FORECAST',
  'APM_AUTO_DESIGN','APM_LEARNING_SCENARIO','APM_PREDICTIVE_ASSESSMENT',
  'APM_AI_LCA_MODELING','APM_IMPACT_FORECAST','APM_SURROGATE',
  'PM_GWP_SURROGATE','REC_DEMO_LIGHTWEIGHT_CONTACT','ASSESS_AI_PREPARED'
]
DETACH DELETE n;

// --- verification -----------------------------------------------------
MATCH (n) WITH count(n) AS nodes
MATCH ()-[r]->() WITH nodes, count(r) AS rels
CALL db.labels() YIELD label WITH nodes, rels, count(*) AS labels
CALL db.relationshipTypes() YIELD relationshipType WITH nodes, rels, labels, count(*) AS relTypes
RETURN nodes, rels, labels, relTypes;   // expect 5618 / 86632 / 39 / 54

MATCH (n) WHERE n:PredictionModel OR n:Recommendation
RETURN 'residual AI nodes' AS check, count(n) AS n;   // expect 0
MATCH ()-[r:PREDICTS|ESTIMATED_BY|RECOMMENDS_FOR]->()
RETURN 'residual AI rels' AS check, count(r) AS n;    // expect 0
MATCH (ap:AssessmentApproach {id:'AP_LERNEND'})<-[:BROADER]-(child)
RETURN 'AP_LERNEND children kept' AS check, collect(child.id) AS n;  // expect [APG_MODEL_TRANSPARENCY]

// ============================================================================
// ROLLBACK  --  restores the 11 nodes + 19 relationships exactly.
// ----------------------------------------------------------------------------
// CREATE (:AssessmentApproach {id:'APG_AI_FORECAST', name:'KI-gestützte Umweltwirkungsprognose', code:'3.1', level:'group'});
// CREATE (:AssessmentApproach {id:'APG_ADAPTIVE_DECISION', name:'adaptive Szenarien- & Entscheidungsunterstützung', code:'3.3', level:'group'});
// CREATE (:AssessmentApproach {id:'APM_IMPACT_FORECAST', name:'Umweltwirkungsprognosen', code:'3.1.1', level:'method'});
// CREATE (:AssessmentApproach {id:'APM_AI_LCA_MODELING', name:'KI-Lebenszyklusmodellierung', code:'3.1.2', level:'method'});
// CREATE (:AssessmentApproach {id:'APM_SURROGATE', name:'Ersatz- und Näherungsmodelle', code:'3.1.3', level:'method'});
// CREATE (:AssessmentApproach {id:'APM_LEARNING_SCENARIO', name:'lernende Szenario Modelle', code:'3.3.1', level:'method'});
// CREATE (:AssessmentApproach {id:'APM_PREDICTIVE_ASSESSMENT', name:'prädiktive Umweltfolgeabschätzungen', code:'3.3.2', level:'method'});
// CREATE (:AssessmentApproach {id:'APM_AUTO_DESIGN', name:'automatisierte Designempfehlung', code:'3.3.3', level:'method'});
// CREATE (:PredictionModel {id:'PM_GWP_SURROGATE', kind:'surrogate', module:'v3.i', status:'prepared', target:'IC_CLIMATE', algorithm:'(not trained)', trainingDataRef:'would draw on ImpactResult{provenance:"LCI-calculated"}', note:'attachment point for 3.1.3 surrogate models; weights and training live outside the graph'});
// CREATE (:Recommendation {id:'REC_DEMO_LIGHTWEIGHT_CONTACT', module:'v3.i', status:'prepared', provenance:'illustrative', confidence:0.5, basis:'design_recommendation.cypher ranking + v3.g INFLUENCES matrix', text:'Prefer a replaceable printed contact element where payload allows: raises repairability and circularity at a small climate cost.'});
// CREATE (:Assessment {id:'ASSESS_AI_PREPARED', name:'AI methods - prepared (no model executed)', assessmentType:'preparation marker', status:'prepared', methodology:'attachment points only: PredictionModel/Recommendation types, ImpactResult.provenance/confidence, BASED_ON, ESTIMATED_BY'});
// MATCH (ler:AssessmentApproach {id:'AP_LERNEND'}) MATCH (g:AssessmentApproach) WHERE g.id IN ['APG_AI_FORECAST','APG_ADAPTIVE_DECISION'] MERGE (g)-[:BROADER]->(ler);
// MATCH (f:AssessmentApproach {id:'APG_AI_FORECAST'}) MATCH (m:AssessmentApproach) WHERE m.id IN ['APM_IMPACT_FORECAST','APM_AI_LCA_MODELING','APM_SURROGATE'] MERGE (m)-[:BROADER]->(f);
// MATCH (d:AssessmentApproach {id:'APG_ADAPTIVE_DECISION'}) MATCH (m:AssessmentApproach) WHERE m.id IN ['APM_LEARNING_SCENARIO','APM_PREDICTIVE_ASSESSMENT','APM_AUTO_DESIGN'] MERGE (m)-[:BROADER]->(d);
// MATCH (a:Assessment {id:'ASSESS_AI_PREPARED'}) MATCH (m:AssessmentApproach) WHERE m.id IN ['APM_IMPACT_FORECAST','APM_AI_LCA_MODELING','APM_SURROGATE','APM_LEARNING_SCENARIO','APM_PREDICTIVE_ASSESSMENT'] MERGE (a)-[:APPLIES_APPROACH]->(m);
// MATCH (a:Assessment {id:'ASSESS_AI_PREPARED'}), (p {id:'PRODUCT_NED2'}) MERGE (a)-[:ASSESSES]->(p);
// MATCH (a:Assessment {id:'ASSESS_AI_PREPARED'}), (s:ModelScenario {id:'SC_BASELINE'}) MERGE (a)-[:UNDER_SCENARIO]->(s);
// MATCH (pm:PredictionModel {id:'PM_GWP_SURROGATE'}), (ic:ImpactCategory {id:'IC_CLIMATE'}) MERGE (pm)-[:PREDICTS]->(ic);
// MATCH (pm:PredictionModel {id:'PM_GWP_SURROGATE'}), (ir:ImpactResult {id:'IR_EF31A_ART_V_AL_IC_CLIMATE'}) MERGE (ir)-[:ESTIMATED_BY {note:'type-defining edge only; this result is LCI-calculated, not predicted', provenance:'illustrative'}]->(pm);
// MATCH (rec:Recommendation {id:'REC_DEMO_LIGHTWEIGHT_CONTACT'}), (art:Artifact {id:'ART_V_AL'}) MERGE (rec)-[:RECOMMENDS_FOR]->(art);
