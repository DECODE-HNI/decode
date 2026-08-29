// ============================================================================
// migration_v3.cypher  --  White box: make the ILCD data interpretable and
//                          method-exchangeable. (v3-minimal first slice.)
//
// Contents:
//   PRE-2  Process.lifecycleModule (EN 15804) + vocab + backfill + processType normalize
//   PRE-3  Assessment functional-unit / system-boundary formalization
//   PRE-4  AssessmentApproach taxonomy (3 paradigms / 7 groups / 23 methods) + links
//          (the "lernende Ansätze" AI/ML branch -- 2 groups + 6 methods -- was
//           removed 2026-08-29, see model_versions/consistency/remove_ki_stubs.cypher;
//           APG_MODEL_TRANSPARENCY / APM_DPP / APM_ENV_KG under AP_LERNEND stay)
//   (base query lca_generic.cypher replaces the hardwired lca_computed_ef31)
//
// Deferred to a v3 follow-up slice:
//   PRE-5  ImpactCategory hygiene (~20 orphan/near-duplicate nodes; edge remapping)
//   second full LCIA method (ReCiPe/CML) -- no characterization data available yet;
//          method-exchange is instead demonstrated with lca_generic over the two
//          methods that already exist (IAM_EF31, IAM_PCF).
//
// All additive/reversible except the processType casing normalization. Rollback at bottom.
// Date: 2026-08-27
// ============================================================================

// ----------------------------------------------------------------------------
// PRE-2a  Normalize Process.processType casing ("End of Life" -> "EndOfLife").
// ----------------------------------------------------------------------------
MATCH (pr:Process {processType:'End of Life'})
SET pr.processType = 'EndOfLife';

// ----------------------------------------------------------------------------
// PRE-2b  Assign EN 15804 lifecycle module.
//   name contains "A1-A3"            -> A1-A3   (cradle-to-gate aggregated dataset)
//   RawMaterialProduction            -> A1
//   Manufacturing / Assembly / Postprocess -> A3
//   Use                              -> B1
//   Service                          -> B4      (replacement of jaw / pad)
//   EndOfLife                        -> C3
// ----------------------------------------------------------------------------
MATCH (pr:Process)
WITH pr,
     CASE
       WHEN pr.name CONTAINS 'A1-A3'                                   THEN 'A1-A3'
       WHEN pr.processType = 'RawMaterialProduction'                   THEN 'A1'
       WHEN pr.processType IN ['Manufacturing','Assembly','Postprocess'] THEN 'A3'
       WHEN pr.processType = 'Use'                                     THEN 'B1'
       WHEN pr.processType = 'Service'                                 THEN 'B4'
       WHEN pr.processType = 'EndOfLife'                               THEN 'C3'
       ELSE null
     END AS mod
SET pr.lifecycleModule = mod,
    pr.lifecycleModuleBasis = 'migration_v3: name pattern + processType';

// ----------------------------------------------------------------------------
// PRE-3  Formalize functional unit / reference flow / system boundary.
//   systemBoundary vocab: cradle-to-gate | cradle-to-grave | gate-to-gate | cradle-to-cradle
// ----------------------------------------------------------------------------
// 3a. the 5 EF3.1 aluminium assessments (already carry free-text systemBoundary/functionalUnit)
MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASSESS_EF31_'
SET as.systemBoundaryNote  = as.systemBoundary,
    as.systemBoundary      = 'cradle-to-gate',
    as.referenceFlow       = 'aluminium contact parts of one gripper',
    as.referenceQuantity   = 1.0,
    as.referenceUnit       = 'jaw set';

// 3b. the 43 PCF screening assessments (no functional unit yet -> declare intent)
MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASS_'
SET as.functionalUnit    = coalesce(as.functionalUnit, 'one gripper as delivered'),
    as.systemBoundary    = coalesce(as.systemBoundary, 'cradle-to-gate'),
    as.referenceFlow     = coalesce(as.referenceFlow, 'one gripper'),
    as.referenceQuantity = coalesce(as.referenceQuantity, 1.0),
    as.referenceUnit     = coalesce(as.referenceUnit, 'gripper');

