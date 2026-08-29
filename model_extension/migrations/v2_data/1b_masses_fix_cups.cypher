// v2_data/1b_masses_fix_cups.cypher -- mass for cup/cylinder geometry
// (diameter + height, no length/width -> bbox formula gave 0).
// Volume ~ pi/4 * d^2 * h ; cups are hollow -> fill factor 0.30.
MATCH (p:Part)-[:USES_MATERIAL]->(m:Material)
MATCH (p)-[:HAS_FORM]->(:Form)-[:HAS_GEOMETRY]->(g:Geometry)
WHERE (p.mass_g IS NULL OR p.mass_g = 0.0) AND g.diameter_mm IS NOT NULL AND g.height_mm IS NOT NULL
WITH p, m, (3.14159/4.0) * g.diameter_mm * g.diameter_mm * g.height_mm AS vol_mm3
SET p.mass_g    = round(vol_mm3 * 0.30 * m.density_kg_m3 * 1e-6, 2),
    p.massBasis = 'v2-data: pi/4 d^2 h x 0.30 fill (hollow cup) x density';
MATCH (p:Part) WHERE p.mass_g = 0.0 OR p.mass_g IS NULL
RETURN 'remaining zero/null part mass (must be 0 rows)' AS check, count(p) AS n, collect(p.id) AS ids;
