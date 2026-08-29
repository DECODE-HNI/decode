// ============================================================================
// migration_v3g.cypher  --  Module v3.g: Cross-Impact & scenario assessment
//   2.2.2 Cross-Impact-Wirkungsanalyse  (INFLUENCES matrix)
//   2.2.1 Szenario-gestützte Umweltbewertung  (results under SC_RECYCLED_ALU)
// Additive. Re-MATCH by id in every statement. Rollback at bottom. 2026-08-28
//
// INFLUENCES sign convention:
//   sign = '+'  -> the cause IMPROVES the target category's sustainability outcome
//                  (lowers burden, or raises circularity / repairability)
//   sign = '-'  -> the cause WORSENS it
//   strength    -> 1 weak · 2 moderate · 3 strong   (qualitative, engineering-reasoned)
// Rationale + sources: model_extension/migrations/ASSUMPTIONS.md §7.
// ============================================================================

// --- 1. Cross-Impact: design lever -> impact category --------------------
UNWIND [
  {from:'FEAT_PRINTABLE', to:'IC_REPAIRABILITY',                        sign:'+', strength:3, mechanism:'replaceable printed contact element -> field repair without spares'},
  {from:'FEAT_PRINTABLE', to:'IC_CIRCULARITY',                          sign:'+', strength:2, mechanism:'print-on-demand spare parts, no inventory scrap'},
  {from:'FEAT_PRINTABLE', to:'IC_CLIMATE',                              sign:'-', strength:1, mechanism:'extra polymer part + FFF energy'},
  {from:'FEAT_EASY',      to:'IC_REPAIRABILITY',                        sign:'+', strength:3, mechanism:'toolless robot interface -> fast reversible mounting'},
  {from:'FEAT_EASY',      to:'IC_CIRCULARITY',                          sign:'+', strength:2, mechanism:'non-destructive disassembly enables material separation'},
  {from:'FEAT_MAGNET',    to:'IC_REPAIRABILITY',                        sign:'+', strength:3, mechanism:'magnetic quick-change contact face'},
  {from:'FEAT_MAGNET',    to:'IC_CIRCULARITY',                          sign:'-', strength:1, mechanism:'NdFeB magnet, hard to separate / recycle'},
  {from:'FEAT_MAGNET',    to:'IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS',sign:'-', strength:2, mechanism:'rare-earth (Nd, Dy) demand'},
  {from:'FEAT_RUBBER',    to:'IC_CIRCULARITY',                          sign:'-', strength:2, mechanism:'elastomer pad, thermoset -> low MCI'},
  {from:'FEAT_RUBBER',    to:'IC_REPAIRABILITY',                        sign:'+', strength:1, mechanism:'friction pad is a replaceable wear part'},
  {from:'FEAT_SOFT',      to:'IC_CIRCULARITY',                          sign:'-', strength:2, mechanism:'monolithic cast elastomer finger, not separable'},
  {from:'FEAT_SUCTION',   to:'IC_CLIMATE',                              sign:'-', strength:1, mechanism:'compressed-air use phase (not yet in system boundary)'},
  {from:'CP_DISASSEMBLY', to:'IC_REPAIRABILITY',                        sign:'+', strength:3, mechanism:'definitional: disassembly capability drives the repair index'},
  {from:'CP_DISASSEMBLY', to:'IC_CIRCULARITY',                          sign:'+', strength:2, mechanism:'design for disassembly -> end-of-life material recovery'}
] AS e
MATCH (src {id:e.from}), (ic:ImpactCategory {id:e.to})
MERGE (src)-[r:INFLUENCES]->(ic)
SET r.sign=e.sign, r.strength=e.strength, r.mechanism=e.mechanism,
    r.evidenceLevel='engineering-reasoned', r.source='ASSUMPTIONS.md §7', r.module='v3.g';

