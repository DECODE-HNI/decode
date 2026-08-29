// ============================================================================
// migration_v3f.cypher  --  Module v3.f: Emissions & pollutant accounting
//   1.1.4 THG-Bilanzierung nach Scope (GHG Protocol)
//   1.2.2 Schadstoffbilanzierung (GHS-Register)
//   1.1.3 Wasser-Fußabdruck (Kategorie-Einheit + Demonstrator)
// Additive. Each ';'-statement is independent -> re-MATCH by id.
// Rollback at bottom. Date: 2026-08-28
// ============================================================================

// --- 1. GHG Protocol scope on every Process ---------------------------------
MATCH (p:Process)
SET p.ghgScope = CASE p.processType
      WHEN 'RawMaterialProduction' THEN '3'
      WHEN 'Use'                   THEN '3'
      WHEN 'EndOfLife'             THEN '3'
      WHEN 'Service'               THEN '3'
      WHEN 'Manufacturing'         THEN '2'
      WHEN 'Postprocess'           THEN '2'
      WHEN 'Assembly'              THEN '1'
      ELSE '3' END,
    p.ghgScopeCategory = CASE p.processType
      WHEN 'RawMaterialProduction' THEN 'S3.1 purchased goods & services'
      WHEN 'Manufacturing'         THEN 'S2 purchased electricity (contract manufacturing)'
      WHEN 'Postprocess'           THEN 'S2 purchased electricity'
      WHEN 'Assembly'              THEN 'S1 on-site (no fossil combustion modelled -> ~0)'
      WHEN 'Use'                   THEN 'S3.11 use of sold product'
      WHEN 'EndOfLife'             THEN 'S3.12 end-of-life treatment'
      WHEN 'Service'               THEN 'S3.11 use-phase servicing'
      ELSE 'S3 other' END,
    p.ghgScopeBasis = 'v3.f: GHG Protocol Corporate Standard, product-system perspective';

// --- 2. GHG species tag on climate-characterised flows --------------------
MATCH (f:Flow)-[:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
WITH f, toLower(coalesce(f.name,'')) AS n
SET f.ghgSpecies = CASE
      WHEN n CONTAINS 'sulfur hexafluoride'  THEN 'SF6'
      WHEN n CONTAINS 'nitrogen trifluoride' THEN 'NF3'
      WHEN n CONTAINS 'nitrous oxide'        THEN 'N2O'
      WHEN n CONTAINS 'methane'              THEN 'CH4'
      WHEN n CONTAINS 'carbon dioxide'       THEN 'CO2'
      WHEN n STARTS WITH 'hfc' OR n STARTS WITH 'hcfc' THEN 'HFC/HCFC'
      WHEN n STARTS WITH 'pfc' OR n STARTS WITH 'fc-'  THEN 'PFC'
      ELSE 'other halocarbon' END;

// --- 3. IAM_GHG method (reuses the climate category) ----------------------
MERGE (m:ImpactAssessmentMethod {id:'IAM_GHG'})
  SET m.name='GHG inventory by scope (GHG Protocol)', m.methodFamily='carbon accounting',
      m.methodStandard='GHG Protocol Corporate Standard + Scope 3 Standard',
      m.source='WRI / WBCSD', m.version='screening';
MATCH (m:ImpactAssessmentMethod {id:'IAM_GHG'}), (ic:ImpactCategory {id:'IC_CLIMATE'})
MERGE (m)-[:HAS_CATEGORY]->(ic);
MATCH (m:ImpactAssessmentMethod {id:'IAM_GHG'}), (ap:AssessmentApproach {id:'APM_GHG'})
MERGE (m)-[:APPLIES_APPROACH]->(ap);

// --- 4. GHG-by-scope demonstrator (5 v2 aluminium grippers) --------------
// Re-partitions the Variant-B climate number into GHG-Protocol scopes; same
// system boundary and same electricity model as lca_from_literals.cypher
// (mass x energyIntensity x grid CF, no materialFactor) so S2 + S3UP == Variant B.
MATCH (art:Artifact)-[:HAS_PROCESS_PLAN]->(:ProcessPlan)-[:CONTAINS_PROCESS]->(mp:Process {processType:'Manufacturing'})
WHERE art.id IN ['ART_V_AL','ART_FLAT_AL','ART_LONG_AL','ART_INTERNAL_AL','ART_PREC_AL7075']
MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(mat:Material)
WHERE p.mass_g IS NOT NULL
WITH art, mp,
     sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg,
     sum(p.mass_g*hc.quantity/1000.0 * coalesce(mat.gwp_A1_kgCO2e_per_kg,0.0)) AS s3up
WITH art, s3up,
     mass_kg * coalesce(mp.energyIntensity_kWh_per_kg,20.0) * 0.38 AS s2
MERGE (as:Assessment {id:'ASSESS_GHG_'+art.id})
  ON CREATE SET as.name='GHG inventory by scope - '+art.name,
                as.assessmentType='carbon accounting screening',
                as.methodology='GHG Protocol scopes over the Variant-B cradle-to-gate system',
                as.status='partial', as.systemBoundary='cradle-to-gate',
                as.functionalUnit='one gripper', as.referenceFlow='one gripper',
                as.referenceQuantity=1.0, as.referenceUnit='gripper', as.dataVariant='B-literal'
SET as.methodology='GHG Protocol scopes over the Variant-B cradle-to-gate system'
WITH as, art, s3up, s2
MATCH (m:ImpactAssessmentMethod {id:'IAM_GHG'}), (ap:AssessmentApproach {id:'APM_GHG'}),
      (ic:ImpactCategory {id:'IC_CLIMATE'})
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:USES_METHOD]->(m)
MERGE (as)-[:APPLIES_APPROACH]->(ap)
WITH as, art, ic, s3up, s2
UNWIND [
  {sfx:'S1',   v:0.0,  lbl:'Scope 1 (direct, on-site)',       note:'no on-site fossil combustion modelled'},
  {sfx:'S2',   v:s2,   lbl:'Scope 2 (purchased electricity)', note:'manufacturing energy x DE grid 0.38 kg CO2e/kWh'},
  {sfx:'S3UP', v:s3up, lbl:'Scope 3 upstream (cat 1)',         note:'purchased materials, A1 GWP literals'}
] AS row
MERGE (ir:ImpactResult {id:'IR_GHG_'+art.id+'_'+row.sfx})
  ON CREATE SET ir.name=row.lbl+' - '+art.name, ir.resultType='Climate change', ir.unit='kg CO2 eq'
