// ============================================================================
// 01_criteria_catalogue.cypher   (DQ concept -- criteria + scale alignment)
// ----------------------------------------------------------------------------
// Aligns the data-quality subgraph with the published HNI concept
// (Rarbach / Graessler / Pottebaum, "Data Quality in the Engineering of
// Circular Products" / "Metadata-based assessment of Data Quality"):
//
//   * ISO 14044 6.3.6 criteria, split into
//       INHERENT        -- intrinsic to the data value (precision, completeness,
//                          methodological consistency, comparability, uncertainty)
//       SYSTEM-RELATED  -- how well the data set's context matches the study's
//                          target system (temporal / geographical / technological
//                          representativeness)
//   * 0..4 pedigree scale, 4 = optimal (Weidema 1..5 inverted: new = 5 - weidema)
//   * NO aggregation formula. A data set's quality against a phase is the WORST
//     of its criterion scores vs that phase's minimum target -- never a mean.
//
// Idempotent (re-runnable). Rollback block at the end.
// Run order: 01 -> 02 -> 03. Then base_queries/dq_radar.cypher to read.
// ============================================================================

// ---- 1a: enrich the 8 DataQualityCriterion nodes -------------------------
UNWIND [
  {id:'DQC_ACC',    name:'Accuracy / precision',             class:'inherent', derivation:'manual',    iso:'ISO 14044 6.3.6 e)',    pedigree:'reliability'},
  {id:'DQC_COMP',   name:'Completeness',                     class:'inherent', derivation:'semi-auto', iso:'ISO 14044 6.3.6 f)',    pedigree:'completeness'},
  {id:'DQC_CONS',   name:'Methodological consistency',       class:'inherent', derivation:'semi-auto', iso:'ISO 14044 6.3.6 h)',    pedigree:''},
  {id:'DQC_COMPAB', name:'Comparability',                    class:'inherent', derivation:'semi-auto', iso:'ISO 14044 / EN 15804',  pedigree:''},
  {id:'DQC_UNC',    name:'Uncertainty',                      class:'inherent', derivation:'manual',    iso:'ISO 14044 6.3.6 j)',    pedigree:'reliability'},
  {id:'DQC_TEMP',   name:'Temporal representativeness',      class:'system',   derivation:'auto',      iso:'ISO 14044 6.3.6 a)',    pedigree:'temporal correlation'},
  {id:'DQC_GEO',    name:'Geographical representativeness',  class:'system',   derivation:'auto',      iso:'ISO 14044 6.3.6 b)',    pedigree:'geographical correlation'},
  {id:'DQC_TECH',   name:'Technological representativeness', class:'system',   derivation:'auto',      iso:'ISO 14044 6.3.6 c)',    pedigree:'further technological correlation'}
] AS c
MATCH (dqc:DataQualityCriterion {id:c.id})
SET dqc.name             = c.name,
    dqc.class            = c.class,
    dqc.derivation       = c.derivation,
    dqc.scale            = '0..4',
    dqc.scaleSemantics   = '4 = optimal (recent / geography- and technology-matched / verified); 3 good; 2 fair; 1 poor; 0 = no basis or not representative',
    dqc.isoRef           = c.iso,
    dqc.pedigreeIndicator= c.pedigree,
    dqc.aggregation      = 'none -- worst criterion vs phase target, never a mean';

// ---- 1b: rescale the hand-authored provenance-tier presets 1..5 -> 0..4 --
MATCH (dq:DataQuality)
WHERE dq.scale = '1..5'
SET dq.overallScore = dq.overallScore - 1,
    dq.scale        = '0..4',
    dq.scaleNote    = 'rescaled 2026-08-29 from 1..5 (Weidema) to 0..4 (4 = optimal) per the HNI DQ concept';

MATCH (:DataQuality)-[e:EVALUATES_CRITERION]->(:DataQualityCriterion)
WHERE coalesce(e.rescaled04, false) = false
  AND e.derivation IS NULL          // only the hand-authored 1..5 edges, not auto edges from step 03
  AND e.score >= 1 AND e.score <= 5
SET e.score = e.score - 1,
    e.rescaled04 = true;

// ---- verification ------------------------------------------------------
MATCH (c:DataQualityCriterion)
RETURN c.class AS class, c.id AS id, c.name AS name, c.derivation AS derivation
ORDER BY class DESC, id;

MATCH (dq:DataQuality)-[e:EVALUATES_CRITERION]->(:DataQualityCriterion)
WHERE e.derivation IS NULL
RETURN 'hand-authored EVALUATES_CRITERION now on 0..4' AS check,
       min(e.score) AS minScore, max(e.score) AS maxScore, count(*) AS edges;

// ---- rollback --------------------------------------------------------
// MATCH (dq:DataQuality) WHERE dq.scale = '0..4' AND dq.scaleNote IS NOT NULL
//   SET dq.overallScore = dq.overallScore + 1, dq.scale = '1..5' REMOVE dq.scaleNote;
// MATCH (:DataQuality)-[e:EVALUATES_CRITERION]->(:DataQualityCriterion)
//   WHERE e.rescaled04 = true SET e.score = e.score + 1 REMOVE e.rescaled04;
// MATCH (c:DataQualityCriterion)
//   REMOVE c.class, c.derivation, c.scaleSemantics, c.isoRef, c.pedigreeIndicator, c.aggregation
//   SET c.scale = '';
