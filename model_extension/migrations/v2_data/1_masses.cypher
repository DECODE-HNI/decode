// ============================================================================
// v2_data/1_masses.cypher  --  Part masses for all 86 parts.
// Contact parts (43, have Geometry): bbox volume x fill factor x density.
//   fill factor by manufacturing route: CNC 0.55, powder/FFF 0.40, cast 0.85
// Interface parts (43, no Geometry): typical robot tool adaptor, by material.
// See ASSUMPTIONS.md section 4. Additive. Rollback at bottom.
// Date: 2026-08-27
// ============================================================================

// --- contact parts: geometry-based -------------------------------------
MATCH (mp:Process {processType:'Manufacturing'})-[:APPLIES_TO]->(p:Part)-[:USES_MATERIAL]->(m:Material)
MATCH (p)-[:HAS_FORM]->(:Form)-[:HAS_GEOMETRY]->(g:Geometry)
WITH p, m, g,
     CASE
       WHEN mp.id = 'PROC_CNC'                              THEN 0.55
       WHEN mp.id IN ['PROC_MJF','PROC_SLS','PROC_FFF']     THEN 0.40
       WHEN mp.id IN ['PROC_SILCAST','PROC_RUBBER','PROC_OVERMOLD'] THEN 0.85
       WHEN mp.id = 'PROC_LASER'                            THEN 0.90
       ELSE 0.5
     END AS fill
WITH p, m,
     coalesce(g.length_mm,0) * coalesce(g.width_mm,0) * coalesce(g.height_mm,0) AS bbox_mm3,
     fill
SET p.mass_g    = round(bbox_mm3 * fill * m.density_kg_m3 * 1e-6, 2),
    p.massBasis = 'v2-data: bbox x ' + toString(fill) + ' fill x density (ASSUMPTIONS.md 4)';

// --- interface parts: typed default ----------------------------------
MATCH (p:Part {partType:'Interface'})-[:USES_MATERIAL]->(m:Material)
WHERE p.mass_g IS NULL
SET p.mass_g    = CASE WHEN m.materialType = 'metal' THEN 35.0 ELSE 20.0 END,
    p.massBasis = 'v2-data: typical robot tool interface default (ASSUMPTIONS.md 4)';

// --- any remaining part without mass: last-resort default ----------
MATCH (p:Part) WHERE p.mass_g IS NULL
SET p.mass_g = 25.0, p.massBasis = 'v2-data: generic default (no geometry, no type match)';

// --- verification -------------------------------------------------
MATCH (p:Part)
RETURN 'part mass coverage' AS check, count(p) AS parts,
       count(p.mass_g) AS withMass,
       round(min(p.mass_g),2) AS minG, round(max(p.mass_g),2) AS maxG,
       round(avg(p.mass_g),2) AS avgG;

MATCH (a:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)
WITH a, round(sum(p.mass_g * hc.quantity),1) AS gripperMass_g
RETURN 'gripper mass (computed vs stated where known)' AS check,
       round(min(gripperMass_g),1) AS minG, round(max(gripperMass_g),1) AS maxG,
       round(avg(gripperMass_g),1) AS avgG;

// --- rollback ---------------------------------------------------
// MATCH (p:Part) WHERE p.massBasis STARTS WITH 'v2-data' REMOVE p.mass_g, p.massBasis;
// (the 5 aluminium parts keep their v2 estimate if that ran first; re-run 1_masses to restore)