// --- 2. Cross-Impact: material class -> impact category -----------------
UNWIND [
  {cls:'metal',     to:'IC_CIRCULARITY',   sign:'+', strength:3, mechanism:'closed-loop recyclable, MCI ~0.65'},
  {cls:'metal',     to:'IC_CLIMATE',       sign:'-', strength:2, mechanism:'primary Al 9.67 kg CO2e/kg + CNC swarf'},
  {cls:'composite', to:'IC_CLIMATE',       sign:'-', strength:3, mechanism:'CF-PA ~24 kg CO2e/kg'},
  {cls:'composite', to:'IC_CIRCULARITY',   sign:'-', strength:3, mechanism:'carbon-fibre/PA, no viable recycling route, MCI ~0.14'},
  {cls:'composite', to:'IC_REPAIRABILITY', sign:'+', strength:1, mechanism:'stiff printed long fingers -> replaceable module'},
  {cls:'polymer',   to:'IC_CLIMATE',       sign:'+', strength:1, mechanism:'lower embodied carbon than metal for the contact part'},
  {cls:'polymer',   to:'IC_CIRCULARITY',   sign:'-', strength:1, mechanism:'mixed-polymer recyclate quality, MCI ~0.33'},
  {cls:'elastomer', to:'IC_CIRCULARITY',   sign:'-', strength:3, mechanism:'thermoset elastomers, MCI ~0.16'}
] AS e
MATCH (m:Material {materialType:e.cls}), (ic:ImpactCategory {id:e.to})
MERGE (m)-[r:INFLUENCES]->(ic)
SET r.sign=e.sign, r.strength=e.strength, r.mechanism=e.mechanism,
    r.evidenceLevel='engineering-reasoned', r.source='ASSUMPTIONS.md §7', r.module='v3.g';

// --- 3. Cross-Impact: category -> category trade-offs ------------------
UNWIND [
  {from:'IC_CIRCULARITY',   to:'IC_CLIMATE',       sign:'+', strength:2, mechanism:'higher recycled feedstock lowers A1 GWP'},
  {from:'IC_REPAIRABILITY', to:'IC_CLIMATE',       sign:'+', strength:2, mechanism:'lifetime extension amortises embodied carbon over more cycles'},
  {from:'IC_REPAIRABILITY', to:'IC_CIRCULARITY',   sign:'+', strength:3, mechanism:'design for disassembly is the common cause of both'},
  {from:'IC_CIRCULARITY',   to:'IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS', sign:'+', strength:3, mechanism:'secondary metal displaces primary extraction'}
] AS e
MATCH (a:ImpactCategory {id:e.from}), (b:ImpactCategory {id:e.to})
MERGE (a)-[r:INFLUENCES]->(b)
SET r.sign=e.sign, r.strength=e.strength, r.mechanism=e.mechanism,
    r.evidenceLevel='LCA-textbook', r.source='ASSUMPTIONS.md §7', r.module='v3.g';

// --- 4. Cross-Impact demonstrator assessment -------------------------
MERGE (as:Assessment {id:'ASSESS_CROSSIMPACT_ART_V_AL'})
  ON CREATE SET as.name='Cross-impact screening - V-groove jaws',
                as.assessmentType='cross-impact analysis',
                as.methodology='qualitative influence matrix (sign x strength), engineering-reasoned',
                as.status='partial', as.systemBoundary='design-decision level',
                as.functionalUnit='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper';
MATCH (as:Assessment {id:'ASSESS_CROSSIMPACT_ART_V_AL'}), (art:Artifact {id:'ART_V_AL'}),
      (ap:AssessmentApproach {id:'APM_CROSS_IMPACT'})
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:APPLIES_APPROACH]->(ap);

