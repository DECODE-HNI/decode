UNWIND [
 {old:'IC_EF_CLIMATE_BIOGENIC', canon:'IC_EF_CLIMATE_CHANGE_BIOGENIC'},
 {old:'IC_EF_CLIMATE_FOSSIL', canon:'IC_EF_CLIMATE_CHANGE_FOSSIL'},
 {old:'IC_EF_CLIMATE_LULUC', canon:'IC_EF_CLIMATE_CHANGE_LAND_USE_AND_LAND_USE_CHANGE'},
 {old:'IC_EF_RESOURCE_FOSSILS', canon:'IC_EF_EF_RESOURCE_USE_FOSSILS'},
 {old:'IC_EF_RESOURCE_MINERALS', canon:'IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS'},
 {old:'IC_EF_EUTROPH_FRESHWATER', canon:'IC_EF_EF_EUTROPHICATION_FRESHWATER'},
 {old:'IC_EF_EUTROPH_TERRESTRIAL', canon:'IC_EF_EF_EUTROPHICATION_TERRESTRIAL'},
 {old:'IC_EF_HUMANTOX_CANCER', canon:'IC_EF_HUMAN_TOXICITY_CANCER'},
 {old:'IC_EF_EF_HUMAN_TOXICITY_CANCER', canon:'IC_EF_HUMAN_TOXICITY_CANCER'},
 {old:'IC_EF_HUMANTOX_NONCANCER', canon:'IC_EF_HUMAN_TOXICITY_NON_CANCER'},
 {old:'IC_EF_EF_HUMAN_TOXICITY_NON_CANCER', canon:'IC_EF_HUMAN_TOXICITY_NON_CANCER'},
 {old:'IC_EF_ECOTOX_FRESHWATER', canon:'IC_EF_ECOTOXICITY_FRESHWATER'},
 {old:'IC_EF_EF_ECOTOXICITY_FRESHWATER', canon:'IC_EF_ECOTOXICITY_FRESHWATER'},
 {old:'IC_EF_IONISING_RADIATION', canon:'IC_EF_EF_IONISING_RADIATION_HUMAN_HEALTH'}
] AS pair
MATCH (old:ImpactCategory {id: pair.old})
MATCH (canon:ImpactCategory {id: pair.canon})
OPTIONAL MATCH (m:ImpactAssessmentMethod)-[r:HAS_CATEGORY]->(old)
WITH old, canon, m, r WHERE r IS NOT NULL
MERGE (m)-[r2:HAS_CATEGORY]->(canon)
ON CREATE SET r2.order = r.order
DELETE r;

UNWIND ['IC_EF_CLIMATE_BIOGENIC','IC_EF_CLIMATE_FOSSIL','IC_EF_CLIMATE_LULUC','IC_EF_RESOURCE_FOSSILS','IC_EF_RESOURCE_MINERALS','IC_EF_EUTROPH_FRESHWATER','IC_EF_EUTROPH_TERRESTRIAL','IC_EF_HUMANTOX_CANCER','IC_EF_EF_HUMAN_TOXICITY_CANCER','IC_EF_HUMANTOX_NONCANCER','IC_EF_EF_HUMAN_TOXICITY_NON_CANCER','IC_EF_ECOTOX_FRESHWATER','IC_EF_EF_ECOTOXICITY_FRESHWATER','IC_EF_IONISING_RADIATION'] AS oldId
MATCH (old:ImpactCategory {id: oldId})
DETACH DELETE old;

MATCH (m:Material {id:'MAT_ALU_GENERIC'}) SET m.name = 'Aluminium (generic, ILCD/IDEMAT)', m.materialType = 'metal', m.density_kg_m3 = 2700.0, m.recycledContent_pct = NULL, m.status = 'reference', m.description = 'Generic aluminium background data (extrusion/sheet routes); not bound to a specific alloy (see MAT_AL6061/MAT_AL7075 for engineering-candidate alloys).';
MATCH (m:Material {id:'MAT_STEEL_GENERIC'}) SET m.name = 'Steel (generic, ILCD/IDEMAT)', m.materialType = 'metal', m.density_kg_m3 = 7850.0, m.recycledContent_pct = NULL, m.status = 'reference', m.description = 'Generic steel background data across multiple production routes (blast furnace/EAF, hot rolled, galvanized, tinplate); not bound to a specific grade.';
MATCH (m:Material {id:'MAT_COPPER_GENERIC'}) SET m.name = 'Copper (generic, ILCD/IDEMAT)', m.materialType = 'metal', m.density_kg_m3 = 8960.0, m.recycledContent_pct = NULL, m.status = 'reference', m.description = 'Generic copper background data (wire/sheet/tube, market and consumption mixes).';
MATCH (m:Material {id:'MAT_LEAD_GENERIC'}) SET m.name = 'Lead (generic, ILCD/IDEMAT)', m.materialType = 'metal', m.density_kg_m3 = 11340.0, m.recycledContent_pct = NULL, m.status = 'reference', m.description = 'Generic lead background data (primary/secondary production mixes).';
MATCH (m:Material {id:'MAT_ZINC_GENERIC'}) SET m.name = 'Zinc (generic, ILCD/IDEMAT)', m.materialType = 'metal', m.density_kg_m3 = 7140.0, m.recycledContent_pct = NULL, m.status = 'reference', m.description = 'Generic special high grade zinc primary production background data.';

MATCH (ic:ImpactCategory {id:'IC_EF_OZONE_DEPLETION'}) SET ic.indicator = 'Ozone Depletion Potential (ODP)';
