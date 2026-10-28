// ============================================================
// Closes the "upstream chain gap" for the rest of the assembly ASSY_PREC_AL7075
// (after close_upstream_gap_proc_cnc.cypher, which only handled PROC_CNC).
//
// PROC_SCREW, PROC_FINISH, PROC_REPAIR previously had no HAS_FLOW
// edges at all (not even placeholders) -- unlike PROC_CNC there are no
// legacy quantities to re-attach. All quantities below are therefore EXPLICITLY
// ASSUMED (not derived from original data), decision of 2026-08-26:
//   - Screws: galvanised (M6), 4 pieces of ~1.5 g ~= 0.006 kg
//   - Finish: 0.05 kWh = 0.18 MJ electricity (assumption for a short deburring step)
//   - Repair: assumption "repair = new production of a contact element",
//     same upstream quantities as PROC_CNC (1 kg aluminium ingot, 3.6 MJ electricity)
//
// PROC_SCREW and PROC_FINISH belong to the same life cycle stage as PROC_CNC
// (manufacturing) and therefore flow into the same RES_PREC_AL7075_CC value.
// PROC_REPAIR is methodologically a different life cycle stage (replacement/service,
// comparable to EN 15804 module B4) and therefore gets its OWN ImpactResult
// instead of distorting the manufacturing value.
//
// Also: fix of a side effect of close_upstream_gap_proc_cnc.cypher --
// RES_PREC_AL7075_CC was still DERIVED_FROM the old placeholder flows
// (FLOW_ALUMINUM/FLOW_ELECTRICITY), which have since become orphaned (PROC_CNC
// no longer points to them). Redirected here to the real flows.
// ============================================================

// --- 1) Create the new HAS_FLOW edges ---

