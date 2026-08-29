// ============================================================================
// fix_DE02_framework_nodes.cypher  --  consistency review, Layer 4 finding DE-02
// ----------------------------------------------------------------------------
// check_decode F3: IAM_PCF and IAM_REPAIR had no MAPS_TO path to any
// ExternalFramework, because the two governing standards were not modelled as
// framework nodes. Add them and wire the mapping. Strictly additive (+2 nodes,
// +2 relationships), idempotent (MERGE on id). Mirrors the v3.i ExternalFramework
// shape (id, name, standard, domain, module).
// 2026-08-29
// ============================================================================

MERGE (pcf:ExternalFramework {id:'EF_ISO14067'})
  ON CREATE SET pcf.name     = 'ISO 14067',
                pcf.standard = 'ISO',
                pcf.domain   = 'product carbon footprint',
                pcf.module   = 'consistency-DE02';

MERGE (rep:ExternalFramework {id:'EF_EN45554'})
  ON CREATE SET rep.name     = 'EN 45554',
                rep.standard = 'CEN',
                rep.domain   = 'ability to repair, reuse and upgrade energy-related products',
                rep.module   = 'consistency-DE02';

MATCH (m:ImpactAssessmentMethod {id:'IAM_PCF'}), (fw:ExternalFramework {id:'EF_ISO14067'})
MERGE (m)-[r:MAPS_TO]->(fw)
  ON CREATE SET r.module = 'consistency-DE02',
                r.element = 'PCF screening follows the ISO 14067 quantification rules';

MATCH (m:ImpactAssessmentMethod {id:'IAM_REPAIR'}), (fw:ExternalFramework {id:'EF_EN45554'})
MERGE (m)-[r:MAPS_TO]->(fw)
  ON CREATE SET r.module = 'consistency-DE02',
                r.element = 'disassembly / repairability index scores against the EN 45554 criteria';

// --- verification ----------------------------------------------------
MATCH (m:ImpactAssessmentMethod)
WHERE NOT EXISTS { (m)-[:MAPS_TO]->(:ExternalFramework) }
  AND NOT EXISTS { (m)<-[:USES_METHOD]-(:Assessment)-[:APPLIES_APPROACH]->(:AssessmentApproach)-[:MAPS_TO]->(:ExternalFramework) }
RETURN 'IAM_* with no ExternalFramework path' AS check, collect(m.id) AS n;   // expect []

MATCH (fw:ExternalFramework) RETURN 'ExternalFramework count' AS check, count(fw) AS n;   // expect 12

// --- rollback ------------------------------------------------------
// MATCH (fw:ExternalFramework) WHERE fw.id IN ['EF_ISO14067','EF_EN45554'] DETACH DELETE fw;
