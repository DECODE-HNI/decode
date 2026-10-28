# RFLPV² – Extension by Product Element, Process Element and Test Cases

Consolidated specification of all agreed changes to the RFLPV² profile
(baseline: `RFLPV²-Profil.mdzip`, Cameo Systems Modeler 2024x, HNI Paderborn).
This file is the tool-neutral reference — the accompanying `.xml` is only a
best-effort export attempt derived from it (see section 9 for the limits in
Enterprise Architect).

**Scope:** Only changed/new elements plus the unchanged elements that are needed as
generalisation or relationship targets. NOT included (because unchanged and
already correctly present in the existing Cameo project): Customer Need/Requirement,
Function, Logical Element, Test/Inspection/Demonstration/Simulation, MBSE Role Model,
ECR, Architecture Candidate.

**Status markers:** ✅ confirmed and implemented in the accompanying XMI · 🕓 confirmed,
but documented as a target state only (no change to the running Neo4j model/the
pipeline) · 💡 open proposal, not yet decided.

---

## 1. Renaming: Physical Element → Product Element ✅

**Rationale:** "Physical" suggests materiality and no longer fits the content of the
layer for CPS with a high software share (control units and control software are not
physical objects). Technically uncritical: in Cameo/EA the stereotype identity hangs on
the internal ID, not on the name — existing model content migrates automatically.

| Old (Physical Element) | New (Product Element) |
|---|---|
| `physicalID` | `productID` |
| `physicalType` | `productType` |
| `physicalParameter` | `productParameter` |
| `physicalParameterType` | `productParameterType` |
| `variantTag`, `elementOwner`, `discipline`, `costs` | unchanged |

Package `04_Physical Element` → `04_Product Element` (diagram name; adjust the icon file
accordingly — cosmetic, no model risk).

## 2. New tags on Product Element ✅

| Tag | Type | Purpose |
|---|---|---|
| `materialRef` | String **[0..\*]** | Reference ID(s), matches `Material.id` in the Neo4j graph. Multiple references are allowed because a Product Element can contain several materials. Quantity shares (`fraction`/`mass_g`) are deliberately NOT duplicated on the SysML side — they stay exclusively in Neo4j (`USES_MATERIAL.fraction`). |
| `realizationType` | **`RealizationType`** (enum) | solves the actual distinction problem that motivated the renaming |

### Enumeration `RealizationType`
`hardware` · `software` · `hybrid`

## 3. New tags on System Requirement ✅

No dedicated stereotype for sustainability — only additional tags, analogous to
`requirementPriority`/`requirementParameter`, which already work without a dedicated
stereotype today:

| Tag | Type | Example |
|---|---|---|
| `sustainabilityIndicatorRef` | String | `GWP100` (references an `ImpactCategory` in Neo4j) |
| `sustainabilityThreshold` | Real | `120` |
| `sustainabilityOperator` | **`SustainabilityOperator`** (enum) | `lessOrEqual` |
| `sustainabilityUnit` | String | `kgCO2eq` |
| `sustainabilityScope` | String | `A1-A3` |

The four fields together yield a fully evaluable expression:
`sustainabilityIndicatorRef sustainabilityOperator sustainabilityThreshold [sustainabilityUnit], scope sustainabilityScope`.

`sustainabilityScope` deliberately stays a string instead of an enum, even if
`Process Element.lifecycleModule` were enumerated (see below): requirements often refer to
module **ranges** ("A1-A3", "A1-C4"), which cannot be represented as a single enum literal.

### Enumeration `SustainabilityOperator`
`lessThan` · `lessOrEqual` · `equal` · `greaterOrEqual` · `greaterThan`

## 4. Process Element — tag semantics clarified ✅

No structural change to the tags themselves, only a clarification:

| Tag | Meaning |
|---|---|
| `processID` | persistent identifier of the Process Element **in the SysML model** |
| `processRef` | reference to **`Process.id` in the Neo4j graph** |
| `lifecycleModule` | EN 15804 module: `A1`–`A3` (manufacturing), `A4`–`A5` (transport/assembly), `B1`–`B7` (use), `C1`–`C4` (end of life), `D` (credits) |

