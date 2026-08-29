// ============================================================================
// lci_hygiene.cypher
// ----------------------------------------------------------------------------
// One-off cleanup of import-parser damage in the LCI layer (Sphera /
// PlasticsEurope exports whose CSV/TSV parser mishandled commas and
// semicolons inside substance names, and merged flows booked in different
// units onto one node). Strictly additive metadata where possible; the two
// parts that change results (P3 unit-split, P6 quarantine) are called out and
// individually reversible. Re-runnable.
//
// After applying, run refresh_variantA.cypher and cf_import/refresh_recipe.cypher.
//
//   P1  casNumber field: move non-CAS values to casNumberRaw, null the field
//   P2  land-use flows: restore the "Occupation, " / "Transformation, " name
//       prefix the parser stripped; move the unit out of casNumber; set the
//       land compartment
//   P3  unit-split: a Flow booked in >1 unit is split into one node per unit
//       so sum(hf.amount) is dimensionally clean; the characterised node keeps
//       the unit its CF expects (kBq for ionising radiation, MJ for fossil
//       resource use), off-unit exchanges move to an uncharacterised sibling
//       -- CHANGES ionising-radiation and fossil-resource results
//   P4  compartment backfill from the flow's unambiguous modal compartment
//   P5  compartment from a curated name rule for well-known air emissions that
//       have no other compartment signal
//   P6  quarantine flows whose name is a shattered fragment ("1", "(2", ...):
//       flag excludeFromCalc and drop their spurious CHARACTERIZES
//       -- CHANGES freshwater-ecotoxicity slightly for the aluminium dataset
// ============================================================================

// ---- P1: casNumber field cleanup -------------------------------------------
MATCH (f:Flow)
WHERE f.casNumber IS NOT NULL AND trim(f.casNumber) =~ '\d{1,7}-\d{2}-\d'
  AND f.casNumber <> trim(f.casNumber)
SET f.casNumber = trim(f.casNumber);

MATCH (f:Flow)
WHERE f.casNumber IS NOT NULL AND NOT trim(f.casNumber) =~ '\d{1,7}-\d{2}-\d'
SET f.casNumberRaw = f.casNumber,
    f.dataFlag = coalesce(f.dataFlag + '; ', '') + 'casNumber-noncas',
    f.casNumber = NULL;

// ---- P2: land-use flow name / unit / compartment repair -------------------
MATCH (f:Flow)
WHERE f.casNumberRaw = 'm2*a'
  AND NOT f.name STARTS WITH 'Occupation' AND NOT f.name STARTS WITH 'Transformation'
SET f.nameRaw = f.name, f.name = 'Occupation, ' + f.name,
    f.unitContext = 'm2*a',
    f.dataFlag = f.dataFlag + '; land-name-prefixed';

MATCH (f:Flow)
WHERE f.casNumberRaw = 'm2'
  AND (f.name STARTS WITH 'from ' OR f.name STARTS WITH 'to ')
SET f.nameRaw = f.name, f.name = 'Transformation, ' + f.name,
    f.unitContext = 'm2',
    f.dataFlag = f.dataFlag + '; land-name-prefixed';

MATCH (:Process)-[hf:HAS_FLOW]->(f:Flow)
WHERE f.casNumberRaw IN ['m2', 'm2*a'] AND coalesce(hf.compartment, '') = ''
SET hf.compartment = 'resource/land', hf.compartmentSource = 'lci-hygiene-land';

// ---- P3: unit-split -------------------------------------------------------
// Pass A: ionising-radiation flows -> canonical unit kBq
MATCH (p:Process)-[hf:HAS_FLOW]->(f:Flow)
WHERE hf.unit IS NOT NULL AND hf.unit <> 'kBq'
  AND EXISTS {
    MATCH (f)-[:CHARACTERIZES]->(ic:ImpactCategory)
    WHERE ic.id IN ['IC_EF_EF_IONISING_RADIATION_HUMAN_HEALTH', 'IC_RECIPE_IR']
  }
  AND EXISTS {
    MATCH (:Process)-[h2:HAS_FLOW]->(f) WHERE h2.unit = 'kBq'
  }
MERGE (sib:Flow {id: f.id + '#u=' + hf.unit})
  ON CREATE SET sib.name = f.name, sib.flowType = f.flowType,
                sib.unitContext = hf.unit, sib.splitFrom = f.id,
                sib.provenance = 'lci-hygiene unit-split',
                sib.dataFlag = 'unit-split sibling (non-canonical unit)';
MATCH (p:Process)-[hf:HAS_FLOW]->(f:Flow)
WHERE hf.unit IS NOT NULL AND hf.unit <> 'kBq'
  AND EXISTS {
    MATCH (f)-[:CHARACTERIZES]->(ic:ImpactCategory)
    WHERE ic.id IN ['IC_EF_EF_IONISING_RADIATION_HUMAN_HEALTH', 'IC_RECIPE_IR']
  }
  AND EXISTS { MATCH (:Process)-[h2:HAS_FLOW]->(f) WHERE h2.unit = 'kBq' }
