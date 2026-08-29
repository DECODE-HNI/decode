// ============================================================================
// v2_data/3_material_gwp_literals.cypher  --  Literature A1 GWP + derived EF3.1
// category factors per kg, for every real material (Variant B basis).
// See ASSUMPTIONS.md section 1. Additive. Rollback at bottom. 2026-08-27
// ============================================================================

// --- 1. A1 GWP literal per material -----------------------------------
UNWIND [
  {id:'MAT_AL6061',  gwp:9.67}, {id:'MAT_AL7075', gwp:9.67},
  {id:'MAT_STEEL',   gwp:2.30}, {id:'MAT_SPRING', gwp:2.80},
  {id:'MAT_PA12',    gwp:9.00}, {id:'MAT_PA11',   gwp:5.50},
  {id:'MAT_PETG',    gwp:4.00}, {id:'MAT_PLA',    gwp:2.70},
  {id:'MAT_ABS',     gwp:4.00}, {id:'MAT_ASA',    gwp:4.50},
  {id:'MAT_PC',      gwp:5.50}, {id:'MAT_POM',    gwp:3.60},
  {id:'MAT_CFPA',    gwp:24.0},
  {id:'MAT_TPU',     gwp:5.20}, {id:'MAT_TPE',    gwp:4.20},
  {id:'MAT_SILICONE',gwp:7.00}, {id:'MAT_NBR',    gwp:3.50}, {id:'MAT_PU', gwp:4.50}
] AS d
MATCH (m:Material {id:d.id})
SET m.gwp_A1_kgCO2e_per_kg = d.gwp,
    m.gwpBasis = 'ASSUMPTIONS.md 1 (literature order-of-magnitude)';

// --- 2. derived EF3.1 category factors per kg (ratio to the Al dataset) --
//   ratios from PROC_ALU_EXTRUSION_EF per-kg profile (ASSUMPTIONS.md 1).
//   Neo4j has no map property type -> parallel arrays, category id order:
//   [IC_CLIMATE, IC_EF_ACIDIFICATION, IC_EF_EUTROPH_MARINE, IC_EF_PHOTOCHEM_OZONE,
//    IC_EF_LAND_USE, IC_EF_OZONE_DEPLETION, IC_EF_PARTICULATE_MATTER]
MATCH (m:Material) WHERE m.gwp_A1_kgCO2e_per_kg IS NOT NULL
WITH m, m.gwp_A1_kgCO2e_per_kg AS g
SET m.ef31_categories = ['IC_CLIMATE','IC_EF_ACIDIFICATION','IC_EF_EUTROPH_MARINE',
                          'IC_EF_PHOTOCHEM_OZONE','IC_EF_LAND_USE','IC_EF_OZONE_DEPLETION',
                          'IC_EF_PARTICULATE_MATTER'],
    m.ef31_factors_A1 = [ g,
                          round(g * 5.4e-3, 6),
                          round(g * 1.07e-3, 6),
                          round(g * 3.15e-3, 6),
                          round(g * 0.89, 4),
                          0.0,
                          0.0 ],
    m.ef31Basis = 'ASSUMPTIONS.md 1 (scaled from Al dataset ratios; weak for polymers)';

// --- 3. refine circularity params from ASSUMPTIONS.md 5 ---------------
UNWIND [
  {ids:['MAT_AL6061','MAT_AL7075'],                       fr:0.35, cr:0.90, cu:0.05},
  {ids:['MAT_STEEL','MAT_SPRING'],                        fr:0.40, cr:0.85, cu:0.05},
  {ids:['MAT_PA12','MAT_PA11','MAT_PETG','MAT_ABS','MAT_ASA','MAT_PC','MAT_POM'], fr:0.05, cr:0.20, cu:0.00},
  {ids:['MAT_PLA'],                                       fr:0.00, cr:0.10, cu:0.00},
  {ids:['MAT_TPU','MAT_TPE','MAT_SILICONE','MAT_NBR','MAT_PU'], fr:0.00, cr:0.10, cu:0.00},
  {ids:['MAT_CFPA'],                                      fr:0.00, cr:0.05, cu:0.00}
] AS d
UNWIND d.ids AS mid
MATCH (m:Material {id:mid})
SET m.recycledContentAssumed = d.fr, m.recyclingRate = d.cr, m.reusability = d.cu,
    m.circularityBasis = 'ASSUMPTIONS.md 5 (refined from v3.a class defaults)';

// --- verification -------------------------------------------------
MATCH (m:Material) WHERE m.gwp_A1_kgCO2e_per_kg IS NOT NULL
RETURN m.materialType AS class, count(*) AS materials,
       round(min(m.gwp_A1_kgCO2e_per_kg),1) AS minGwp, round(max(m.gwp_A1_kgCO2e_per_kg),1) AS maxGwp
ORDER BY class;

// --- rollback ---------------------------------------------------
// MATCH (m:Material) REMOVE m.gwp_A1_kgCO2e_per_kg, m.gwpBasis, m.ef31_A1, m.ef31Basis;
