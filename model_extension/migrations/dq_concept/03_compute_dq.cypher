// ============================================================================
// 03_compute_dq.cypher   (DQ concept -- automated / semi-automated scoring)
// ----------------------------------------------------------------------------
// Derives 0..4 criterion scores for every LCI data set (a Process reached by
// Material-[:MODELED_BY]->) purely from existing edge/node metadata, and rolls
// them up (MIN, never mean) onto every LCA Assessment that consumes such a data
// set. Re-runnable: auto edges are dropped and recomputed each run; manual
// (accuracy, uncertainty) edges are created once and never overwritten.
//
//   AUTO  (node/edge metadata only)
//     DQC_TEMP  <- Process.referenceYear vs study year 2026 (Weidema bands)
//     DQC_GEO   <- Process.geographicalLocation vs target geography DE
//     DQC_TECH  <- MODELED_BY.proxy / .proxyRationale (+ HAS_FLOW.dataMaturity)
//   SEMI-AUTO (graph structure)
//     DQC_COMP  <- share of elementary exchanges that are characterised and
//                  carry compartment + unit
//     DQC_CONS  <- share of the data set's CFs that are harmonised / proxy /
//                  low-confidence bridges
//     DQC_COMPAB<- lifecycleModule + dataSetType present (ILCD/EN15804 shape);
//                  capped at 3 (sub-type + functional-unit match stay manual)
//   MANUAL (expert at the gate -- left as score = null)
//     DQC_ACC, DQC_UNC
//
// Study frame: reference year 2026, target geography DE (EU/RER = "good").
// Idempotent. Rollback block at the end.
// ============================================================================

// ---- A: one DQ_AUTO node per LCI data set ------------------------------
MATCH (p:Process)
WHERE EXISTS { (:Material)-[:MODELED_BY]->(p) }
MERGE (dq:DataQuality {id:'DQ_AUTO_' + p.id})
  SET dq.name        = 'auto DQ -- ' + p.id,
      dq.subject     = 'lci-dataset',
      dq.derivation  = 'auto',
      dq.scale       = '0..4',
      dq.method      = 'metadata-derived (dq_concept/03_compute_dq.cypher)',
      dq.computedAt  = '2026-08-29'
MERGE (p)-[:HAS_DATA_QUALITY]->(dq);

// ---- B: clear previous auto criterion edges (refresh) ------------------
MATCH (dq:DataQuality)-[e:EVALUATES_CRITERION]->(:DataQualityCriterion)
WHERE dq.id STARTS WITH 'DQ_AUTO_'
  AND e.derivation IN ['auto','auto-rollup','semi-auto']
DELETE e;

// ---- C: DQC_TEMP -- temporal representativeness -----------------------
MATCH (p:Process)
WHERE EXISTS { (:Material)-[:MODELED_BY]->(p) }
WITH p, toInteger(p.referenceYear) AS ry
WITH p, CASE
    WHEN ry IS NULL          THEN 0
    WHEN 2026 - ry <= 3      THEN 4
    WHEN 2026 - ry <= 6      THEN 3
    WHEN 2026 - ry <= 10     THEN 2
    WHEN 2026 - ry <= 15     THEN 1
    ELSE 0 END AS score
MATCH (dq:DataQuality {id:'DQ_AUTO_' + p.id})
MATCH (c:DataQualityCriterion {id:'DQC_TEMP'})
MERGE (dq)-[e:EVALUATES_CRITERION]->(c)
SET e.score = score, e.derivation = 'auto',
    e.rating = CASE score WHEN 4 THEN 'very good' WHEN 3 THEN 'good' WHEN 2 THEN 'fair' WHEN 1 THEN 'poor' ELSE 'no basis' END,
    e.derivedFrom = 'Process.referenceYear=' + coalesce(toString(p.referenceYear),'null') + ' vs study year 2026',
    e.computedAt = '2026-08-29';

// ---- D: DQC_GEO -- geographical representativeness ------------------
MATCH (p:Process)
WHERE EXISTS { (:Material)-[:MODELED_BY]->(p) }
WITH p, toUpper(trim(coalesce(p.geographicalLocation,''))) AS geo
WITH p, geo, CASE
    WHEN geo IN ['DE','GERMANY']                                   THEN 4
    WHEN geo IN ['EU','EU-27','EU-28','EU-25','RER','EUROPE','WEU'] THEN 3
    WHEN geo IN ['GLO','ROW']                                      THEN 2
    WHEN geo = ''                                                  THEN 0
    ELSE 1 END AS score
