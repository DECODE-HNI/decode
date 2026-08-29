// ============================================================================
// migration_v3h.cypher  --  Module v3.h: advanced LCA (light -- hook + 1 example each)
//   2.1.1 prospective LCA    (SC_GRID_2035 + climate under it)
//   2.1.2 dynamic LCA        (CHARACTERIZES_DYNAMIC, GWP20)
//   2.1.3 consequential LCA  (SUBSTITUTES / AVOIDS, module-D credit, marketType)
//   2.1.4 hybrid LCA         (EEIOSector + COVERED_BY_EEIO)
// Additive. Re-MATCH by id in every statement. Rollback at bottom. 2026-08-29
// ============================================================================

// ==== 2.1.1 PROSPECTIVE LCA ==============================================
MERGE (ms:ModelScenario {id:'SC_GRID_2035'})
  SET ms.name='DE grid mix 2035 projection', ms.type='prospective', ms.horizonYear=2035,
      ms.note='DE electricity CF 0.15 kg CO2e/kWh (policy-scenario projection)', ms.module='v3.h';

MATCH (p:Process) WHERE p.processType IN ['Manufacturing','Postprocess']
SET p.marketPeriod='2020-2025', p.timeValidFrom=2020, p.timeValidUntil=2025;

// climate for the 5 aluminium grippers under the 2035 grid (A1 materials + A3 electricity @ 0.15)
MATCH (art:Artifact)-[:HAS_PROCESS_PLAN]->(:ProcessPlan)-[:CONTAINS_PROCESS]->(mp:Process {processType:'Manufacturing'})
WHERE art.id IN ['ART_V_AL','ART_FLAT_AL','ART_LONG_AL','ART_INTERNAL_AL','ART_PREC_AL7075']
MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(mat:Material)
WHERE p.mass_g IS NOT NULL
WITH art,
     sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg,
     coalesce(mp.energyIntensity_kWh_per_kg,20.0) AS eInt,
     sum(p.mass_g*hc.quantity/1000.0 * coalesce(mat.gwp_A1_kgCO2e_per_kg,0.0)) AS a1
WITH art, a1 + mass_kg*eInt*0.15 AS climate2035
MERGE (as:Assessment {id:'ASSESS_EF31_SCEN_GRID2035_'+art.id})
  ON CREATE SET as.name='EF3.1 climate under DE grid 2035 - '+art.id,
                as.assessmentType='prospective LCA', as.status='partial',
                as.methodology='Variant-B climate with a 2035 grid emission factor (0.15)',
                as.systemBoundary='cradle-to-gate', as.functionalUnit='one gripper',
                as.referenceQuantity=1.0, as.referenceUnit='gripper',
                as.dataVariant='B-literal', as.scenarioRef='SC_GRID_2035'
WITH as, art, climate2035
MATCH (ms:ModelScenario {id:'SC_GRID_2035'}), (ap:AssessmentApproach {id:'APM_PROSPECTIVE_LCA'}),
      (ic:ImpactCategory {id:'IC_CLIMATE'})
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:APPLIES_APPROACH]->(ap)
MERGE (as)-[:UNDER_SCENARIO]->(ms)
MERGE (ir:ImpactResult {id:'IR_EF31_SCEN_GRID2035_'+art.id+'_IC_CLIMATE'})
  ON CREATE SET ir.name='Climate (grid 2035) - '+art.id, ir.resultType='Climate change', ir.unit='kg CO2 eq'
SET ir.value=round(climate2035,4), ir.provenance='LCI-calculated', ir.computedAt='2026-08-29',
    ir.status='calculated', ir.scenarioRef='SC_GRID_2035', ir.dataVariant='B-literal',
    ir.coverage='A1 material literals + A3 electricity at a 2035 grid factor (0.15)'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ic);

// ==== 2.1.2 DYNAMIC LCA =================================================
// GWP20 (IPCC AR6) on the key climate flows, alongside the GWP100 CHARACTERIZES.
UNWIND [
  {fid:'08a91e70-3ddc-11dd-923d-0050c2490048', gwp20:1.0},      // carbon dioxide (fossil)
  {fid:'08a91e70-3ddc-11dd-9c14-0050c2490048', gwp20:1.0},      // carbon dioxide (fossil), 2nd node
  {fid:'08a91e70-3ddc-11dd-9610-0050c2490048', gwp20:82.5},     // methane (fossil)
  {fid:'fe0acd60-3ddc-11dd-a8e8-0050c2490048', gwp20:80.3},     // methane (biogenic)
  {fid:'08a91e70-3ddc-11dd-94c3-0050c2490048', gwp20:273.0},    // nitrous oxide
  {fid:'fe0acd60-3ddc-11dd-ac51-0050c2490048', gwp20:18300.0}   // sulfur hexafluoride
] AS d
MATCH (f:Flow {id:d.fid}), (ic:ImpactCategory {id:'IC_CLIMATE'})
MERGE (f)-[cd:CHARACTERIZES_DYNAMIC {timeHorizon:20}]->(ic)
  SET cd.factor=d.gwp20, cd.metric='GWP20', cd.source='IPCC AR6', cd.module='v3.h';

