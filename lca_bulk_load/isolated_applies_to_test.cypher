// Isolierter Test: APPLIES_TO komplett loeschen und NUR diesen einen Typ neu
// laden, ohne dass irgendein anderer Ladeschritt vorher/nachher stattfindet.
// Ziel: klaeren, ob das Problem am Statement selbst + Knotenzustand liegt,
// oder an einer Wechselwirkung mit anderen zuvor geladenen Relationship-Typen.

MATCH ()-[r:APPLIES_TO]->() DELETE r;

LOAD CSV WITH HEADERS FROM 'file:///r_1_APPLIES_TO_Process_TO_Part.csv' AS row
WITH row
CALL (row) {
  MATCH (source: `Process` { `id`: row.`from_id` })
  MATCH (target: `Part` { `id`: row.`to_id` })
  MERGE (source)-[r: `APPLIES_TO`]->(target)
  SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM 'file:///r_39_APPLIES_TO_Process_TO_Material.csv' AS row
WITH row
CALL (row) {
  MATCH (source: `Process` { `id`: row.`from_id` })
  MATCH (target: `Material` { `id`: row.`to_id` })
  MERGE (source)-[r: `APPLIES_TO`]->(target)
  SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

MATCH ()-[r:APPLIES_TO]->() RETURN count(r) AS applies_to_count;
