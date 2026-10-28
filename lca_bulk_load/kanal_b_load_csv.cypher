// ============================================================
// Channel B for a local Neo4j instance: r_40_HAS_FLOW_Process_TO_Flow.csv /
// r_41_CHARACTERIZES_Flow_TO_ImpactCategory.csv are already in the import/
// folder of this DBMS -- LOAD CSV FROM 'file:///...'
// works directly here (unlike Aura). Replaces the Python
// script completely for this local instance.
//
// IMPORTANT: the MERGE key deliberately contains more than (from,to), otherwise
// parallel edges between the same pair of nodes collapse (the original
// cause of the whole HAS_FLOW/CHARACTERIZES problem):
//   HAS_FLOW: MERGE key = exchangeId (globally unique)
//   CHARACTERIZES: MERGE key = (from,to,location)
//
// Run only AFTER the channel A import (the Process/Flow/ImpactCategory
// nodes must exist, otherwise the MATCH clauses find nothing).
//
// Beforehand, existing HAS_FLOW/CHARACTERIZES edges are deleted (full
// rebuild, as already planned for the Aura route) -- on a fresh
// local instance without a previous import this is a no-op.
// ============================================================

// --- Uniqueness constraints (once; IF NOT EXISTS makes reruns safe) ---
// HAS_FLOW.exchangeId is globally unique by construction -> direct constraint.
// CHARACTERIZES is only unique via (flow, impact category, location) -- so write
// the synthetic characterizesId below and constrain ON THAT,
// because a relationship constraint can only check its own properties, not
// end-node combinations.
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
// IMPORTANT: LOAD CSV delivers an empty CSV field as null, not as "" --
// and Cypher does not allow null as a property value INSIDE a MERGE
// pattern ("22N31: cannot be used with ... null"). location must therefore be
// mapped with coalesce() to a real (empty) string default
// BEFORE the MERGE. Affects 4,035 rows here (global/default factors
// without a country-specific location code). characterizesId is formed directly from
// the same normalised location so that it fits the constraint.
LOAD CSV WITH HEADERS FROM 'file:///r_41_CHARACTERIZES_Flow_TO_ImpactCategory.csv' AS row
CALL (row) {
  MATCH (f:Flow {id: row.from_id})
  MATCH (c:ImpactCategory {id: row.to_id})
  WITH f, c, row, coalesce(row.location, '') AS loc
  MERGE (f)-[r:CHARACTERIZES {location: loc}]->(c)
  SET r.factor = toFloat(row.factor),
      r.characterizesId = f.id + '|' + c.id + '|' + loc
} IN TRANSACTIONS OF 500 ROWS;

// --- Control count ---
MATCH ()-[r]->() WHERE type(r) IN ['HAS_FLOW','CHARACTERIZES']
RETURN type(r) AS relType, count(r) AS n ORDER BY relType;
