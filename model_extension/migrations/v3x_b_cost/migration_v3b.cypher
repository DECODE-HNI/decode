// ============================================================================
// migration_v3b.cypher  --  Module v3.b: Cost dimension + MFCA/eco-efficiency
//                          PROTOTYPE. All monetary values are placeholders
//                          (class-default order-of-magnitude), flagged as such.
// Additive. Rollback at bottom. Date: 2026-08-27
// ============================================================================

// --- 1. Cost vocabulary carrier: CostItem + HAS_COST ----------------------
//   CostItem.category in [material, energy, system, waste-management, capital, labour]

// --- 2. Material unit cost (prototype placeholders, EUR/kg) --------------
UNWIND [
  {cls:'metal', c:4.0}, {cls:'polymer', c:6.0}, {cls:'elastomer', c:12.0}, {cls:'composite', c:40.0}
] AS d
MATCH (m:Material {materialType:d.cls})
SET m.unitCost=d.c, m.costUnit='EUR/kg', m.costBasis='prototype placeholder (class default)';

// --- 3. Flow MFCA class on the manufacturing template flows -------------
MATCH (:Process)-[:HAS_FLOW]->(f:Flow)
WHERE f.id IN ['FLOW_COMPONENT']       SET f.mfcaClass='product';
MATCH (:Process)-[:HAS_FLOW]->(f:Flow)
WHERE f.id IN ['FLOW_WASTE']           SET f.mfcaClass='material-loss';

// --- 4. Illustrative CostItems for the aluminium A1 path ---------------
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(m:Material)-[:MODELED_BY]->(:Process)
WHERE p.mass_g IS NOT NULL
WITH art, p, m, sum(p.mass_g*hc.quantity)/1000.0 AS mass_kg
MERGE (ci:CostItem {id:'COST_MAT_' + p.id})
  SET ci.category='material', ci.currency='EUR', ci.perUnit='per gripper',
      ci.amount=round(mass_kg * m.unitCost, 4), ci.basis='prototype: mass x class-default unit cost'
MERGE (p)-[:HAS_COST]->(ci);

// --- 5. Assessment product-system value (for eco-efficiency) -----------
MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASSESS_EF31_'
SET as.productSystemValue=1.0, as.productSystemValueUnit='functional unit (one jaw set)',
    as.productSystemValueBasis='prototype placeholder';

// --- verification ----------------------------------------------------
MATCH (p:Part)-[:HAS_COST]->(ci:CostItem)
RETURN ci.category AS cat, count(*) AS items, round(sum(ci.amount),4) AS totalEUR;
MATCH (m:Material) WHERE m.unitCost IS NOT NULL
RETURN m.materialType AS class, m.unitCost AS eurPerKg, count(*) AS materials ORDER BY class;

// --- rollback ------------------------------------------------------
// MATCH (p)-[r:HAS_COST]->(ci:CostItem) DELETE r; MATCH (ci:CostItem) DETACH DELETE ci;
// MATCH (m:Material) REMOVE m.unitCost, m.costUnit, m.costBasis;
// MATCH (f:Flow) REMOVE f.mfcaClass;
// MATCH (as:Assessment) REMOVE as.productSystemValue, as.productSystemValueUnit, as.productSystemValueBasis;