MATCH (sib:Flow {id: f.id + '#u=' + hf.unit})
CREATE (p)-[nhf:HAS_FLOW]->(sib)
SET nhf = apoc.map.setKey(properties(hf), 'exchangeId',
            CASE WHEN hf.exchangeId IS NULL THEN NULL
                 ELSE hf.exchangeId + '#split=' + hf.unit END)
DELETE hf;

// Pass B: fossil-resource-use flows -> canonical unit MJ
MATCH (p:Process)-[hf:HAS_FLOW]->(f:Flow)
WHERE hf.unit IS NOT NULL AND hf.unit <> 'MJ'
  AND EXISTS { MATCH (f)-[:CHARACTERIZES]->(:ImpactCategory {id: 'IC_EF_EF_RESOURCE_USE_FOSSILS'}) }
  AND EXISTS { MATCH (:Process)-[h2:HAS_FLOW]->(f) WHERE h2.unit = 'MJ' }
MERGE (sib:Flow {id: f.id + '#u=' + hf.unit})
  ON CREATE SET sib.name = f.name, sib.flowType = f.flowType,
                sib.unitContext = hf.unit, sib.splitFrom = f.id,
                sib.provenance = 'lci-hygiene unit-split',
                sib.dataFlag = 'unit-split sibling (non-canonical unit)';
MATCH (p:Process)-[hf:HAS_FLOW]->(f:Flow)
WHERE hf.unit IS NOT NULL AND hf.unit <> 'MJ'
  AND EXISTS { MATCH (f)-[:CHARACTERIZES]->(:ImpactCategory {id: 'IC_EF_EF_RESOURCE_USE_FOSSILS'}) }
  AND EXISTS { MATCH (:Process)-[h2:HAS_FLOW]->(f) WHERE h2.unit = 'MJ' }
MATCH (sib:Flow {id: f.id + '#u=' + hf.unit})
CREATE (p)-[nhf:HAS_FLOW]->(sib)
SET nhf = apoc.map.setKey(properties(hf), 'exchangeId',
            CASE WHEN hf.exchangeId IS NULL THEN NULL
                 ELSE hf.exchangeId + '#split=' + hf.unit END)
DELETE hf;

// Pass C: remaining mixed-unit flows with no CF -> canonical unit = modal (most edges)
MATCH (:Process)-[hf:HAS_FLOW]->(f:Flow)
WHERE hf.unit IS NOT NULL AND NOT EXISTS { MATCH (f)-[:CHARACTERIZES]->() }
WITH f, hf.unit AS u, count(*) AS c
WITH f, collect({u: u, c: c}) AS byUnit
WHERE size(byUnit) > 1
WITH f, [x IN byUnit WHERE x.c = reduce(m = 0, y IN byUnit | CASE WHEN y.c > m THEN y.c ELSE m END)][0].u AS canon
MATCH (p:Process)-[hf:HAS_FLOW]->(f)
WHERE hf.unit IS NOT NULL AND hf.unit <> canon
MERGE (sib:Flow {id: f.id + '#u=' + hf.unit})
  ON CREATE SET sib.name = f.name, sib.flowType = f.flowType,
                sib.unitContext = hf.unit, sib.splitFrom = f.id,
                sib.provenance = 'lci-hygiene unit-split',
                sib.dataFlag = 'unit-split sibling (non-canonical unit)';
MATCH (:Process)-[hf:HAS_FLOW]->(f:Flow)
WHERE hf.unit IS NOT NULL AND NOT EXISTS { MATCH (f)-[:CHARACTERIZES]->() }
WITH f, hf.unit AS u, count(*) AS c
WITH f, collect({u: u, c: c}) AS byUnit
WHERE size(byUnit) > 1
WITH f, [x IN byUnit WHERE x.c = reduce(m = 0, y IN byUnit | CASE WHEN y.c > m THEN y.c ELSE m END)][0].u AS canon
MATCH (p:Process)-[hf:HAS_FLOW]->(f)
WHERE hf.unit IS NOT NULL AND hf.unit <> canon
MATCH (sib:Flow {id: f.id + '#u=' + hf.unit})
CREATE (p)-[nhf:HAS_FLOW]->(sib)
SET nhf = apoc.map.setKey(properties(hf), 'exchangeId',
            CASE WHEN hf.exchangeId IS NULL THEN NULL
                 ELSE hf.exchangeId + '#split=' + hf.unit END)
DELETE hf;

// ---- P4: compartment backfill from unambiguous modal ---------------------
MATCH (:Process)-[hf:HAS_FLOW]->(f:Flow)
WHERE coalesce(hf.compartment, '') <> ''
WITH f, collect(DISTINCT hf.compartment) AS comps
WHERE size(comps) = 1
WITH f, comps[0] AS modal
MATCH (:Process)-[blank:HAS_FLOW]->(f)
WHERE coalesce(blank.compartment, '') = ''
SET blank.compartment = modal, blank.compartmentSource = 'backfilled-modal';

