// Generiert von aas_to_neo4j_import.ps1 aus: .\aas_instance_blackbox_prec_al7075_contact.json
// AAS-Shell: AAS_PART_PREC_AL7075_CONTACT_BlackBox [https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT_BLACKBOX]

// ================= BLACK BOX: Assessment + :DECLARES-Kanten zu ImpactCategory =================
MERGE (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'})
  SET a.traceabilityLevel = 'black',
      a.sourceAAS = 'https://ned2-gripper.example/ids/aas/PART_PREC_AL7075_CONTACT_BLACKBOX',
      a.lifeCycleStage = 'A1-A3 (PROC_CNC + PROC_SCREW + PROC_FINISH)',
      a.attachedFile = './ilcd/ilcd_export_proc_cnc.xml',  // Blob-Referenz, wird NICHT geparst
      a.rawSubmodelJson = '{"modelType":"Submodel","id":"https://ned2-gripper.example/ids/sm/EnvironmentalFootprintBlack_PART_PREC_AL7075_CONTACT","idShort":"EnvironmentalFootprintBlack","kind":"Instance","submodelElements":[{"modelType":"SubmodelElementCollection","idShort":"EPDMetadata","value":[{"modelType":"Property","idShort":"ProgramOperator","valueType":"xs:string","value":"IBU"},{"modelType":"Property","idShort":"UnderlyingPCR","valueType":"xs:string","value":"PCR Teil B: Metalle"},{"modelType":"Property","idShort":"ValidUntil","valueType":"xs:string","value":"2031-08-26"},{"modelType":"Property","idShort":"Verifier","valueType":"xs:string","value":"unabhaengiger Dritt-Pruefer (Typ III, illustrativ)"}]},{"modelType":"SubmodelElementCollection","idShort":"EnvironmentalIndicators","value":[{"modelType":"Property","idShort":"LifeCycleStage","valueType":"xs:string","value":"A1-A3 (PROC_CNC + PROC_SCREW + PROC_FINISH)"},{"modelType":"Property","idShort":"GWPTotal","valueType":"xs:double","value":"9.178024104499100"},{"modelType":"Property","idShort":"GWPTotalUnit","valueType":"xs:string","value":"kg CO2-eq"},{"modelType":"Property","idShort":"ODP","valueType":"xs:double","value":"1.0777159620947944E-10"},{"modelType":"Property","idShort":"ODPUnit","valueType":"xs:string","value":"kg CFC11-eq"},{"modelType":"Property","idShort":"AP","valueType":"xs:double","value":"1.0611392739045878"},{"modelType":"Property","idShort":"APUnit","valueType":"xs:string","value":"mol H+-eq"},{"modelType":"Property","idShort":"EPFreshwater","valueType":"xs:double","value":"5.740953145927146E-6"},{"modelType":"Property","idShort":"EPFreshwaterUnit","valueType":"xs:string","value":"kg P-eq"},{"modelType":"Property","idShort":"EPMarine","valueType":"xs:double","value":"0.3759123610593301"},{"modelType":"Property","idShort":"EPMarineUnit","valueType":"xs:string","value":"kg N-eq"},{"modelType":"Property","idShort":"EPTerrestrial","valueType":"xs:double","value":"1.574630337203425"},{"modelType":"Property","idShort":"EPTerrestrialUnit","valueType":"xs:string","value":"mol N-eq"},{"modelType":"Property","idShort":"POCP","valueType":"xs:double","value":"1.0399849904303108"},{"modelType":"Property","idShort":"POCPUnit","valueType":"xs:string","value":"kg NMVOC-eq"},{"modelType":"Property","idShort":"ADPE","valueType":"xs:double","value":"1.6167E-6"},{"modelType":"Property","idShort":"ADPEUnit","valueType":"xs:string","value":"kg Sb-eq"},{"modelType":"Property","idShort":"ADPF","valueType":"xs:double","value":"114.4404662529269"},{"modelType":"Property","idShort":"ADPFUnit","valueType":"xs:string","value":"MJ"},{"modelType":"Property","idShort":"WDP","valueType":"xs:double","value":"562.4514668924422"},{"modelType":"Property","idShort":"WDPUnit","valueType":"xs:string","value":"m3 world-eq"}]},{"modelType":"File","idShort":"SupportingReport","contentType":"application/xml","value":"./ilcd/ilcd_export_proc_cnc.xml"}]}';

MATCH (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'}), (ic:ImpactCategory {id:'IC_CLIMATE'})
MERGE (a)-[d:DECLARES]->(ic)
  SET d.value = 9.178024104499100,
      d.unit = 'kg CO2-eq',
      d.traceabilityLevel = 'black';

MATCH (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'}), (ic:ImpactCategory {id:'IC_EF_OZONE_DEPLETION'})
MERGE (a)-[d:DECLARES]->(ic)
  SET d.value = 1.0777159620947944E-10,
      d.unit = 'kg CFC11-eq',
      d.traceabilityLevel = 'black';

MATCH (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'}), (ic:ImpactCategory {id:'IC_EF_ACIDIFICATION'})
MERGE (a)-[d:DECLARES]->(ic)
  SET d.value = 1.0611392739045878,
      d.unit = 'mol H+-eq',
      d.traceabilityLevel = 'black';

MATCH (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'}), (ic:ImpactCategory {id:'IC_EF_EF_EUTROPHICATION_FRESHWATER'})
MERGE (a)-[d:DECLARES]->(ic)
  SET d.value = 5.740953145927146E-6,
      d.unit = 'kg P-eq',
      d.traceabilityLevel = 'black';

MATCH (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'}), (ic:ImpactCategory {id:'IC_EF_EUTROPH_MARINE'})
MERGE (a)-[d:DECLARES]->(ic)
  SET d.value = 0.3759123610593301,
      d.unit = 'kg N-eq',
      d.traceabilityLevel = 'black';

MATCH (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'}), (ic:ImpactCategory {id:'IC_EF_EF_EUTROPHICATION_TERRESTRIAL'})
MERGE (a)-[d:DECLARES]->(ic)
  SET d.value = 1.574630337203425,
      d.unit = 'mol N-eq',
      d.traceabilityLevel = 'black';

MATCH (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'}), (ic:ImpactCategory {id:'IC_EF_PHOTOCHEM_OZONE'})
MERGE (a)-[d:DECLARES]->(ic)
  SET d.value = 1.0399849904303108,
      d.unit = 'kg NMVOC-eq',
      d.traceabilityLevel = 'black';

MATCH (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'}), (ic:ImpactCategory {id:'IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS'})
MERGE (a)-[d:DECLARES]->(ic)
  SET d.value = 1.6167E-6,
      d.unit = 'kg Sb-eq',
      d.traceabilityLevel = 'black';

MATCH (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'}), (ic:ImpactCategory {id:'IC_EF_EF_RESOURCE_USE_FOSSILS'})
MERGE (a)-[d:DECLARES]->(ic)
  SET d.value = 114.4404662529269,
      d.unit = 'MJ',
      d.traceabilityLevel = 'black';

MATCH (a:Assessment {id:'EXT_BLACK_AAS_PART_PREC_AL7075_CONTACT_BlackBox'}), (ic:ImpactCategory {id:'IC_EF_WATER_USE'})
MERGE (a)-[d:DECLARES]->(ic)
  SET d.value = 562.4514668924422,
      d.unit = 'm3 world-eq',
      d.traceabilityLevel = 'black';

