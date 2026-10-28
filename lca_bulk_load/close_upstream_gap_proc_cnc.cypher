// ============================================================
// Closes the "upstream chain gap" for PROC_CNC (Precision jaws / Al7075 / CNC):
// The two generic legacy input flows (FLOW_ALUMINUM, FLOW_ELECTRICITY)
// are re-attached to the real, characterised ILCD library flows:
//   - Aluminium  -> PROC_ALU_INGOT_MIX_CONSUMPTION, reference output "Aluminium ingot"
//                   (ae206e6f-e4f5-4dbf-8de7-42576f6da892), 1 kg, exact quantity match
//   - Electricity -> PROC_ELECTRICITY_GREEN_GRID_MIX_DE, reference output "Electricity"
//                   (890a70b7-b677-4e2a-8a1b-7d017e0a10ae) -- the same flow node
//                   that PROC_ALU_CAST_MACHINING already uses as an input (shared
//                   flow instead of a duplicate, an existing pattern in the graph).
//                   Unit converted: 1 kWh = 3.6 MJ.
// Decision (2026-08-26): German green electricity mix instead of CN grid mix.
//
// Result: RES_PREC_AL7075_CC.value is computed for real for the first time instead of NULL,
// as a CHARACTERIZES-weighted sum of the two upstream processes (climate change),
// scaled to the quantity actually consumed (here 1:1 each, since the reference quantities
// match exactly).
//
// Prerequisite: runs on the local instance with the fully loaded
// V2 model (2,721 nodes / 79,642 relationships). Reversible via the old
// exchangeId values + reloading full_init.cypher, if necessary.
// ============================================================

// --- 1) Re-attach the aluminium input ---
MATCH (:Process {id:'PROC_CNC'})-[old:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_AL_IN'}]->(:Flow {id:'FLOW_ALUMINUM'})
DELETE old;

MATCH (p:Process {id:'PROC_CNC'}), (f:Flow {id:'ae206e6f-e4f5-4dbf-8de7-42576f6da892'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_AL_IN', direction:'input', amount:1.0, unit:'kg'}]->(f);

// --- 2) Re-attach the electricity input (kWh -> MJ) ---
MATCH (:Process {id:'PROC_CNC'})-[old:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_ELEC_IN'}]->(:Flow {id:'FLOW_ELECTRICITY'})
DELETE old;

MATCH (p:Process {id:'PROC_CNC'}), (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_ELEC_IN', direction:'input', amount:3.6, unit:'MJ'}]->(f);

// --- 3) Compute the climate change result for real for the first time and store it ---
MATCH (alu:Process {id:'PROC_ALU_INGOT_MIX_CONSUMPTION'})-[hfA:HAS_FLOW]->(fA:Flow)-[cA:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
WITH sum(hfA.amount * cA.factor) AS aluPerKg
MATCH (elec:Process {id:'PROC_ELECTRICITY_GREEN_GRID_MIX_DE'})-[hfE:HAS_FLOW]->(fE:Flow)-[cE:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
WITH aluPerKg, sum(hfE.amount * cE.factor) AS elecPerRef
MATCH (cnc:Process {id:'PROC_CNC'})-[hfAl:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_AL_IN'}]->()
MATCH (cnc)-[hfEl:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_ELEC_IN'}]->()
WITH aluPerKg * hfAl.amount AS aluContribution, elecPerRef * (hfEl.amount / 3.6) AS elecContribution
MATCH (ir:ImpactResult {id:'RES_PREC_AL7075_CC'})
SET ir.value = aluContribution + elecContribution,
    ir.unit = 'kg CO2-eq',
    ir.note = 'Calculated 2026-08-26: PROC_ALU_INGOT_MIX_CONSUMPTION + PROC_ELECTRICITY_GREEN_GRID_MIX_DE, CHARACTERIZES-weighted sum (climate change), upstream chain gap closed'
RETURN aluContribution, elecContribution, ir.value;
