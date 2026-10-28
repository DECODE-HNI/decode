# EA → Neo4j: mapping specification (RFLPV2_Extension_Profile_V006)

This document is the binding contract between the Enterprise Architect profile
(`RFLPV2_Extension_Profile_V006.xml`) and the existing Neo4j graph model
(`ned2_gripper_full_model_neo4j/`). It describes how `ea_xmi_extract.py` and
`ea_to_neo4j_load.py` work together. All decisions recorded here were agreed with
the project owner; points marked "Open" are assumptions that still have to be
confirmed.

## 1. Architecture

```
EA project (SysML, RFLPV2 profile)
   │  Project ▸ Model Exchange ▸ Export Package as XMI  (type: XMI 2.1)
   ▼
<project>.xml  (EA XMI export)
   │  ea_xmi_extract.py
   ▼
ea_extract/*.csv   (one CSV per target label or relationship type,
                     GUIDs already resolved to business keys)
   │  ea_to_neo4j_load.py  (Bolt driver, credentials only via environment variables)
   ▼
Neo4j (existing local instance)
```

**Status (2026-08-28): complete pipeline (extractor + loader) verified end-to-end
against a real, fresh test Neo4j instance.** `ea_to_neo4j_load.py`
ran without errors against `ea_extract/` (from the real XMI test model) — all 13
node types and 5 relationship types loaded in exactly the expected numbers,
constraints created correctly, the `materialRef` warning raised correctly (the test
DB does not know `MAT_ALU_GENERIC`, as expected). Testing was deliberately done
against an empty, separate instance instead of the real Ned2 database, because the
test data carry placeholder names (`Block1` etc.) that would overwrite `name` when
merged onto existing nodes (see the `SET n += row` note above) — the "merge onto
existing nodes" path is therefore not tested separately yet, only the "create new"
path.

`references_count = 0` in the test DB additionally confirms: the
`processRef <> row.id` filter logic in `PROCESS_REFERENCES_QUERY` works
correctly (no `:REFERENCES` created although 1 row ran through the query --
Neo4j even reports "Relationship type does not exist", because the type was never
created). The complete pipeline (profile, toolbox,
extractor, loader) is thus verified end-to-end against real EA export data.

**Merge-onto-existing test (2026-08-28, against the real Ned2 instance) passed.**
`rflpv2_merge_test.xml` (hand-built in the verified format, real IDs:
`FUNC_GRASP`, `SP_PARALLEL`, `ART_CUSTOM`/`ASSY_CUSTOM`/`PART_CUSTOM_CONTACT`,
`REQ_COMPAT`) loaded successfully: existing nodes were enriched instead of
duplicated (`FUNC_GRASP` kept all old properties + new ones), existing
`REALIZES_FUNCTION`/`SATISFIES_REQUIREMENT` edges were merged instead of
doubled (`count = 1`, not `2`).

**Important lesson found in the process:** `PART_USES_MATERIAL_QUERY` MERGEs a
`USES_MATERIAL` edge to the material named in `materialRef`, **but does not replace
an existing one** — `PART_CUSTOM_CONTACT` already really had
`MAT_PA12`, the test with `materialRef=MAT_ALU_GENERIC` created a
**second, parallel, factually wrong** edge (cause: an unchecked
test value instead of looking up the real material first). Cleaned up manually after the
incident (wrong edge deleted, invented test values such as
`sustainabilityThreshold=3.0` on `REQ_COMPAT` removed, `sourceStereotype`
provenance properties deliberately kept). **Decided and implemented
(2026-08-28):** `materialRef` now replaces the material assignment instead of only
adding to it — a part does not consist of two materials at the same time.
`PART_USES_MATERIAL_QUERY` deletes, before creating the new edge, all existing
`:USES_MATERIAL` edges of the part to a material OTHER than the one named in
`materialRef`.

