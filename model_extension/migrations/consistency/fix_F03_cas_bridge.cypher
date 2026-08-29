// ============================================================================
// fix_F03_cas_bridge.cypher   --  consistency review, finding F-03
// ----------------------------------------------------------------------------
// Root cause: several imported ILCD datasets store Flow.casNumber zero-padded
// ("000124-38-9"). The bulk EF3.1 CF layer was matched without leading-zero
// normalisation, so those flows never got EF3.1 CFs, while the ReCiPe importer
// (norm_cas()) did -> EF3.1 vs ReCiPe results diverge (steel 8/19 vs 14/18
// categories; 4 steel grippers show a PA12-interface-only climate value).
//
// Step 1 adds a permanent normalised CAS to every flow (leading zeros stripped)
//        -- useful for any future CF matching.
// Step 2 copies each missing EF3.1 CF from the clean-CAS twin flow (same
//        normalised CAS AND same substance name), taking the global
//        (location='') factor. Additive, derived=true, idempotent.
// Rollback at the foot.
// ============================================================================

// ---- step 1: normalised CAS on every flow --------------------------
CREATE INDEX flow_casnorm IF NOT EXISTS FOR (f:Flow) ON (f.casNumberNorm);

MATCH (f:Flow) WHERE f.casNumber IS NOT NULL AND f.casNumberNorm IS NULL
SET f.casNumberNorm = ltrim(replace(f.casNumber, ' ', ''), '0');

// ---- step 2: bridge missing EF3.1 CFs onto zero-padded flows -------
MATCH (:Material)-[:MODELED_BY]->(:Process)-[:HAS_FLOW]->(fz:Flow)
WHERE fz.casNumber STARTS WITH '0' AND fz.casNumberNorm IS NOT NULL AND fz.name IS NOT NULL
  AND size(split(fz.casNumberNorm, '-')) = 3
WITH DISTINCT fz, toLower(trim(fz.name)) AS fzName
MATCH (ft:Flow {casNumberNorm: fz.casNumberNorm})
WHERE ft.id <> fz.id AND toLower(trim(coalesce(ft.name, ''))) = fzName
MATCH (ft)-[ctE:CHARACTERIZES]->(icE:ImpactCategory)<-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_EF31'})
WHERE NOT EXISTS { (fz)-[:CHARACTERIZES]->(icE) }
WITH fz, icE, ctE
ORDER BY CASE WHEN coalesce(ctE.location, '') = '' THEN 0 ELSE 1 END
WITH fz, icE, head(collect(ctE.factor)) AS factor
WHERE factor IS NOT NULL
MERGE (fz)-[nc:CHARACTERIZES {characterizesId: fz.id + '|' + icE.id + '|caspad'}]->(icE)
  ON CREATE SET nc.factor = factor, nc.location = '', nc.method = 'IAM_EF31',
                nc.source = 'EF3.1 CF bridged via CAS zero-padding normalisation',
                nc.derived = true, nc.matchedBy = 'cas-normalised';

// ---- verification --------------------------------------------------
MATCH ()-[nc:CHARACTERIZES]->() WHERE nc.matchedBy = 'cas-normalised'
RETURN 'EF3.1 CFs bridged' AS check, count(nc) AS n;

MATCH (ds:Process)<-[:MODELED_BY]-(:Material)
WITH DISTINCT ds
OPTIONAL MATCH (ds)-[:HAS_FLOW]->(:Flow)-[:CHARACTERIZES]->(icE:ImpactCategory)<-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_EF31'})
RETURN ds.id AS dataset, count(DISTINCT icE) AS ef31Categories ORDER BY ef31Categories;

MATCH (ds:Process {id:'PROC_STEEL_SECTIONS_ILCD'})-[hf:HAS_FLOW]->(f:Flow)
WITH ds, f, sum(hf.amount) AS amt
MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory {id:'IC_CLIMATE'})
RETURN 'steel dataset IC_CLIMATE perKg (was 0)' AS check, round(sum(amt * c.factor), 4) AS perKg;

// ---- rollback ----------------------------------------------------
// MATCH ()-[nc:CHARACTERIZES]->() WHERE nc.matchedBy = 'cas-normalised' DELETE nc;
// MATCH (f:Flow) WHERE f.casNumberNorm IS NOT NULL REMOVE f.casNumberNorm;
// DROP INDEX flow_casnorm IF EXISTS;
