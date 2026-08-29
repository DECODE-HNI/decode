// export_flows.cypher -- flow list for import_recipe_cf.py --flows
// Run with cypher-shell --format plain and redirect stdout to db_all_flows.tsv:
//   cypher-shell --format plain -f export_flows.cypher > db_all_flows.tsv
// Columns: flowId \t casNumber \t name \t compartments(csv) \t units(csv)
MATCH (p:Process)-[hf:HAS_FLOW]->(f:Flow)
WITH f, collect(DISTINCT hf.compartment) AS comps, collect(DISTINCT hf.unit) AS units
RETURN f.id + '\t' + coalesce(f.casNumber,'') + '\t' + coalesce(f.name,'') + '\t' +
       reduce(s='', x IN comps | s + CASE WHEN s='' THEN '' ELSE ',' END + coalesce(x,'')) + '\t' +
       reduce(s='', x IN units | s + CASE WHEN s='' THEN '' ELSE ',' END + coalesce(x,'')) AS row;