MATCH (dq:DataQuality {id:'DQ_AUTO_' + p.id})
MATCH (c:DataQualityCriterion {id:'DQC_GEO'})
MERGE (dq)-[e:EVALUATES_CRITERION]->(c)
SET e.score = score, e.derivation = 'auto',
    e.rating = CASE score WHEN 4 THEN 'very good' WHEN 3 THEN 'good' WHEN 2 THEN 'fair' WHEN 1 THEN 'poor' ELSE 'no basis' END,
    e.derivedFrom = "Process.geographicalLocation='" + coalesce(p.geographicalLocation,'') + "' vs target DE",
    e.computedAt = '2026-08-29';

// ---- E: DQC_TECH -- technological representativeness ----------------
MATCH (p:Process)
WHERE EXISTS { (:Material)-[:MODELED_BY]->(p) }
MATCH (p)<-[mb:MODELED_BY]-(:Material)
WITH p, collect(mb) AS mbs
WITH p, [x IN mbs | CASE
      WHEN coalesce(x.proxy,false) = false                                                              THEN 4
      WHEN toLower(coalesce(x.proxyRationale,'')) =~ '.*(closest real|close match|closest match|same |equivalent|comparable grade|eco-profile).*' THEN 3
      WHEN toLower(coalesce(x.proxyRationale,'')) =~ '.*(generic|average|a1-a3 generic).*'              THEN 2
      WHEN toLower(coalesce(x.proxyRationale,'')) =~ '.*(different|surrogate|no dataset|placeholder).*' THEN 1
      ELSE 2 END ] AS scores
WITH p, reduce(mx = 0, s IN scores | CASE WHEN s > mx THEN s ELSE mx END) AS baseScore
OPTIONAL MATCH (p)-[hf:HAS_FLOW]->() WHERE hf.dataMaturity = 'screening/reference'
WITH p, baseScore, count(hf) AS screeningFlows
WITH p, CASE WHEN screeningFlows > 0 AND baseScore > 0 THEN baseScore - 1 ELSE baseScore END AS score
MATCH (dq:DataQuality {id:'DQ_AUTO_' + p.id})
MATCH (c:DataQualityCriterion {id:'DQC_TECH'})
MERGE (dq)-[e:EVALUATES_CRITERION]->(c)
SET e.score = score, e.derivation = 'auto',
    e.rating = CASE score WHEN 4 THEN 'very good' WHEN 3 THEN 'good' WHEN 2 THEN 'fair' WHEN 1 THEN 'poor' ELSE 'no basis' END,
    e.derivedFrom = 'MODELED_BY.proxy / .proxyRationale (+ HAS_FLOW.dataMaturity)',
    e.computedAt = '2026-08-29';

// ---- F: DQC_COMP -- impact-category coverage (semi-auto) -----------
// Completeness = does the data set produce a contribution across the whole
// method's category set, or only part of it. Referenced to EF3.1 (the case-
// study standard method). This measures dataset breadth, not the long tail of
// trace substances the LCIA method simply has no CF for.
MATCH (:ImpactAssessmentMethod {id:'IAM_EF31'})-[:HAS_CATEGORY]->(allic:ImpactCategory)
WITH count(DISTINCT allic) AS totalCats
MATCH (p:Process)
WHERE EXISTS { (:Material)-[:MODELED_BY]->(p) }
OPTIONAL MATCH (p)-[:HAS_FLOW]->(:Flow)-[:CHARACTERIZES]->(ic:ImpactCategory)<-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_EF31'})
WITH p, totalCats, count(DISTINCT ic) AS covered
WITH p, totalCats, covered, CASE WHEN totalCats = 0 THEN 0.0 ELSE toFloat(covered) / totalCats END AS frac
WITH p, totalCats, covered, CASE
    WHEN frac >= 0.95  THEN 4
    WHEN frac >= 0.85  THEN 3
    WHEN frac >= 0.70  THEN 2
    WHEN frac >= 0.50  THEN 1
    ELSE 0 END AS score
