// ============================================================
// Kompletter Rebuild in EINEM Skript: Kanal A (Data-Importer-Export) +
// Sicherheits-Wartezeile + Kanal B (HAS_FLOW/CHARACTERIZES) + Schlusskontrolle.
//
// Voraussetzung: alle referenzierten CSVs liegen im import/-Ordner dieser
// DBMS (bereits der Fall). Setzt eine LEERE Datenbank voraus (siehe
// reset_to_blank.cypher) -- sonst schlagen die Constraint-Erstellungen
// oder MERGE-Aufrufe ggf. auf bereits vorhandenen, abweichenden Daten fehl.
//
// Ausfuehrung: als Ganzes in Neo4j Browser/Neo4j Desktop einfuegen und
// laufen lassen (":param" wird dort verstanden). NICHT in der Aura Query
// Console -- dort funktioniert ":param" nicht und Datei-Pfade sind ohnehin
// nicht erreichbar (siehe HANDOFF_CONTEXT_V2.md).
// ============================================================

:param {
  file_path_root: 'file:///',
  file_0: 'Product.csv',
  file_1: 'Artifact.csv',
  file_2: 'Part.csv',
  file_3: 'Assembly.csv',
  file_4: 'Feature.csv',
  file_5: 'CoreProperty.csv',
  file_6: 'Function.csv',
  file_7: 'Behavior.csv',
  file_8: 'Form.csv',
  file_9: 'Geometry.csv',
  file_10: 'Material.csv',
  file_11: 'Requirement.csv',
  file_12: 'Specification.csv',
  file_13: 'SolutionPrinciple.csv',
  file_14: 'ProcessPlan.csv',
  file_15: 'Process.csv',
  file_16: 'Scenario.csv',
  file_17: 'Assessment.csv',
  file_18: 'ImpactAssessmentMethod.csv',
  file_19: 'ImpactCategory.csv',
  file_20: 'ImpactResult.csv',
  file_21: 'DataItem.csv',
  file_22: 'DataSource.csv',
  file_23: 'DataQuality.csv',
  file_24: 'DataQualityCriterion.csv',
  file_25: 'Flow.csv',
  file_26: 'FlowProperty.csv',
  file_27: 'r_1_APPLIES_TO_Process_TO_Part.csv',
  file_28: 'r_2_ASSESSES_Assessment_TO_Artifact.csv',
  file_29: 'r_3_CHARACTERIZES_PROPERTY_Behavior_TO_CoreProperty.csv',
  file_30: 'r_4_CONTAINS_PROCESS_ProcessPlan_TO_Process.csv',
  file_31: 'r_6_EVALUATES_CRITERION_DataQuality_TO_DataQualityCriterion.csv',
  file_32: 'r_7_FOR_CATEGORY_ImpactResult_TO_ImpactCategory.csv',
  file_33: 'r_8_FROM_SOURCE_DataItem_TO_DataSource.csv',
  file_34: 'r_9_HAS_ARTIFACT_Product_TO_Artifact.csv',
  file_35: 'r_10_HAS_BEHAVIOR_Artifact_TO_Behavior.csv',
  file_36: 'r_11_HAS_CATEGORY_ImpactAssessmentMethod_TO_ImpactCategory.csv',
  file_37: 'r_12_HAS_COMPONENT_Artifact_TO_Assembly.csv',
  file_38: 'r_13_HAS_COMPONENT_Assembly_TO_Part.csv',
  file_39: 'r_14_HAS_DATA_Artifact_TO_DataItem.csv',
  file_40: 'r_16_HAS_DATA_ImpactResult_TO_DataItem.csv',
  file_41: 'r_17_HAS_DATA_Material_TO_DataItem.csv',
  file_42: 'r_18_HAS_DATA_Process_TO_DataItem.csv',
  file_43: 'r_19_HAS_DATA_QUALITY_DataItem_TO_DataQuality.csv',
  file_44: 'r_21_HAS_FEATURE_Artifact_TO_Feature.csv',
  file_45: 'r_22_HAS_FLOW_PROPERTY_Flow_TO_FlowProperty.csv',
  file_46: 'r_23_HAS_FORM_Part_TO_Form.csv',
  file_47: 'r_24_HAS_GEOMETRY_Form_TO_Geometry.csv',
  file_48: 'r_25_HAS_PROCESS_PLAN_Artifact_TO_ProcessPlan.csv',
  file_49: 'r_26_HAS_PROPERTY_Artifact_TO_CoreProperty.csv',
  file_50: 'r_27_HAS_RESULT_Assessment_TO_ImpactResult.csv',
  file_51: 'r_28_HAS_SCENARIO_ProcessPlan_TO_Scenario.csv',
  file_52: 'r_29_REALIZES_FUNCTION_SolutionPrinciple_TO_Function.csv',
  file_53: 'r_30_REALIZES_PRINCIPLE_Artifact_TO_SolutionPrinciple.csv',
  file_54: 'r_32_SATISFIES_REQUIREMENT_Artifact_TO_Requirement.csv',
  file_55: 'r_33_SPECIFIED_BY_Requirement_TO_Specification.csv',
  file_56: 'r_34_SUITABLE_FOR_Artifact_TO_Scenario.csv',
  file_57: 'r_35_USES_MATERIAL_Part_TO_Material.csv',
  file_58: 'r_36_USES_METHOD_Assessment_TO_ImpactAssessmentMethod.csv',
  file_59: 'r_39_APPLIES_TO_Process_TO_Material.csv',
  file_60: 'r_5_DERIVED_FROM_ImpactResult_TO_Flow.csv',
  file_61: 'r_15b_HAS_DATA_Flow_TO_DataItem.csv',
  file_62: 'r_40_HAS_FLOW_Process_TO_Flow.csv',
  file_63: 'r_41_CHARACTERIZES_Flow_TO_ImpactCategory.csv'
};

