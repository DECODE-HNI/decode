// Prueft eine Stichprobe der Part-Knoten aus den fehlenden APPLIES_TO-Paaren.
UNWIND ['PART_PREC_PC_CONTACT','PART_FLAT_ABS_CONTACT','PART_3FINGER_PA12_CONTACT','PART_CUSTOM_CONTACT','PART_XL_PA12_INTERFACE'] AS pid
MATCH (n {id: pid})
RETURN pid, labels(n) AS labels, count(*) AS nodeCount
ORDER BY pid;

// Und direkt: existiert die Relationship fuer EINEN konkreten Fall bereits,
// nur eventuell anders als erwartet (z.B. andere Richtung oder Duplikat)?
MATCH (p:Process {id: 'PROC_SCREW'})
OPTIONAL MATCH (p)-[r:APPLIES_TO]->(x)
RETURN p.id, count(r) AS outgoing_applies_to, collect(DISTINCT labels(x)) AS target_labels;

// Existiert irgendeine Relationship (jeglichen Typs) zwischen PROC_SCREW
// und PART_CUSTOM_CONTACT, in beide Richtungen?
MATCH (p:Process {id: 'PROC_SCREW'}), (part:Part {id: 'PART_CUSTOM_CONTACT'})
OPTIONAL MATCH (p)-[r1]-(part)
RETURN type(r1) AS relType, startNode(r1).id AS fromId, endNode(r1).id AS toId;
