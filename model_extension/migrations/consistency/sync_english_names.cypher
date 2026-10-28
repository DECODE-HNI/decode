// ============================================================================
// sync_english_names.cypher  --  English pass: bring a live database in line
//                                with the English AssessmentApproach names and
//                                the three renamed paradigm ids.
// ----------------------------------------------------------------------------
// Context: migration_v3.cypher now creates the taxonomy with English names and
// the ids AP_ACCOUNTING / AP_DATA_DRIVEN / AP_LEARNING (formerly the German-
// rooted AP_BILANZIEREND / AP_DATENBASIERT / AP_LERNEND). A database that was
// built from the earlier migration still carries the old values; run this
// script once against it. Idempotent: it only touches ids that still carry the
// old spelling and re-sets names to the same values.
//
// Each ';'-statement is independent (re-MATCH by id, no shared variables).
// Rollback: the three renames below can be reversed by swapping old/new ids.
// ============================================================================

MATCH (n:AssessmentApproach {id:'AP_BILANZIEREND'}) SET n.id = 'AP_ACCOUNTING';
MATCH (n:AssessmentApproach {id:'AP_DATENBASIERT'}) SET n.id = 'AP_DATA_DRIVEN';
MATCH (n:AssessmentApproach {id:'AP_LERNEND'})      SET n.id = 'AP_LEARNING';

UNWIND [
  {id:'AP_ACCOUNTING', name:'Accounting approaches'},
  {id:'AP_DATA_DRIVEN', name:'Data-driven approaches'},
  {id:'AP_LEARNING', name:'Learning approaches'},
  {id:'APG_LCA_BASED', name:'Life-cycle-based environmental assessment'},
  {id:'APG_SUBSTANCE_RESOURCE', name:'Substance- and resource-related accounting'},
  {id:'APG_ECO_ECONOMIC', name:'Integrated ecological-economic accounting'},
  {id:'APG_PROSPECTIVE_LCA', name:'Prospective life-cycle-based environmental assessment'},
  {id:'APG_SCENARIO_BASED', name:'Scenario-based environmental assessment'},
  {id:'APG_IMPACT_UNCERTAINTY', name:'Impact and uncertainty analyses'},
  {id:'APG_MODEL_TRANSPARENCY', name:'Model-based product and life-cycle transparency'},
  {id:'APM_LCA', name:'Life cycle assessment'},
  {id:'APM_CF_CO2', name:'Carbon footprint (CO2)'},
  {id:'APM_CF_H2O', name:'Water footprint (H2O)'},
  {id:'APM_GHG', name:'Greenhouse gas accounting'},
  {id:'APM_MFA', name:'Substance and material flow analysis'},
  {id:'APM_POLLUTANT', name:'Pollutant accounting'},
  {id:'APM_CED', name:'Cumulative energy demand'},
  {id:'APM_CIRCULARITY', name:'Circularity assessment'},
  {id:'APM_MFCA', name:'Material flow cost accounting'},
  {id:'APM_ECO_EFFICIENCY', name:'Eco-efficiency assessment'},
  {id:'APM_EEA', name:'Environmental-economic accounting'},
  {id:'APM_PROSPECTIVE_LCA', name:'Prospective life cycle assessment'},
  {id:'APM_DYNAMIC_LCA', name:'Dynamic life cycle assessment'},
  {id:'APM_CONSEQUENTIAL_LCA', name:'Consequential life cycle assessment'},
  {id:'APM_HYBRID_LCA', name:'Hybrid life cycle assessment'},
  {id:'APM_SCENARIO_ASSESSMENT', name:'Scenario-supported environmental assessment'},
  {id:'APM_CROSS_IMPACT', name:'Cross-impact analysis'},
  {id:'APM_ROBUSTNESS', name:'Robustness and resilience analysis'},
  {id:'APM_IMPACT_CHAIN', name:'Impact chain analysis'},
  {id:'APM_UNCERTAINTY_SENSITIVITY', name:'Uncertainty and sensitivity analysis'},
  {id:'APM_HOTSPOT', name:'Hotspot analysis'},
  {id:'APM_DPP', name:'Digital product passport'},
  {id:'APM_ENV_KG', name:'Environmental knowledge graph'}
] AS row
MATCH (n:AssessmentApproach {id: row.id})
SET n.name = row.name;

// --- verification -----------------------------------------------------------
MATCH (n:AssessmentApproach) RETURN count(n) AS approaches;                    // expect 33
MATCH (n:AssessmentApproach) WHERE n.id IN ['AP_BILANZIEREND','AP_DATENBASIERT','AP_LERNEND']
RETURN count(n) AS stale_ids;                                                    // expect 0
MATCH (n:AssessmentApproach) WHERE n.name =~ '.*[äöüÄÖÜß].*' RETURN count(n) AS names_with_umlauts;   // expect 0
