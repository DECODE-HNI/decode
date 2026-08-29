// ============================================================================
// recipe_cf.EXAMPLE.cypher  --  SYNTHETIC shape example, NOT real data.
// ----------------------------------------------------------------------------
// `import_recipe_cf.py` writes a file of exactly this shape (real runs produce
// a few thousand rows). The flow UUIDs, factor values and match tags below are
// invented placeholders — they will not match any flow in a real graph.
//
// The real ReCiPe 2016 characterisation factors come from the free openLCA
// "LCIA Methods" package and are NOT redistributed in this repository. Download
// the package and generate your own file:
//
//   cypher-shell ... -f export_flows.cypher > db_all_flows.tsv
//   python import_recipe_cf.py --openlca-zip "openLCA LCIA Methods ....zip" \
//          --flows db_all_flows.tsv --out recipe_cf.cypher --supersede-gw
//   cypher-shell ... -f recipe_cf.cypher
//   cypher-shell ... -f refresh_recipe.cypher
// ============================================================================

// --- supersede the v3.e climate approximation (EF3.1 GWP x 1.06) -------------
MATCH (:Flow)-[c:CHARACTERIZES]->(:ImpactCategory {id:'IC_RECIPE_GW'})
WHERE c.source STARTS WITH 'approximated from EF3.1'
DELETE c;

UNWIND [
  {fid:"00000000-0000-0000-0000-000000000001", ic:"IC_RECIPE_GW",  v:1.0,   mb:"CAS+air"},
  {fid:"00000000-0000-0000-0000-000000000002", ic:"IC_RECIPE_GW",  v:29.8,  mb:"CAS+air"},
  {fid:"00000000-0000-0000-0000-000000000003", ic:"IC_RECIPE_TA",  v:1.0,   mb:"CAS+air"},
  {fid:"00000000-0000-0000-0000-000000000004", ic:"IC_RECIPE_PMFP", v:0.29, mb:"CAS+air"},
  {fid:"00000000-0000-0000-0000-000000000005", ic:"IC_RECIPE_FE",  v:1.0,   mb:"CAS+water"},
  {fid:"00000000-0000-0000-0000-000000000006", ic:"IC_RECIPE_FET", v:14.1,  mb:"CAS+water"},
  {fid:"00000000-0000-0000-0000-000000000007", ic:"IC_RECIPE_MRS", v:0.167, mb:"name"},
  {fid:"00000000-0000-0000-0000-000000000008", ic:"IC_RECIPE_FRS", v:1.0,   mb:"name"}
] AS r
MATCH (f:Flow {id:r.fid}), (ic:ImpactCategory {id:r.ic})
WHERE NOT (f)-[:CHARACTERIZES]->(ic)
MERGE (f)-[c:CHARACTERIZES {characterizesId: r.fid + '|' + r.ic + '|'}]->(ic)
  ON CREATE SET c.factor = r.v, c.location = '', c.method = 'IAM_RECIPE',
                c.source = 'ReCiPe 2016 Midpoint (H) / openLCA LCIA pack',
                c.matchedBy = r.mb, c.derived = true;

// --- coverage ---------------------------------------------------------------
MATCH (m:ImpactAssessmentMethod {id:'IAM_RECIPE'})-[:HAS_CATEGORY]->(ic:ImpactCategory)
OPTIONAL MATCH (f:Flow)-[c:CHARACTERIZES]->(ic)
RETURN ic.id AS category, count(DISTINCT f) AS charFlows
ORDER BY category;

// --- rollback -------------------------------------------------------------
// MATCH (:Flow)-[c:CHARACTERIZES {method:'IAM_RECIPE'}]->() DELETE c;
