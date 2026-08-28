// Prueft, ob die 7 Prozesse, deren APPLIES_TO-Kanten fehlen, ueberhaupt als
// :Process-Knoten existieren (mit korrektem Label), und wie viele Knoten
// insgesamt mit dieser id existieren (falls doppelt/anders gelabelt).
UNWIND ['PROC_CNC','PROC_FFF','PROC_FINISH','PROC_REPAIR','PROC_RUBBER','PROC_SCREW','PROC_SLS'] AS pid
MATCH (n {id: pid})
RETURN pid, labels(n) AS labels, count(*) AS nodeCount
ORDER BY pid;
