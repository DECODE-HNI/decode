// --- 1) Delete all data (batched, safe even for large volumes) ---
MATCH (n)
CALL (n) { DETACH DELETE n } IN TRANSACTIONS OF 10000 ROWS;
 
// --- 2) Remove all constraints ---
// Cypher cannot form DROP CONSTRAINT dynamically from a variable --
// so list them first and drop the names one by one. For this
// model currently exactly these two (see README.md in this folder):
DROP CONSTRAINT has_flow_exchangeid_unique IF EXISTS;
DROP CONSTRAINT characterizes_id_unique IF EXISTS;
// If the full channel A import had already run, additionally the 27
// node unique constraints (Product_id_unique, Artifact_id_unique, ...) --
// check with SHOW CONSTRAINTS and add the remaining names:
SHOW CONSTRAINTS YIELD name RETURN name;
// Then remove every remaining name like this:
//   DROP CONSTRAINT <name> IF EXISTS;
 
// --- 3) Check: everything should be at 0 ---
MATCH (n) RETURN count(n) AS nodes;
MATCH ()-[r]->() RETURN count(r) AS relationships;
SHOW CONSTRAINTS YIELD name RETURN count(name) AS remainingConstraints;