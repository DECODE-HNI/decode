// ============================================================
// Ergaenzt Eindeutigkeits-Absicherung fuer HAS_FLOW und CHARACTERIZES.
//
// HAS_FLOW.exchangeId ist per Konstruktion bereits global eindeutig ->
// direkter Property-Uniqueness-Constraint.
//
// CHARACTERIZES ist nur ueber die Kombination (Flow, ImpactCategory,
// location) eindeutig -- Neo4j kann Relationship-Constraints nur auf
// eigene Properties setzen, nicht auf Endknoten-Kombinationen. Deshalb
// zuerst eine synthetische characterizesId = "<flowId>|<categoryId>|<location>"
// auf ALLE bestehenden Kanten nachtragen, dann DARAUF den Constraint setzen.
// ============================================================

// --- 1) HAS_FLOW: direkter Constraint, da exchangeId bereits eindeutig ist ---
CREATE CONSTRAINT has_flow_exchangeid_unique IF NOT EXISTS
FOR ()-[r:HAS_FLOW]-()
REQUIRE r.exchangeId IS UNIQUE;

// --- 2) CHARACTERIZES: characterizesId auf alle bestehenden Kanten nachtragen ---
MATCH (f:Flow)-[r:CHARACTERIZES]->(c:ImpactCategory)
CALL (f, r, c) {
  SET r.characterizesId = f.id + '|' + c.id + '|' + coalesce(r.location, '')
} IN TRANSACTIONS OF 2000 ROWS;

// --- 3) CHARACTERIZES: Constraint auf die neue characterizesId ---
CREATE CONSTRAINT characterizes_id_unique IF NOT EXISTS
FOR ()-[r:CHARACTERIZES]-()
REQUIRE r.characterizesId IS UNIQUE;

// --- 4) Kontrolle ---
SHOW CONSTRAINTS YIELD name, type, entityType, labelsOrTypes, properties
WHERE name IN ['has_flow_exchangeid_unique', 'characterizes_id_unique']
RETURN name, type, entityType, labelsOrTypes, properties;
