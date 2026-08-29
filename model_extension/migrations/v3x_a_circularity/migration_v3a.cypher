// ============================================================================
// migration_v3a.cypher  --  Module v3.a: Circularity (simplified MCI)
// Additive. Class-based literature-order-of-magnitude defaults, all flagged.
// Rollback at bottom. Date: 2026-08-27
// ============================================================================

// --- 1. Circularity method + category -------------------------------------
// NOTE: each ';'-separated statement is independent -> always re-MATCH by id;
// never leave an AssessmentApproach as an inline MERGE node pattern.
MERGE (m:ImpactAssessmentMethod {id:'IAM_MCI'})
  SET m.name='Material Circularity Indicator (simplified)', m.methodFamily='circularity',
      m.source='Ellen MacArthur Foundation, linearised', m.version='prototype';
MERGE (ic:ImpactCategory {id:'IC_CIRCULARITY'})
  SET ic.name='Material circularity', ic.indicator='MCI', ic.unit='dimensionless';
MATCH (m:ImpactAssessmentMethod {id:'IAM_MCI'}), (ic:ImpactCategory {id:'IC_CIRCULARITY'})
MERGE (m)-[:HAS_CATEGORY]->(ic);
MATCH (m:ImpactAssessmentMethod {id:'IAM_MCI'}), (ap:AssessmentApproach {id:'APM_CIRCULARITY'})
MERGE (m)-[:APPLIES_APPROACH]->(ap);

// --- 2. End-of-life routes -------------------------------------------------
UNWIND [
  {id:'EOL_RECYCLING',       name:'Recycling',        type:'recycling'},
  {id:'EOL_REUSE',           name:'Reuse',            type:'reuse'},
  {id:'EOL_ENERGY_RECOVERY', name:'Energy recovery',  type:'incineration-ER'},
  {id:'EOL_LANDFILL',        name:'Landfill',         type:'landfill'}
] AS r
MERGE (e:EndOfLifeRoute {id:r.id}) SET e.name=r.name, e.type=r.type;

// --- 3. Material circularity parameters (class defaults) -------------------
UNWIND [
  {cls:'metal',     cr:0.90, cu:0.05, fr:0.35, rec:0.90, er:0.00, lf:0.10},
  {cls:'polymer',   cr:0.45, cu:0.00, fr:0.10, rec:0.45, er:0.40, lf:0.15},
  {cls:'elastomer', cr:0.15, cu:0.00, fr:0.00, rec:0.15, er:0.55, lf:0.30},
  {cls:'composite', cr:0.10, cu:0.00, fr:0.00, rec:0.10, er:0.50, lf:0.40}
] AS d
MATCH (mat:Material {materialType:d.cls})
SET mat.recyclingRate          = d.cr,
    mat.reusability            = d.cu,
    mat.recycledContentAssumed = d.fr,
    mat.circularityBasis       = 'class default (literature order-of-magnitude)';

// EoL route fractions per material
UNWIND [
  {cls:'metal',     routes:[{r:'EOL_RECYCLING',f:0.90},{r:'EOL_LANDFILL',f:0.10}]},
  {cls:'polymer',   routes:[{r:'EOL_RECYCLING',f:0.45},{r:'EOL_ENERGY_RECOVERY',f:0.40},{r:'EOL_LANDFILL',f:0.15}]},
  {cls:'elastomer', routes:[{r:'EOL_RECYCLING',f:0.15},{r:'EOL_ENERGY_RECOVERY',f:0.55},{r:'EOL_LANDFILL',f:0.30}]},
  {cls:'composite', routes:[{r:'EOL_RECYCLING',f:0.10},{r:'EOL_ENERGY_RECOVERY',f:0.50},{r:'EOL_LANDFILL',f:0.40}]}
] AS d
MATCH (mat:Material {materialType:d.cls})
UNWIND d.routes AS rt
MATCH (e:EndOfLifeRoute {id:rt.r})
MERGE (mat)-[hr:HAS_EOL_ROUTE]->(e) SET hr.fraction=rt.f, hr.basis='class default';

// --- 4. Artifact design lifetime (neutral default -> utility X = 1) --------
MATCH (a:Artifact)
SET a.designLifetime   = coalesce(a.designLifetime, 5.0),
    a.referenceLifetime = coalesce(a.referenceLifetime, 5.0),
    a.lifetimeBasis     = 'v3.a default: 5 y design = 5 y reference (utility neutral)';

