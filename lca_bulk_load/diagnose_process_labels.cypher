// Checks whether the 7 processes whose APPLIES_TO edges are missing exist at all as
// :Process nodes (with the correct label), and how many nodes
// with this id exist in total (in case of duplicates/other labels).
UNWIND ['PROC_CNC','PROC_FFF','PROC_FINISH','PROC_REPAIR','PROC_RUBBER','PROC_SCREW','PROC_SLS'] AS pid
MATCH (n {id: pid})
RETURN pid, labels(n) AS labels, count(*) AS nodeCount
ORDER BY pid;
