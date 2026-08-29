// ============================================================================
// 02_phase_targets.cypher   (DQ concept -- engineering phases + gate targets)
// ----------------------------------------------------------------------------
// Minimum target score per criterion per engineering / reporting phase.
// The gate is MIN-based: a data set (or an assessment) passes a phase iff
// EVERY criterion score >= that phase's minScore for the criterion. There is
// deliberately no averaging and no single "DQ index".
//
// Phases follow the graph's own black/grey/white-box staging (model_versions/
// PLAN.md) and the RFLPV(2) verification layer:
//   PH_SCREENING   -- early estimate, concept gate            (v1 black-box)
//   PH_DESIGN      -- variant decisions, design-freeze gate   (v2/v3 grey->white)
//   PH_DECLARATION -- EPD / DPP, external release gate        (v3.x white-box)
//
// The minScore matrix below is a DEFAULT to be tuned against the published
// phase target values (basis = 'default' on every TARGETS edge).
// Idempotent. Rollback block at the end.
// ============================================================================

CREATE CONSTRAINT DQPhase_id_unique IF NOT EXISTS FOR (node:DQPhase) REQUIRE (node.id) IS UNIQUE;

MERGE (p1:DQPhase {id:'PH_SCREENING'})
  SET p1.name='Screening / concept', p1.order=1, p1.gate='concept gate',
      p1.boxStage='v1 black-box',
      p1.description='First estimate; cross-material proxies and older background data are acceptable.';
MERGE (p2:DQPhase {id:'PH_DESIGN'})
  SET p2.name='Design & variant comparison', p2.order=2, p2.gate='design-freeze gate',
      p2.boxStage='v2/v3 grey->white',
      p2.description='Variant decisions must rest on comparable, technology-matched data on one method / system boundary.';
MERGE (p3:DQPhase {id:'PH_DECLARATION'})
  SET p3.name='Declaration / external reporting', p3.order=3, p3.gate='release gate',
      p3.boxStage='v3.x white-box',
      p3.description='EPD / DPP: recent, geography- and technology-matched, methodologically clean, expert-verified data.';

// minScore matrix (0..4, 4 = optimal)
//   criterion   SCREEN  DESIGN  DECLARE
//   DQC_TEMP      1       2       3
//   DQC_GEO       1       2       3
//   DQC_TECH      1       2       3
//   DQC_COMP      1       2       3
//   DQC_CONS      1       3       4
//   DQC_COMPAB    0       2       3
//   DQC_ACC       1       2       3
//   DQC_UNC       0       1       2
UNWIND [
  {ph:'PH_SCREENING',   t:[['DQC_TEMP',1],['DQC_GEO',1],['DQC_TECH',1],['DQC_COMP',1],['DQC_CONS',1],['DQC_COMPAB',0],['DQC_ACC',1],['DQC_UNC',0]]},
  {ph:'PH_DESIGN',      t:[['DQC_TEMP',2],['DQC_GEO',2],['DQC_TECH',2],['DQC_COMP',2],['DQC_CONS',3],['DQC_COMPAB',2],['DQC_ACC',2],['DQC_UNC',1]]},
  {ph:'PH_DECLARATION', t:[['DQC_TEMP',3],['DQC_GEO',3],['DQC_TECH',3],['DQC_COMP',3],['DQC_CONS',4],['DQC_COMPAB',3],['DQC_ACC',3],['DQC_UNC',2]]}
] AS row
MATCH (ph:DQPhase {id:row.ph})
UNWIND row.t AS pair
MATCH (c:DataQualityCriterion {id:pair[0]})
MERGE (ph)-[r:TARGETS]->(c)
  SET r.minScore = pair[1],
      r.basis    = 'default -- tune against published phase target values';

// ---- verification ------------------------------------------------------
MATCH (ph:DQPhase)-[r:TARGETS]->(c:DataQualityCriterion)
RETURN ph.order AS ord, ph.id AS phase, c.id AS criterion, r.minScore AS minScore
ORDER BY ord, criterion;

// ---- rollback --------------------------------------------------------
// MATCH (ph:DQPhase) DETACH DELETE ph;