// --- 5. Simplified linear MCI per material --------------------------------
//   V  = 1 - FR - FU           (virgin fraction; FU reused feedstock = 0)
//   W0 = 1 - CR - CU           (unrecoverable)
//   Wf = 0.1 * CR ; Wc = 0.1 * FR   (recycling process losses, Ef = 0.9)
//   W  = W0 + (Wf + Wc)/2
//   LFI = (V + W) / (2 - (Wf + Wc)/2)
//   X  = designLifetime / referenceLifetime  (= 1) ; F(X) = 0.9 / X
//   MCI = max(0, 1 - LFI * F(X))
MATCH (mat:Material)
WHERE mat.recyclingRate IS NOT NULL
WITH mat,
     (1.0 - mat.recycledContentAssumed)                          AS V,
     (1.0 - mat.recyclingRate - mat.reusability)                 AS W0,
     0.1 * mat.recyclingRate                                     AS Wf,
     0.1 * mat.recycledContentAssumed                            AS Wc
WITH mat, V, W0, Wf, Wc, (W0 + (Wf + Wc)/2.0) AS W
WITH mat, (V + W) / (2.0 - (Wf + Wc)/2.0) AS LFI
SET mat.mci = CASE WHEN 1.0 - LFI * 0.9 < 0 THEN 0.0 ELSE round(1.0 - LFI * 0.9, 4) END,
    mat.mciMethod = 'simplified linear MCI (reuse feedstock 0, utility 1, Ef 0.9)';

// --- 6. Mass-weighted artifact MCI where part masses exist ----------------
MATCH (art:Artifact)-[:HAS_COMPONENT]->(:Assembly)-[hc:HAS_COMPONENT]->(p:Part)-[:USES_MATERIAL]->(mat:Material)
WHERE p.mass_g IS NOT NULL AND mat.mci IS NOT NULL
WITH art, sum(p.mass_g * hc.quantity) AS totMass, sum(p.mass_g * hc.quantity * mat.mci) AS weighted
WITH art, round(weighted / totMass, 4) AS artMci
MATCH (efc:ImpactCategory {id:'IC_CIRCULARITY'}), (mth:ImpactAssessmentMethod {id:'IAM_MCI'}),
      (apc:AssessmentApproach {id:'APM_CIRCULARITY'})
MERGE (as:Assessment {id:'ASSESS_MCI_' + art.id})
  ON CREATE SET as.name='MCI screening - ' + art.name, as.assessmentType='circularity screening',
                as.methodology='simplified linear MCI', as.status='partial',
                as.systemBoundary='cradle-to-cradle', as.functionalUnit='one gripper',
                as.referenceFlow='one gripper', as.referenceQuantity=1.0, as.referenceUnit='gripper'
MERGE (as)-[:ASSESSES]->(art)
MERGE (as)-[:USES_METHOD]->(mth)
MERGE (as)-[:APPLIES_APPROACH]->(apc)
MERGE (ir:ImpactResult {id:'IR_MCI_' + art.id})
  ON CREATE SET ir.name='MCI - ' + art.name, ir.resultType='Material circularity', ir.unit='dimensionless'
SET ir.value=artMci, ir.provenance='LCI-calculated', ir.computedAt='2026-08-27',
    ir.status='calculated', ir.coverage='mass-weighted over parts with a mass estimate (aluminium contact parts)'
MERGE (as)-[:HAS_RESULT]->(ir)
MERGE (ir)-[:FOR_CATEGORY]->(efc);

// --- verification --------------------------------------------------------
MATCH (mat:Material) WHERE mat.mci IS NOT NULL
RETURN mat.materialType AS class, round(avg(mat.mci),4) AS avgMci, count(*) AS materials ORDER BY class;
MATCH (ir:ImpactResult {resultType:'Material circularity'})
RETURN ir.id, ir.value ORDER BY ir.value;

// --- rollback ----------------------------------------------------------
// MATCH (as:Assessment) WHERE as.id STARTS WITH 'ASSESS_MCI_' OPTIONAL MATCH (as)-[:HAS_RESULT]->(ir) DETACH DELETE as, ir;
// MATCH (mat:Material) REMOVE mat.recyclingRate, mat.reusability, mat.recycledContentAssumed, mat.circularityBasis, mat.mci, mat.mciMethod;
// MATCH (a:Artifact) REMOVE a.designLifetime, a.referenceLifetime, a.lifetimeBasis;
// MATCH (:Material)-[r:HAS_EOL_ROUTE]->() DELETE r;
// MATCH (e:EndOfLifeRoute) DETACH DELETE e;
// MATCH (m:ImpactAssessmentMethod {id:'IAM_MCI'}) DETACH DELETE m;
// MATCH (ic:ImpactCategory {id:'IC_CIRCULARITY'}) DETACH DELETE ic;