// --- 5. Scenario assessment: SC_RECYCLED_ALU climate ----------------
// recycled-content-adjusted A1 factor for aluminium:
//   gwp_adj = primary(9.67)*(1-rc) + recycled(0.55)*rc ,  rc = 0.75  -> 2.83 kg CO2e/kg
MATCH (ms:ModelScenario {id:'SC_RECYCLED_ALU'})-[:SETS]->(:ParameterValue {value:0.75})
WITH 9.67*(1.0-0.75) + 0.55*0.75 AS gwpAdjAl
MATCH (art:Artifact)-[:HAS_PROCESS_PLAN]->(:ProcessPlan)-[:CONTAINS_PROCESS]->(mp:Process {processType:'Manufacturing'})
WHERE art.id IN ['ART_V_AL','ART_FLAT_AL','ART_LONG_AL','ART_INTERNAL_AL','ART_PREC_AL7075']
MATCH (art)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(mat:Material)
WHERE p.mass_g IS NOT NULL
WITH art, gwpAdjAl,
     sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg,
     coalesce(mp.energyIntensity_kWh_per_kg,20.0) AS eInt,
     sum(p.mass_g*hc.quantity/1000.0 *
         CASE WHEN mat.materialType='metal' THEN gwpAdjAl
              ELSE coalesce(mat.gwp_A1_kgCO2e_per_kg,0.0) END) AS a1
WITH art, a1 + mass_kg*eInt*0.38 AS climateScen
MERGE (as:Assessment {id:'ASSESS_EF31_SCEN_RECALU_'+art.id})
  ON CREATE SET as.name='EF3.1 climate under recycled-Al scenario - '+art.id,
                as.assessmentType='scenario assessment',
                as.methodology='Variant-B climate with recycled-content-adjusted Al A1 factor (rc=0.75)',
                as.status='partial', as.systemBoundary='cradle-to-gate',
                as.functionalUnit='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper',
                as.dataVariant='B-literal', as.scenarioRef='SC_RECYCLED_ALU'
WITH as, art, climateScen
MATCH (ms:ModelScenario {id:'SC_RECYCLED_ALU'}), (ap:AssessmentApproach {id:'APM_SCENARIO_ASSESSMENT'}),
      (ic:ImpactCategory {id:'IC_CLIMATE'})
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:APPLIES_APPROACH]->(ap)
MERGE (as)-[:UNDER_SCENARIO]->(ms)
MERGE (ir:ImpactResult {id:'IR_EF31_SCEN_RECALU_'+art.id+'_IC_CLIMATE'})
  ON CREATE SET ir.name='Climate (recycled-Al scenario) - '+art.id,
                ir.resultType='Climate change', ir.unit='kg CO2 eq'
SET ir.value=round(climateScen,4), ir.provenance='LCI-calculated', ir.computedAt='2026-08-28',
    ir.status='calculated', ir.scenarioRef='SC_RECYCLED_ALU', ir.dataVariant='B-literal',
    ir.coverage='A1 (recycled-content-adjusted Al + literal others) + A3 electricity'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(ic);

// --- verification -------------------------------------------------
MATCH ()-[r:INFLUENCES]->() RETURN r.module AS module, r.sign AS sign, count(*) AS edges ORDER BY sign;
MATCH (src)-[r:INFLUENCES]->(ic:ImpactCategory)
RETURN labels(src)[0] AS fromType, count(*) AS edges ORDER BY fromType;
MATCH (b:ImpactResult {id:'IR_EF31_SCEN_RECALU_ART_V_AL_IC_CLIMATE'}),
      (base:ImpactResult {id:'IR_EF31B_ART_V_AL_IC_CLIMATE'})
RETURN base.value AS baseline_climate, b.value AS recycledAl_climate,
       round(base.value-b.value,4) AS saving;
MATCH (ap:AssessmentApproach {level:'method'})<-[:APPLIES_APPROACH]-(as:Assessment)
WHERE ap.code IN ['2.2.1','2.2.2']
RETURN ap.code AS code, ap.id AS approach, count(DISTINCT as) AS assessments ORDER BY code;

// --- rollback ---------------------------------------------------
// MATCH ()-[r:INFLUENCES {module:'v3.g'}]->() DELETE r;
// MATCH (as:Assessment) WHERE as.id='ASSESS_CROSSIMPACT_ART_V_AL' OR as.id STARTS WITH 'ASSESS_EF31_SCEN_RECALU_'
//   OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir) DETACH DELETE as, ir;
