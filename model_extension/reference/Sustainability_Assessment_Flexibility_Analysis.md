# Flexibility analysis: Neo4j model for multiple sustainability-assessment methods

**Basis:** `neo4j_importer_model.json` (export of 2026-08-27, channel-A schema —
`HAS_FLOW`/`CHARACTERIZES` run separately over channel B and are deliberately not
part of the Data Importer schema).

**Goal of this analysis:** check whether the current data base can carry four
method families at the same time without a structural rebuild:
1. LCA method family (ISO 14040/44, interchangeable characterisation methods)
2. circularity / EoL indicators (e.g. Material Circularity Indicator)
3. structural / qualitative indices (repairability, disassemblability)
4. EN 15804 / EPD reporting format (module-based aggregation)

Status marking as in the earlier specification documents: ✅ present ·
🕓 partial / usable only as a convention · ❌ structurally missing.

> This analysis is from 2026-08-27. Its conclusions have since been acted on:
> gap 1 (`Process.lifecycleModule`) is now live on all 58 processes; gap 4
> (`ImpactResult -[:BASED_ON]-> …`) is partially in place (v3.d, 57 edges); the
> functional unit is on `Assessment` as a property. Gaps 2 (declared functional
> unit as a node), 3 (`ASSESSES` widening) and the rest of 5 remain a documented
> forward list.

---

## 1. Current model structure (reference)

| Area | Node types | Core relationships |
|---|---|---|
| product structure | `Product`→`Artifact`→`Assembly`→`Part`, `Feature`, `Form`→`Geometry` | `HAS_ARTIFACT`, `HAS_COMPONENT` (recursive), `HAS_FEATURE`, `HAS_FORM`, `HAS_GEOMETRY` |
| function/behaviour | `Function`, `Behavior`, `SolutionPrinciple`, `CoreProperty` | `REALIZES_FUNCTION`, `HAS_BEHAVIOR`, `CHARACTERIZES_PROPERTY`, `HAS_PROPERTY` |
| requirements | `Requirement`→`Specification` | `SATISFIES_REQUIREMENT`, `SPECIFIED_BY` |
| material/process | `Material`, `Process`, `ProcessPlan`, `Scenario` | `USES_MATERIAL`, `CONTAINS_PROCESS`, `APPLIES_TO` (Process→Part/Material, `role` as discriminator), `HAS_SCENARIO`, `SUITABLE_FOR` |
| **assessment** | `Assessment`, `ImpactAssessmentMethod`, `ImpactCategory`, `ImpactResult`, `Flow`, `FlowProperty` | `ASSESSES` (only →`Artifact`), `USES_METHOD`, `HAS_CATEGORY`, `HAS_RESULT`, `FOR_CATEGORY`, `DERIVED_FROM` (only →`Flow`) |
| data base | `DataItem`, `DataSource`, `DataQuality`, `DataQualityCriterion` | `HAS_DATA` (Artifact/Material/Process/ImpactResult/Flow →`DataItem`), `FROM_SOURCE`, `HAS_DATA_QUALITY`, `EVALUATES_CRITERION` |

**Central observation:** the assessment layer
(`Assessment`→`USES_METHOD`→`ImpactAssessmentMethod`→`HAS_CATEGORY`→`ImpactCategory`)
is already built method-agnostically — a new method needs **no schema change**,
only a new `ImpactAssessmentMethod` node with its own `ImpactCategory` children.
That is the most important existing flexibility and the starting point for all
four methods below.

---

## 2. LCA method family (ISO 14040/44, EF3.1/ReCiPe/CML/TRACI interchangeable)

