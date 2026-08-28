// ============================================================
// Schliesst die "Vorketten-Luecke" fuer den Rest der Baugruppe ASSY_PREC_AL7075
// (nach close_upstream_gap_proc_cnc.cypher, das nur PROC_CNC behandelt hat).
//
// PROC_SCREW, PROC_FINISH, PROC_REPAIR hatten VORHER ueberhaupt keine HAS_FLOW-
// Kanten (nicht mal Platzhalter) -- anders als PROC_CNC gibt es hier keine
// Alt-Mengen zum Umhaengen. Alle Mengenangaben unten sind daher EXPLIZIT
// ANGENOMMEN (nicht aus Originaldaten abgeleitet), Nutzer-Entscheidung 26.08.2026:
//   - Schrauben: verzinkt (M6), 4 Stueck a ~1.5g ~= 0.006 kg
//   - Finish: 0.05 kWh = 0.18 MJ Strom (Annahme fuer kurzen Entgrat-Vorgang)
//   - Repair: Annahme "Reparatur = Neuproduktion eines Kontaktelements",
//     gleiche Vorketten-Mengen wie PROC_CNC (1 kg Aluminium-Ingot, 3.6 MJ Strom)
//
// PROC_SCREW und PROC_FINISH gehoeren zur selben Lebenszyklusstufe wie PROC_CNC
// (Fertigung) und fliessen daher in denselben RES_PREC_AL7075_CC-Wert ein.
// PROC_REPAIR ist methodisch eine andere Lebenszyklusstufe (Ersatz/Service,
// vergleichbar EN15804-Modul B4) und bekommt daher ein EIGENES ImpactResult,
// statt den Fertigungswert zu verfaelschen.
//
// Ausserdem: Fix eines Nebeneffekts aus close_upstream_gap_proc_cnc.cypher --
// RES_PREC_AL7075_CC war noch DERIVED_FROM auf die alten Platzhalter-Flows
// (FLOW_ALUMINUM/FLOW_ELECTRICITY) verwiesen, die seitdem verwaist sind (PROC_CNC
// zeigt nicht mehr auf sie). Wird hier auf die echten Flows umgebogen.
// ============================================================

// --- 1) Neue HAS_FLOW-Kanten anlegen ---

// Schrauben: PROC_SCREW -> reale "Screw M6 (hardened; zinc coated)" (PROC_SCREW_GALVANIZED-Referenz)
MATCH (p:Process {id:'PROC_SCREW'}), (f:Flow {id:'0d925357-e1c9-48c1-a5c7-caaae8185108'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_SCREW_FLOW_SCREW_IN', direction:'input', amount:0.006, unit:'kg'}]->(f);

// Finish: PROC_FINISH -> geteilter Electricity-Flow (Gruenstrom DE, wie PROC_CNC)
MATCH (p:Process {id:'PROC_FINISH'}), (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_FINISH_FLOW_ELEC_IN', direction:'input', amount:0.18, unit:'MJ'}]->(f);

// Repair: PROC_REPAIR -> dieselben zwei Vorketten wie PROC_CNC (Annahme: Ersatzteil-Neuproduktion)
MATCH (p:Process {id:'PROC_REPAIR'}), (f:Flow {id:'ae206e6f-e4f5-4dbf-8de7-42576f6da892'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_REPAIR_FLOW_AL_IN', direction:'input', amount:1.0, unit:'kg'}]->(f);

MATCH (p:Process {id:'PROC_REPAIR'}), (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_REPAIR_FLOW_ELEC_IN', direction:'input', amount:3.6, unit:'MJ'}]->(f);

// --- 2) Verwaiste DERIVED_FROM-Kanten (aus dem PROC_CNC-Fix) korrigieren ---
MATCH (ir:ImpactResult {id:'RES_PREC_AL7075_CC'})-[old:DERIVED_FROM]->(f:Flow)
WHERE f.id IN ['FLOW_ALUMINUM','FLOW_ELECTRICITY']
DELETE old;

MATCH (ir:ImpactResult {id:'RES_PREC_AL7075_CC'}), (f:Flow)
WHERE f.id IN ['ae206e6f-e4f5-4dbf-8de7-42576f6da892','890a70b7-b677-4e2a-8a1b-7d017e0a10ae','0d925357-e1c9-48c1-a5c7-caaae8185108']
MERGE (ir)-[:DERIVED_FROM]->(f);

// --- 3) Fertigungswert (RES_PREC_AL7075_CC) neu berechnen: PROC_CNC + PROC_SCREW + PROC_FINISH ---
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
    ir.note = 'Fertigungsstufe (~A1-A3): PROC_CNC (Aluminium-Ingot + Gruenstrom DE) + PROC_SCREW (Schrauben, Menge angenommen) + PROC_FINISH (Strom, Menge angenommen). Berechnet 26.08.2026.'
RETURN aluContribution, elecContribution, screwContribution, ir.value AS total;

// --- 4) Neues ImpactResult fuer die Reparatur-/Ersatz-Stufe (separat, andere Lebenszyklusstufe) ---
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
  note: 'Angenommen: Reparatur = Neuproduktion eines Ersatz-Kontaktelements, gleiche Vorketten-Mengen wie PROC_CNC. Menge nicht aus Originaldaten. Berechnet 26.08.2026.'
})
CREATE (a)-[:HAS_RESULT]->(ir)
CREATE (ir)-[:FOR_CATEGORY]->(ic)
CREATE (ir)-[:DERIVED_FROM]->(fAl)
CREATE (ir)-[:DERIVED_FROM]->(fEl)
RETURN aluContribution, elecContribution, ir.value AS total;
