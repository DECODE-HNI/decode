// Generiert von aas_to_neo4j_import.ps1 aus: .\aas_instance_whitebox_prec_al7075_contact.json
// AAS-Shell: AAS_PART_PREC_AL7075_CONTACT [https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT]

// ================= WHITE BOX: Process/Flow/HAS_FLOW =================
MERGE (p:Process {id:'EXT_PROC_CNC'})
  SET p.name = 'CNC milling',
      p.sourceProcessId = 'PROC_CNC',
      p.sourceAAS = 'https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT',
      p.traceabilityLevel = 'white';
MERGE (f:Flow {id:'ae206e6f-e4f5-4dbf-8de7-42576f6da892'})
  ON CREATE SET f.name = 'Aluminium ingot';
MATCH (p:Process {id:'EXT_PROC_CNC'}), (f:Flow {id:'ae206e6f-e4f5-4dbf-8de7-42576f6da892'})
MERGE (p)-[r:HAS_FLOW {exchangeId:'EXT_PROC_CNC#0'}]->(f)
  SET r.sourceExchangeId = 'PROC_CNC#0',
      r.direction = 'input',
      r.amount = 1.0,
      r.unit = 'kg';

MERGE (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
  ON CREATE SET f.name = 'Electricity';
MATCH (p:Process {id:'EXT_PROC_CNC'}), (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
MERGE (p)-[r:HAS_FLOW {exchangeId:'EXT_PROC_CNC#1'}]->(f)
  SET r.sourceExchangeId = 'PROC_CNC#1',
      r.direction = 'input',
      r.amount = 3.6,
      r.unit = 'MJ';

MERGE (f:Flow {id:'FLOW_COMPONENT'})
  ON CREATE SET f.name = 'Finished gripper component';
MATCH (p:Process {id:'EXT_PROC_CNC'}), (f:Flow {id:'FLOW_COMPONENT'})
MERGE (p)-[r:HAS_FLOW {exchangeId:'EXT_PROC_CNC#2'}]->(f)
  SET r.sourceExchangeId = 'PROC_CNC#2',
      r.direction = 'output',
      r.amount = 1.0,
      r.unit = 'pcs';

MERGE (f:Flow {id:'FLOW_WASTE'})
  ON CREATE SET f.name = 'Manufacturing waste';
MATCH (p:Process {id:'EXT_PROC_CNC'}), (f:Flow {id:'FLOW_WASTE'})
MERGE (p)-[r:HAS_FLOW {exchangeId:'EXT_PROC_CNC#3'}]->(f)
  SET r.sourceExchangeId = 'PROC_CNC#3',
      r.direction = 'output',
      r.amount = 0.0,
      r.unit = 'kg';

MERGE (p:Process {id:'EXT_PROC_SCREW'})
  SET p.name = 'Screw fastening',
      p.sourceProcessId = 'PROC_SCREW',
      p.sourceAAS = 'https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT',
      p.traceabilityLevel = 'white';
MERGE (f:Flow {id:'0d925357-e1c9-48c1-a5c7-caaae8185108'})
  ON CREATE SET f.name = 'Screw M6 (hardened; zinc coated)';
MATCH (p:Process {id:'EXT_PROC_SCREW'}), (f:Flow {id:'0d925357-e1c9-48c1-a5c7-caaae8185108'})
MERGE (p)-[r:HAS_FLOW {exchangeId:'EXT_PROC_SCREW#0'}]->(f)
  SET r.sourceExchangeId = 'PROC_SCREW#0',
      r.direction = 'input',
      r.amount = 0.006,
      r.unit = 'kg';

MERGE (p:Process {id:'EXT_PROC_FINISH'})
  SET p.name = 'Deburring / finishing',
      p.sourceProcessId = 'PROC_FINISH',
      p.sourceAAS = 'https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT',
      p.traceabilityLevel = 'white';
MERGE (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
  ON CREATE SET f.name = 'Electricity';
MATCH (p:Process {id:'EXT_PROC_FINISH'}), (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
MERGE (p)-[r:HAS_FLOW {exchangeId:'EXT_PROC_FINISH#0'}]->(f)
  SET r.sourceExchangeId = 'PROC_FINISH#0',
      r.direction = 'input',
      r.amount = 0.18,
      r.unit = 'MJ';

MERGE (p:Process {id:'EXT_PROC_REPAIR'})
  SET p.name = 'Replace jaw / pad',
      p.sourceProcessId = 'PROC_REPAIR',
      p.sourceAAS = 'https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT',
      p.traceabilityLevel = 'white';
MERGE (f:Flow {id:'ae206e6f-e4f5-4dbf-8de7-42576f6da892'})
  ON CREATE SET f.name = 'Aluminium ingot';
MATCH (p:Process {id:'EXT_PROC_REPAIR'}), (f:Flow {id:'ae206e6f-e4f5-4dbf-8de7-42576f6da892'})
MERGE (p)-[r:HAS_FLOW {exchangeId:'EXT_PROC_REPAIR#0'}]->(f)
  SET r.sourceExchangeId = 'PROC_REPAIR#0',
      r.direction = 'input',
      r.amount = 1.0,
      r.unit = 'kg';

MERGE (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
  ON CREATE SET f.name = 'Electricity';
MATCH (p:Process {id:'EXT_PROC_REPAIR'}), (f:Flow {id:'890a70b7-b677-4e2a-8a1b-7d017e0a10ae'})
MERGE (p)-[r:HAS_FLOW {exchangeId:'EXT_PROC_REPAIR#1'}]->(f)
  SET r.sourceExchangeId = 'PROC_REPAIR#1',
      r.direction = 'input',
      r.amount = 3.6,
      r.unit = 'MJ';

// ---- CarbonFootprintSummary -> Assessment/ImpactResult (traceabilityLevel=white) ----
MERGE (ir:ImpactResult {id:'EXT_RES_PREC_AL7075_CC'})
  SET ir.value = 9.178024104499102,
      ir.unit = 'kg CO2-eq',
      ir.lifeCyclePhase = 'A1-A3 (Manufacturing: PROC_CNC + PROC_SCREW + PROC_FINISH)',
      ir.calculationMethod = 'EF 3.1 -- Climate change',
      ir.sourceAAS = 'https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT',
      ir.traceabilityLevel = 'white',
      ir.rawSubmodelJson = '{"modelType":"SubmodelElementCollection","idShort":"ProductCarbonFootprint_Manufacturing","value":[{"modelType":"Property","idShort":"PCFCO2eq","valueType":"xs:double","value":"9.178024104499102"},{"modelType":"Property","idShort":"PCFCalculationMethod","valueType":"xs:string","value":"EF 3.1 -- Climate change"},{"modelType":"Property","idShort":"PCFLifeCyclePhase","valueType":"xs:string","value":"A1-A3 (Manufacturing: PROC_CNC + PROC_SCREW + PROC_FINISH)"},{"modelType":"Property","idShort":"SourceImpactResultId","valueType":"xs:string","value":"RES_PREC_AL7075_CC"}]}';

MERGE (ir:ImpactResult {id:'EXT_RES_PREC_AL7075_REPAIR_CC'})
  SET ir.value = 9.154962801954616,
      ir.unit = 'kg CO2-eq',
      ir.lifeCyclePhase = 'B4 (Replace/Repair: PROC_REPAIR)',
      ir.calculationMethod = 'EF 3.1 -- Climate change',
      ir.sourceAAS = 'https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT',
      ir.traceabilityLevel = 'white',
      ir.rawSubmodelJson = '{"modelType":"SubmodelElementCollection","idShort":"ProductCarbonFootprint_Service","value":[{"modelType":"Property","idShort":"PCFCO2eq","valueType":"xs:double","value":"9.154962801954616"},{"modelType":"Property","idShort":"PCFCalculationMethod","valueType":"xs:string","value":"EF 3.1 -- Climate change"},{"modelType":"Property","idShort":"PCFLifeCyclePhase","valueType":"xs:string","value":"B4 (Replace/Repair: PROC_REPAIR)"},{"modelType":"Property","idShort":"SourceImpactResultId","valueType":"xs:string","value":"RES_PREC_AL7075_REPAIR_CC"}]}';

