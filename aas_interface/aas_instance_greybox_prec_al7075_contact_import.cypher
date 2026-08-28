// Generiert von aas_to_neo4j_import.ps1 aus: .\aas_instance_greybox_prec_al7075_contact.json
// AAS-Shell: AAS_PART_PREC_AL7075_CONTACT_GreyBox [https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT_GREYBOX]

// ================= GREY BOX: Assessment + FragmentReference-Aufloesung =================
MERGE (ir:ImpactResult {id:'EXT_GREY_AAS_PART_PREC_AL7075_CONTACT_GreyBox'})
  SET ir.value = 9.154962801954616,
      ir.unit = 'kg CO2-eq',
      ir.lifeCyclePhase = 'A1-A3 (PROC_CNC: CNC milling)',
      ir.calculationMethod = 'EF 3.1 -- Climate change',
      ir.attachedFile = './ilcd/ilcd_export_proc_cnc.xml',
      ir.sourceAAS = 'https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT_GREYBOX',
      ir.traceabilityLevel = 'grey',
      ir.rawSubmodelJson = '{"modelType":"Submodel","id":"https://ned2-gripper.example/ids/sm/CarbonFootprintGrey_PART_PREC_AL7075_CONTACT","idShort":"CarbonFootprintGrey","kind":"Instance","submodelElements":[{"modelType":"SubmodelElementCollection","idShort":"ProductCarbonFootprint","value":[{"modelType":"Property","idShort":"PCFCO2eq","valueType":"xs:double","value":"9.154962801954616"},{"modelType":"Property","idShort":"PCFCalculationMethod","valueType":"xs:string","value":"EF 3.1 -- Climate change"},{"modelType":"Property","idShort":"PCFLifeCyclePhase","valueType":"xs:string","value":"A1-A3 (PROC_CNC: CNC milling)"},{"modelType":"Property","idShort":"PCFReferenceValueForCalculation","valueType":"xs:string","value":"1 Stueck gefertigtes Kontaktelement"}]},{"modelType":"File","idShort":"AttachedILCDDataset","contentType":"application/xml","value":"./ilcd/ilcd_export_proc_cnc.xml"},{"modelType":"AnnotatedRelationshipElement","idShort":"PCFCO2eq_Provenance_Aluminum","first":{"type":"ModelReference","keys":[{"type":"Submodel","value":"https://ned2-gripper.example/ids/sm/CarbonFootprintGrey_PART_PREC_AL7075_CONTACT"},{"type":"SubmodelElementCollection","value":"ProductCarbonFootprint"},{"type":"Property","value":"PCFCO2eq"}]},"second":{"type":"ModelReference","keys":[{"type":"Submodel","value":"https://ned2-gripper.example/ids/sm/CarbonFootprintGrey_PART_PREC_AL7075_CONTACT"},{"type":"File","value":"AttachedILCDDataset"},{"type":"FragmentReference","value":"ilcd:exchange:PROC_CNC#0"}]},"annotations":[{"modelType":"Property","idShort":"ContributionNote","valueType":"xs:string","value":"1 kg Aluminium-Ingot, Vorkette PROC_ALU_INGOT_MIX_CONSUMPTION, 9.083655796559631 kg CO2-eq"}]},{"modelType":"AnnotatedRelationshipElement","idShort":"PCFCO2eq_Provenance_Electricity","first":{"type":"ModelReference","keys":[{"type":"Submodel","value":"https://ned2-gripper.example/ids/sm/CarbonFootprintGrey_PART_PREC_AL7075_CONTACT"},{"type":"SubmodelElementCollection","value":"ProductCarbonFootprint"},{"type":"Property","value":"PCFCO2eq"}]},"second":{"type":"ModelReference","keys":[{"type":"Submodel","value":"https://ned2-gripper.example/ids/sm/CarbonFootprintGrey_PART_PREC_AL7075_CONTACT"},{"type":"File","value":"AttachedILCDDataset"},{"type":"FragmentReference","value":"ilcd:exchange:PROC_CNC#1"}]},"annotations":[{"modelType":"Property","idShort":"ContributionNote","valueType":"xs:string","value":"3.6 MJ (= 1 kWh) Oekostrom DE, Vorkette PROC_ELECTRICITY_GREEN_GRID_MIX_DE, 0.07130700539498436 kg CO2-eq"}]}]}';

// Verifikationsversuch fuer 'PCFCO2eq_Provenance_Aluminum': existiert 'PROC_CNC#0' im Graphen?
MATCH (ir:ImpactResult {id:'EXT_GREY_AAS_PART_PREC_AL7075_CONTACT_GreyBox'})
OPTIONAL MATCH (srcP:Process)-[srcHf:HAS_FLOW {exchangeId:'PROC_CNC#0'}]->(srcF:Flow)
FOREACH (_ IN CASE WHEN srcF IS NOT NULL THEN [1] ELSE [] END |
  MERGE (ir)-[v:VERIFIED_AGAINST {exchangeId:'PROC_CNC#0'}]->(srcF)
  SET v.resolvedAmount = srcHf.amount, v.resolvedUnit = srcHf.unit, v.resolvedFromProcess = srcP.id
)
WITH ir, srcF
FOREACH (_ IN CASE WHEN srcF IS NULL THEN [1] ELSE [] END |
  SET ir.unresolvedFragments = coalesce(ir.unresolvedFragments, []) + ['PROC_CNC#0']
)
;

// Verifikationsversuch fuer 'PCFCO2eq_Provenance_Electricity': existiert 'PROC_CNC#1' im Graphen?
MATCH (ir:ImpactResult {id:'EXT_GREY_AAS_PART_PREC_AL7075_CONTACT_GreyBox'})
OPTIONAL MATCH (srcP:Process)-[srcHf:HAS_FLOW {exchangeId:'PROC_CNC#1'}]->(srcF:Flow)
FOREACH (_ IN CASE WHEN srcF IS NOT NULL THEN [1] ELSE [] END |
  MERGE (ir)-[v:VERIFIED_AGAINST {exchangeId:'PROC_CNC#1'}]->(srcF)
  SET v.resolvedAmount = srcHf.amount, v.resolvedUnit = srcHf.unit, v.resolvedFromProcess = srcP.id
)
WITH ir, srcF
FOREACH (_ IN CASE WHEN srcF IS NULL THEN [1] ELSE [] END |
  SET ir.unresolvedFragments = coalesce(ir.unresolvedFragments, []) + ['PROC_CNC#1']
)
;

