// F-05: single source of truth for result units -- copy from ImpactCategory.unit
MATCH (ir:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory)
WHERE ic.unit IS NOT NULL AND coalesce(ir.unit,'') <> ic.unit
SET ir.unit = ic.unit;
// verify
MATCH (ir:ImpactResult)-[:FOR_CATEGORY]->(ic:ImpactCategory)
WITH ic.id AS category, collect(DISTINCT coalesce(ir.unit,'<null>')) AS units WHERE size(units) > 1
RETURN 'categories with >1 result unit (expect 0)' AS check, count(*) AS n;