| Requirement | Status | Reason |
|---|---|---|
| several characterisation methods usable in parallel | ✅ | each method = its own `ImpactAssessmentMethod` node with its own `ImpactCategory` set. `Flow --CHARACTERIZES{factor,location}--> ImpactCategory` (channel B) lets one flow carry several factors for several methods at once — exactly why the channel-B split was introduced. |
| inventory-data traceability (flow → result) | ✅ | `ImpactResult --DERIVED_FROM{contribution,exchangeId}--> Flow` maps the LCI contribution chain cleanly. |
| process origin / provenance | ✅ | `Process.source`/`sourceDatabase`/`referenceYear`, `Flow.source`/`sourceDatabase`, plus `FROM_SOURCE`→`DataSource` — already present from the ILCD rebuild. |
| functional unit / reference quantity | ❌ | neither `Product`/`Artifact` nor `Assessment` has a field for the functional unit (e.g. "1 gripping cycle", "1 kg of gripped part"). ISO 14044 requires it explicitly for comparability — currently only implicit/undocumented. |
| system boundary / cut-off per assessment | 🕓 | `Assessment.developmentPhase` describes something else (concept/detail phase). No property for "cradle-to-gate" vs "cradle-to-grave". Closely tied to point 4 (`lifecycleModule`). |
| allocation method for multi-output processes | ❌ | `Process` has no field for the allocation rule used (mass/economic/none). If you want it to vary per assessment, the hook is entirely missing. |
| uncertainty (quantitative) | 🕓 | `DataQuality`/`DataQualityCriterion` covers a pedigree-matrix-style *qualitative* rating, but `ImpactResult`/`Flow` have no field for distribution parameters (min/max/stdev). Planned as an optional column in the rebuild plan, but not guaranteed to be populated. |

**LCA conclusion:** the core architecture already carries method switching well.
The two gaps with real effect are the missing functional unit and the missing
system-boundary statement — both needed as soon as you actually want to compare
two assessments (e.g. EF3.1 vs ReCiPe, or two scenarios).

---

## 3. Circularity / EoL indicators (e.g. Material Circularity Indicator)

| Requirement | Status | Reason |
|---|---|---|
| recycled content in the input | ✅ | `Material.recycledContent_pct` already exists — covers the input side of MCI (V, recycled/feedstock share). |
| recyclability/reusability at the output/EoL | ❌ | no counterpart on `Material` or `Part` for the output side (collection rate, recyclability, reuse rate). MCI needs both sides, currently only one. |
| use intensity / lifetime (utility factor) | ❌ | no field on `Product`/`Artifact` for expected/actual lifetime or use intensity — MCI's utility factor needs exactly that. |
| unambiguous identification of EoL processes | ❌ | `Process.processType`/`technology` are free text with no controlled vocabulary. Without `lifecycleModule` (see section 4), "give me all disposal/recycling processes" cannot be queried reliably. |
| composite index structure (several weighted sub-terms) | 🕓 | no schema break needed — each MCI sub-term (utility factor, linear-flow index, V, W) could be modelled as its own `ImpactResult` with `resultType='MCI_utility_factor'` etc. under one `Assessment`. Works, but only as a naming convention, not as structure. |

**Circularity conclusion:** a larger substantive gap than for LCA. Three new
properties (recyclability/reusability on `Material`, lifetime on
`Artifact`/`Product`) plus `lifecycleModule` on `Process` would cover the family
fully.

---

## 4. Structural / qualitative indices (repairability, disassemblability, modularity)

| Requirement | Status | Reason |
|---|---|---|
| disassembly / build structure | ✅ | `Assembly`→`Part` (recursive via `HAS_COMPONENT`) already maps the disassembly hierarchy — the basis for depth/count metrics. |
| connection type / reversibility per connection | ❌ | neither `Feature` nor the `HAS_COMPONENT` relation itself carries a field for connection type (screw/snap/glue/weld) or reversibility — exactly what a repairability/disassembly index typically needs (tool requirement, non-destructiveness). |
| accessibility of individual parts | ❌ | no field for it on `Part`/`Feature`. |
| weighted multi-criteria rating | ✅ | `DataQuality`(method, overallScore, scale) + `DataQualityCriterion`(category, definition, weight, direction) via `EVALUATES_CRITERION{score,rating}` is already a generic, method-independent framework for exactly such a weighted index — directly reusable, even though it was originally meant for data quality. |
| assessment at part/assembly level, not just artifact | ❌ | `Assessment --ASSESSES--> Artifact` is the only permitted target. A structural index is typically computed per part/assembly ("how easy is *this* wear part to swap"), not per whole artifact — currently only possible via over-aggregation to artifact level. |
| traceability: which structural elements led to the result | ❌ | `DERIVED_FROM` points firmly at `Flow` — for non-LCI-based results (e.g. "this score is based on these 4 feature connections") there is no equivalent. |