## 5. Relationships Process Element ↔ Product Element

Unchanged on the SysML side, fully reused (no new relation in the profile):

| Life cycle phase (EN 15804) | Relation |
|---|---|
| A1–A3 (manufacturing) | `Process Element --Realizes--> Product Element` |
| A4–A5, B1–B7, C1–C4, D | `Process Element --Affects--> Product Element` |

**🕓 Neo4j target state (documented, not implemented):** `Realizes`/`Affects` are to appear
in the graph as dedicated relationship types `REALIZES`/`AFFECTS` instead of both being
carried under `APPLIES_TO` — justified by an already existing real case: the waste
incineration process (`PROC_WASTE_INCINERATION_MSW`, a C-module/"Affects" case) cannot
currently be distinguished via `APPLIES_TO` from the A-module/"Realizes" manufacturing
processes. Implementation requires reclassifying the existing edges (17 manufacturing
processes → `REALIZES`, the one EoL process → `AFFECTS`) as well as adjustments to the
Data Importer schema/the pipeline scripts — deliberately only at the next full rebuild,
not now on the running model.

## 6. Verification layer: Test Case, Test Case Description, Test Scenario ✅

(after Ebel/Pottebaum/Graessler 2024, "Model-based planning of test cases and test scenarios...",
ISSE 2024). All three generalise the existing `Verification` (or `Class`); no change to
`Test`/`Inspection`/`Demonstration`/`Simulation`.

| Stereotype | generalises | Tags |
|---|---|---|
| `Test Case` | `Verification` (inherits `base_Behavior`, `base_Operation`, `verificationID`, `verificationParameter`) | `testCaseOwner`, `systemLevel`, `dataAnalysisType`, `testMethod`, `sustainabilityResult`, `sustainabilityStatus` |
| `Test Case Description` | `Class` | `environmentalConditions`, `systemState`, `user`, `expectedResults` |
| `Test Scenario` | `Verification` | `testScenarioOwner`, `testItems`, `testScenarioEnvironmentalParameters` |

`verificationID` continues to be used as the test case ID; there is no separate `testCaseID`.

### Semantics of `sustainabilityResult`/`sustainabilityStatus` ✅ (tags stay, meaning clarified)

| Tag | Type | Meaning |
|---|---|---|
| `sustainabilityResult` | Real | result of the sustainability assessment of this test case that is currently being or was last performed |
| `sustainabilityStatus` | String | current verification status. Recommended values: `passed`, `failed`, `inconclusive`, `notEvaluated` |

Relationships (all reused, no new relation): `Test Case --Verifies--> System
Requirement`, `Test Case --(simple dependency)--> Product Element` (test item), `Test Case
*-- Test Case Description` (composition), `Test Scenario --(simple dependency)--> Test Case`
(≥2, forms the verification matrix).

**✅ Neo4j target state (implemented 2026-08-29, `model_extension/migrations/demonstrator/`):**
Substantively, the sustainability assessment remains the result of a test case; Neo4j
stores the concrete executions separately:

```
TestCase --[:VERIFIES]--> Requirement
TestCase --[:HAS_ASSESSMENT]--> Assessment --[:HAS_RESULT]--> ImpactResult --[:FOR_CATEGORY]--> ImpactCategory
TestCase --[:TESTS]--> Artifact        (Test Item)
```

`sustainabilityResult`/`sustainabilityStatus` in the SysML model = current cache value;
`Assessment` in Neo4j = complete assessment execution. The new node type `TestCase`
(`verificationID`, `testCaseOwner`, `systemLevel`, `dataAnalysisType`, `testMethod`,
`sustainabilityResult`, `sustainabilityStatus` ∈ {`passed`,`failed`,`inconclusive`,
`notEvaluated`}) additionally carries the constraint `TestCase_id_unique`. Implemented
initially for an 8-gripper demonstrator slice (24 test cases). The test case status is
written back to `SATISFIES_REQUIREMENT.verificationStatus`.

## 7. Neo4j overview