**Status (2026-08-28): `ea_xmi_extract.py` is verified against a real EA export.**
A test model with one element per stereotype + composition +
5 relationships was built in EA (`rflpv2_package.xml`, export via "Export
Package to Native/XMI File", format XMI 2.1) and extracted completely
correctly — all 13 node types, all 5 relationships with correctly resolved
business keys, Artifact/Assembly/Part correctly separated by composition depth.
The actual structure differed considerably from the originally assumed
XMI 2.1 extension format (see below) — the extractor was
therefore rewritten completely, not just patched.

**Actual structure (verified, no longer an assumption):**
- Stereotype applications are elements of their own in the profile's own XML namespace
  (`xmlns:RFLPV2_Sustainability_Process_Extension="http://www.sparxsystems.com/profiles/RFLPV2_Sustainability_Process_Extension/1.0"`),
  directly as siblings of the `packagedElement`s in `<uml:Model>`:
  `<RFLPV2_..:Logical_Element base_Class="EAID_.." __EAStereoName="Logical Element" logicalID="SP_PARALLEL"/>`.
  No `<xmi:Extension>` needed for stereotypes/tags.
- Dependencies: normal `<packagedElement xmi:type="uml:Dependency" client=".." supplier="..">`, client=source, supplier=target.
- Composition: `<uml:Association>` with two ends (`memberEnd` idrefs) — **important
  correction of a wrong assumption**: the end with `aggregation="composite"`
  points to the **child** (part), not the parent. The other end points to
  the parent (whole). Verified empirically.

**⚠️ Most important EA workflow finding of this phase (2026-08-27): re-importing the
MDG technology is NOT enough.** An `RFLPV2_MDG_v0XX.xml` import via
`Settings ▸ MDG Technologies ▸ Manage MDG Technologies` updates the
toolbox, but **not reliably the UML profile
registration** bundled in it (`RFLPV2_Sustainability_Process_Extension`). Hours of
troubleshooting with `Customer Need`/`Derives` (the connector could not be drawn
although the profile had long been correct in content) finally turned out to be exactly
this problem. **After every profile update, always reload BOTH separately:** (1) the
MDG technology (for the toolbox) AND (2) the UML profile
itself via `Resources ▸ UML Profiles ▸ RFLPV2_Sustainability_Process_Extension
▸ Import Profile` (the same route used earlier to look at the profile's
stereotype list). An MDG re-import alone is not enough, not even
after completely removing and reinstalling the technology.

## 2. Node mapping

| EA stereotype | `AppliesTo` | Neo4j label | Business key (EA tag → Neo4j `id`) | Merge behaviour |
|---|---|---|---|---|
| `Customer Need` | Class | **`:CustomerNeed`** (new, no existing nodes) | `needID` | new node type |
| `Customer Requirement` | Class | `:Requirement` (existing) | `customerRequirementID` | MERGE on `id`; sets `level = 'customer'` |
| `System Requirement` | Class | `:Requirement` (existing) | `systemRequirementID` | MERGE on `id`; sets `level = 'system'` |
| `Function` | Class | `:Function` (existing) | `functionID` | MERGE on `id` — enriches existing nodes (e.g. `FUNC_GRASP`) with new properties where applicable |
| `Logical Element` | Class | `:SolutionPrinciple` (existing) | `logicalID` | MERGE on `id` |
| `Process Element` | Class | `:Process` (existing) | `processID` | MERGE on `id`; see special rule `processRef` (section 4) |
| `Product Element` | Class | `:Artifact` / `:Assembly` / `:Part` (existing, derived via composition) | `productID` | MERGE on `id`; see special rule level derivation (section 4) |
| `Test Case` | Activity/Operation | **`:TestCase`** (new) | `testCaseID` (added 2026-08-28) | new node type |
| `Test Case Description` | Class | **`:TestCaseDescription`** (new) | `testCaseDescriptionID` (added 2026-08-28) | new node type |
| `Test Scenario` | Activity/Operation | **`:TestScenario`** (new) | `testScenarioID` (added 2026-08-28) | new node type |
| `Validation` | Behavior/Operation | **`:Validation`** (new) | `validationID` | new node type |
| `Verification` | Behavior/Operation | **`:Verification`** (new) | `verificationID` | new node type |
| `Analysis`/`Demonstration`/`Inspection`/`Simulation`/`Test` | (generalise `Validation`) | **no node of their own** | — | only set `method = '<stereotype name>'` on the :Validation/:Verification node that carries this element (see section 4) |

Tag→property mapping is 1:1 in principle (same name), with one exception:
the profile tag `Mainfeature` (capital M, an outlier in the otherwise consistent
lowerCamelCase convention) is normalised to `mainFeature` on import.

## 3. Relationship mapping

| EA dependency stereotype | Target rule | Fallback |
|---|---|---|
| `Satisfies` | target stereotype ∈ {`Customer Requirement`, `System Requirement`} → **`:SATISFIES_REQUIREMENT`** (existing, direction source→requirement) | otherwise new type `:SATISFIES`, with log warning (unexpected stereotype combination) |
| `Realizes` | source=`Logical Element` & target=`Function` → **`:REALIZES_FUNCTION`** (existing); source=`Product Element` & target=`Logical Element` → **`:REALIZES_PRINCIPLE`** (existing) | otherwise new type `:REALIZES`, with log warning |
| `Applies` (added 2026-08-28) | source=`Process Element` & target=`Product Element` → **`:APPLIES_TO`** (existing, direction Process→Part) | otherwise new type `:APPLIES` |
| `Affects` | — | new type `:AFFECTS` |
| `Derives` | — | new type `:DERIVES` |
| `Refines` | — | new type `:REFINES` |
| `Requires` | — | new type `:REQUIRES` |
| `Specifies` | — | new type `:SPECIFIES` (deliberately **not** the same as the existing `SPECIFIED_BY` Requirement→Specification, different direction/semantics) |
| `Validates` | — | new type `:VALIDATES` |
| `Verifies` | — | new type `:VERIFIES` |

All new relationship types carry `sourceStereotype`/`targetStereotype` as
properties, so that unexpected combinations (fallback cases) remain traceable in the
graph itself, without having to search the load scripts.

**EA-side finding (2026-08-27): generic `SysML1.4::trace` is heavily restricted in
EA's implementation.** Empirically confirmed in EA: connectors
that generalise `trace` could not be drawn between two block-generalised
elements (e.g. `Logical Element` → `Function`)
("Invalid combination of source and target types for this connector type"),
whereas connectors generalising `SysML1.4::allocate` (`Refines`, `Requires`)
worked there without problems. This affected not only Product Element pairs
but also extended to pairs actually close to requirements with
`Customer Need`. Fix: `Derives`, `Satisfies`, `Verifies` now generalise
the more specific, semantically fitting native SysML stereotypes
`SysML1.4::deriveReqt`, `SysML1.4::satisfy`, `SysML1.4::verify` instead of the
generic `trace` — which also corresponds to the actual OMG SysML intention
(these three are specifically meant for requirements traceability, `trace` is
the unspecific catch-all). For `Affects`, `Realizes`, `Specifies`,
`Validates` there is no 1:1 native SysML equivalent — they stay on `trace`
or the previous state for now, until the test model shows whether they are needed
at all in the desired combinations. For the
EA→Neo4j extraction this finding changes nothing, since `ea_xmi_extract.py`
matches exclusively on the stereotype **names** (`Derives`, `Satisfies`, ...),
not on their SysML generalisation.

**Addendum (2026-08-27):** After the correct two-step re-import (see
section 1) it was confirmed: the actual problem was mostly the
missing profile re-import, not `trace` itself — `Derives`
(Customer Need → Customer Requirement) worked as soon as the profile had been
reloaded cleanly. `Realizes` (Logical Element → Function, block-to-
block, no requirement involved) kept failing, however, even in a
completely fresh EA project. Additional finding: the stereotype
`Function` is displayed differently by EA (fx icon instead of
block notation with stereotype label) — concerns `Function` only,
not `Logical Element`/`Process Element`/`Product Element`, although all four are
structurally identical (`generalizes="SysML1.4::block"`).
EA presumably treats the name "Function" specially internally (e.g. a remnant of
classic structured analysis/DFD notation), independent of the active
technology list. Pragmatic fix instead of root-cause research: `Realizes`
now also generalises `SysML1.4::allocate` instead of `trace` (as `Refines`/`Requires`
already do), since `allocate` demonstrably works reliably block-to-block. `Affects`,
`Specifies`, `Validates` are still on `trace` and, after the two-step re-import fix,
have not been retested — they might well work already if they have a
requirement endpoint.

**Update:** `Realizes`/`allocate` confirmed working, both for elements drawn from
the profile and from the toolbox (Function ↔ Logical
Element) — so the toolbox was never the problem, the `allocate` fix was the
decisive one. The `Function` appearance (fx icon instead of block notation) persists,
also when drawn from the profile, so it is EA-internal and independent of our
profile/toolbox — deliberately accepted as cosmetic, blocks nothing.

**Conclusion (2026-08-27): all 9 dependency stereotypes confirmed functional.**
`Affects`, `Specifies`, `Validates` (still `trace`)
were retested and work between Function ↔ Logical Element,
created both on the toolbox side and on the profile side. The entire
`SysML1.4::trace` restriction theory was thus mostly an artefact of the
missing two-step re-import (section 1) — only `Derives`/`Satisfies`/
`Verifies`/`Realizes` actually needed a different SysML base, the rest
worked correctly from the start once imported properly. The relationship
side of the profile is thus fully verified.

**`Customer Need` stays Class (not Note).** It was temporarily set back to
`Note` (pure free text), but this was discarded again: since
`Customer Need` is still supposed to be source/target of `Derives`/`Affects` edges,
it must remain a `NamedElement` — a `Comment` (UML note) is not one according to the
metamodel, so a `Dependency` cannot attach to it. `Class` is
thus the only one of the two options that makes the planned derivation chain
`Customer Need → Customer Requirement` modellable at all.

## 4. Special rules

**Artifact/Assembly/Part derivation (`Product Element`).** The profile has no
stereotype of its own for composition — this is intentional, since SysML block composition
(association with `aggregation="composite"`) is already built in and needs no stereotyping
of its own. The extractor reads all `uml:Association` elements
between two `Product Element` nodes with `aggregation="composite"` on one
end, builds a directed component tree from them and assigns labels by depth:
depth 0 (no incoming composition) → `:Artifact`, depth 1 → `:Assembly`,
depth ≥2 → `:Part`. For depth >2 a warning is logged, since the existing
schema is strictly three-tier (`Artifact → Assembly → Part`).

**`materialRef` (Product Element).** Only meaningful on nodes classified as `:Part`.
In addition to the node, creates a `:USES_MATERIAL` edge to the referenced
`:Material` node (must already exist — no auto-creation). If `materialRef` appears
on an `:Artifact`/`:Assembly` node, this is logged as a data quality warning instead of
silently creating a possibly wrong edge.

**`processRef` (Process Element).** Since `Process Element` merges directly onto the
existing `:Process` label (`processID` = `id`), `processRef` is only
relevant if it differs from its own `processID` — in that case the loader
additionally creates a `:REFERENCES` edge from the new/updated
`:Process` node to the referenced `:Process` node (e.g. for
process grouping nodes that point to a detail process from the
LCA inventory without replacing it). ⚠ Open: deliberate assumption, not yet
checked with real data.

**Verification method (`Analysis`/`Demonstration`/`Inspection`/`Simulation`/`Test`).**
These five stereotypes (plus `Test Case`/`Test Scenario`) originally had no
`AppliesTo` of their own — as a result they did not appear at all as independently usable
elements in EA's resource tree under "UML Profiles". This has been fixed:
all seven now have the same `AppliesTo` (Behavior + Operation) as
`Validation`/`Verification` and were verified live in EA on 2026-08-27
(the resource tree now shows two variants per stereotype correctly). The
extractor assigns them to the label `:Validation` (matching the
`generalizes="Validation"` in the profile) and writes the concrete stereotype name into
the property `method`. ⚠ Still open: according to
`baseStereotypes`, the profile theoretically also allows an assignment to `Verification` — if
in practice elements with e.g. `Simulation` are meant as verification evidence (not
validation), this rule has to be adapted in the extractor. That
is a domain assignment question, no longer an EA import question, and stays open until
the first real XMI test export.

**Requirement.level for existing data.** The 40 existing `:Requirement` nodes
currently have no `level` property (neither 'customer' nor 'system'). The pipeline
sets `level` only on nodes that are actually merged via an EA requirement stereotype —
existing data stays untouched until it is either maintained manually
or touched by a future EA merge.

## 5. New uniqueness constraints

See `ea_new_labels_constraints.cypher` — one `IS UNIQUE` constraint on `id` each
for `CustomerNeed`, `TestCase`, `TestCaseDescription`, `TestScenario`,
`Validation`, `Verification`.

## 6. Test export for parser verification

To check `ea_xmi_extract.py` against real EA output, a small
test package in EA is enough, with e.g.:

- one element each with stereotype `Customer Need`, `System Requirement`,
  `Function`, `Logical Element`, `Product Element` (ideally 3 of them in
  a composition, to test the Artifact/Assembly/Part derivation),
  `Process Element`
- 2–3 dependency relationships between them, e.g. `Derives`
  (Customer Need → System Requirement), `Satisfies` (Product Element →
  System Requirement), `Realizes` (Logical Element → Function)
- one element with stereotype `Verification` or `Simulation`

Export via *Project ▸ Model Exchange ▸ Export Package as XMI*, format
"XMI 2.1", applied to the test package. Then check the parser against the file
and record specifically what is still missing.

## 7. Return path: Neo4j → EA (bootstrap export)

**Script:** `neo4j_to_ea_export.py` (2026-08-28). Reads the Neo4j graph read-only
and produces an XMI 2.1 file in the same, verified dialect that
`ea_xmi_extract.py` reads in — for import into EA via *Project ▸ Model
Exchange ▸ Import Package from XMI*. Not a return path in the sense of reversing
`ea_to_neo4j_load.py` — nothing in Neo4j is changed.

**Scope (decided with the project owner):** full graph, no filtering. All
currently 267 base elements are thus exported: 43 Artifact + 43 Assembly + 86 Part
(all chained via `HAS_COMPONENT` into a three-tier composition), 8
Function, 8 SolutionPrinciple, 55 Process, 24 Requirement. Plus 131
composition edges and 333 relationships (26 `REALIZES_FUNCTION`, 44
`REALIZES_PRINCIPLE`, 263 `SATISFIES_REQUIREMENT`). `CustomerNeed`, `TestCase`,
`TestCaseDescription`, `TestScenario`, `Validation`, `Verification` are prepared in the
script, but currently yield 0 rows (no existing data — these labels
were only introduced for the EA integration).

**Requirement level (derived structurally, not guessed):** all 24
existing `:Requirement` nodes are exported as **System Requirement**.
Rationale: every single one has a `SPECIFIED_BY` edge to a
`:Specification` with a quantified value (`valueNumber`/`unit`/
`toleranceMin`/`toleranceMax`) or a role text such as "engineering target
(unvalidated)"/"engineering criterion (unvalidated)". That is the structural
signature of already formalised, technically derived requirements — not
that of raw, unformalised customer wishes. There is not a single `:CustomerNeed`
node in the existing data that could serve as a counter-check, and
no requirement deviates structurally from this pattern (no case with a
missing or purely qualitative `SPECIFIED_BY` link) — so the assignment
is uniform for the entire current data and not borderline. `requirementType`
(e.g. "performance", "sustainability") and `priority` (must/should) were checked
and provide **no** usable customer/system distinguishing feature, since they represent
a different classification axis.

**Known, deliberate gaps (Neo4j properties without a tag in the RFLPV2 profile):**
Function.input/output/constraintText, SolutionPrinciple.physicalPrinciple/
status, Process.technology/geographicalLocation/dataAcquisition/status/source/
sourceDatabase/referenceYear, Artifact/Assembly/Part.variant(Family)/
manufacturer/mass_g/opening_mm/tcp_mm/evidenceLevel/validationRequired/
description/status, Requirement.requirementType/statement/priority/status.
These properties remain unchanged in Neo4j but do not appear in the EA model.
Special case `priority`: Neo4j holds it as a string enum ("must"/"should"),
but the profile tag `requirementPriority` is of type `Real` — without an invented
scale there is no lossless 1:1 conversion, hence deliberately left empty.
Free text such as `Requirement.statement` currently has no verified target in the
XMI dialect (EA notes encoding when **writing** has never been checked empirically
in this pipeline, it was never needed when reading) — deliberately omitted
instead of guessing an untested XML structure.

**Self-test (2026-08-28, without Neo4j connection):** `build_xmi()` was called offline
with the already verified `rflpv2_merge_test.xml` scenario (FUNC_GRASP,
SP_PARALLEL, ART_CUSTOM→ASSY_CUSTOM→PART_CUSTOM_CONTACT with `materialRef`,
REQ_COMPAT, Realizes, Satisfies) as mock data. Result: (1) XML
well-formed (`ElementTree.fromstring` successful), (2) the generated file
then run through `ea_xmi_extract.py` itself — correct
Artifact/Assembly/Part depth derivation, correct `materialRef`, correct
`level=system`, both dependencies resolved correctly. The
XMI generation is thus verified as structurally consistent with the rest of the pipeline.
**Not yet verified:** a real import of the generated file
into EA itself (still pending, see the warning below).

**⚠️ Important before the real import:** EA's XMI import matches elements only via
their GUID (`xmi:id`), not via business keys. The script assigns
deterministic IDs (`EAID_<BusinessKey>`), but `rflpv2.qea` already has FUNC_GRASP,
SP_PARALLEL, ART_CUSTOM/ASSY_CUSTOM/PART_CUSTOM_CONTACT, REQ_COMPAT created by
hand, with their own random GUIDs — an import into the same project
would create duplicates for these elements instead of merging. Recommendation:
import into a **new, empty EA project** (with the RFLPV2 profile imported), in order
to mirror the actual state of the graph cleanly; `rflpv2.qea` remains the separate
hand-built test project.

**Diagram generation (2026-08-28, added on explicit request; imported live into
EA and confirmed).** The format (`<xmi:Extension>`/`<diagrams>`,
`DUID`-based linking of shape to edge via `EOID`/`SOID`) was verified
character by character against `rflpv2_package.xml`, including the edge direction
(`SOID`=start, `EOID`=end — for composition `SOID` points to
the child, `EOID` to the parent, the same rule as for the
`aggregation="composite"` end in `<uml:Model>`). **Confirmed:** the bare
`<diagrams>` block suffices on import even *without* the accompanying, highly
redundant `<elements>`/`<connectors>` bookkeeping blocks that EA's own
exporter writes in addition — the first import test (a single diagram
with all 730 elements/edges) visibly worked.

**Split into 7 diagrams (2026-08-28, second iteration, following a sketch by the
project owner).** One diagram with 730 shapes/edges was technically correct but,
as expected, unwieldy. New structure: 1 requirements diagram +
6 BDD diagrams (Functions, Logical Elements, Product Structure, Processes,
Test Cases, Test Scenarios) — each with its own row-grid layout,
`DIAGRAM_SPECS` in `neo4j_to_ea_export.py`. Only the Product Structure
diagram draws edges (the `HAS_COMPONENT` composition chain) — every
dependency relationship in this data model (`Realizes`, `Satisfies`, ...)
connects two *different* categories and can therefore not be drawn on any of the
strictly single-category diagrams; the edges still exist completely in the model,
just not as a line on one of the 7 diagrams. For the cross-category relations
the project owner instead wants **relation tables** between the diagrams (sketch: arrows
between the diagram "boxes", labelled "Relations-Table") — presumably
EA's built-in feature *View ▸ Relationship Matrix* (source/target type +
connector type configurable). Deliberately NOT script-generated: a
relationship matrix is created by hand in EA in seconds, its
XMI storage format was never verified against a real export — the
effort/risk ratio clearly argues for doing it manually rather than guessing
another untested XML structure. Confirmed by the project owner.