MATCH (dq:DataQuality {id:'DQ_AUTO_' + p.id})
MATCH (c:DataQualityCriterion {id:'DQC_COMP'})
MERGE (dq)-[e:EVALUATES_CRITERION]->(c)
SET e.score = score, e.derivation = 'semi-auto',
    e.rating = CASE score WHEN 4 THEN 'very good' WHEN 3 THEN 'good' WHEN 2 THEN 'fair' WHEN 1 THEN 'poor' ELSE 'no basis' END,
    e.derivedFrom = 'EF3.1 impact-category coverage ' + toString(covered) + '/' + toString(totalCats),
    e.computedAt = '2026-08-29';

// ---- G: DQC_CONS -- CF provenance uniformity (semi-auto) -----------
MATCH (p:Process)
WHERE EXISTS { (:Material)-[:MODELED_BY]->(p) }
OPTIONAL MATCH (p)-[:HAS_FLOW]->(:Flow)-[cf:CHARACTERIZES]->(:ImpactCategory)
WITH p, count(cf) AS cfs,
     sum(CASE WHEN coalesce(cf.source,'') CONTAINS 'harmonis'
               OR toLower(coalesce(cf.confidence,'')) = 'low'
               OR coalesce(cf.proxy,false) THEN 1 ELSE 0 END) AS patch
WITH p, cfs, patch, CASE WHEN cfs = 0 THEN 0.0 ELSE toFloat(patch) / cfs END AS pfrac
WITH p, cfs, patch, pfrac, CASE
    WHEN cfs = 0        THEN 0
    WHEN pfrac <= 0.02  THEN 4
    WHEN pfrac <= 0.10  THEN 3
    WHEN pfrac <= 0.25  THEN 2
    ELSE 1 END AS score
MATCH (dq:DataQuality {id:'DQ_AUTO_' + p.id})
MATCH (c:DataQualityCriterion {id:'DQC_CONS'})
MERGE (dq)-[e:EVALUATES_CRITERION]->(c)
SET e.score = score, e.derivation = 'semi-auto',
    e.rating = CASE score WHEN 4 THEN 'very good' WHEN 3 THEN 'good' WHEN 2 THEN 'fair' WHEN 1 THEN 'poor' ELSE 'no basis' END,
    e.derivedFrom = 'harmonised/proxy CFs ' + toString(patch) + '/' + toString(cfs),
    e.computedAt = '2026-08-29';

// ---- H: DQC_COMPAB -- ILCD/EN15804 shape (semi-auto, capped 3) -----
MATCH (p:Process)
WHERE EXISTS { (:Material)-[:MODELED_BY]->(p) }
WITH p, CASE
    WHEN coalesce(p.lifecycleModule,'') <> '' AND coalesce(p.dataSetType,'') <> '' THEN 3
    WHEN coalesce(p.lifecycleModule,'') <> ''                                      THEN 2
    ELSE 1 END AS score
MATCH (dq:DataQuality {id:'DQ_AUTO_' + p.id})
MATCH (c:DataQualityCriterion {id:'DQC_COMPAB'})
MERGE (dq)-[e:EVALUATES_CRITERION]->(c)
SET e.score = score, e.derivation = 'semi-auto',
    e.rating = CASE score WHEN 3 THEN 'good' WHEN 2 THEN 'fair' ELSE 'poor' END,
    e.derivedFrom = 'lifecycleModule/dataSetType present; EN15804 sub-type + FU match stay manual (cap 3)',
    e.computedAt = '2026-08-29';

// ---- I: DQC_ACC + DQC_UNC -- manual, created once, never overwritten
MATCH (p:Process)
WHERE EXISTS { (:Material)-[:MODELED_BY]->(p) }
MATCH (dq:DataQuality {id:'DQ_AUTO_' + p.id})
UNWIND ['DQC_ACC','DQC_UNC'] AS cid
MATCH (c:DataQualityCriterion {id:cid})
MERGE (dq)-[e:EVALUATES_CRITERION]->(c)
  ON CREATE SET e.score = null, e.derivation = 'manual',
                e.rating = 'expert assessment required at gate',
                e.computedAt = '2026-08-29';

// ---- J0: drop all rollup nodes (pure derived, recreated below) ------
MATCH (dqa:DataQuality {subject:'assessment'}) WHERE dqa.id STARTS WITH 'DQ_AUTO_'
DETACH DELETE dqa;

