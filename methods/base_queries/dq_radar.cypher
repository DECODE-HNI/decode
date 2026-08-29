// ============================================================================
// dq_radar.cypher  --  data-quality radar + phase gate for one LCA assessment
// ----------------------------------------------------------------------------
// Reads the auto-derived DQ layer (model_versions/dq_concept/). Returns the
// 8-criterion score vector (radar axes), the selected phase's target vector,
// and a per-axis + overall pass/fail. The gate is MIN-based: gatePass is true
// iff EVERY criterion meets its target -- there is no averaging and no index.
//
//   :param assessmentId => 'ASSESS_RECIPE_A_ART_FLAT_AL';
//   :param phase        => 'PH_DECLARATION';   // PH_SCREENING | PH_DESIGN | PH_DECLARATION
// ============================================================================

// --- radar: one row per criterion (inherent block, then system block) ---
MATCH (a:Assessment {id:$assessmentId})-[:HAS_DATA_QUALITY]->(dqa:DataQuality {subject:'assessment'})
MATCH (dqa)-[e:EVALUATES_CRITERION]->(c:DataQualityCriterion)
OPTIONAL MATCH (:DQPhase {id:$phase})-[t:TARGETS]->(c)
RETURN c.class                                             AS class,
       c.id                                               AS criterion,
       c.name                                             AS name,
       e.score                                            AS score,
       e.derivation                                       AS derivation,
       t.minScore                                         AS target,
       CASE WHEN e.score IS NULL THEN null
            ELSE e.score >= coalesce(t.minScore, 0) END   AS meetsTarget,
       e.derivedFrom                                      AS basis
ORDER BY class DESC, criterion;

// --- verdict: overall gate for the chosen phase ------------------------
MATCH (a:Assessment {id:$assessmentId})-[:HAS_DATA_QUALITY]->(:DataQuality {subject:'assessment'})-[e:EVALUATES_CRITERION]->(c:DataQualityCriterion)
MATCH (ph:DQPhase {id:$phase})-[t:TARGETS]->(c)
WITH ph, a,
     collect({crit:c.id,
              score:e.score,
              target:t.minScore,
              ok:(e.score IS NOT NULL AND e.score >= t.minScore)}) AS rows
RETURN a.id                                          AS assessment,
       ph.name                                       AS phase,
       all(r IN rows WHERE r.ok)                     AS gatePass,
       [r IN rows WHERE NOT r.ok | r.crit]           AS failingCriteria,
       reduce(mn = 4, r IN rows |
              CASE WHEN r.score IS NOT NULL AND r.score < mn THEN r.score ELSE mn END) AS worstScore;

// --- context: the same for every phase (progress view) ---------------
MATCH (a:Assessment {id:$assessmentId})-[:HAS_DATA_QUALITY]->(:DataQuality {subject:'assessment'})-[e:EVALUATES_CRITERION]->(c:DataQualityCriterion)
MATCH (ph:DQPhase)-[t:TARGETS]->(c)
WITH ph, collect({ok:(e.score IS NOT NULL AND e.score >= t.minScore), crit:c.id}) AS rows
RETURN ph.order AS ord, ph.id AS phase,
       all(r IN rows WHERE r.ok) AS gatePass,
       [r IN rows WHERE NOT r.ok | r.crit] AS failingCriteria
ORDER BY ord;
