// ============================================================================
// migration_pre5.cypher  --  PRE-5: ImpactCategory hygiene.
// The graph has TWO parallel EF3.1 category sets: method-slot nodes (linked to
// IAM_EF31, but 0 CHARACTERIZES factors, messy name/unit) and factor-bearing
// nodes (the real characterization data, but NOT linked to the method).
// Fix: for each concept keep the factor-bearing node, merge the slot node(s)
// into it (transfers HAS_CATEGORY + FOR_CATEGORY, dedupes), then normalize
// name / indicator / unit.
// Uses apoc.refactor.mergeNodes (rels moved, not deleted).
// Date: 2026-08-27. Rollback: not automatic -- restore from a snapshot.
// ============================================================================

// --- baseline count (for the post-check) ---
MATCH ()-[c:CHARACTERIZES]->() RETURN 'CHARACTERIZES before' AS check, count(c) AS n;

// --- merge groups: [canonical_keep, slot_to_merge, ...] ---
UNWIND [
  ['IC_CLIMATE',                       ['IC_EF_CLIMATE_TOTAL']],
  ['IC_EF_CLIMATE_CHANGE_BIOGENIC',    ['IC_EF_CLIMATE_BIOGENIC']],
  ['IC_EF_CLIMATE_CHANGE_FOSSIL',      ['IC_EF_CLIMATE_FOSSIL']],
  ['IC_EF_CLIMATE_CHANGE_LAND_USE_AND_LAND_USE_CHANGE', ['IC_EF_CLIMATE_LULUC']],
  ['IC_EF_ECOTOXICITY_FRESHWATER',     ['IC_EF_ECOTOX_FRESHWATER','IC_EF_EF_ECOTOXICITY_FRESHWATER']],
  ['IC_EF_EF_EUTROPHICATION_FRESHWATER',['IC_EF_EUTROPH_FRESHWATER']],
  ['IC_EF_EF_EUTROPHICATION_TERRESTRIAL',['IC_EF_EUTROPH_TERRESTRIAL']],
  ['IC_EF_HUMAN_TOXICITY_CANCER',      ['IC_EF_HUMANTOX_CANCER','IC_EF_EF_HUMAN_TOXICITY_CANCER']],
  ['IC_EF_HUMAN_TOXICITY_NON_CANCER',  ['IC_EF_HUMANTOX_NONCANCER','IC_EF_EF_HUMAN_TOXICITY_NON_CANCER']],
  ['IC_EF_EF_IONISING_RADIATION_HUMAN_HEALTH',['IC_EF_IONISING_RADIATION']],
  ['IC_EF_EF_RESOURCE_USE_FOSSILS',    ['IC_EF_RESOURCE_FOSSILS']],
  ['IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS',['IC_EF_RESOURCE_MINERALS']]
] AS grp
WITH grp[0] AS keepId, grp[1] AS slotIds
MATCH (keep:ImpactCategory {id:keepId})
WITH keep, slotIds
UNWIND slotIds AS sid
MATCH (slot:ImpactCategory {id:sid})
WITH keep, collect(slot) AS slots
CALL apoc.refactor.mergeNodes([keep] + slots, {properties:'discard', mergeRels:true}) YIELD node
RETURN node.id AS merged, size(slots) AS absorbed;

