// Checks a sample of the part nodes from the missing APPLIES_TO pairs.
UNWIND ['PART_PREC_PC_CONTACT','PART_FLAT_ABS_CONTACT','PART_3FINGER_PA12_CONTACT','PART_CUSTOM_CONTACT','PART_XL_PA12_INTERFACE'] AS pid
MATCH (n {id: pid})
RETURN pid, labels(n) AS labels, count(*) AS nodeCount
ORDER BY pid;

// And directly: does the relationship already exist for ONE concrete case,
// just perhaps differently than expected (e.g. other direction or duplicate)?
MATCH (p:Process {id: 'PROC_SCREW'})
OPTIONAL MATCH (p)-[r:APPLIES_TO]->(x)
RETURN p.id, count(r) AS outgoing_applies_to, collect(DISTINCT labels(x)) AS target_labels;

// Does any relationship (of any type) exist between PROC_SCREW
// and PART_CUSTOM_CONTACT, in either direction?
MATCH (p:Process {id: 'PROC_SCREW'}), (part:Part {id: 'PART_CUSTOM_CONTACT'})
OPTIONAL MATCH (p)-[r1]-(part)
RETURN type(r1) AS relType, startNode(r1).id AS fromId, endNode(r1).id AS toId;