MERGE (as:Assessment {id:'ASSESS_DYNLCA_ART_V_AL'})
  ON CREATE SET as.name='Dynamic LCA (GWP20 vs GWP100) - V-groove jaws',
                as.assessmentType='dynamic LCA', as.status='partial',
                as.methodology='recompute IC_CLIMATE with CHARACTERIZES_DYNAMIC{timeHorizon:20}; see base_queries/dynamic_gwp.cypher',
                as.systemBoundary='cradle-to-gate', as.functionalUnit='one gripper',
                as.referenceQuantity=1.0, as.referenceUnit='gripper';
MATCH (as:Assessment {id:'ASSESS_DYNLCA_ART_V_AL'}), (art:Artifact {id:'ART_V_AL'}),
      (ap:AssessmentApproach {id:'APM_DYNAMIC_LCA'})
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:APPLIES_APPROACH]->(ap);

// ==== 2.1.3 CONSEQUENTIAL LCA ==========================================
MATCH (p:Process {id:'PROC_ALU_EXTRUSION_EF'}) SET p.marketType='average';
// recycling route credits avoided PRIMARY aluminium (EN 15804 module D)
MATCH (e:EndOfLifeRoute {id:'EOL_RECYCLING'}), (p:Process {id:'PROC_ALU_EXTRUSION_EF'})
MERGE (e)-[a:AVOIDS]->(p)
  SET a.ratio=0.90, a.module='D', a.avoidedProcess='primary aluminium production',
      a.avoidedGwp_kgCO2e_per_kg=8.2,
      a.basis='Al EoL recycling rate 0.90 x (primary 9.67 - secondary 0.55) kg CO2e/kg', a.module_v='v3.h';
// secondary aluminium substitutes primary (marginal supplier view)
MATCH (p:Process {id:'PROC_ALU_EXTRUSION_EF'})
MERGE (sec:Process {id:'PROC_ALU_SECONDARY_MARGINAL'})
  ON CREATE SET sec.name='Secondary aluminium (marginal, remelt)', sec.processType='RawMaterialProduction',
                sec.marketType='marginal', sec.gwp_A1_kgCO2e_per_kg=0.55,
                sec.provenance='v3.h consequential hook (literature order of magnitude)', sec.lifecycleModule='A1-A3';
MATCH (sec:Process {id:'PROC_ALU_SECONDARY_MARGINAL'}), (p:Process {id:'PROC_ALU_EXTRUSION_EF'})
MERGE (sec)-[s:SUBSTITUTES]->(p) SET s.ratio=1.0, s.basis='remelt secondary displaces primary ingot', s.module='v3.h';

MERGE (as:Assessment {id:'ASSESS_CONSEQ_ART_V_AL'})
  ON CREATE SET as.name='Consequential LCA hook (module D credit) - V-groove jaws',
                as.assessmentType='consequential LCA', as.status='partial',
                as.methodology='attributional core + module-D avoided-burden credit via EOL_RECYCLING-[:AVOIDS]->primary; see base_queries/avoided_burden.cypher',
                as.systemBoundary='cradle-to-grave + module D', as.functionalUnit='one gripper',
                as.referenceQuantity=1.0, as.referenceUnit='gripper';
MATCH (as:Assessment {id:'ASSESS_CONSEQ_ART_V_AL'}), (art:Artifact {id:'ART_V_AL'}),
      (ap:AssessmentApproach {id:'APM_CONSEQUENTIAL_LCA'})
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:APPLIES_APPROACH]->(ap);