// ---- P5: compartment from curated name rule (air emissions only) ---------
MATCH (:Process)-[hf:HAS_FLOW]->(f:Flow)
WHERE coalesce(hf.compartment, '') = '' AND coalesce(hf.direction, '') IN ['output', 'Output']
  AND EXISTS { MATCH (f)-[:CHARACTERIZES]->() }
  AND (
       toLower(f.name) CONTAINS 'carbon dioxide' OR toLower(f.name) CONTAINS 'methane'
    OR toLower(f.name) CONTAINS 'dinitrogen monoxide' OR toLower(f.name) CONTAINS 'nitrous oxide'
    OR toLower(f.name) = 'nitrogen oxides' OR toLower(f.name) STARTS WITH 'nitrogen dioxide'
    OR toLower(f.name) CONTAINS 'sulfur dioxide' OR toLower(f.name) CONTAINS 'sulphur dioxide'
    OR toLower(f.name) CONTAINS 'sulfur oxides' OR toLower(f.name) = 'ammonia'
    OR toLower(f.name) CONTAINS 'non-methane volatile' OR toLower(f.name) = 'volatile organic compound'
    OR toLower(f.name) CONTAINS 'particulates' OR toLower(f.name) STARTS WITH 'particles ('
  )
SET hf.compartment = 'emission/air', hf.compartmentSource = 'backfilled-namerule';

// ---- P6: quarantine delimiter-shattered flows --------------------------
MATCH (f:Flow)
WHERE f.name =~ '\d{1,3}' OR f.name =~ '\(\d{1,3}' OR f.name = '2-chloro-N-(2'
SET f.dataFlag = coalesce(f.dataFlag + '; ', '') + 'delimiter-shattered; needs re-import',
    f.excludeFromCalc = true;
MATCH (f:Flow)-[c:CHARACTERIZES]->()
WHERE coalesce(f.excludeFromCalc, false) = true
SET f._removedCharacterizes = coalesce(f._removedCharacterizes, 0) + 1
DELETE c;

// ---- verification -------------------------------------------------------
MATCH (f:Flow) WHERE f.casNumberRaw IS NOT NULL
RETURN 'P1 casNumber moved to casNumberRaw' AS step, count(f) AS n;
MATCH (f:Flow) WHERE f.dataFlag CONTAINS 'land-name-prefixed'
RETURN 'P2 land-use names prefixed' AS step, count(f) AS n;
MATCH (sib:Flow) WHERE sib.splitFrom IS NOT NULL
RETURN 'P3 unit-split siblings created' AS step, count(sib) AS n;
MATCH (:Process)-[hf:HAS_FLOW]->(:Flow) WHERE hf.compartmentSource = 'backfilled-modal'
RETURN 'P4 compartments backfilled (modal)' AS step, count(hf) AS n;
MATCH (:Process)-[hf:HAS_FLOW]->(:Flow) WHERE hf.compartmentSource = 'backfilled-namerule'
RETURN 'P5 compartments backfilled (name rule)' AS step, count(hf) AS n;
MATCH (f:Flow) WHERE f.excludeFromCalc = true
RETURN 'P6 flows quarantined' AS step, count(f) AS n;
MATCH (:Process)-[hf:HAS_FLOW]->(:Flow)
WITH hf.unit AS u, collect(DISTINCT hf.unit) AS x
MATCH (:Process)-[h2:HAS_FLOW]->(f2:Flow)
WITH f2, collect(DISTINCT h2.unit) AS units
WHERE size([u IN units WHERE u IS NOT NULL]) > 1
RETURN 'remaining mixed-unit flows (expect 0)' AS step, count(f2) AS n;

// ---- rollback ---------------------------------------------------------
// P1: MATCH (f:Flow) WHERE f.casNumberRaw IS NOT NULL SET f.casNumber = f.casNumberRaw REMOVE f.casNumberRaw;
// P2: MATCH (f:Flow) WHERE f.nameRaw IS NOT NULL SET f.name = f.nameRaw REMOVE f.nameRaw;
// P3: MATCH (p:Process)-[hf:HAS_FLOW]->(sib:Flow) WHERE sib.splitFrom IS NOT NULL
//     MATCH (orig:Flow {id: sib.splitFrom}) CREATE (p)-[n:HAS_FLOW]->(orig) SET n = properties(hf) DELETE hf;
//     MATCH (sib:Flow) WHERE sib.splitFrom IS NOT NULL DETACH DELETE sib;
// P4/P5: MATCH (:Process)-[hf:HAS_FLOW]->() WHERE hf.compartmentSource IN ['backfilled-modal','backfilled-namerule','lci-hygiene-land']
//     SET hf.compartment = '' REMOVE hf.compartmentSource;
// P6: (CHARACTERIZES deletions are not automatically reversible -- re-run cf imports)
//     MATCH (f:Flow) WHERE f.excludeFromCalc = true REMOVE f.excludeFromCalc;