// --- normalize name / indicator / unit on the canonical set ---
UNWIND [
  {id:'IC_CLIMATE',                              name:'Climate change (total)',              ind:'GWP100',                    unit:'kg CO2-eq'},
  {id:'IC_EF_CLIMATE_CHANGE_BIOGENIC',           name:'Climate change - biogenic',           ind:'GWP100 biogenic',           unit:'kg CO2-eq'},
  {id:'IC_EF_CLIMATE_CHANGE_FOSSIL',             name:'Climate change - fossil',             ind:'GWP100 fossil',             unit:'kg CO2-eq'},
  {id:'IC_EF_CLIMATE_CHANGE_LAND_USE_AND_LAND_USE_CHANGE', name:'Climate change - land use & LUC', ind:'GWP100 LULUC',        unit:'kg CO2-eq'},
  {id:'IC_EF_ACIDIFICATION',                     name:'Acidification',                       ind:'Accumulated Exceedance',    unit:'mol H+ eq'},
  {id:'IC_EF_EUTROPH_MARINE',                    name:'Eutrophication, marine',              ind:'N to marine end compartment', unit:'kg N eq'},
  {id:'IC_EF_EF_EUTROPHICATION_FRESHWATER',      name:'Eutrophication, freshwater',          ind:'P to freshwater end compartment', unit:'kg P eq'},
  {id:'IC_EF_EF_EUTROPHICATION_TERRESTRIAL',     name:'Eutrophication, terrestrial',         ind:'Accumulated Exceedance',    unit:'mol N eq'},
  {id:'IC_EF_LAND_USE',                          name:'Land use',                           ind:'Soil quality index',        unit:'dimensionless (pt)'},
  {id:'IC_EF_OZONE_DEPLETION',                   name:'Ozone depletion',                     ind:'ODP',                       unit:'kg CFC-11 eq'},
  {id:'IC_EF_PARTICULATE_MATTER',                name:'Particulate matter',                  ind:'PM health impact',          unit:'disease incidence'},
  {id:'IC_EF_PHOTOCHEM_OZONE',                   name:'Photochemical ozone formation',       ind:'Tropospheric ozone',        unit:'kg NMVOC eq'},
  {id:'IC_EF_WATER_USE',                         name:'Water use',                           ind:'AWARE deprivation',         unit:'m3 world eq'},
  {id:'IC_EF_ECOTOXICITY_FRESHWATER',            name:'Ecotoxicity, freshwater',            ind:'CTUe',                      unit:'CTUe'},
  {id:'IC_EF_HUMAN_TOXICITY_CANCER',             name:'Human toxicity, cancer',             ind:'CTUh',                      unit:'CTUh'},
  {id:'IC_EF_HUMAN_TOXICITY_NON_CANCER',         name:'Human toxicity, non-cancer',         ind:'CTUh',                      unit:'CTUh'},
  {id:'IC_EF_EF_IONISING_RADIATION_HUMAN_HEALTH',name:'Ionising radiation, human health',   ind:'U235 exposure eq',          unit:'kBq U235 eq'},
  {id:'IC_EF_EF_RESOURCE_USE_FOSSILS',           name:'Resource use, fossils',              ind:'ADP fossil',                unit:'MJ'},
  {id:'IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS',name:'Resource use, minerals & metals',   ind:'ADP ultimate reserve',      unit:'kg Sb eq'}
] AS d
MATCH (ic:ImpactCategory {id:d.id})
SET ic.name = d.name, ic.indicator = d.ind, ic.unit = d.unit,
    ic.hygiene = 'PRE-5 2026-08-27: canonicalised, name/indicator/unit normalised';

// --- ensure IAM_EF31 links the full canonical midpoint set ---
MATCH (m:ImpactAssessmentMethod {id:'IAM_EF31'})
UNWIND ['IC_CLIMATE','IC_EF_ACIDIFICATION','IC_EF_EUTROPH_MARINE','IC_EF_EF_EUTROPHICATION_FRESHWATER',
        'IC_EF_EF_EUTROPHICATION_TERRESTRIAL','IC_EF_LAND_USE','IC_EF_OZONE_DEPLETION',
        'IC_EF_PARTICULATE_MATTER','IC_EF_PHOTOCHEM_OZONE','IC_EF_WATER_USE',
        'IC_EF_ECOTOXICITY_FRESHWATER','IC_EF_HUMAN_TOXICITY_CANCER','IC_EF_HUMAN_TOXICITY_NON_CANCER',
        'IC_EF_EF_IONISING_RADIATION_HUMAN_HEALTH','IC_EF_EF_RESOURCE_USE_FOSSILS',
        'IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS','IC_EF_CLIMATE_CHANGE_FOSSIL',
        'IC_EF_CLIMATE_CHANGE_BIOGENIC','IC_EF_CLIMATE_CHANGE_LAND_USE_AND_LAND_USE_CHANGE'] AS cid
MATCH (ic:ImpactCategory {id:cid})
MERGE (m)-[:HAS_CATEGORY]->(ic);

// --- post-check ---
MATCH ()-[c:CHARACTERIZES]->() RETURN 'CHARACTERIZES after (must equal before)' AS check, count(c) AS n;
MATCH (ic:ImpactCategory) RETURN 'ImpactCategory total' AS check, count(*) AS n;
MATCH (m:ImpactAssessmentMethod {id:'IAM_EF31'})-[:HAS_CATEGORY]->(ic)
WITH ic, EXISTS { (:Flow)-[:CHARACTERIZES]->(ic) } AS hasFactors
RETURN 'EF3.1 categories linked' AS check, count(ic) AS linked,
       sum(CASE WHEN hasFactors THEN 1 ELSE 0 END) AS withFactors;
MATCH (n) WHERE size(labels(n))=0 RETURN 'labelless (must be 0)' AS check, count(n) AS n;