// ==== 2.1.4 HYBRID LCA =================================================
UNWIND [
  {id:'EEIO_C25', name:'Fabricated metal products (ISIC C25)',      isic:'C25', gwpPerEUR:0.80},
  {id:'EEIO_C22', name:'Rubber and plastics products (ISIC C22)',   isic:'C22', gwpPerEUR:1.20},
  {id:'EEIO_D35', name:'Electricity, gas, steam (ISIC D35)',        isic:'D35', gwpPerEUR:1.50},
  {id:'EEIO_H49', name:'Land transport (ISIC H49)',                 isic:'H49', gwpPerEUR:0.90}
] AS s
MERGE (e:EEIOSector {id:s.id})
  SET e.name=s.name, e.isicCode=s.isic, e.gwpIntensity_kgCO2e_per_EUR=s.gwpPerEUR,
      e.priceYear=2019, e.source='EXIOBASE 3 EU-27, producer prices (order of magnitude)', e.module='v3.h';

// cover the existing CostItem nodes with an EEIO sector (top-up path for cost not in a dataset)
MATCH (ci:CostItem)<-[:HAS_COST]-(x)
WITH ci, x, CASE
     WHEN 'Part' IN labels(x) OR ci.category='material' THEN 'EEIO_C25'
     WHEN ci.category IN ['energy'] THEN 'EEIO_D35'
     WHEN ci.category IN ['waste-management'] THEN 'EEIO_H49'
     ELSE 'EEIO_C25' END AS sectorId
MATCH (e:EEIOSector {id:sectorId})
MERGE (ci)-[c:COVERED_BY_EEIO]->(e)
  SET c.monetaryValue=ci.amount, c.currency=coalesce(ci.currency,'EUR'),
      c.note='hybrid top-up: EEIO intensity x monetary value', c.module='v3.h';

MERGE (as:Assessment {id:'ASSESS_HYBRID_ART_V_AL'})
  ON CREATE SET as.name='Hybrid LCA hook (process + EEIO top-up) - V-groove jaws',
                as.assessmentType='hybrid LCA', as.status='partial',
                as.methodology='process-LCA foreground + EEIOSector intensity x monetary value for cost items without a dataset; see base_queries/hybrid_eeio.cypher',
                as.systemBoundary='cradle-to-gate (hybrid)', as.functionalUnit='one gripper',
                as.referenceQuantity=1.0, as.referenceUnit='gripper';
MATCH (as:Assessment {id:'ASSESS_HYBRID_ART_V_AL'}), (art:Artifact {id:'ART_V_AL'}),
      (ap:AssessmentApproach {id:'APM_HYBRID_LCA'})
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:APPLIES_APPROACH]->(ap);

// --- verification ---------------------------------------------------
MATCH ()-[cd:CHARACTERIZES_DYNAMIC]->() RETURN count(cd) AS dynamicFactors;
MATCH (:EndOfLifeRoute)-[a:AVOIDS]->(:Process) RETURN a.avoidedGwp_kgCO2e_per_kg AS moduleD_credit_per_kg;
MATCH (e:EEIOSector) OPTIONAL MATCH (e)<-[c:COVERED_BY_EEIO]-() RETURN e.id AS sector, e.gwpIntensity_kgCO2e_per_EUR AS kgPerEUR, count(c) AS costItemsCovered ORDER BY sector;
MATCH (ir:ImpactResult) WHERE ir.id STARTS WITH 'IR_EF31_SCEN_GRID2035_'
RETURN ir.id AS id, ir.value AS climate2035 ORDER BY id;
MATCH (ap:AssessmentApproach {level:'method'})<-[:APPLIES_APPROACH]-(as:Assessment)
WHERE ap.code STARTS WITH '2.1.'
RETURN ap.code AS code, ap.id AS approach, count(DISTINCT as) AS assessments ORDER BY code;

// --- rollback -----------------------------------------------------
// MATCH ()-[cd:CHARACTERIZES_DYNAMIC {module:'v3.h'}]->() DELETE cd;
// MATCH (:EndOfLifeRoute)-[a:AVOIDS {module_v:'v3.h'}]->() DELETE a;
// MATCH (sec:Process {id:'PROC_ALU_SECONDARY_MARGINAL'}) DETACH DELETE sec;
// MATCH ()-[c:COVERED_BY_EEIO {module:'v3.h'}]->() DELETE c;
// MATCH (e:EEIOSector {module:'v3.h'}) DETACH DELETE e;
// MATCH (ms:ModelScenario {id:'SC_GRID_2035'}) DETACH DELETE ms;
// MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASSESS_EF31_SCEN_GRID2035_' OR as.id IN
//   ['ASSESS_DYNLCA_ART_V_AL','ASSESS_CONSEQ_ART_V_AL','ASSESS_HYBRID_ART_V_AL']
//   OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir) DETACH DELETE as, ir;
// MATCH (p:Process) REMOVE p.marketType, p.marketPeriod, p.timeValidFrom, p.timeValidUntil;