// ----------------------------------------------------------------------------
// PRE-4  AssessmentApproach taxonomy from the method diagram.
// ----------------------------------------------------------------------------
UNWIND [
  // paradigms
  {id:'AP_BILANZIEREND',   name:'bilanzierende Ansätze',  level:'paradigm', code:'1', parent:null},
  {id:'AP_DATENBASIERT',   name:'datenbasierte Ansätze',  level:'paradigm', code:'2', parent:null},
  {id:'AP_LERNEND',        name:'lernende Ansätze',        level:'paradigm', code:'3', parent:null},
  // groups
  {id:'APG_LCA_BASED',          name:'lebenszyklusbasierte Umweltbewertung',              level:'group', code:'1.1', parent:'AP_BILANZIEREND'},
  {id:'APG_SUBSTANCE_RESOURCE', name:'Stoff- und ressourcenbezogene Bilanzierung',        level:'group', code:'1.2', parent:'AP_BILANZIEREND'},
  {id:'APG_ECO_ECONOMIC',       name:'integrierte ökologisch-ökonomische Bilanzierung',   level:'group', code:'1.3', parent:'AP_BILANZIEREND'},
  {id:'APG_PROSPECTIVE_LCA',    name:'prospektive lebenszyklusbasierte Umweltbewertung',  level:'group', code:'2.1', parent:'AP_DATENBASIERT'},
  {id:'APG_SCENARIO_BASED',     name:'szenariobasierte Umweltbewertung',                  level:'group', code:'2.2', parent:'AP_DATENBASIERT'},
  {id:'APG_IMPACT_UNCERTAINTY', name:'Wirkungs- und Unsicherheitsanalysen',               level:'group', code:'2.3', parent:'AP_DATENBASIERT'},
  {id:'APG_MODEL_TRANSPARENCY', name:'modellbasierte Produkt- und Lebenszyklustransparenz', level:'group', code:'3.2', parent:'AP_LERNEND'},
  // methods
  {id:'APM_LCA',                     name:'Ökobilanzierung',                       level:'method', code:'1.1.1', parent:'APG_LCA_BASED'},
  {id:'APM_CF_CO2',                  name:'Umweltfußabdruck CO2',                   level:'method', code:'1.1.2', parent:'APG_LCA_BASED'},
  {id:'APM_CF_H2O',                  name:'Umweltfußabdruck H2O',                   level:'method', code:'1.1.3', parent:'APG_LCA_BASED'},
  {id:'APM_GHG',                     name:'Treibhausgasbilanzierung',              level:'method', code:'1.1.4', parent:'APG_LCA_BASED'},
  {id:'APM_MFA',                     name:'Stoff- & Materialstromanalyse',          level:'method', code:'1.2.1', parent:'APG_SUBSTANCE_RESOURCE'},
  {id:'APM_POLLUTANT',              name:'Schadstoffbilanzierung',                level:'method', code:'1.2.2', parent:'APG_SUBSTANCE_RESOURCE'},
  {id:'APM_CED',                     name:'kumulierter Energieverbrauch',           level:'method', code:'1.2.3', parent:'APG_SUBSTANCE_RESOURCE'},
  {id:'APM_CIRCULARITY',            name:'Zirkularitätsbewertung',                level:'method', code:'1.2.4', parent:'APG_SUBSTANCE_RESOURCE'},
  {id:'APM_MFCA',                    name:'Materialfluss-Kostenrechnung',           level:'method', code:'1.3.1', parent:'APG_ECO_ECONOMIC'},
  {id:'APM_ECO_EFFICIENCY',         name:'Ökoeffizienz Bewertung',                level:'method', code:'1.3.2', parent:'APG_ECO_ECONOMIC'},
  {id:'APM_EEA',                     name:'Umwelt-ökon. Gesamtrechnung',           level:'method', code:'1.3.3', parent:'APG_ECO_ECONOMIC'},
  {id:'APM_PROSPECTIVE_LCA',        name:'prospektive Ökobilanzierung',           level:'method', code:'2.1.1', parent:'APG_PROSPECTIVE_LCA'},
  {id:'APM_DYNAMIC_LCA',            name:'dynamische Ökobilanzierung',            level:'method', code:'2.1.2', parent:'APG_PROSPECTIVE_LCA'},
  {id:'APM_CONSEQUENTIAL_LCA',      name:'konsequenzielle Ökobilanzierung',       level:'method', code:'2.1.3', parent:'APG_PROSPECTIVE_LCA'},
  {id:'APM_HYBRID_LCA',            name:'hybride Ökobilanzierung',               level:'method', code:'2.1.4', parent:'APG_PROSPECTIVE_LCA'},
  {id:'APM_SCENARIO_ASSESSMENT',   name:'Szenario-gestützte Umweltbewertung',    level:'method', code:'2.2.1', parent:'APG_SCENARIO_BASED'},
  {id:'APM_CROSS_IMPACT',          name:'Cross-Impact Wirkungsanalyse',          level:'method', code:'2.2.2', parent:'APG_SCENARIO_BASED'},
  {id:'APM_ROBUSTNESS',            name:'Robustheits- und Resilienzanalyse',     level:'method', code:'2.2.3', parent:'APG_SCENARIO_BASED'},
  {id:'APM_IMPACT_CHAIN',          name:'Wirkkettenanalyse',                     level:'method', code:'2.3.1', parent:'APG_IMPACT_UNCERTAINTY'},
  {id:'APM_UNCERTAINTY_SENSITIVITY', name:'Unsicherheits- und Sensitivitätsanalyse', level:'method', code:'2.3.2', parent:'APG_IMPACT_UNCERTAINTY'},
  {id:'APM_HOTSPOT',               name:'Hotspot-Analyse',                       level:'method', code:'2.3.3', parent:'APG_IMPACT_UNCERTAINTY'},
  {id:'APM_DPP',                    name:'Digitaler Produktpass',                 level:'method', code:'3.2.1', parent:'APG_MODEL_TRANSPARENCY'},
  {id:'APM_ENV_KG',                name:'Umwelt-Wissensgraph',                   level:'method', code:'3.2.2', parent:'APG_MODEL_TRANSPARENCY'}
] AS row
MERGE (ap:AssessmentApproach {id: row.id})
  SET ap.name = row.name, ap.level = row.level, ap.code = row.code