// ============================================================
// KANAL A -- CONSTRAINTS (aus dem Data-Importer-Export)
// ============================================================
CREATE CONSTRAINT `Product_id_unique` IF NOT EXISTS FOR (n: `Product`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Artifact_id_unique` IF NOT EXISTS FOR (n: `Artifact`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Part_id_unique` IF NOT EXISTS FOR (n: `Part`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Assembly_id_unique` IF NOT EXISTS FOR (n: `Assembly`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Feature_id_unique` IF NOT EXISTS FOR (n: `Feature`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `CoreProperty_id_unique` IF NOT EXISTS FOR (n: `CoreProperty`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Function_id_unique` IF NOT EXISTS FOR (n: `Function`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Behavior_id_unique` IF NOT EXISTS FOR (n: `Behavior`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Form_id_unique` IF NOT EXISTS FOR (n: `Form`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Geometry_id_unique` IF NOT EXISTS FOR (n: `Geometry`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Material_id_unique` IF NOT EXISTS FOR (n: `Material`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Requirement_id_unique` IF NOT EXISTS FOR (n: `Requirement`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Specification_id_unique` IF NOT EXISTS FOR (n: `Specification`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `SolutionPrinciple_id_unique` IF NOT EXISTS FOR (n: `SolutionPrinciple`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `ProcessPlan_id_unique` IF NOT EXISTS FOR (n: `ProcessPlan`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Process_id_unique` IF NOT EXISTS FOR (n: `Process`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Scenario_id_unique` IF NOT EXISTS FOR (n: `Scenario`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Assessment_id_unique` IF NOT EXISTS FOR (n: `Assessment`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `ImpactAssessmentMethod_id_unique` IF NOT EXISTS FOR (n: `ImpactAssessmentMethod`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `ImpactCategory_id_unique` IF NOT EXISTS FOR (n: `ImpactCategory`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `ImpactResult_id_unique` IF NOT EXISTS FOR (n: `ImpactResult`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `DataItem_id_unique` IF NOT EXISTS FOR (n: `DataItem`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `DataSource_id_unique` IF NOT EXISTS FOR (n: `DataSource`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `DataQuality_id_unique` IF NOT EXISTS FOR (n: `DataQuality`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `DataQualityCriterion_id_unique` IF NOT EXISTS FOR (n: `DataQualityCriterion`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `Flow_id_unique` IF NOT EXISTS FOR (n: `Flow`) REQUIRE (n.`id`) IS UNIQUE;
CREATE CONSTRAINT `FlowProperty_id_unique` IF NOT EXISTS FOR (n: `FlowProperty`) REQUIRE (n.`id`) IS UNIQUE;

// Kanal-B-Constraints hier schon mit anlegen, damit EIN gemeinsamer
// awaitIndexes()-Aufruf fuer alles wartet (Sicherheitsmassnahme gegen Bug #8).
CREATE CONSTRAINT has_flow_exchangeid_unique IF NOT EXISTS
FOR ()-[r:HAS_FLOW]-() REQUIRE r.exchangeId IS UNIQUE;
CREATE CONSTRAINT characterizes_id_unique IF NOT EXISTS
FOR ()-[r:CHARACTERIZES]-() REQUIRE r.characterizesId IS UNIQUE;

// --- Sicherheitsmassnahme gegen Bug #8 (siehe HANDOFF_CONTEXT_V2.md) ---
CALL db.awaitIndexes();

:param {
  idsToSkip: [],
  bracketPairs: [["{","}"],["<",">"],["[","]"],["(",")"]]
};

// ============================================================
// KANAL A -- NODE LOAD
// ============================================================
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_0) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Product` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`productNumber` = row.`productNumber`,
      n.`manufacturer` = row.`manufacturer`, n.`version` = row.`version`, n.`status` = row.`status`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_1) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Artifact` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`artifactType` = row.`artifactType`,
      n.`variantFamily` = row.`variantFamily`, n.`manufacturer` = row.`manufacturer`,
      n.`mass_g` = toFloat(trim(row.`mass_g`)), n.`opening_mm` = toFloat(trim(row.`opening_mm`)),
      n.`tcp_mm` = toFloat(trim(row.`tcp_mm`)), n.`evidenceLevel` = row.`evidenceLevel`,
      n.`validationRequired` = toLower(trim(row.`validationRequired`)) IN ['1','true','yes'],
      n.`status` = row.`status`, n.`description` = row.`description`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_2) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Part` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`partType` = row.`partType`,
      n.`variant` = row.`variant`, n.`mass_g` = toFloat(trim(row.`mass_g`)), n.`status` = row.`status`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_3) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Assembly` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`assemblyType` = row.`assemblyType`,
      n.`variant` = row.`variant`, n.`status` = row.`status`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_4) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Feature` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`featureType` = row.`featureType`, n.`description` = row.`description`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_5) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `CoreProperty` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`propertyType` = row.`propertyType`,
      n.`valueNumber` = toFloat(trim(row.`valueNumber`)), n.`valueText` = row.`valueText`,
      n.`unit` = row.`unit`, n.`status` = row.`status`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_6) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Function` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`functionType` = row.`functionType`,
      n.`input` = row.`input`, n.`output` = row.`output`, n.`constraintText` = row.`constraintText`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_7) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Behavior` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`behaviorType` = row.`behaviorType`,
      n.`state` = row.`state`, n.`description` = row.`description`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_8) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Form` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`formType` = row.`formType`, n.`description` = row.`description`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_9) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Geometry` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`geometryType` = row.`geometryType`,
      n.`length_mm` = toFloat(trim(row.`length_mm`)), n.`width_mm` = toFloat(trim(row.`width_mm`)),
      n.`height_mm` = toFloat(trim(row.`height_mm`)), n.`diameter_mm` = toFloat(trim(row.`diameter_mm`)),
      n.`openingAngle_deg` = toFloat(trim(row.`openingAngle_deg`))
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_10) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Material` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`materialType` = row.`materialType`,
      n.`density_kg_m3` = toFloat(trim(row.`density_kg_m3`)), n.`recycledContent_pct` = toFloat(trim(row.`recycledContent_pct`)),
      n.`status` = row.`status`, n.`description` = row.`description`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_11) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Requirement` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`requirementType` = row.`requirementType`,
      n.`statement` = row.`statement`, n.`priority` = row.`priority`, n.`status` = row.`status`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_12) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Specification` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`valueNumber` = toFloat(trim(row.`valueNumber`)),
      n.`valueText` = row.`valueText`, n.`unit` = row.`unit`,
      n.`toleranceMin` = toFloat(trim(row.`toleranceMin`)), n.`toleranceMax` = toFloat(trim(row.`toleranceMax`))
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_13) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `SolutionPrinciple` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`solutionType` = row.`solutionType`,
      n.`physicalPrinciple` = row.`physicalPrinciple`, n.`status` = row.`status`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_14) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `ProcessPlan` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`planType` = row.`planType`,
      n.`variant` = row.`variant`, n.`status` = row.`status`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_15) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Process` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`processType` = row.`processType`,
      n.`technology` = row.`technology`, n.`geographicalLocation` = row.`geographicalLocation`,
      n.`dataAcquisition` = row.`dataAcquisition`, n.`status` = row.`status`,
      n.`source` = row.`source`, n.`sourceDatabase` = row.`sourceDatabase`, n.`referenceYear` = row.`referenceYear`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_16) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Scenario` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`scenarioType` = row.`scenarioType`,
      n.`objectGeometry` = row.`objectGeometry`, n.`objectMaterial` = row.`objectMaterial`,
      n.`fragility` = row.`fragility`, n.`porosity` = row.`porosity`,
      n.`ferromagnetic` = toLower(trim(row.`ferromagnetic`)) IN ['1','true','yes'], n.`description` = row.`description`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_17) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Assessment` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`assessmentType` = row.`assessmentType`,
      n.`developmentPhase` = row.`developmentPhase`, n.`methodology` = row.`methodology`,
      n.`status` = row.`status`, n.`calculatedAt` = row.`calculatedAt`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_18) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `ImpactAssessmentMethod` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`methodFamily` = row.`methodFamily`,
      n.`version` = row.`version`, n.`source` = row.`source`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_19) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `ImpactCategory` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`indicator` = row.`indicator`, n.`unit` = row.`unit`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_20) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `ImpactResult` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`resultType` = row.`resultType`,
      n.`quantity` = toFloat(trim(row.`quantity`)), n.`unit` = row.`unit`, n.`status` = row.`status`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_21) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `DataItem` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`propertyName` = row.`propertyName`,
      n.`valueText` = row.`valueText`, n.`valueNumber` = toFloat(trim(row.`valueNumber`)),
      n.`unit` = row.`unit`, n.`maturity` = row.`maturity`, n.`validFrom` = row.`validFrom`, n.`note` = row.`note`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_22) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `DataSource` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`sourceType` = row.`sourceType`,
      n.`provider` = row.`provider`, n.`uri` = row.`uri`, n.`accessedAt` = row.`accessedAt`, n.`evidenceLevel` = row.`evidenceLevel`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_23) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `DataQuality` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`method` = row.`method`,
      n.`overallScore` = toFloat(trim(row.`overallScore`)), n.`scale` = row.`scale`, n.`comment` = row.`comment`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_24) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `DataQualityCriterion` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`category` = row.`category`,
      n.`definition` = row.`definition`, n.`weight` = toFloat(trim(row.`weight`)), n.`direction` = row.`direction`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_25) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `Flow` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`flowType` = row.`flowType`, n.`category` = row.`category`,
      n.`referenceUnit` = row.`referenceUnit`, n.`casNumber` = row.`casNumber`, n.`status` = row.`status`,
      n.`description` = row.`description`, n.`source` = row.`source`, n.`sourceDatabase` = row.`sourceDatabase`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_26) AS row
WITH row WHERE NOT row.`id` IN $idsToSkip AND NOT row.`id` IS NULL
CALL (row) {
  MERGE (n: `FlowProperty` { `id`: row.`id` })
  SET n.`id` = row.`id`, n.`name` = row.`name`, n.`propertyType` = row.`propertyType`,
      n.`referenceUnit` = row.`referenceUnit`, n.`description` = row.`description`
} IN TRANSACTIONS OF 10000 ROWS;

// ============================================================
// KANAL A -- RELATIONSHIP LOAD (alles ausser HAS_FLOW/CHARACTERIZES)
// ============================================================
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_27) AS row
WITH row CALL (row) {
  MATCH (source: `Process` { `id`: row.`from_id` }) MATCH (target: `Part` { `id`: row.`to_id` })
  MERGE (source)-[r: `APPLIES_TO`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_28) AS row
WITH row CALL (row) {
  MATCH (source: `Assessment` { `id`: row.`from_id` }) MATCH (target: `Artifact` { `id`: row.`to_id` })
  MERGE (source)-[r: `ASSESSES`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_29) AS row
WITH row CALL (row) {
  MATCH (source: `Behavior` { `id`: row.`from_id` }) MATCH (target: `CoreProperty` { `id`: row.`to_id` })
  MERGE (source)-[r: `CHARACTERIZES_PROPERTY`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_30) AS row
WITH row CALL (row) {
  MATCH (source: `ProcessPlan` { `id`: row.`from_id` }) MATCH (target: `Process` { `id`: row.`to_id` })
  MERGE (source)-[r: `CONTAINS_PROCESS`]->(target)
  SET r.`sequence` = toInteger(trim(row.`sequence`)), r.`share` = toFloat(trim(row.`share`))
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_31) AS row
WITH row CALL (row) {
  MATCH (source: `DataQuality` { `id`: row.`from_id` }) MATCH (target: `DataQualityCriterion` { `id`: row.`to_id` })
  MERGE (source)-[r: `EVALUATES_CRITERION`]->(target)
  SET r.`score` = toFloat(trim(row.`score`)), r.`rating` = row.`rating`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_32) AS row
WITH row CALL (row) {
  MATCH (source: `ImpactResult` { `id`: row.`from_id` }) MATCH (target: `ImpactCategory` { `id`: row.`to_id` })
  MERGE (source)-[r: `FOR_CATEGORY`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_33) AS row
WITH row CALL (row) {
  MATCH (source: `DataItem` { `id`: row.`from_id` }) MATCH (target: `DataSource` { `id`: row.`to_id` })
  MERGE (source)-[r: `FROM_SOURCE`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_34) AS row
WITH row CALL (row) {
  MATCH (source: `Product` { `id`: row.`from_id` }) MATCH (target: `Artifact` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_ARTIFACT`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_35) AS row
WITH row CALL (row) {
  MATCH (source: `Artifact` { `id`: row.`from_id` }) MATCH (target: `Behavior` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_BEHAVIOR`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_36) AS row
WITH row CALL (row) {
  MATCH (source: `ImpactAssessmentMethod` { `id`: row.`from_id` }) MATCH (target: `ImpactCategory` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_CATEGORY`]->(target) SET r.`order` = toInteger(trim(row.`order`))
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_37) AS row
WITH row CALL (row) {
  MATCH (source: `Artifact` { `id`: row.`from_id` }) MATCH (target: `Assembly` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_COMPONENT`]->(target)
  SET r.`quantity` = toFloat(trim(row.`quantity`)), r.`unit` = row.`unit`, r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_38) AS row
WITH row CALL (row) {
  MATCH (source: `Assembly` { `id`: row.`from_id` }) MATCH (target: `Part` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_COMPONENT`]->(target)
  SET r.`quantity` = toFloat(trim(row.`quantity`)), r.`unit` = row.`unit`, r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_39) AS row
WITH row CALL (row) {
  MATCH (source: `Artifact` { `id`: row.`from_id` }) MATCH (target: `DataItem` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_DATA`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_40) AS row
WITH row CALL (row) {
  MATCH (source: `ImpactResult` { `id`: row.`from_id` }) MATCH (target: `DataItem` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_DATA`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_41) AS row
WITH row CALL (row) {
  MATCH (source: `Material` { `id`: row.`from_id` }) MATCH (target: `DataItem` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_DATA`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_42) AS row
WITH row CALL (row) {
  MATCH (source: `Process` { `id`: row.`from_id` }) MATCH (target: `DataItem` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_DATA`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_43) AS row
WITH row CALL (row) {
  MATCH (source: `DataItem` { `id`: row.`from_id` }) MATCH (target: `DataQuality` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_DATA_QUALITY`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_44) AS row
WITH row CALL (row) {
  MATCH (source: `Artifact` { `id`: row.`from_id` }) MATCH (target: `Feature` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_FEATURE`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_45) AS row
WITH row CALL (row) {
  MATCH (source: `Flow` { `id`: row.`from_id` }) MATCH (target: `FlowProperty` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_FLOW_PROPERTY`]->(target)
  SET r.`referenceProperty` = toLower(trim(row.`referenceProperty`)) IN ['1','true','yes']
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_46) AS row
WITH row CALL (row) {
  MATCH (source: `Part` { `id`: row.`from_id` }) MATCH (target: `Form` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_FORM`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_47) AS row
WITH row CALL (row) {
  MATCH (source: `Form` { `id`: row.`from_id` }) MATCH (target: `Geometry` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_GEOMETRY`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_48) AS row
WITH row CALL (row) {
  MATCH (source: `Artifact` { `id`: row.`from_id` }) MATCH (target: `ProcessPlan` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_PROCESS_PLAN`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_49) AS row
WITH row CALL (row) {
  MATCH (source: `Artifact` { `id`: row.`from_id` }) MATCH (target: `CoreProperty` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_PROPERTY`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_50) AS row
WITH row CALL (row) {
  MATCH (source: `Assessment` { `id`: row.`from_id` }) MATCH (target: `ImpactResult` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_RESULT`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_51) AS row
WITH row CALL (row) {
  MATCH (source: `ProcessPlan` { `id`: row.`from_id` }) MATCH (target: `Scenario` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_SCENARIO`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_52) AS row
WITH row CALL (row) {
  MATCH (source: `SolutionPrinciple` { `id`: row.`from_id` }) MATCH (target: `Function` { `id`: row.`to_id` })
  MERGE (source)-[r: `REALIZES_FUNCTION`]->(target) SET r.`degreeOfFulfilment` = toFloat(trim(row.`degreeOfFulfilment`))
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_53) AS row
WITH row CALL (row) {
  MATCH (source: `Artifact` { `id`: row.`from_id` }) MATCH (target: `SolutionPrinciple` { `id`: row.`to_id` })
  MERGE (source)-[r: `REALIZES_PRINCIPLE`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_54) AS row
WITH row CALL (row) {
  MATCH (source: `Artifact` { `id`: row.`from_id` }) MATCH (target: `Requirement` { `id`: row.`to_id` })
  MERGE (source)-[r: `SATISFIES_REQUIREMENT`]->(target) SET r.`verificationStatus` = row.`verificationStatus`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_55) AS row
WITH row CALL (row) {
  MATCH (source: `Requirement` { `id`: row.`from_id` }) MATCH (target: `Specification` { `id`: row.`to_id` })
  MERGE (source)-[r: `SPECIFIED_BY`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_56) AS row
WITH row CALL (row) {
  MATCH (source: `Artifact` { `id`: row.`from_id` }) MATCH (target: `Scenario` { `id`: row.`to_id` })
  MERGE (source)-[r: `SUITABLE_FOR`]->(target)
  SET r.`suitability` = row.`suitability`, r.`rationale` = row.`rationale`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_57) AS row
WITH row CALL (row) {
  MATCH (source: `Part` { `id`: row.`from_id` }) MATCH (target: `Material` { `id`: row.`to_id` })
  MERGE (source)-[r: `USES_MATERIAL`]->(target)
  SET r.`mass_g` = toFloat(trim(row.`mass_g`)), r.`fraction` = toFloat(trim(row.`fraction`)), r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_58) AS row
WITH row CALL (row) {
  MATCH (source: `Assessment` { `id`: row.`from_id` }) MATCH (target: `ImpactAssessmentMethod` { `id`: row.`to_id` })
  MERGE (source)-[r: `USES_METHOD`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_59) AS row
WITH row CALL (row) {
  MATCH (source: `Process` { `id`: row.`from_id` }) MATCH (target: `Material` { `id`: row.`to_id` })
  MERGE (source)-[r: `APPLIES_TO`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_60) AS row
WITH row CALL (row) {
  MATCH (source: `ImpactResult` { `id`: row.`from_id` }) MATCH (target: `Flow` { `id`: row.`to_id` })
  MERGE (source)-[r: `DERIVED_FROM`]->(target)
  SET r.`exchangeId` = row.`exchangeId`, r.`contribution` = toFloat(trim(row.`contribution`))
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_61) AS row
WITH row CALL (row) {
  MATCH (source: `Flow` { `id`: row.`from_id` }) MATCH (target: `DataItem` { `id`: row.`to_id` })
  MERGE (source)-[r: `HAS_DATA`]->(target) SET r.`role` = row.`role`
} IN TRANSACTIONS OF 10000 ROWS;

// ============================================================
// KANAL B -- HAS_FLOW / CHARACTERIZES (nicht Teil des Data-Importer-Schemas,
// siehe HANDOFF_CONTEXT_V2.md Abschnitt 4 -- Parallel-Kanten brauchen einen
// zusammengesetzten MERGE-Schluessel, den der Data Importer nicht kann)
// ============================================================
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_62) AS row
CALL (row) {
  MATCH (p:Process {id: row.from_id})
  MATCH (f:Flow {id: row.to_id})
  MERGE (p)-[r:HAS_FLOW {exchangeId: row.exchangeId}]->(f)
  SET r.amount = toFloat(row.amount),
      r.unit = row.unit,
      r.direction = row.direction,
      r.location = row.location,
      r.quantitativeReference = (row.quantitativeReference = 'true'),
      r.ratioToReference = toFloat(row.ratioToReference),
      r.dataMaturity = row.dataMaturity,
      r.referenceYear = row.referenceYear,
      r.uncertainty = CASE WHEN row.uncertainty = '' THEN null ELSE toFloat(row.uncertainty) END,
      r.comment = row.comment
} IN TRANSACTIONS OF 500 ROWS;

// location als null->'' normieren (LOAD CSV liefert leere Felder als null,
// MERGE-Pattern erlaubt kein null -- siehe Memory-Datei Punkt 4)
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_63) AS row
CALL (row) {
  MATCH (f:Flow {id: row.from_id})
  MATCH (c:ImpactCategory {id: row.to_id})
  WITH f, c, row, coalesce(row.location, '') AS loc
  MERGE (f)-[r:CHARACTERIZES {location: loc}]->(c)
  SET r.factor = toFloat(row.factor),
      r.characterizesId = f.id + '|' + c.id + '|' + loc
} IN TRANSACTIONS OF 500 ROWS;

// ============================================================
// SCHLUSSKONTROLLE
// ============================================================
MATCH ()-[r]->() RETURN type(r) AS relType, count(r) AS n ORDER BY relType;
