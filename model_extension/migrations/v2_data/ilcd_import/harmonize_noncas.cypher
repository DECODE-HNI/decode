// ============================================================================
// harmonize_noncas.cypher
// ----------------------------------------------------------------------------
// Bridge the CAS-less "alias" elementary flows that the PlasticsEurope
// eco-profile packages emit to the EF3.1 characterisation set. The CAS-based
// step in gen_import.sh (steps 4/5) cannot reach these because the source
// flows carry no CAS number; they are matched here by name + compartment.
//
// Strictly additive, idempotent, re-runnable. Run order:
//   import_<MAT>.cypher  ->  harmonize_noncas.cypher  ->  refresh_variantA.cypher
//
// Aliases handled (air emissions; compartment implicit in the canonical CF):
//   particles (PM2.5 - PM10)     -> particles (PM10) CF      (2.5-10 um fraction)
//   volatile organic compound    -> non-methane VOC CFs      (older label, same
//                                    substance bucket; copies every EF3.1 CF the
//                                    canonical NMVOC flow carries: POCP + the
//                                    inherited USEtox ecotox / human-tox factors)
//   Particulates (unspecified)   -> particles (PM10) CF      (documented proxy)
//   Dust (unspecified)           -> particles (PM10) CF      (documented proxy)
//
// NOT handled, on purpose:
//   particles (> PM10)  -- EF3.1 CF for the > 10 um fraction is 0 (no modelled
//                          health effect); leaving it uncharacterised is exact.
//   chemical / biological oxygen demand -- no EF3.1 (nor ReCiPe 2016) category
//                          is driven by COD/BOD. EF3.1 freshwater eutrophication
//                          is phosphorus-only, marine eutrophication is
//                          nitrogen-only. COD/BOD would only feed a CML-2001
//                          "aquatic eutrophication" category, which this model
//                          does not implement. Uncharacterised is correct here.
//
// characterizesId convention: "<aliasFlowUuid>|<icId>|"  (keeps MERGE unique and
// never collides with the canonical flow's own "<canonUuid>|<icId>|" edge).
// Reverse with:  MATCH ()-[c:CHARACTERIZES]->() WHERE c.source IN
//   ['harmonised via non-CAS name+compartment',
//    'proxy: unspecified particulates -> PM10 CF'] DELETE c;
// ============================================================================

// --- 1. exact aliases: copy every EF3.1 CF from the canonical flow -----------
UNWIND [
  {alias:'08a91e70-3ddc-11dd-9501-0050c2490048', canon:'08a91e70-3ddc-11dd-91be-0050c2490048'}, // PM2.5-PM10 -> PM10
  {alias:'08a91e70-3ddc-11dd-9155-0050c2490048', canon:'08a91e70-3ddc-11dd-a302-0050c2490048'}  // VOC -> NMVOC
] AS m
MATCH (canon:Flow {id:m.canon})-[cc:CHARACTERIZES]->(ic:ImpactCategory)
      <-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_EF31'})
MATCH (alias:Flow {id:m.alias})
WHERE NOT (alias)-[:CHARACTERIZES]->(ic)
MERGE (alias)-[nc:CHARACTERIZES {characterizesId: m.alias + '|' + ic.id + '|'}]->(ic)
  ON CREATE SET nc.factor        = cc.factor,
                nc.location      = coalesce(cc.location,''),
                nc.source        = 'harmonised via non-CAS name+compartment',
                nc.harmonisedFrom = m.canon,
                nc.derived       = true;

// --- 2. unspecified particulate buckets: PM10 CF as conservative proxy -------
UNWIND ['38a9d121-fc90-45c7-9ea7-11a9a3b68041',   // Particulates (unspecified)
        '4f520365-e5ce-486a-ab24-1703f5b2297d']   // Dust (unspecified)
  AS aliasId
MATCH (canon:Flow {id:'08a91e70-3ddc-11dd-91be-0050c2490048'})
      -[cc:CHARACTERIZES]->(ic:ImpactCategory {id:'IC_EF_PARTICULATE_MATTER'})
MATCH (alias:Flow {id:aliasId})
WHERE NOT (alias)-[:CHARACTERIZES]->(ic)
MERGE (alias)-[nc:CHARACTERIZES {characterizesId: aliasId + '|IC_EF_PARTICULATE_MATTER|'}]->(ic)
  ON CREATE SET nc.factor        = cc.factor,
                nc.location      = '',
                nc.source        = 'proxy: unspecified particulates -> PM10 CF',
                nc.harmonisedFrom = '08a91e70-3ddc-11dd-91be-0050c2490048',
                nc.proxy         = true,
                nc.confidence    = 'low',
                nc.derived       = true;

// --- verification -----------------------------------------------------------
MATCH (f:Flow)-[c:CHARACTERIZES]->(ic:ImpactCategory)
WHERE c.source IN ['harmonised via non-CAS name+compartment',
                   'proxy: unspecified particulates -> PM10 CF']
RETURN f.name AS aliasFlow, ic.id AS ic, c.factor AS factor,
       c.source AS source, coalesce(c.proxy,false) AS proxy
ORDER BY aliasFlow, ic;
