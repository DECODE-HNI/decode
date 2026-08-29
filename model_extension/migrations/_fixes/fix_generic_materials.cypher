// Pre-existing data-quality fix (not v1-specific).
// The 5 generic reference materials came in with a CSV column shift:
//   - density value landed in recycledContent_pct
//   - density_kg_m3 left NULL
//   - name truncated at the comma ("Aluminium (generic")
//   - materialType holds the fragment after the comma (" ILCD/IDEMAT)")
// These nodes are only referenced from the ILCD Process layer (APPLIES_TO),
// never from a Part (USES_MATERIAL) -> they belong to the v2/grey-box layer.
// Recycled content is genuinely unknown -> set to NULL, do not guess.

UNWIND [
  {id:'MAT_ALU_GENERIC',    name:'Aluminium (generic, ILCD/IDEMAT)', density:2700.0},
  {id:'MAT_STEEL_GENERIC',   name:'Steel (generic, ILCD/IDEMAT)',     density:7850.0},
  {id:'MAT_COPPER_GENERIC', name:'Copper (generic, ILCD/IDEMAT)',    density:8960.0},
  {id:'MAT_LEAD_GENERIC',    name:'Lead (generic, ILCD/IDEMAT)',      density:11340.0},
  {id:'MAT_ZINC_GENERIC',    name:'Zinc (generic, ILCD/IDEMAT)',      density:7140.0}
] AS row
MATCH (m:Material {id: row.id})
SET m.name             = row.name,
    m.materialType     = 'metal',
    m.density_kg_m3    = row.density,
    m.recycledContent_pct = NULL,
    m.dataQualityNote  = 'fixed 2026-08-27: CSV column shift corrected (density was stored in recycledContent_pct; name truncated at comma)'
RETURN m.id, m.name, m.materialType, m.density_kg_m3, m.recycledContent_pct;