// ---- J: one roll-up DQ node per LCA assessment that reaches a data set
// Uses the same Artifact->Assembly->Part->Material->MODELED_BY join as
// refresh_variantA / refresh_recipe (mass-bearing parts only), so a rollup
// exists exactly where a real ImpactResult exists.
MATCH (a:Assessment)-[:USES_METHOD]->(m:ImpactAssessmentMethod)
WHERE m.id IN ['IAM_EF31','IAM_RECIPE']
MATCH (a)-[:ASSESSES]->(art:Artifact)
WHERE EXISTS {
  (art)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(pp:Part)
       -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(:Process)
  WHERE pp.mass_g IS NOT NULL
}
MERGE (dqa:DataQuality {id:'DQ_AUTO_' + a.id})
  SET dqa.name       = 'auto DQ rollup -- ' + a.id,
      dqa.subject    = 'assessment',
      dqa.derivation = 'auto-rollup',
      dqa.scale      = '0..4',
      dqa.method     = 'MIN of contributing LCI data set criteria (no mean)',
      dqa.computedAt = '2026-08-29'
MERGE (a)-[:HAS_DATA_QUALITY]->(dqa);

// ---- K: roll up each criterion as MIN over contributing data sets ---
MATCH (a:Assessment)-[:HAS_DATA_QUALITY]->(dqa:DataQuality {subject:'assessment'})
MATCH (a)-[:ASSESSES]->(art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(p:Part)
      -[:USES_MATERIAL]->(:Material)-[:MODELED_BY]->(ds:Process)
WHERE p.mass_g IS NOT NULL
MATCH (ds)-[:HAS_DATA_QUALITY]->(:DataQuality {subject:'lci-dataset'})-[ep:EVALUATES_CRITERION]->(c:DataQualityCriterion)
WHERE ep.derivation IN ['auto','semi-auto'] AND ep.score IS NOT NULL
WITH dqa, c, min(ep.score) AS rollScore, count(DISTINCT ds) AS nDatasets
MERGE (dqa)-[e:EVALUATES_CRITERION]->(c)
SET e.score = rollScore, e.derivation = 'auto-rollup',
    e.rating = CASE rollScore WHEN 4 THEN 'very good' WHEN 3 THEN 'good' WHEN 2 THEN 'fair' WHEN 1 THEN 'poor' ELSE 'no basis' END,
    e.derivedFrom = 'MIN over ' + toString(nDatasets) + ' contributing data set(s)',
    e.computedAt = '2026-08-29';

// ---- L: worst-criterion summary on every auto DQ node --------------
MATCH (dq:DataQuality)-[e:EVALUATES_CRITERION]->(:DataQualityCriterion)
WHERE dq.id STARTS WITH 'DQ_AUTO_' AND e.score IS NOT NULL
  AND e.derivation IN ['auto','semi-auto','auto-rollup']
WITH dq, min(e.score) AS worst, collect(e.score) AS scores
SET dq.worstScore    = worst,
    dq.meanScoreInfo = round(reduce(s = 0.0, x IN scores | s + x) / size(scores), 2),
    dq.summaryNote   = 'worstScore drives the gate; meanScoreInfo is informational only, never a pass criterion';

// ---- verification ------------------------------------------------------
MATCH (dq:DataQuality) WHERE dq.id STARTS WITH 'DQ_AUTO_'
RETURN dq.subject AS subject, count(*) AS nodes,
       sum(CASE WHEN dq.worstScore IS NOT NULL THEN 1 ELSE 0 END) AS withWorst;

MATCH (p:Process)-[:HAS_DATA_QUALITY]->(dq:DataQuality {subject:'lci-dataset'})-[e:EVALUATES_CRITERION]->(c:DataQualityCriterion)
RETURN p.id AS dataset, c.id AS criterion, e.score AS score
ORDER BY dataset, criterion;

MATCH (a:Assessment)-[:HAS_DATA_QUALITY]->(dq:DataQuality {subject:'assessment'})
WHERE a.id IN ['ASSESS_RECIPE_A_ART_FLAT_AL','ASSESS_RECIPE_A_ART_FLAT_ABS']
MATCH (dq)-[e:EVALUATES_CRITERION]->(c:DataQualityCriterion)
RETURN a.id AS assessment, c.class AS class, c.id AS criterion, e.score AS score, e.derivation AS derivation
ORDER BY assessment, class DESC, criterion;

// ---- rollback --------------------------------------------------------
// MATCH (dq:DataQuality) WHERE dq.id STARTS WITH 'DQ_AUTO_' DETACH DELETE dq;
