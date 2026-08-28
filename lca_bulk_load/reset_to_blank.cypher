// --- 1) Alle Daten loeschen (gebatcht, sicher auch bei grossen Mengen) ---
MATCH (n)
CALL (n) { DETACH DELETE n } IN TRANSACTIONS OF 10000 ROWS;
 
// --- 2) Alle Constraints entfernen ---
// Cypher kann DROP CONSTRAINT nicht dynamisch aus einer Variable bilden --
// daher zuerst anzeigen lassen und die Namen einzeln droppen. Fuer dieses
// Modell aktuell genau diese beiden (siehe HANDOFF_CONTEXT_V2.md):
DROP CONSTRAINT has_flow_exchangeid_unique IF EXISTS;
DROP CONSTRAINT characterizes_id_unique IF EXISTS;
// Falls der volle Kanal-A-Import bereits gelaufen war, zusaetzlich die 27
// Node-Unique-Constraints (Product_id_unique, Artifact_id_unique, ...) --
// per SHOW CONSTRAINTS pruefen und die restlichen Namen ergaenzen:
SHOW CONSTRAINTS YIELD name RETURN name;
// Danach jeden verbleibenden Namen so entfernen:
//   DROP CONSTRAINT <name> IF EXISTS;
 
// --- 3) Kontrolle: sollte alles auf 0 stehen ---
MATCH (n) RETURN count(n) AS nodes;
MATCH ()-[r]->() RETURN count(r) AS relationships;
SHOW CONSTRAINTS YIELD name RETURN count(name) AS remainingConstraints;