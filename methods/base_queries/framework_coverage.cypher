// framework_coverage.cypher  --  external-framework mapping (1.3.3 SEEA and neighbours).
// Lists every ExternalFramework (v3.i) and what in the graph maps onto it:
// LCIA methods, assessment approaches, impact categories, declarations.
// No parameters.
MATCH (fw:ExternalFramework)
OPTIONAL MATCH (src)-[:MAPS_TO]->(fw)
WITH fw, src,
     head([l IN labels(src) WHERE l IN
       ['ImpactAssessmentMethod','AssessmentApproach','ImpactCategory','Declaration']]) AS srcType
RETURN fw.id                              AS framework,
       fw.standard                        AS standard,
       fw.domain                          AS domain,
       collect(DISTINCT srcType + ':' + coalesce(src.id, src.name)) AS mappedFrom
ORDER BY framework;
