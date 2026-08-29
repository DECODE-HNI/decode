# Method one-pagers

One short profile per method of the method diagram. Every method is addressable
as an `AssessmentApproach` node in the graph (`APPLIES_APPROACH` from the
assessments).

> The one-pager files themselves are in German (the demonstrator's working
> language); this index is English.

> The "learning approaches" paradigm (AI/ML: the former methods 3.1.1–3.1.3,
> 3.3.1–3.3.3) was removed from graph and docs on 2026-08-29 — out of the
> case-study scope. See
> `../../model_extension/migrations/consistency/remove_ki_stubs.cypher` (with a
> rollback block). 3.2.1 Digital Product Passport and 3.2.2 environmental
> knowledge graph are kept.

| Code | Method | Status |
|---|---|---|
| [1.1.1](1.1.1_apm_lca.md) | Life-cycle assessment (LCA) | implemented (computes) |
| [1.1.2](1.1.2_apm_cf_co2.md) | Carbon footprint (CO₂) | implemented (computes) |
| [1.1.3](1.1.3_apm_cf_h2o.md) | Water footprint (H₂O) | partial (structure + factors present) |
| [1.1.4](1.1.4_apm_ghg.md) | GHG accounting (GHG Protocol) | schema prepared |
| [1.2.1](1.2.1_apm_mfa.md) | Material / substance flow analysis (MFA) | schema prepared |
| [1.2.2](1.2.2_apm_pollutant.md) | Pollutant accounting | schema prepared |
| [1.2.3](1.2.3_apm_ced.md) | Cumulative energy demand (CED) | partial (category present) |
| [1.2.4](1.2.4_apm_circularity.md) | Circularity assessment (MCI) | implemented (computes, simplified) |
| [1.3.1](1.3.1_apm_mfca.md) | Material flow cost accounting (MFCA) | schema prepared (prototype) |
| [1.3.2](1.3.2_apm_eco_efficiency.md) | Eco-efficiency assessment (ISO 14045) | schema prepared (prototype) |
| [1.3.3](1.3.3_apm_eea.md) | Environmental-economic accounting (SEEA) | documented path |
| [2.1.1](2.1.1_apm_prospective_lca.md) | Prospective LCA | schema prepared |
| [2.1.2](2.1.2_apm_dynamic_lca.md) | Dynamic LCA | documented path |
| [2.1.3](2.1.3_apm_consequential_lca.md) | Consequential LCA | schema prepared |
| [2.1.4](2.1.4_apm_hybrid_lca.md) | Hybrid LCA | documented path |
| [2.2.1](2.2.1_apm_scenario_assessment.md) | Scenario-based environmental assessment | schema prepared (1 scenario) |
| [2.2.2](2.2.2_apm_cross_impact.md) | Cross-impact analysis | schema prepared |
| [2.2.3](2.2.3_apm_robustness.md) | Robustness & resilience analysis | partial (query-based) |
| [2.3.1](2.3.1_apm_impact_chain.md) | Impact-chain analysis | implemented (repairability as a result) |
| [2.3.2](2.3.2_apm_uncertainty_sensitivity.md) | Uncertainty & sensitivity analysis | partial (metadata present) |
| [2.3.3](2.3.3_apm_hotspot.md) | Hotspot analysis | implemented (query) |
| [3.2.1](3.2.1_apm_dpp.md) | Digital Product Passport | implemented (demonstrator) |
| [3.2.2](3.2.2_apm_env_kg.md) | Environmental knowledge graph | n/a (this project) |
