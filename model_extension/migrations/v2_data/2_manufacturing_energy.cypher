// ============================================================================
// v2_data/2_manufacturing_energy.cypher  --  A3 manufacturing energy.
// Sets Process.energyIntensity_kWh_per_kg + materialFactor, gives the template
// electricity flow a climate characterization factor for the default grid.
// See ASSUMPTIONS.md sections 2 + 3. Additive. Rollback at bottom. 2026-08-27
// ============================================================================

// --- 1. energy + material factor per manufacturing process --------------
UNWIND [
  {id:'PROC_MJF',                  kwh:15.0, matf:1.1},
  {id:'PROC_SLS',                  kwh:30.0, matf:1.1},
  {id:'PROC_FFF',                  kwh:20.0, matf:1.1},
  {id:'PROC_CNC',                  kwh:20.0, matf:1.8},
  {id:'PROC_LASER',                kwh:8.0,  matf:1.3},
  {id:'PROC_BEND',                 kwh:2.0,  matf:1.05},
  {id:'PROC_SILCAST',              kwh:4.0,  matf:1.05},
  {id:'PROC_RUBBER',               kwh:5.0,  matf:1.05},
  {id:'PROC_OVERMOLD',             kwh:6.0,  matf:1.05},
  {id:'PROC_ALU_CAST_MACHINING',   kwh:15.0, matf:1.3},
  {id:'PROC_ALU_SHEET_STAMPING',   kwh:3.0,  matf:1.1}
] AS d
MATCH (pr:Process {id:d.id})
SET pr.energyIntensity_kWh_per_kg = d.kwh,
    pr.materialFactor             = d.matf,
    pr.energyBasis                = 'ASSUMPTIONS.md 2';

// --- 2. electricity emission factors (grid variants) -----------------
//   stored on the template FLOW_ELECTRICITY as a small property map-ish set
MATCH (f:Flow {id:'FLOW_ELECTRICITY'})
SET f.gwp_kgCO2e_per_kWh_DE       = 0.38,
    f.gwp_kgCO2e_per_kWh_DE_green = 0.04,
    f.gwp_kgCO2e_per_kWh_CN       = 0.58,
    f.gwp_kgCO2e_per_kWh_EU       = 0.28,
    f.electricityFactorBasis      = 'ASSUMPTIONS.md 3 (default: DE)';

// --- 3. give FLOW_ELECTRICITY a CHARACTERIZES factor to IC_CLIMATE (DE) --
MATCH (f:Flow {id:'FLOW_ELECTRICITY'}), (ic:ImpactCategory {id:'IC_CLIMATE'})
MERGE (f)-[c:CHARACTERIZES {characterizesId:'CF_FLOW_ELECTRICITY_IC_CLIMATE_DE'}]->(ic)
SET c.factor = 0.38, c.location = 'DE', c.source = 'ASSUMPTIONS.md 3';

// --- 4. set real amounts on the manufacturing template flows -----------
//   material input  = part mass x materialFactor
//   electricity     = part mass x energyIntensity
//   (per gripper the query multiplies by component quantity)
MATCH (mp:Process {processType:'Manufacturing'})-[:APPLIES_TO]->(p:Part)
WHERE mp.energyIntensity_kWh_per_kg IS NOT NULL AND p.mass_g IS NOT NULL
WITH mp, avg(p.mass_g)/1000.0 AS avgMass_kg   // representative part mass for this route
MATCH (mp)-[hfe:HAS_FLOW]->(fe:Flow {id:'FLOW_ELECTRICITY'})
SET hfe.amount = round(avgMass_kg * mp.energyIntensity_kWh_per_kg, 4), hfe.unit = 'kWh',
    hfe.amountBasis = 'v2-data: representative part mass x energy intensity';

MATCH (mp:Process {processType:'Manufacturing'})-[:APPLIES_TO]->(p:Part)
WHERE mp.materialFactor IS NOT NULL AND p.mass_g IS NOT NULL
WITH mp, avg(p.mass_g)/1000.0 AS avgMass_kg
MATCH (mp)-[hfm:HAS_FLOW]->(fm:Flow)
WHERE fm.id STARTS WITH 'FLOW_' AND fm.id <> 'FLOW_ELECTRICITY'
  AND fm.id <> 'FLOW_COMPONENT' AND fm.id <> 'FLOW_WASTE'
SET hfm.amount = round(avgMass_kg * mp.materialFactor, 4), hfm.unit = 'kg',
    hfm.amountBasis = 'v2-data: representative part mass x material factor';

// --- verification -------------------------------------------------
MATCH (mp:Process {processType:'Manufacturing'}) WHERE mp.energyIntensity_kWh_per_kg IS NOT NULL
MATCH (mp)-[hfe:HAS_FLOW]->(:Flow {id:'FLOW_ELECTRICITY'})
RETURN mp.id, mp.energyIntensity_kWh_per_kg AS kwh_per_kg, hfe.amount AS elec_kWh
ORDER BY mp.id;

// --- rollback ---------------------------------------------------
// MATCH (pr:Process) REMOVE pr.energyIntensity_kWh_per_kg, pr.materialFactor, pr.energyBasis;
// MATCH (f:Flow {id:'FLOW_ELECTRICITY'}) REMOVE f.gwp_kgCO2e_per_kWh_DE, f.gwp_kgCO2e_per_kWh_DE_green,
//   f.gwp_kgCO2e_per_kWh_CN, f.gwp_kgCO2e_per_kWh_EU, f.electricityFactorBasis;
// MATCH (:Flow {id:'FLOW_ELECTRICITY'})-[c:CHARACTERIZES {characterizesId:'CF_FLOW_ELECTRICITY_IC_CLIMATE_DE'}]->() DELETE c;