**Structural conclusion:** the disassembly hierarchy and the data-quality
framework (reusable as a weighting scheme) are good building blocks. The real gap
is twofold: (a) missing connection-type/reversibility properties and (b) the
`ASSESSES` edge fixed to `Artifact` plus the `DERIVED_FROM` edge fixed to `Flow`,
both too granular/narrow for structural indices.

---

## 5. EN 15804 / EPD reporting format (A1-A3, A4-A5, B1-B7, C1-C4, D)

| Requirement | Status | Reason |
|---|---|---|
| indicator catalogue representable | ✅ | `ImpactCategory`(indicator, unit) is generic enough to take the EN15804 indicator list 1:1 (GWP-total/-fossil/-biogenic, ODP, AP, EP-freshwater, …) — pure data-content question, not a structure problem. |
| module assignment (A1-A3/B/C/D) per process | ❌ | `Process.lifecycleModule` does not exist in the live model. It was already foreseen as a target state in the SysML profile extension (`Process Element.lifecycleModule`), but by decision "document only" deliberately not carried into Neo4j. |
| module-wise aggregation of results | ❌ | without `lifecycleModule`, an `ImpactResult` cannot be broken down cleanly by A1-A3/C/D — a prerequisite for a norm-compliant EPD results-table format. |
| declared unit | ❌ | same gap as the functional unit for LCA (section 2), but mandatory in EN15804 rather than optional. |

**EN15804 conclusion:** this is the method family with the most clearly
identified and only real blocker: `lifecycleModule` on `Process`. Everything else
is data content, not a structure problem.

---

## 6. Synthesis: shared gaps across all four methods

Notably, the individual gaps condense into **five** additive, non-breaking
changes — none of the 32 existing relationship types would have to change:

| # | Change | Affects methods | Effort |
|---|---|---|---|
| 1 | `Process.lifecycleModule` (EN15804 code A1-A3 etc.) | EN15804/EPD, circularity (EoL processes filterable), partly LCA (system boundary) | one new property, already specified (RFLPV² document), only not yet carried into Neo4j |
| 2 | declared functional unit (`Assessment.functionalUnit`/`referenceQuantity`/`referenceUnit` or on `Product`) | LCA, EN15804/EPD | one to three new properties on `Assessment` or `Product` |
| 3 | widen `Assessment --ASSESSES-->` to `Part`/`Material`/`Process`/`ProcessPlan` (not only `Artifact`) | circularity (material-related), structure (part-related) | extending an existing relationship to further target nodes — no new type needed |
| 4 | generic traceability edge `ImpactResult --BASED_ON--> (Feature\|CoreProperty\|DataItem)` alongside `DERIVED_FROM--> Flow` | structure, circularity | one new, additional relationship type |
| 5 | recyclability/reusability (`Material`), lifetime/use intensity (`Artifact`/`Product`), connection type/reversibility (`Feature` or on `HAS_COMPONENT`) | circularity, structure | pure property additions, no structure change |

None of these five breaks anything existing — they are purely additive. Point 1
is by far the most reused (3 of 4 method families benefit directly) and was
already specified, only deferred as "document only".

**Recommendation:** document this analysis as a target state first, like the
RFLPV² extension, rather than applying it to the live model straight away —
consistent with the standing decision to make Neo4j-effective changes only after
explicit sign-off. If you want to start directly: point 1 (`lifecycleModule`)
would have the biggest leverage for the least effort, because it is already fully
specified and needs only the schema migration + population from the ILCD source
data (the raw data usually carries the EN15804 module as process metadata).

---

## 7. Open questions for the next round

- Should the five additive changes now be specified (schema draft, migration
  Cypher, population logic from the ILCD sources), or stay a candidate list?
- If `lifecycleModule` is implemented first: populate retroactively for the
  already-imported processes (derivable from the ILCD raw data) or only for
  future imports?
- For the structural indices: is there already a concrete target metric (e.g.
  the French Indice de Réparabilité, IEC 62309, an own weighting) so the
  connection-type properties can be tailored exactly to its criteria catalogue
  rather than guessed generically?
