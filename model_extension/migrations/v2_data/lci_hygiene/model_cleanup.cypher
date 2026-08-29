// ============================================================================
// model_cleanup.cypher   (second hygiene round -- structural cruft)
// ----------------------------------------------------------------------------
// Removes legacy nodes and edges that no query reads and that only inflate the
// graph. Nothing here changes a computed result except C5 (removes a wrong CF).
// Run after lci_hygiene.cypher; then re-run refresh_variantA.cypher and
// cf_import/refresh_recipe.cypher.
//
//   C1  6 orphan EF3.1 sub-fraction categories (_ORGANICS / _INORGANICS) plus
//       their ~1 840 CHARACTERIZES -- redundant: every flow that has a
//       sub-fraction CF also has the parent-category CF, and lca_generic only
//       traverses HAS_CATEGORY so the sub-fractions were never counted
//   C2  IC_ENERGY, IC_WASTE -- placeholder categories under IAM_EF31 with no
//       CF and no result; EF3.1 has no such category and ced.cypher does not
//       use them
//   C3  PROC_PA66_GRANULATE_MIX -- the pre-ILCD PA6.6 proxy process (2 728
//       HAS_FLOW), superseded by PROC_PA66_PLASTICSEUROPE_EF and no longer
//       referenced; PROC_FINISH -- empty stub
//   C4  4 detached ILCD reference-product flows (ABS / PC / POM / PA66
//       granulate) left over from the package import
//   C5  uranium -[:CHARACTERIZES]-> IC_EF_EF_RESOURCE_USE_FOSSILS -- uranium is
//       nuclear primary energy, not a fossil resource; the CF of 1.0 was
//       wrong and inflated fossil resource use / CED
// ============================================================================

// ---- C1: orphan EF3.1 sub-fraction categories ---------------------------
MATCH (ic:ImpactCategory)
WHERE ic.id IN [
  'IC_EF_HUMAN_TOXICITY_CANCER_ORGANICS', 'IC_EF_HUMAN_TOXICITY_CANCER_INORGANICS',
  'IC_EF_HUMAN_TOXICITY_NON_CANCER_ORGANICS', 'IC_EF_HUMAN_TOXICITY_NON_CANCER_INORGANICS',
  'IC_EF_ECOTOXICITY_FRESHWATER_ORGANICS', 'IC_EF_ECOTOXICITY_FRESHWATER_INORGANICS'
]
  AND NOT (:ImpactAssessmentMethod)-[:HAS_CATEGORY]->(ic)
DETACH DELETE ic;

// ---- C2: dead placeholder categories ----------------------------------
MATCH (ic:ImpactCategory) WHERE ic.id IN ['IC_ENERGY', 'IC_WASTE']
  AND NOT EXISTS { (:Flow)-[:CHARACTERIZES]->(ic) }
  AND NOT EXISTS { (:ImpactResult)-[:FOR_CATEGORY]->(ic) }
DETACH DELETE ic;

// ---- C3: superseded / empty processes --------------------------------
MATCH (p:Process {id: 'PROC_PA66_GRANULATE_MIX'})
WHERE NOT (p)<-[:MODELED_BY]-() AND NOT (p)<-[:CONTAINS_PROCESS]-()
DETACH DELETE p;
MATCH (p:Process {id: 'PROC_FINISH'})
WHERE NOT (p)-[:HAS_FLOW]->() AND NOT (p)<-[:MODELED_BY]-()
DETACH DELETE p;

// ---- C4: detached ILCD reference-product flows -----------------------
MATCH (f:Flow)
WHERE f.name IN ['Acrylonitrile butadiene styrene (ABS)', 'Polycarbonate granulate (PC)',
                 'Polyoxymethylene (POM)', 'Polyamide 66 (PA66)']
  AND NOT (f)--()
DELETE f;

// ---- C5: wrong CF -- uranium is not a fossil resource ---------------
MATCH (f:Flow {name: 'uranium'})-[c:CHARACTERIZES]->(:ImpactCategory {id: 'IC_EF_EF_RESOURCE_USE_FOSSILS'})
DELETE c;

// ---- C6: prune stale ImpactResults (withdrawn fossil-sibling FRS run) ---
// refresh_variantA / refresh_recipe MERGE a result only for (dataset, category)
// pairs the recompute yields, and never delete stale ones. The withdrawn
// fossil-sibling CF addendum left 43 IR_RECIPE_*_IC_RECIPE_FRS nodes with
// frozen values; remove just those.
MATCH (ir:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory {id: 'IC_RECIPE_FRS'})
WHERE NOT EXISTS { (:Flow)-[:CHARACTERIZES]->(ic) }
DETACH DELETE ir;
// NOTE: a general stale-result prune (timestamp-based, inside the refresh
// files) is deferred to the consistency review -- e.g. EF3.1 fossil resource
// use for plastic-only grippers such as ART_FLAT_ABS still shows a pre-hygiene
// value because that (dataset, category) pair dropped out after P3.

// ---- verification ---------------------------------------------------
MATCH (ic:ImpactCategory) WHERE ic.id ENDS WITH '_ORGANICS' OR ic.id ENDS WITH '_INORGANICS'
RETURN 'orphan sub-categories remaining (expect 0)' AS check, count(ic) AS n;
MATCH (ic:ImpactCategory) WHERE ic.id IN ['IC_ENERGY', 'IC_WASTE']
RETURN 'IC_ENERGY/IC_WASTE remaining (expect 0)' AS check, count(ic) AS n;
MATCH (p:Process) WHERE p.id IN ['PROC_PA66_GRANULATE_MIX', 'PROC_FINISH']
RETURN 'legacy processes remaining (expect 0)' AS check, count(p) AS n;
MATCH (:Flow {name: 'uranium'})-[c:CHARACTERIZES]->(:ImpactCategory {id: 'IC_EF_EF_RESOURCE_USE_FOSSILS'})
RETURN 'uranium->fossils CF remaining (expect 0)' AS check, count(c) AS n;
MATCH (m:ImpactAssessmentMethod {id: 'IAM_EF31'})-[:HAS_CATEGORY]->(ic)
RETURN 'IAM_EF31 categories now' AS check, count(ic) AS n;

// ---- rollback -----------------------------------------------------
// C1/C2/C4: not automatically reversible -- re-run the EF3.1 CF import.
// C3: re-run v2_data/4A_realonly.cypher / the relevant package import.
// C5: MATCH (f:Flow {name:'uranium'}), (ic:ImpactCategory {id:'IC_EF_EF_RESOURCE_USE_FOSSILS'})
//     MERGE (f)-[:CHARACTERIZES {factor:1.0, location:''}]->(ic);
