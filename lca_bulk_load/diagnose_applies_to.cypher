// Findet exakt die Zeilen, fuer die KEINE entsprechende Relationship im
// Graphen existiert. Rein lesend, kein Transaktions-Batching noetig.
// Bitte alle drei einzeln ausfuehren und die Ergebnisse teilen.

// --- 1) APPLIES_TO Process -> Part ---
LOAD CSV WITH HEADERS FROM 'file:///r_1_APPLIES_TO_Process_TO_Part.csv' AS row
OPTIONAL MATCH (source:Process {id: row.from_id})-[r:APPLIES_TO]->(target:Part {id: row.to_id})
WITH row, r
WHERE r IS NULL
RETURN row.from_id AS missing_from, row.to_id AS missing_to, row.role AS role
ORDER BY missing_from, missing_to;

// --- 2) APPLIES_TO Process -> Material ---
LOAD CSV WITH HEADERS FROM 'file:///r_39_APPLIES_TO_Process_TO_Material.csv' AS row
OPTIONAL MATCH (source:Process {id: row.from_id})-[r:APPLIES_TO]->(target:Material {id: row.to_id})
WITH row, r
WHERE r IS NULL
RETURN row.from_id AS missing_from, row.to_id AS missing_to, row.role AS role
ORDER BY missing_from, missing_to;

// --- 3) EVALUATES_CRITERION DataQuality -> DataQualityCriterion ---
LOAD CSV WITH HEADERS FROM 'file:///r_6_EVALUATES_CRITERION_DataQuality_TO_DataQualityCriterion.csv' AS row
OPTIONAL MATCH (source:DataQuality {id: row.from_id})-[r:EVALUATES_CRITERION]->(target:DataQualityCriterion {id: row.to_id})
WITH row, r
WHERE r IS NULL
RETURN row.from_id AS missing_from, row.to_id AS missing_to, row.score AS score, row.rating AS rating
ORDER BY missing_from, missing_to;