SET ir.value=round(row.v,4), ir.provenance='LCI-calculated', ir.computedAt='2026-08-28',
    ir.status = CASE WHEN row.sfx='S1' THEN 'data incomplete' ELSE 'calculated' END,
    ir.coverage=row.note, ir.ghgScope=row.sfx, ir.dataVariant='B-literal'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ic);

// --- 5. GHS hazard statements -------------------------------------------
UNWIND [
  {code:'H350', text:'May cause cancer',                                hazardClass:'CMR'},
  {code:'H351', text:'Suspected of causing cancer',                     hazardClass:'CMR'},
  {code:'H340', text:'May cause genetic defects',                       hazardClass:'CMR'},
  {code:'H360', text:'May damage fertility or the unborn child',        hazardClass:'CMR'},
  {code:'H372', text:'Causes damage to organs (prolonged exposure)',    hazardClass:'STOT'},
  {code:'H330', text:'Fatal if inhaled',                                hazardClass:'acute-tox'},
  {code:'H317', text:'May cause an allergic skin reaction',             hazardClass:'sensitiser'},
  {code:'H334', text:'May cause allergy/asthma symptoms if inhaled',    hazardClass:'sensitiser'},
  {code:'H314', text:'Causes severe skin burns and eye damage',         hazardClass:'corrosive'},
  {code:'H400', text:'Very toxic to aquatic life',                      hazardClass:'aquatic'},
  {code:'H410', text:'Very toxic to aquatic life, long lasting effects',hazardClass:'aquatic'},
  {code:'H411', text:'Toxic to aquatic life with long lasting effects', hazardClass:'aquatic'}
] AS h
MERGE (hs:HazardStatement {code:h.code})
  SET hs.text=h.text, hs.hazardClass=h.hazardClass, hs.scheme='GHS/CLP';

// --- 6. Hazard classification on identifiable elementary flows ----------
MATCH (f:Flow)
WHERE f.flowType='ElementaryFlow' AND f.name IS NOT NULL
WITH f, toLower(f.name) AS n
SET f.hazardClass = CASE
      WHEN n IN ['mercury','lead','cadmium','arsenic','chromium vi','nickel','zinc','antimony','cobalt','copper','chromium']
        THEN 'heavy-metal'
      WHEN n IN ['benzene','formaldehyde','benzo[a]pyrene','ethylene oxide','acryolonitrile','acrylonitrile',
                 'vinyl chloride','trichloroethene','dichloromethane','1;2-dichloroethane']
        THEN 'CMR'
      WHEN n IN ['sulfur dioxide','sulfur oxides','sulfur trioxide','nitrogen oxides','nitrogen dioxide',
                 'nitrogen monoxide','ammonia']
        THEN 'acidifying-precursor'
      WHEN n CONTAINS 'particulates' OR n CONTAINS 'particulate matter' OR n CONTAINS ' dust'
        THEN 'particulate'
      WHEN n CONTAINS 'nmvoc' OR n CONTAINS 'non-methane volatile' OR n CONTAINS 'volatile organic compounds'
           OR n IN ['toluene','xylene','ethylbenzene','styrene','hexane','isoprene']
        THEN 'VOC'
      ELSE f.hazardClass END;

MATCH (f:Flow) WHERE f.hazardClass IS NOT NULL
WITH f, f.hazardClass AS hc
MATCH (hs:HazardStatement)
WHERE (hc='heavy-metal'          AND hs.code IN ['H410','H372','H351'])
   OR (hc='CMR'                  AND hs.code IN ['H350','H340'])
   OR (hc='acidifying-precursor' AND hs.code IN ['H314','H330'])
   OR (hc='particulate'          AND hs.code IN ['H372'])
   OR (hc='VOC'                  AND hs.code IN ['H351','H317'])