**`Applies` (added 2026-08-28).** The Prod.↔Proc. arrow from the sketch
gets a dependency stereotype of its own, `generalizes="SysML1.4::allocate"`
(the same reliable pattern as `Realizes`/`Refines`/`Requires`) — maps to
the already existing `APPLIES_TO` relationship (Process→Part, see
`r_1_APPLIES_TO_Process_TO_Part.csv` in `lca_bulk_load/`). Rationale from the project owner:
"After all, our Neo4j model is ultimately supposed to be importable from EA
(EA→Neo4j). That is the use case in our user story." Profile/toolbox/MDG
(v010), `ea_xmi_extract.py` (override
`("Applies", "Process Element", "Product Element") → "APPLIES_TO"`) and
`neo4j_to_ea_export.py` (new `DEPENDENCY_SPECS` entry) are adapted and
verified by an offline round-trip self-test (generated Applies edge →
extractor → correctly classified as `ea_rel_APPLIES_TO.csv`) **and confirmed live in
EA** — it can be drawn from both the profile and the toolbox
between Process Element and Product Element. The real
`neo4j_to_ea_export.py` run against the production instance delivered 196
`APPLIES_TO` edges (271 nodes, 129 composition edges, 526 relationships
in total = 25+43+262+196), all 7 diagrams + `Applies` thus fully
verified end-to-end.
