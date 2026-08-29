// ============================================================================
// migration_v3c.cypher  --  Module v3.c: Parameter / scenario layer + uncertainty
//                          metadata. Additive. One illustrative scenario.
// NOTE: every statement re-MATCHes nodes by id (statements are independent).
// Rollback at bottom. Date: 2026-08-27
// ============================================================================

// --- 1. Uncertainty distribution type on populated HAS_FLOW edges --------
MATCH ()-[hf:HAS_FLOW]->()
WHERE hf.uncertainty IS NOT NULL AND hf.uncertaintyDistribution IS NULL
SET hf.uncertaintyDistribution = 'lognormal',
    hf.uncertaintyBasis = 'v3.c default: ILCD secondary background LCI';

// --- 2. Parameter layer nodes -----------------------------------------
MERGE (par:Parameter {id:'PARAM_AL_RECYCLED_CONTENT'})
  SET par.name='Aluminium recycled content', par.unit='fraction', par.baseValue=0.35;
MERGE (sc:ModelScenario {id:'SC_RECYCLED_ALU'})
  SET sc.name='Recycled aluminium feedstock', sc.type='what-if', sc.horizonYear=2030,
      sc.description='Al6061 recycled content raised 0.35 -> 0.75 (secondary route)';
MERGE (base:ModelScenario {id:'SC_BASELINE'})
  SET base.name='Baseline', base.type='baseline', base.description='as-modelled defaults';
MERGE (pv:ParameterValue {id:'PV_SC_RECYCLED_ALU_AL_RC'})
  SET pv.value=0.75, pv.unit='fraction';

// --- 3. Parameter layer edges (re-match by id) -----------------------
MATCH (par:Parameter {id:'PARAM_AL_RECYCLED_CONTENT'}), (m:Material {id:'MAT_AL6061'})
MERGE (par)-[:PARAM_OF]->(m);
MATCH (sc:ModelScenario {id:'SC_RECYCLED_ALU'}), (pv:ParameterValue {id:'PV_SC_RECYCLED_ALU_AL_RC'})
MERGE (sc)-[:SETS]->(pv);
MATCH (pv:ParameterValue {id:'PV_SC_RECYCLED_ALU_AL_RC'}), (par:Parameter {id:'PARAM_AL_RECYCLED_CONTENT'})
MERGE (pv)-[:FOR]->(par);

// --- 4. Attach every Assessment to the baseline scenario ------------
MATCH (as:Assessment), (base:ModelScenario {id:'SC_BASELINE'})
MERGE (as)-[:UNDER_SCENARIO]->(base)
SET as.scenarioRef = coalesce(as.scenarioRef,'SC_BASELINE');

MATCH (as:Assessment)-[:UNDER_SCENARIO]->(s:ModelScenario)
MATCH (as)-[:HAS_RESULT]->(ir:ImpactResult)
SET ir.scenarioRef = s.id;

// --- verification --------------------------------------------------
MATCH ()-[hf:HAS_FLOW]->() WHERE hf.uncertaintyDistribution IS NOT NULL
RETURN 'HAS_FLOW.uncertaintyDistribution' AS check, count(hf) AS edges;
MATCH (s:ModelScenario) OPTIONAL MATCH (s)-[:SETS]->(pv) RETURN s.id, s.type, count(pv) AS setsValues;
MATCH (p:Parameter)-[:PARAM_OF]->(x) RETURN p.id AS parameter, labels(x)[0]+':'+x.id AS parameterizes;
MATCH ()-[r:UNDER_SCENARIO]->() RETURN 'UNDER_SCENARIO' AS check, count(r) AS edges;
MATCH (n) WHERE size(labels(n))=0 RETURN 'labelless (must be 0)' AS check, count(n) AS n;

// --- rollback ------------------------------------------------------
// MATCH ()-[hf:HAS_FLOW]->() REMOVE hf.uncertaintyDistribution, hf.uncertaintyBasis;
// MATCH (n) WHERE n:Parameter OR n:ParameterValue OR n:ModelScenario DETACH DELETE n;
// MATCH (ir:ImpactResult) REMOVE ir.scenarioRef;
// MATCH (as:Assessment) REMOVE as.scenarioRef;