WITH row, ap
WHERE row.parent IS NOT NULL
MATCH (parent:AssessmentApproach {id: row.parent})
MERGE (ap)-[:BROADER]->(parent);

// PRE-4b  link existing Assessments to their approach
MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASSESS_EF31_'
MATCH (m:AssessmentApproach {id:'APM_LCA'})
MERGE (as)-[:APPLIES_APPROACH]->(m);

MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASS_'
MATCH (m:AssessmentApproach {id:'APM_CF_CO2'})
MERGE (as)-[:APPLIES_APPROACH]->(m);

// ----------------------------------------------------------------------------
// Verification
// ----------------------------------------------------------------------------
MATCH (pr:Process)
RETURN 'lifecycleModule coverage' AS check, pr.lifecycleModule AS module, count(*) AS processes
ORDER BY module;

MATCH (ap:AssessmentApproach)
RETURN 'taxonomy' AS check, ap.level AS level, count(*) AS nodes
ORDER BY level;

MATCH (as:Assessment)-[:APPLIES_APPROACH]->(m:AssessmentApproach)
RETURN 'assessments linked to approach' AS check, m.name AS approach, count(*) AS assessments;

MATCH (as:Assessment)
RETURN 'systemBoundary vocab' AS check, as.systemBoundary AS boundary, count(*) AS assessments
ORDER BY boundary;

// ----------------------------------------------------------------------------
// Rollback
// ----------------------------------------------------------------------------
// MATCH (pr:Process) REMOVE pr.lifecycleModule, pr.lifecycleModuleBasis;
// MATCH (pr:Process {processType:'EndOfLife'}) WHERE NOT (pr)-[:HAS_FLOW]->() SET pr.processType='End of Life';  // partial; casing was lossy
// MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASSESS_EF31_'
//   SET as.systemBoundary = as.systemBoundaryNote REMOVE as.systemBoundaryNote, as.referenceFlow, as.referenceQuantity, as.referenceUnit;
// MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASS_' REMOVE as.functionalUnit, as.systemBoundary, as.referenceFlow, as.referenceQuantity, as.referenceUnit;
// MATCH (ap:AssessmentApproach) DETACH DELETE ap;