MERGE (f)-[r:HAS_HAZARD]->(hs) SET r.basis='v3.f class-based screening assignment';

// --- 7. Pollutant-register demonstrator --------------------------------
MERGE (as:Assessment {id:'ASSESS_POLLUTANT_ART_V_AL'})
  ON CREATE SET as.name='Pollutant release register - V-groove jaws',
                as.assessmentType='pollutant inventory',
                as.methodology='characterised elementary-flow register (E-PRTR style)',
                as.status='partial', as.systemBoundary='cradle-to-gate',
                as.functionalUnit='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper';
MATCH (as:Assessment {id:'ASSESS_POLLUTANT_ART_V_AL'}), (art:Artifact {id:'ART_V_AL'}),
      (ap:AssessmentApproach {id:'APM_POLLUTANT'})
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:APPLIES_APPROACH]->(ap);

// --- 8. Water-use category unit + footprint demonstrator (structure only) -----
// Diagnostic finding (2026-08-28): PROC_ALU_EXTRUSION_EF and PROC_STEEL_SECTIONS_ILCD
// carry NO IC_EF_WATER_USE characterisation; only PROC_PA66_GRANULATE_MIX does, and
// its per-kg figure (~165 m3 world eq/kg) is implausibly high. The interface part is
// a constant 20 g in all 5 grippers, so a computed value would be identical and
// misleading. -> materialise the 1.1.3 demonstrator as SHELLS with status
// 'data incomplete'; real numbers wait for a water-inventory dataset (open task).
MATCH (ic:ImpactCategory {id:'IC_EF_WATER_USE'})
SET ic.referenceUnit = coalesce(ic.referenceUnit,'m3 world eq');

UNWIND ['ART_V_AL','ART_FLAT_AL','ART_LONG_AL','ART_INTERNAL_AL','ART_PREC_AL7075'] AS aid
MATCH (art:Artifact {id:aid}), (ap:AssessmentApproach {id:'APM_CF_H2O'}),
      (ic:ImpactCategory {id:'IC_EF_WATER_USE'})
MERGE (as:Assessment {id:'ASSESS_H2O_'+aid})
  ON CREATE SET as.name='Water footprint - '+aid,
                as.assessmentType='water footprint screening',
                as.methodology='AWARE-style (ISO 14046); see base_queries/water_footprint.cypher',
                as.systemBoundary='cradle-to-gate',
                as.functionalUnit='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper'
SET as.status='data incomplete'
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:APPLIES_APPROACH]->(ap)
MERGE (ir:ImpactResult {id:'IR_H2O_'+aid})
  ON CREATE SET ir.name='Water use - '+aid, ir.resultType='Water use', ir.unit='m3 world eq'
SET ir.value=NULL, ir.provenance='not computed', ir.computedAt='2026-08-28',
    ir.status='data incomplete',
    ir.coverage='blocked: Al/steel datasets have no AWARE water factor; PA66 proxy factor implausible'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ic);

// --- verification -----------------------------------------------------
MATCH (p:Process) RETURN p.ghgScope AS scope, count(*) AS processes ORDER BY scope;
MATCH (f:Flow) WHERE f.ghgSpecies IS NOT NULL RETURN f.ghgSpecies AS species, count(*) AS flows ORDER BY flows DESC;
MATCH (ir:ImpactResult) WHERE ir.id STARTS WITH 'IR_GHG_'
RETURN ir.id AS id, ir.value AS kgCO2e, ir.status AS status ORDER BY id;
MATCH (hs:HazardStatement) OPTIONAL MATCH (f:Flow)-[:HAS_HAZARD]->(hs)
RETURN hs.code AS code, hs.hazardClass AS class, count(f) AS flows ORDER BY code;
MATCH (f:Flow) WHERE f.hazardClass IS NOT NULL RETURN f.hazardClass AS class, count(*) AS flows ORDER BY flows DESC;
MATCH (ir:ImpactResult) WHERE ir.id STARTS WITH 'IR_H2O_' RETURN ir.id AS id, ir.value AS m3worldEq ORDER BY id;
MATCH (ap:AssessmentApproach {level:'method'})<-[:APPLIES_APPROACH]-(as:Assessment)
WHERE ap.code IN ['1.1.3','1.1.4','1.2.2']
RETURN ap.code AS code, ap.id AS approach, count(DISTINCT as) AS assessments ORDER BY code;

// --- rollback -------------------------------------------------------
// MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASSESS_GHG_' OR as.id STARTS WITH 'ASSESS_H2O_' OR as.id='ASSESS_POLLUTANT_ART_V_AL'
//   OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir) DETACH DELETE as, ir;
// MATCH (m:ImpactAssessmentMethod {id:'IAM_GHG'}) DETACH DELETE m;
// MATCH (:Flow)-[r:HAS_HAZARD]->() DELETE r;
// MATCH (hs:HazardStatement) DETACH DELETE hs;
// MATCH (f:Flow) REMOVE f.ghgSpecies, f.hazardClass;
// MATCH (p:Process) REMOVE p.ghgScope, p.ghgScopeCategory, p.ghgScopeBasis;
