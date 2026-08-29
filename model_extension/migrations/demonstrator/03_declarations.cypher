// ============================================================================
// 03_declarations.cypher   (demonstrator slice -- EPD / DPP + status lifecycle)
// ----------------------------------------------------------------------------
// Adds a status lifecycle to Declaration (draft -> verified -> published ->
// expired) and issues EPD + DPP for the rest of the 8-gripper slice
// (previously only ART_V_AL had them). Idempotent. Rollback at the foot.
// ============================================================================

// existing ART_V_AL declarations: the published reference
MATCH (d:Declaration) WHERE d.id IN ['DECL_EPD_ART_V_AL','DECL_DPP_ART_V_AL']
SET d.status='published',
    d.verifiedBy='third-party (demonstrator placeholder)',
    d.issuedAt='2026-06-01', d.expiresAt='2031-06-01';

// new declarations. tier: real-data grippers -> verified; partial-data -> draft
UNWIND [
  {art:'ART_FLAT_AL',    tier:'verified'},
  {art:'ART_PREC_POM',   tier:'verified'},
  {art:'ART_FLAT_ABS',   tier:'verified'},
  {art:'ART_PREC_PC',    tier:'verified'},
  {art:'ART_LONG_CFPA',  tier:'draft'},
  {art:'ART_FINRAY_TPU', tier:'draft'},
  {art:'ART_MAGNET',     tier:'draft'}
] AS d
MATCH (art:Artifact {id:d.art})
MERGE (epd:Declaration {id:'DECL_EPD_' + d.art})
  ON CREATE SET epd.type='EPD', epd.standard='EN 15804+A2',
                epd.functionalUnit='one gripper (modelled material parts)',
                epd.scope='cradle-to-gate (A1-A3)',
                epd.validFrom='2026-06-01', epd.validUntil='2031-06-01'
SET epd.status=d.tier,
    epd.verifiedBy=CASE d.tier WHEN 'verified' THEN 'internal review (demonstrator)' ELSE null END,
    epd.issuedAt=CASE d.tier WHEN 'verified' THEN '2026-06-01' ELSE null END,
    epd.note=CASE d.tier WHEN 'draft' THEN 'LCA partial -- jaw material lacks a working real dataset' ELSE null END
MERGE (epd)-[:DECLARES]->(art)
MERGE (dpp:Declaration {id:'DECL_DPP_' + d.art})
  ON CREATE SET dpp.type='DPP', dpp.standard='ESPR (draft)',
                dpp.functionalUnit='one gripper',
                dpp.scope='product passport (material, circularity, repairability, PCF)',
                dpp.validFrom='2026-06-01'
SET dpp.status=d.tier
MERGE (dpp)-[:DECLARES]->(art);

// REPORTS: EPD -> EF3.1 Variant-A category results
UNWIND ['ART_FLAT_AL','ART_PREC_POM','ART_FLAT_ABS','ART_PREC_PC','ART_LONG_CFPA','ART_FINRAY_TPU','ART_MAGNET'] AS aid
MATCH (epd:Declaration {id:'DECL_EPD_' + aid})
MATCH (:Assessment {id:'ASSESS_EF31A_' + aid})-[:HAS_RESULT]->(ir:ImpactResult)
MERGE (epd)-[:REPORTS]->(ir);

// REPORTS: DPP -> MCI + repairability results
UNWIND ['ART_FLAT_AL','ART_PREC_POM','ART_FLAT_ABS','ART_PREC_PC','ART_LONG_CFPA','ART_FINRAY_TPU','ART_MAGNET'] AS aid
MATCH (dpp:Declaration {id:'DECL_DPP_' + aid})
OPTIONAL MATCH (:Assessment {id:'ASSESS_MCI_' + aid})-[:HAS_RESULT]->(mci:ImpactResult)
OPTIONAL MATCH (:Assessment {id:'ASSESS_REPAIR_' + aid})-[:HAS_RESULT]->(rep:ImpactResult)
FOREACH (x IN CASE WHEN mci IS NULL THEN [] ELSE [mci] END | MERGE (dpp)-[:REPORTS]->(x))
FOREACH (x IN CASE WHEN rep IS NULL THEN [] ELSE [rep] END | MERGE (dpp)-[:REPORTS]->(x));

// verification
MATCH (d:Declaration)
OPTIONAL MATCH (d)-[rep:REPORTS]->()
RETURN d.type AS type, d.status AS status, d.id AS id, count(rep) AS reports ORDER BY type, id;

// rollback
// MATCH (d:Declaration) WHERE d.id STARTS WITH 'DECL_EPD_' OR d.id STARTS WITH 'DECL_DPP_'
//   AND NOT d.id ENDS WITH 'ART_V_AL' DETACH DELETE d;
// MATCH (d:Declaration) WHERE d.id IN ['DECL_EPD_ART_V_AL','DECL_DPP_ART_V_AL']
//   REMOVE d.status, d.verifiedBy, d.issuedAt, d.expiresAt;
