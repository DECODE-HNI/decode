// ============================================================
// Schliesst die "Vorketten-Luecke" fuer PROC_CNC (Precision jaws / Al7075 / CNC):
// Die beiden generischen Legacy-Input-Flows (FLOW_ALUMINUM, FLOW_ELECTRICITY)
// werden auf die realen, charakterisierten ILCD-Bibliotheksfluesse umgehaengt:
//   - Aluminium  -> PROC_ALU_INGOT_MIX_CONSUMPTION, Referenzoutput "Aluminium ingot"
//                   (ae206e6f-e4f5-4dbf-8de7-42576f6da892), 1 kg, exakter Mengenmatch
//   - Electricity -> PROC_ELECTRICITY_GREEN_GRID_MIX_DE, Referenzoutput "Electricity"
//                   (890a70b7-b677-4e2a-8a1b-7d017e0a10ae) -- derselbe Flow-Knoten,
//                   den PROC_ALU_CAST_MACHINING bereits als Input nutzt (geteilter
//                   Flow statt Duplikat, bereits bestehendes Muster im Graphen).
//                   Einheit 1 kWh = 3.6 MJ umgerechnet.
// Nutzer-Entscheidung (26.08.2026): deutscher Gruenstrom-Mix statt CN Grid Mix.
//
// Ergebnis: RES_PREC_AL7075_CC.value wird zum ersten Mal real berechnet statt NULL,
// als CHARACTERIZES-gewichtete Summe der beiden Vorketten-Prozesse (Climate Change),
// skaliert auf die tatsaechlich verbrauchte Menge (hier je 1:1, da Referenzmengen
// exakt passen).
//
// Voraussetzung: laeuft auf der lokalen Instanz mit dem vollstaendig geladenen
// V2-Modell (2.721 Knoten / 79.642 Relationships). Reversibel ueber die alten
// exchangeId-Werte + full_init.cypher-Neuladung, falls noetig.
// ============================================================

// --- 1) Aluminium-Input umhaengen ---
MATCH (:Process {id:'PROC_CNC'})-[old:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_AL_IN'}]->(:Flow {id:'FLOW_ALUMINUM'})
DELETE old;

MATCH (p:Process {id:'PROC_CNC'}), (f:Flow {id:'ae206e6f-e4f5-4dbf-8de7-42576f6da892'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_AL_IN', direction:'input', amount:1.0, unit:'kg'}]->(f);

// --- 2) Strom-Input umhaengen (kWh -> MJ) ---
MATCH (:Process {id:'PROC_CNC'})-[old:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_ELEC_IN'}]->(:Flow {id:'FLOW_ELECTRICITY'})
DELETE old;

MATCH (p:Process {id:'PROC_CNC'}), (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
CREATE (p)-[:HAS_FLOW {exchangeId:'EX_PROC_CNC_FLOW_ELEC_IN', direction:'input', amount:3.6, unit:'MJ'}]->(f);

// --- 3) Climate-Change-Ergebnis erstmals real berechnen und speichern ---
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
    ir.note = 'Berechnet 26.08.2026: PROC_ALU_INGOT_MIX_CONSUMPTION + PROC_ELECTRICITY_GREEN_GRID_MIX_DE, CHARACTERIZES-gewichtete Summe (Climate Change), Vorketten-Luecke geschlossen'
RETURN aluContribution, elecContribution, ir.value;