// Screws: PROC_SCREW -> real "Screw M6 (hardened; zinc coated)" (PROC_SCREW_GALVANIZED reference)
MATCH (p:Process {id:'PROC_SCREW'}), (f:Flow {id:'0d925357-e1c9-48c1-a5c7-caaae8185108'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_SCREW_FLOW_SCREW_IN', direction:'input', amount:0.006, unit:'kg'}]->(f);

// Finish: PROC_FINISH -> shared electricity flow (green electricity DE, like PROC_CNC)
MATCH (p:Process {id:'PROC_FINISH'}), (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_FINISH_FLOW_ELEC_IN', direction:'input', amount:0.18, unit:'MJ'}]->(f);

// Repair: PROC_REPAIR -> the same two upstream chains as PROC_CNC (assumption: new production of the spare part)
MATCH (p:Process {id:'PROC_REPAIR'}), (f:Flow {id:'ae206e6f-e4f5-4dbf-8de7-42576f6da892'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_REPAIR_FLOW_AL_IN', direction:'input', amount:1.0, unit:'kg'}]->(f);

MATCH (p:Process {id:'PROC_REPAIR'}), (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_REPAIR_FLOW_ELEC_IN', direction:'input', amount:3.6, unit:'MJ'}]->(f);

// --- 2) Fix orphaned DERIVED_FROM edges (from the PROC_CNC fix) ---
MATCH (ir:ImpactResult {id:'RES_PREC_AL7075_CC'})-[old:DERIVED_FROM]->(f:Flow)
WHERE f.id IN ['FLOW_ALUMINUM','FLOW_ELECTRICITY']
DELETE old;

MATCH (ir:ImpactResult {id:'RES_PREC_AL7075_CC'}), (f:Flow)
WHERE f.id IN ['ae206e6f-e4f5-4dbf-8de7-42576f6da892','890a70b7-b677-4e2a-8a1b-7d017e0a10ae','0d925357-e1c9-48c1-a5c7-caaae8185108']
MERGE (ir)-[:DERIVED_FROM]->(f);

// --- 3) Recalculate the manufacturing value (RES_PREC_AL7075_CC): PROC_CNC + PROC_SCREW + PROC_FINISH ---
MATCH (alu:Process {id:'PROC_ALU_INGOT_MIX_CONSUMPTION'})-[hfA:HAS_FLOW]->(:Flow)-[cA:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
WITH sum(hfA.amount * cA.factor) AS aluPerKg
MATCH (elec:Process {id:'PROC_ELECTRICITY_GREEN_GRID_MIX_DE'})-[hfE:HAS_FLOW]->(:Flow)-[cE:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
WITH aluPerKg, sum(hfE.amount * cE.factor) AS elecPerRef
MATCH (screw:Process {id:'PROC_SCREW_GALVANIZED'})-[hfS:HAS_FLOW]->(:Flow)-[cS:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
WITH aluPerKg, elecPerRef, sum(hfS.amount * cS.factor) AS screwPerKg
MATCH (:Process {id:'PROC_CNC'})-[cncAl:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_AL_IN'}]->()
MATCH (:Process {id:'PROC_CNC'})-[cncEl:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_ELEC_IN'}]->()
MATCH (:Process {id:'PROC_FINISH'})-[finEl:HAS_FLOW {exchangeId:'EX_PROC_FINISH_FLOW_ELEC_IN'}]->()
MATCH (:Process {id:'PROC_SCREW'})-[scrS:HAS_FLOW {exchangeId:'EX_PROC_SCREW_FLOW_SCREW_IN'}]->()
WITH aluPerKg * cncAl.amount AS aluContribution,
     elecPerRef * ((cncEl.amount + finEl.amount) / 3.6) AS elecContribution,
     screwPerKg * scrS.amount AS screwContribution
MATCH (ir:ImpactResult {id:'RES_PREC_AL7075_CC'})
SET ir.value = aluContribution + elecContribution + screwContribution,
    ir.note = 'Manufacturing stage (~A1-A3): PROC_CNC (aluminium ingot + green electricity DE) + PROC_SCREW (screws, quantity assumed) + PROC_FINISH (electricity, quantity assumed). Calculated 2026-08-26.'
RETURN aluContribution, elecContribution, screwContribution, ir.value AS total;

// --- 4) New ImpactResult for the repair/replacement stage (separate, different life cycle stage) ---
MATCH (alu:Process {id:'PROC_ALU_INGOT_MIX_CONSUMPTION'})-[hfA:HAS_FLOW]->(:Flow)-[cA:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
WITH sum(hfA.amount * cA.factor) AS aluPerKg
MATCH (elec:Process {id:'PROC_ELECTRICITY_GREEN_GRID_MIX_DE'})-[hfE:HAS_FLOW]->(:Flow)-[cE:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
WITH aluPerKg, sum(hfE.amount * cE.factor) AS elecPerRef
MATCH (rep:Process {id:'PROC_REPAIR'})-[repAl:HAS_FLOW {exchangeId:'EX_PROC_REPAIR_FLOW_AL_IN'}]->(fAl:Flow)
MATCH (rep)-[repEl:HAS_FLOW {exchangeId:'EX_PROC_REPAIR_FLOW_ELEC_IN'}]->(fEl:Flow)
WITH aluPerKg * repAl.amount AS aluContribution, elecPerRef * (repEl.amount / 3.6) AS elecContribution, fAl, fEl
MATCH (a:Assessment {id:'ASS_PREC_AL7075'})
MATCH (ic:ImpactCategory {id:'IC_CLIMATE'})
CREATE (ir:ImpactResult {
  id: 'RES_PREC_AL7075_REPAIR_CC',
  value: aluContribution + elecContribution,
  unit: 'kg CO2-eq',
  lifeCycleStage: 'B4 (Replace/Repair)',
  note: 'Assumed: repair = new production of a replacement contact element, same upstream quantities as PROC_CNC. Quantity not from original data. Calculated 2026-08-26.'
})
CREATE (a)-[:HAS_RESULT]->(ir)
CREATE (ir)-[:FOR_CATEGORY]->(ic)
CREATE (ir)-[:DERIVED_FROM]->(fAl)
CREATE (ir)-[:DERIVED_FROM]->(fEl)
RETURN aluContribution, elecContribution, ir.value AS total;
