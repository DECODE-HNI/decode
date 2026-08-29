# Method catalogue

The sustainability-assessment methods the extended graph is meant to carry,
and the queries that run them. The catalogue follows a taxonomy of **29
methods** in **3 paradigms / 9 groups**:

| Paradigm | Groups | Examples |
|---|---|---|
| **Accounting** (`bilanzierende Ansätze`) | life-cycle-based environmental assessment · substance/resource accounting · integrated eco-economic accounting | LCA, carbon/water footprint, GHG-by-scope, MFA, CED, circularity/MCI, MFCA, eco-efficiency, SEEA |
| **Data-based** (`datenbasierte Ansätze`) | prospective LCA · scenario-based assessment · impact & uncertainty analysis | prospective / dynamic / consequential / hybrid LCA, scenario assessment, cross-impact, robustness, impact-chain, sensitivity, hotspot |
| **Learning** (`lernende Ansätze`) | AI impact forecasting · model-based product/lifecycle transparency · adaptive scenarios & decision support | impact forecasting, AI life-cycle modelling, surrogate models, digital product passport, environmental knowledge graph, automated design recommendation |

Design intent for the demonstrator: the **accounting** methods are largely
modelled in the graph; **cost** calculation is prototyped; the **learning**
methods are only *prepared* — attachment points exist (`PredictionModel`
type, `ImpactResult.provenance` / `confidence`, `BASED_ON`), the ML itself
lives outside the graph.

## What's here

| | |
|---|---|
| [`onepagers/`](onepagers/) | one Markdown file per method (`<code>_<apm_id>.md`). Each states: status in the model, what existing structure it reuses, the schema delta it needs, its base query, and — bidirectionally — which other methods a given change also affects. |
| [`base_queries/`](base_queries/) | read-only Cypher, one result per method, all tested against a running instance. [`base_queries/README.md`](base_queries/README.md) is the index with per-file status and a call example. |

## Status at a glance

- **Computes now:** LCA (EF3.1, 19 categories), carbon footprint, circularity/MCI,
  repairability, GHG-by-scope, cross-impact, scenario assessment, hotspot —
  plus approximate queries for water footprint, MFA, CED, MFCA, eco-efficiency,
  sensitivity, robustness, impact chain, digital product passport, design
  recommendation.
- **Schema / layer prepared:** pollutant register, prospective / consequential /
  dynamic / hybrid LCA, SEEA.
- **Prepared only (AI, by design):** impact forecasting, surrogate models,
  learning scenarios, predictive assessment.

Method exchangeability is demonstrated concretely: three LCIA methods
(EF3.1, PCF, ReCiPe) run through the single `lca_generic($methodId)` query in
[`../model_extension/migrations/v3_whitebox/`](../model_extension/migrations/v3_whitebox/) —
adding ReCiPe was pure data, zero query change.

> Note on language: the one-pagers and the `.cypher` comments are in German
> (the demonstrator's working language); IDs, structure and this catalogue
> are in English.
