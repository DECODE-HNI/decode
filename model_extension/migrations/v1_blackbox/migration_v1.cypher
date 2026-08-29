// ============================================================================
// migration_v1.cypher  --  Black-box completion: formalize repairability
//                          and attach concrete, computed indicators.
// Runs against the LIVE database. All changes are additive / reversible
// (new relationship properties, new node properties, catalogue links).
// Rollback snippet at the bottom.
// Date: 2026-08-27
// ============================================================================

// ----------------------------------------------------------------------------
// 1. Relocate the joining information off the (v2-only) Process layer onto
//    HAS_COMPONENT edges, so it survives in the v1 black-box snapshot.
//    Evidence: Process PROC_SCREW {joiningType:"screw (reversible)"} APPLIES_TO
//    the CONTACT and INTERFACE parts of every gripper.
// ----------------------------------------------------------------------------
MATCH (:Process {id:'PROC_SCREW'})-[:APPLIES_TO]->(p:Part)<-[hc:HAS_COMPONENT]-(:Assembly)
SET hc.connectionType = 'screw',
    hc.reversible      = true,
    hc.evidenceLevel   = 'documented',
    hc.evidenceRef     = 'PROC_SCREW.joiningType';

// ----------------------------------------------------------------------------
// 2. The gripper-to-robot join (Artifact)-[:HAS_COMPONENT]->(Assembly).
//    Grippers carrying the EasyConnect feature (FEAT_EASY, "Magnetic
//    quick-change interface") use a tool-less reversible mount; the rest are
//    screwed to the tool flange.
// ----------------------------------------------------------------------------
MATCH (a:Artifact)-[hc:HAS_COMPONENT]->(:Assembly)
OPTIONAL MATCH (a)-[:HAS_FEATURE]->(fe:Feature {id:'FEAT_EASY'})
SET hc.connectionType = CASE WHEN fe IS NULL THEN 'screw' ELSE 'magnetic-quickchange' END,
    hc.reversible      = true,
    hc.toolless        = fe IS NOT NULL,
    hc.evidenceLevel   = CASE WHEN fe IS NULL THEN 'assumed' ELSE 'documented' END,
    hc.evidenceRef     = CASE WHEN fe IS NULL THEN 'Niryo tool-flange convention' ELSE 'FEAT_EASY' END;

// ----------------------------------------------------------------------------
// 3. Any HAS_COMPONENT edge still without a connection type: conservative
//    reversible default, flagged as assumed. (Expected: 0 with current data.)
// ----------------------------------------------------------------------------
MATCH ()-[hc:HAS_COMPONENT]->()
WHERE hc.connectionType IS NULL
SET hc.connectionType = 'screw',
    hc.reversible      = true,
    hc.evidenceLevel   = 'assumed',
    hc.evidenceRef     = 'default';

// ----------------------------------------------------------------------------
// 4. Complete the CP_DISASSEMBLY catalogue link for every Artifact
//    (currently present on 38 of 43).
// ----------------------------------------------------------------------------
MATCH (a:Artifact), (cp:CoreProperty {id:'CP_DISASSEMBLY'})
MERGE (a)-[hp:HAS_PROPERTY]->(cp)
  ON CREATE SET hp.role = 'sustainability indicator';

// ----------------------------------------------------------------------------
// 5. Compute the concrete repairability indicators per Artifact and store them
//    as literal scalar properties (same pattern as Artifact.mass_g etc.).
//      disassemblyReversibility  reversible HAS_COMPONENT edges / all edges
//      componentCount            distinct parts in the component tree
//      distinctMaterialCount     distinct materials used across those parts
//      toollessRobotInterface    EasyConnect present
//      replaceableContactElement replaceable-jaws feature present (FEAT_PRINTABLE)
//      repairabilityClass        A best .. E worst (rubric below)
// ----------------------------------------------------------------------------
MATCH (a:Artifact)
CALL {
  WITH a
  MATCH (a)-[hc:HAS_COMPONENT]->(:Assembly) RETURN hc
  UNION
  WITH a
  MATCH (a)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(:Part) RETURN hc
}
WITH a, collect(hc) AS hcs
OPTIONAL MATCH (a)-[:HAS_COMPONENT]->(:Assembly)-[:HAS_COMPONENT]->(pt:Part)
OPTIONAL MATCH (pt)-[:USES_MATERIAL]->(m:Material)
WITH a, hcs, collect(DISTINCT pt) AS parts, collect(DISTINCT m.id) AS mats
OPTIONAL MATCH (a)-[:HAS_FEATURE]->(f:Feature)
WITH a, hcs, parts, mats, collect(DISTINCT f.id) AS feats
WITH a,
     size(hcs)                                             AS total,
     size([r IN hcs WHERE r.reversible = true])            AS revd,
     size(parts)                                           AS componentCount,
     size(mats)                                            AS distinctMaterialCount,
     ('FEAT_EASY'      IN feats)                            AS toolless,
     ('FEAT_PRINTABLE' IN feats)                            AS modular
WITH a, total, componentCount, distinctMaterialCount, toolless, modular,
     CASE WHEN total = 0 THEN null ELSE round(toFloat(revd) / total, 3) END AS ratio
SET a.disassemblyReversibility  = ratio,
    a.componentCount            = componentCount,
    a.distinctMaterialCount     = distinctMaterialCount,
    a.toollessRobotInterface    = toolless,
    a.replaceableContactElement = modular,
    a.repairabilityClass =
      CASE
        WHEN ratio = 1.0 AND toolless AND modular       THEN 'A'
        WHEN ratio = 1.0 AND (toolless OR modular)      THEN 'B'
        WHEN ratio = 1.0                                THEN 'C'
        WHEN ratio >= 0.5                               THEN 'D'
        ELSE 'E'
      END,
    a.repairabilityMethod = 'v1 black-box: connection reversibility + quick-change + modular-jaw features';

// ----------------------------------------------------------------------------
// Verification
// ----------------------------------------------------------------------------
MATCH ()-[hc:HAS_COMPONENT]->()
RETURN 'HAS_COMPONENT connectionType coverage' AS check,
       count(hc) AS edges,
       count(hc.connectionType) AS typed,
       collect(DISTINCT hc.connectionType) AS types,
       collect(DISTINCT hc.evidenceLevel) AS evidence;

MATCH (a:Artifact)
RETURN 'repairabilityClass distribution' AS check,
       a.repairabilityClass AS class, count(*) AS artifacts
ORDER BY class;

MATCH (a:Artifact)
RETURN 'indicator ranges' AS check,
       min(a.disassemblyReversibility) AS minRev, max(a.disassemblyReversibility) AS maxRev,
       min(a.componentCount) AS minParts, max(a.componentCount) AS maxParts,
       sum(CASE WHEN a.toollessRobotInterface THEN 1 ELSE 0 END) AS toolless,
       sum(CASE WHEN a.replaceableContactElement THEN 1 ELSE 0 END) AS modular;

// ----------------------------------------------------------------------------
// Rollback
// ----------------------------------------------------------------------------
// MATCH ()-[hc:HAS_COMPONENT]->()
//   REMOVE hc.connectionType, hc.reversible, hc.toolless, hc.evidenceLevel, hc.evidenceRef;
// MATCH (a:Artifact)
//   REMOVE a.disassemblyReversibility, a.componentCount, a.distinctMaterialCount,
//          a.toollessRobotInterface, a.replaceableContactElement,
//          a.repairabilityClass, a.repairabilityMethod;
// (HAS_PROPERTY links added in step 4 for the 5 missing artifacts can stay.)
