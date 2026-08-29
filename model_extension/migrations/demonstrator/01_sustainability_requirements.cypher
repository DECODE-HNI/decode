// ============================================================================
// 01_sustainability_requirements.cypher   (demonstrator slice)
// ----------------------------------------------------------------------------
// Three sustainability Requirements + attachment to the 8-gripper demonstrator
// slice. Field set mirrors the existing REQ_COMPAT demonstrator
// (sustainabilityIndicatorRef / Threshold / Operator / Unit / Scope / Basis).
// Idempotent. Rollback at the foot.
//
// Slice: ART_V_AL, ART_FLAT_AL  (Al6061, real data)
//        ART_PREC_POM, ART_FLAT_ABS, ART_PREC_PC  (engineering/commodity plastic, real data)
//        ART_LONG_CFPA  (CF-PA, no jaw dataset -- worst-case flag)
//        ART_FINRAY_TPU (TPU, no jaw dataset -- compliant structure)
//        ART_MAGNET     (steel + NdFeB, dataset present but no climate CF -- review flag)
// ============================================================================

MERGE (r:Requirement {id:'REQ_SUS_GWP'})
  SET r.name='Gripper cradle-to-gate GWP ceiling',
      r.requirementType='sustainability',
      r.statement='The cradle-to-gate global warming potential of one gripper shall not exceed 0.50 kg CO2-eq.',
      r.priority='should', r.status='active',
      r.sustainabilityIndicatorRef='IC_CLIMATE',
      r.sustainabilityThreshold=0.50, r.sustainabilityOperator='<=',
      r.sustainabilityUnit='kg CO2-eq',
      r.sustainabilityScope='cradle-to-gate, one gripper',
      r.sustainabilityBasis='demonstrator target, aligned with REQ_COMPAT';

MERGE (r:Requirement {id:'REQ_SUS_MCI'})
  SET r.name='Gripper material circularity floor',
      r.requirementType='sustainability',
      r.statement='The material circularity indicator (MCI) of one gripper shall be at least 0.30.',
      r.priority='should', r.status='active',
      r.sustainabilityIndicatorRef='IC_CIRCULARITY',
      r.sustainabilityThreshold=0.30, r.sustainabilityOperator='>=',
      r.sustainabilityUnit='dimensionless (0-1)',
      r.sustainabilityScope='material loops, one gripper',
      r.sustainabilityBasis='demonstrator target near the polymer class default (~0.33)';

MERGE (r:Requirement {id:'REQ_SUS_REPAIR'})
  SET r.name='Gripper disassembly reversibility floor',
      r.requirementType='sustainability',
      r.statement='The disassembly reversibility of one gripper shall be at least 0.70.',
      r.priority='shall', r.status='active',
      r.sustainabilityIndicatorRef='IC_REPAIRABILITY',
      r.sustainabilityThreshold=0.70, r.sustainabilityOperator='>=',
      r.sustainabilityUnit='dimensionless (0-1)',
      r.sustainabilityScope='field disassembly, one gripper',
      r.sustainabilityBasis='design-for-disassembly target';

UNWIND ['ART_V_AL','ART_FLAT_AL','ART_PREC_POM','ART_FLAT_ABS','ART_PREC_PC',
        'ART_LONG_CFPA','ART_FINRAY_TPU','ART_MAGNET'] AS aid
UNWIND ['REQ_SUS_GWP','REQ_SUS_MCI','REQ_SUS_REPAIR'] AS rid
MATCH (art:Artifact {id:aid}), (r:Requirement {id:rid})
MERGE (art)-[sr:SATISFIES_REQUIREMENT]->(r)
  ON CREATE SET sr.verificationStatus='notEvaluated';

// verification
MATCH (art:Artifact)-[:SATISFIES_REQUIREMENT]->(r:Requirement) WHERE r.id STARTS WITH 'REQ_SUS_'
RETURN r.id AS requirement, r.sustainabilityOperator + ' ' + toString(r.sustainabilityThreshold) AS bar,
       count(art) AS grippers ORDER BY requirement;

// rollback
// MATCH (art:Artifact)-[sr:SATISFIES_REQUIREMENT]->(r:Requirement) WHERE r.id STARTS WITH 'REQ_SUS_' DELETE sr;
// MATCH (r:Requirement) WHERE r.id STARTS WITH 'REQ_SUS_' DELETE r;