| SysML | Neo4j | Status |
|---|---|---|
| `Product Element.materialRef` | `Material.id` | ✅ |
| `Process Element.processRef` | `Process.id` | ✅ |
| `Process Element.processType` | `Process.processType` | ✅ |
| `Process Element.lifecycleModule` | `Process.lifecycleModule` | ✅ live on all 58 `Process` nodes since v2 (values `A1`, `A1-A3`, `A3`, `B1`, `B4`, `C3`), evaluated by the DQ layer — correction from consistency review layer 4 (DE-01), as of 2026-08-29 |
| `Process Element --Realizes--> Product Element` | `Process -[:REALIZES]-> Part` | 🕓 see section 5 |
| `Process Element --Affects--> Product Element` | `Process -[:AFFECTS]-> Part` | 🕓 see section 5 |
| `System Requirement.sustainabilityIndicatorRef` | `ImpactCategory.id` | ✅ |
| `System Requirement.sustainabilityThreshold` | `Specification.valueNumber` | ✅ (existing field) |
| `System Requirement.sustainabilityUnit` | `Specification.unit` | 💡 existing field, no new property needed |
| `System Requirement.sustainabilityOperator` | `Specification.comparator` (new) *or* derivable from `toleranceMin`/`toleranceMax` | 💡 open, see below |
| `Test Case.sustainabilityResult`/`-Status` | stays a cache value on the SysML side; mirrored on `TestCase` in Neo4j | ✅ |
| concrete test execution | `TestCase -[:HAS_ASSESSMENT]-> Assessment` | ✅ implemented 2026-08-29 (`demonstrator/`) |
| assessment result | `Assessment -[:HAS_RESULT]-> ImpactResult` | ✅ already present |
| impact category | `ImpactResult -[:FOR_CATEGORY]-> ImpactCategory` | ✅ already present |

## 8. Open proposals (not yet decided) 💡

These three points were raised in the discussion but not confirmed — deliberately not
carried into the accompanying XMI:

1. **`lifecycleModule` as enum `EN15804Module`** (`A1`…`A5`, `B1`…`B7`, `C1`…`C4`, `D`) instead
   of a string — consistent with the decision on `realizationType`, since EN 15804 is a
   closed standard vocabulary.
2. **`sustainabilityStatus` as enum `TestVerificationStatus`** (`passed`/`failed`/
   `inconclusive`/`notEvaluated`) instead of a string — for the same consistency reason.
3. **Reuse `Specification.unit` for `sustainabilityUnit`** instead of creating a new
   property; for `sustainabilityOperator`, possibly use the existing `toleranceMin`/
   `toleranceMax` structure instead of a new `comparator` field.

## 9. Limits of the accompanying XMI export for Enterprise Architect

EA and Cameo are both XMI 2.1 compliant but **structurally different** in how they handle
stereotype tags: Cameo represents tags as regular `uml:Property` elements on the stereotype
(as in the accompanying file), whereas EA manages tags internally through its own "Tagged
Value Types" directory, which is not populated 1:1 from a raw UML2 profile XMI. The
accompanying `RFLPV2_Extension_Profile.xml` is therefore a **best-effort scaffold**, not a
guaranteed one-click import — it has not been tested against a real EA instance.

Two ways, depending on the result of the import:
1. **Try the import**: `Extensions > Import Reference Data` (or, depending on the EA version,
   `Publish > Technology > Import Technology`) with the `.xml`. If stereotypes arrive
   without tags or without a working metaclass assignment: the profile is still usable as
   a raw scaffold, and the tags must then be added manually in the Profile Helper.
2. **Rebuild directly in EA** (the safer way, approx. 30–45 min for the 9 stereotypes of this
   extension): `Configure > Reference Data > UML Profiles > New Profile`, create one classifier
   with `«stereotype»` per stereotype, attach it via an Extend relationship to the metaclass
   (`Class`, `Block`, `TestCase`, `Dependency`, `Behavior`+`Operation`), create the tags via
   the "Tagged Value Types" management there (name + type from the tables above, including
   the two enumerations `RealizationType` and `SustainabilityOperator`). This specification
   is the complete source for that.

The generalisations to SysML stereotypes (`Block`, `Requirement`, `TestCase`, `Trace`)
additionally require the SysML technology to be activated in EA — otherwise the
`generalization` edges can be manually redirected to `Class` there, without affecting tags
or relations.
