// ============================================================
// Kanal B fuer lokale Neo4j-Instanz: r_40_HAS_FLOW_Process_TO_Flow.csv /
// r_41_CHARACTERIZES_Flow_TO_ImpactCategory.csv liegen bereits im import/-
// Ordner dieser DBMS -- LOAD CSV FROM 'file:///...'
// funktioniert hier direkt (im Gegensatz zu Aura). Ersetzt das Python-
// Skript vollstaendig fuer diese lokale Instanz.
//
// WICHTIG: MERGE-Schluessel enthaelt bewusst mehr als (from,to), sonst
// kollabieren Parallel-Kanten zwischen gleichem Knotenpaar (die urspruengliche
// Ursache des gesamten HAS_FLOW/CHARACTERIZES-Problems):
//   HAS_FLOW: MERGE-Schluessel = exchangeId (global eindeutig)
//   CHARACTERIZES: MERGE-Schluessel = (from,to,location)
//
// Erst NACH dem Kanal-A-Import ausfuehren (Process/Flow/ImpactCategory-
// Knoten muessen existieren, sonst finden die MATCH-Klauseln nichts).
//
// Vorher werden bestehende HAS_FLOW/CHARACTERIZES-Kanten geloescht (voller
// Rebuild, wie bereits fuer den Aura-Weg vorgesehen) -- bei einer frischen
// lokalen Instanz ohne vorherigen Import ist das ein no-op.
// ============================================================

// --- Eindeutigkeits-Constraints (einmalig, IF NOT EXISTS macht Reruns sicher) ---
// HAS_FLOW.exchangeId ist per Konstruktion global eindeutig -> direkter Constraint.
// CHARACTERIZES ist nur ueber (Flow,ImpactCategory,location) eindeutig -- dafuer
// unten die synthetische characterizesId mitschreiben und DARAUF constrainen,
// da ein Relationship-Constraint nur eigene Properties pruefen kann, keine
// Endknoten-Kombinationen.
CREATE CONSTRAINT has_flow_exchangeid_unique IF NOT EXISTS
FOR ()-[r:HAS_FLOW]-()
REQUIRE r.exchangeId IS UNIQUE;

CREATE CONSTRAINT characterizes_id_unique IF NOT EXISTS
FOR ()-[r:CHARACTERIZES]-()
REQUIRE r.characterizesId IS UNIQUE;

MATCH ()-[r:HAS_FLOW]->() CALL (r) { DELETE r } IN TRANSACTIONS OF 5000 ROWS;
MATCH ()-[r:CHARACTERIZES]->() CALL (r) { DELETE r } IN TRANSACTIONS OF 5000 ROWS;

// --- HAS_FLOW ---
LOAD CSV WITH HEADERS FROM 'file:///r_40_HAS_FLOW_Process_TO_Flow.csv' AS row
CALL (row) {
  MATCH (p:Process {id: row.from_id})
  MATCH (f:Flow {id: row.to_id})
  MERGE (p)-[r:HAS_FLOW {exchangeId: row.exchangeId}]->(f)
  SET r.amount = toFloat(row.amount),
      r.unit = row.unit,
      r.direction = row.direction,
      r.location = row.location,
      r.quantitativeReference = (row.quantitativeReference = 'true'),
      r.ratioToReference = toFloat(row.ratioToReference),
      r.dataMaturity = row.dataMaturity,
      r.referenceYear = row.referenceYear,
      r.uncertainty = CASE WHEN row.uncertainty = '' THEN null ELSE toFloat(row.uncertainty) END,
      r.comment = row.comment
} IN TRANSACTIONS OF 500 ROWS;

// --- CHARACTERIZES ---
// WICHTIG: LOAD CSV liefert ein leeres CSV-Feld als null, nicht als "" --
// und Cypher erlaubt kein null als Property-Wert INNERHALB eines MERGE-
// Patterns ("22N31: cannot be used with ... null"). location muss daher
// VOR dem MERGE mit coalesce() auf einen echten (leeren) String-Default
// abgebildet werden. Betrifft hier 4.035 Zeilen (globale/Default-Faktoren
// ohne laenderspezifischen Location-Code). characterizesId wird direkt aus
// derselben normierten location gebildet, damit sie zum Constraint passt.
LOAD CSV WITH HEADERS FROM 'file:///r_41_CHARACTERIZES_Flow_TO_ImpactCategory.csv' AS row
CALL (row) {
  MATCH (f:Flow {id: row.from_id})
  MATCH (c:ImpactCategory {id: row.to_id})
  WITH f, c, row, coalesce(row.location, '') AS loc
  MERGE (f)-[r:CHARACTERIZES {location: loc}]->(c)
  SET r.factor = toFloat(row.factor),
      r.characterizesId = f.id + '|' + c.id + '|' + loc
} IN TRANSACTIONS OF 500 ROWS;

// --- Kontrollzaehlung ---
MATCH ()-[r]->() WHERE type(r) IN ['HAS_FLOW','CHARACTERIZES']
RETURN type(r) AS relType, count(r) AS n ORDER BY relType;
