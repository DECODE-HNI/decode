// ============================================================
// Adds uniqueness safeguards for HAS_FLOW and CHARACTERIZES.
//
// HAS_FLOW.exchangeId is already globally unique by construction ->
// direct property uniqueness constraint.
//
// CHARACTERIZES is only unique via the combination (flow, impact category,
// location) -- Neo4j can only set relationship constraints on
// their own properties, not on end-node combinations. Therefore
// first back-fill a synthetic characterizesId = "<flowId>|<categoryId>|<location>"
// on ALL existing edges, then set the constraint ON THAT.
// ============================================================

// --- 1) HAS_FLOW: direct constraint, since exchangeId is already unique ---
CREATE CONSTRAINT has_flow_exchangeid_unique IF NOT EXISTS
FOR ()-[r:HAS_FLOW]-()
REQUIRE r.exchangeId IS UNIQUE;

// --- 2) CHARACTERIZES: back-fill characterizesId on all existing edges ---
MATCH (f:Flow)-[r:CHARACTERIZES]->(c:ImpactCategory)
CALL (f, r, c) {
  SET r.characterizesId = f.id + '|' + c.id + '|' + coalesce(r.location, '')
} IN TRANSACTIONS OF 2000 ROWS;

// --- 3) CHARACTERIZES: constraint on the new characterizesId ---
CREATE CONSTRAINT characterizes_id_unique IF NOT EXISTS
FOR ()-[r:CHARACTERIZES]-()
REQUIRE r.characterizesId IS UNIQUE;

// --- 4) Check ---
SHOW CONSTRAINTS YIELD name, type, entityType, labelsOrTypes, properties
WHERE name IN ['has_flow_exchangeid_unique', 'characterizes_id_unique']
RETURN name, type, entityType, labelsOrTypes, properties;
