// ============================================================================
// migration_v3e.cypher  --  Module v3.e: second LCIA method (ReCiPe 2016 midpoint,
// Hierarchist). Demonstrates "a new method is pure data": method node + 18
// midpoint category nodes + HAS_CATEGORY, and CHARACTERIZES factors for the
// climate category (approximated from the EF3.1 GHG factors x 1.06 for the
// ReCiPe-H climate-carbon-feedback adjustment). The other 17 categories are
// structure-only (factor population = data task, see ASSUMPTIONS.md 6).
// lca_generic($methodId='IAM_RECIPE') then works with no query change.
// Additive. Rollback at bottom. Date: 2026-08-27
// ============================================================================

MERGE (m:ImpactAssessmentMethod {id:'IAM_RECIPE'})
  SET m.name='ReCiPe 2016 midpoint (H)', m.methodFamily='ReCiPe',
      m.version='2016 v1.1', m.source='Huijbregts et al. 2017 / RIVM 2016-0104',
      m.note='midpoint, Hierarchist perspective; factor population partial (climate only)';

// --- 18 midpoint category nodes ------------------------------------
UNWIND [
  {id:'IC_RECIPE_GW',      name:'Global warming',                        unit:'kg CO2 eq',    ind:'GWP100'},
  {id:'IC_RECIPE_OD',      name:'Stratospheric ozone depletion',         unit:'kg CFC-11 eq', ind:'ODP'},
  {id:'IC_RECIPE_IR',      name:'Ionizing radiation',                    unit:'kBq Co-60 eq', ind:'IRP'},
  {id:'IC_RECIPE_OF_HH',   name:'Ozone formation, human health',         unit:'kg NOx eq',    ind:'EOFP'},
  {id:'IC_RECIPE_PM',      name:'Fine particulate matter formation',     unit:'kg PM2.5 eq',  ind:'PMFP'},
  {id:'IC_RECIPE_OF_EC',   name:'Ozone formation, terrestrial ecosystems',unit:'kg NOx eq',   ind:'EOFP'},
  {id:'IC_RECIPE_TA',      name:'Terrestrial acidification',             unit:'kg SO2 eq',    ind:'TAP'},
  {id:'IC_RECIPE_FE',      name:'Freshwater eutrophication',             unit:'kg P eq',      ind:'FEP'},
  {id:'IC_RECIPE_ME',      name:'Marine eutrophication',                 unit:'kg N eq',      ind:'MEP'},
  {id:'IC_RECIPE_TET',     name:'Terrestrial ecotoxicity',              unit:'kg 1,4-DCB',   ind:'TETP'},
  {id:'IC_RECIPE_FET',     name:'Freshwater ecotoxicity',               unit:'kg 1,4-DCB',   ind:'FETP'},
  {id:'IC_RECIPE_MET',     name:'Marine ecotoxicity',                   unit:'kg 1,4-DCB',   ind:'METP'},
  {id:'IC_RECIPE_HCT',     name:'Human carcinogenic toxicity',          unit:'kg 1,4-DCB',   ind:'HTPc'},
  {id:'IC_RECIPE_HNCT',    name:'Human non-carcinogenic toxicity',      unit:'kg 1,4-DCB',   ind:'HTPnc'},
  {id:'IC_RECIPE_LU',      name:'Land use',                             unit:'m2a crop eq',  ind:'LOP'},
  {id:'IC_RECIPE_MRS',     name:'Mineral resource scarcity',            unit:'kg Cu eq',     ind:'SOP'},
  {id:'IC_RECIPE_FRS',     name:'Fossil resource scarcity',             unit:'kg oil eq',    ind:'FFP'},
  {id:'IC_RECIPE_WC',      name:'Water consumption',                    unit:'m3',           ind:'WCP'}
] AS d
MERGE (ic:ImpactCategory {id:d.id})
  SET ic.name=d.name, ic.unit=d.unit, ic.indicator=d.ind, ic.method='ReCiPe 2016 midpoint (H)';

// --- HAS_CATEGORY links + approach ------------------------------
MATCH (m:ImpactAssessmentMethod {id:'IAM_RECIPE'}), (ic:ImpactCategory)
WHERE ic.id STARTS WITH 'IC_RECIPE_'
MERGE (m)-[:HAS_CATEGORY]->(ic);
MATCH (m:ImpactAssessmentMethod {id:'IAM_RECIPE'}), (ap:AssessmentApproach {id:'APM_LCA'})
MERGE (m)-[:APPLIES_APPROACH]->(ap);

// --- climate CHARACTERIZES: copy EF3.1 GHG factors x 1.06 -------
MATCH (f:Flow)-[c:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
MATCH (gw:ImpactCategory {id:'IC_RECIPE_GW'})
MERGE (f)-[nc:CHARACTERIZES {characterizesId:'CF_RECIPE_GW_' + coalesce(c.characterizesId, toString(id(c)))}]->(gw)
SET nc.factor = c.factor * 1.06,
    nc.location = c.location,
    nc.source = 'approximated from EF3.1 GWP100 x 1.06 (ReCiPe-H climate-carbon feedback)';

// --- verification ---------------------------------------------
MATCH (m:ImpactAssessmentMethod {id:'IAM_RECIPE'})-[:HAS_CATEGORY]->(ic)
RETURN 'ReCiPe categories' AS check, count(ic) AS n;
MATCH (:Flow)-[c:CHARACTERIZES]->(:ImpactCategory {id:'IC_RECIPE_GW'})
RETURN 'ReCiPe GW factors' AS check, count(c) AS n;

// --- rollback ------------------------------------------------
// MATCH (:Flow)-[c:CHARACTERIZES]->(:ImpactCategory {id:'IC_RECIPE_GW'}) DELETE c;
// MATCH (ic:ImpactCategory) WHERE ic.id STARTS WITH 'IC_RECIPE_' DETACH DELETE ic;
// MATCH (m:ImpactAssessmentMethod {id:'IAM_RECIPE'}) DETACH DELETE m;
