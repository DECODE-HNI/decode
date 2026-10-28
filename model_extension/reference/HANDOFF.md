# Project context: Niryo Ned2 gripper sustainability knowledge graph

As of 2026-08-29. All file paths are relative to the root of this repository.

---

## 1. What this is about

PhD case study: a Neo4j knowledge graph models a Niryo Ned2 robot gripper
(product structure, functions, material, processes) and links it to life cycle
assessment data (ILCD/EF3.1, ReCiPe 2016) in order to make sustainability assessments
feasible and **method-agnostic**. Two parallel work strands:

- **Neo4j side** — the knowledge graph model itself (nodes/edges, data import
  from ILCD sources, staged build-out, assessment layer).
- **MBSE side** — a SysML profile extension (RFLPV²) in Enterprise Architect
  that defines how product developers capture the required sustainability data in a
  structured way so that it can later flow into the Neo4j model.

The systematically elaborated solutions are in this repository (layout
see section 6).

## 2. Current Neo4j model state

**Live DB (Neo4j Desktop, 2026-08-29, after all stages + consistency review
layers 1–4 + AI removal):**

| Metric | Value |
|---|---:|
| Nodes | **5,620** |
| Relationships | **86,635** |
| Node labels | 39 |
| Relationship types | 54 |
| Uniqueness constraints | 39 (+ `flow_casnorm` index, 42 indexes in total) |

0 label-less nodes · 0 duplicate nodes · 0 orphaned/valueless `ImpactResult` ·
all parts with mass. The authoritative as-built state is always the live DB; the
consolidated reference for it is
[`model_extension/reference/EXTENSION_REFERENCE.md`](EXTENSION_REFERENCE.md),
the machine-readable schema is
[`model_extension/reference/graph_schema_v3x.json`](graph_schema_v3x.json)
(93 keys).

### Development stages (strictly additive, non-breaking — that *is* the proof of flexibility)

| Stage | Box | Core | Migration |
|---|---|---|---|
| **v1** | black | product model + concrete indicators + repairability formalised | `model_extension/migrations/v1_blackbox/` |
| **v2** | grey | ILCD/EF3.1 inventory + calculation core `ImpactResult.value`; aluminium A1 path | `model_extension/migrations/v2_greybox/` |
| **v3** | white | `lca_generic($methodId)`, functional unit, EN 15804 modules, `AssessmentApproach` taxonomy | `model_extension/migrations/v3_whitebox/` |
| **v3.a–e** | modules | circularity (MCI) · cost/MFCA · scenario/uncertainty · provenance + EPD/DPP · ReCiPe 2016 (2nd LCIA method) | `model_extension/migrations/v3x_{a..e}_*/` |
| **v3.f–i** | modules | GHG scopes · pollutant screening · cross-impact · advanced LCA hooks · external frameworks · self-describing KG | `model_extension/migrations/v3x_nonlcia/` |
| **v2-data** | data | part masses (86), manufacturing energy, material GWP; variants A (real ILCD datasets, standard from v3) / B (literals) | `model_extension/migrations/v2_data/` |
| **PRE-5 / LCI hygiene** | data maintenance | ImpactCategory canonicalisation, CAS/unit/compartment clean-up | `model_extension/migrations/v3_followup_pre5/`, `v2_data/lci_hygiene/` |
| **DQ concept** | methodology | data quality criteria inherent/system-related (0..4), `DQPhase` gates, auto-DQ from edge metadata | `model_extension/migrations/dq_concept/` (01–03) |
| **Demonstrator** | artefacts | sustainability `Requirement`s + `TestCase` verification chain (RFLPV² §6) + EPD/DPP status lifecycle + scenario coverage, 8-gripper slice | `model_extension/migrations/demonstrator/` (00–04) |
| **Consistency review** | QA | 4 layers, read-only harness, every change documented | `model_extension/migrations/consistency/` |

### Assessment methods in the graph (6)

`IAM_EF31` (Environmental Footprint 3.1, 19 categories, computes) ·
`IAM_PCF` (Product Carbon Footprint, screening) ·
`IAM_RECIPE` (ReCiPe 2016 Midpoint H, 18 categories, 16 compute) ·
`IAM_MCI` (Material Circularity, simplified, computes) ·
`IAM_REPAIR` (repairability v1, computes) ·
`IAM_GHG` (GHG accounting by scope, GHG Protocol).

All **23 approaches** of the method diagram (3 paradigms / 7 groups) are addressable as
`AssessmentApproach` nodes; one-pagers in
[`methods/onepagers/`](../../methods/onepagers/). Base queries per approach in
[`methods/base_queries/`](../../methods/base_queries/).

### Flexibility analysis against four assessment methods

Full document:
[`model_extension/reference/Sustainability_Assessment_Flexibility_Analysis.md`](Sustainability_Assessment_Flexibility_Analysis.md).
The assessment layer
(`Assessment`→`USES_METHOD`→`ImpactAssessmentMethod`→`HAS_CATEGORY`→`ImpactCategory`)
is method-agnostic — new methods need no schema change. Of the five additive gaps
originally identified, the largest has been implemented; four remain as a
**documented forward list** (none breaks existing content):

1. ~~`Process.lifecycleModule` (EN 15804 code)~~ — **live** on all 58
   `Process` nodes since v2 (`A1`, `A1-A3`, `A3`, `B1`, `B4`, `C3`), evaluated by the
   DQ layer. Consistency review layer 4 (DE-01) corrected the outdated "documented
   only" statement in the spec and the handoff.
2. Declared functional unit as a node of its own (missing for LCA and EPD
   alike; currently only an `Assessment` property).
3. Extend `Assessment --ASSESSES-->` from `Artifact` only to also
   `Part`/`Material`/`Process`/`ProcessPlan`.
4. Generic traceability edge `ImpactResult --BASED_ON-->
   (Feature|CoreProperty|DataItem)` — partly there (57 edges, v3.d), not yet
   consistent for non-LCI-based results.
5. Pure property additions: recyclability/reusability
   (`Material`, partly there), service life/usage intensity (`Artifact`),
   joining type/reversibility (`Feature`/`HAS_COMPONENT`).

### AI/ML paradigm — removed (2026-08-29)

The paradigm "learning approaches" was only intended as a docking point (approaches
3.1.x/3.3.x, `PredictionModel`/`Recommendation`, `PREDICTS`/`ESTIMATED_BY`/`RECOMMENDS_FOR`,
`ASSESS_AI_PREPARED`) and was removed completely from the graph and the docs as being
outside the case-study scope —
`model_extension/migrations/consistency/remove_ki_stubs.cypher` (with rollback block).
Kept: the `AP_LEARNING` root + `APG_MODEL_TRANSPARENCY` + `APM_DPP` + `APM_ENV_KG`
(real, not AI) as well as `ImpactResult.provenance`/`.confidence` (general).

## 3. Consistency review (4 layers, completed 2026-08-29)

Read-only harness under
[`model_extension/migrations/consistency/`](../migrations/consistency/). Every finding
is triaged with the user (fix now / defer / accept + document) and recorded in
`FINDINGS.md` / `CHANGELOG.md`.

| Layer | File | Result |
|---|---|---|
| **1 methodical building blocks** | `check_meta.cypher` | done — live count vs. reference docs/schema |
| **2 model consistency** | `check_model.cypher` (+ `_oneshot`) | done — 8 findings (F-01…F-10); fixes `fix_F02/F03/F05_*.cypher`, rest accepted |
| **3 tool consistency** | `check_tools.sh` + `check_tools_drift.cypher` | done — 43 PASS / 0 FAIL / 1 by-design skip; 1 finding **F-11** (ReCiPe CF importer not idempotent against the post-hygiene graph — accepted + documented, baseline pinned) |
| **4 logical DECODE embedding** | `check_decode.cypher` (+ `_oneshot`) | done — 21 structural checks pass; **DE-01** (spec §7 on `lifecycleModule` corrected), **DE-02** (2 `ExternalFramework` nodes added, `fix_DE02_framework_nodes.cypher`) |

Layer 4 is **not** a software integration test — it checks that the graph is a
faithful **logical** target for the RFLPV² profile (`RFLPV2_Extension_Spec.md` §7)
and for the reporting frameworks.

The two `*_oneshot.cypher` variants run without the browser's multi-statement
setting: paste the whole file, run it once — an empty result table = clean.

## 4. Snapshots

`snapshots/` (only in the maintainer's working copy, not in the repository) —
end state as a restorable export:

- `graph_full_2026-08-29.cypher` (~34 MB, `apoc.export.cypher.all`, format
  `cypher-shell`) — can only be loaded into an **empty** DB.
- `graph_full_2026-08-29.graphml` (~48 MB) — for Gephi / yEd / `neo4j-admin import`.
- `schema_2026-08-29.json` (~130 KB) — pure structure, no values.

⚠️ The two large dumps re-express the inventory data base derived from licensed ILCD
datasets and **must not go into the Git repo** (licence). For the APOC file exports,
`conf/apoc.conf` (`apoc.export.file.enabled=true`) is in the DBMS instance; it takes
effect after a DBMS restart.

Real per-stage dumps cannot be created retroactively — the reproducible stage path is
the migration chain (each stage with its own `CHANGELOG.md`).
The only real intermediate dump: `model_extension/migrations/v1_blackbox/v1_snapshot.cypher`.

## 5. RFLPV² SysML profile extension (Enterprise Architect)

Goal: extend RFLPV² (Requirements-Functional-Logical-Physical/Product-Verification,
HNI approach for CPS engineering) with a sustainability dimension — materials/
processes as lightweight properties instead of new stereotypes, the Process Element as
anchor for the life cycle concept, EN 15804 module reference, test case concepts from the
Ebel/Pottebaum/Graessler paper (ISSE 2024).

Complete, final specification:
[`ea_neo4j_pipeline/profile_spec/RFLPV2_Extension_Spec.md`](../../ea_neo4j_pipeline/profile_spec/RFLPV2_Extension_Spec.md).

Key contents:
- Physical Element renamed → **Product Element**; new tag `realizationType`
  (hardware/software/hybrid).
- `materialRef` as **String[0..*]**.
- System Requirement + `sustainabilityIndicatorRef`, `sustainabilityThreshold`,
  `sustainabilityOperator` (enum), `sustainabilityUnit`, `sustainabilityScope`.
- Process Element: `processID` (SysML ID) vs. `processRef` (Neo4j `Process.id`)
  kept apart, `lifecycleModule` (EN 15804 code) as a tag.
- Verification layer + Test Case/Test Case Description/Test Scenario, with
  `sustainabilityResult`/`sustainabilityStatus`.
- §7 mapping table: ✅ live vs. 🕓 documented only. The one 🕓 row still open
  is `REALIZES`/`AFFECTS` (dedicated relationship types instead of
  `APPLIES_TO` + discriminator) — deliberately deferred to the next rebuild.

### EA implementation state (last recorded state 2026-08-27)

Profile rebuilt as a standalone SysML extension in EA (25 stereotypes, reconciled
against the original Cameo profile), 2 enumerations, 3 local PrimitiveTypes, all 5
generalisation groups drawn manually. Files: the EA-validated profile
`ea_neo4j_pipeline/RFLPV2_Extension_Profile_V009.xml` (with `RFLPV2_Toolbox_v003.xml`
and `RFLPV2_MDG_v010.xml`); `ea_neo4j_pipeline/profile_spec/RFLPV2_Extension_Profile.xml`
is the early draft, `RFLPV2_Example_Model.xml` there the instance example (header
comment marks real vs. placeholder IDs).

**Last open blocker:** the profile registered via `Resources → UML Profiles → Import
Profile` did not appear in the `Profile:` dropdown of the stereotype assignment dialog;
the example model could be imported, but without stereotype assignment. Pragmatic
fallback (not yet confirmed): type the stereotype name directly into the "Stereotype"
text field in the Properties window. The pipeline side (`ea_neo4j_pipeline/`) is
independent of this and verified.

## 6. Repository layout and conventions

| Repo path | Content |
|---|---|
| `model_extension/migrations/` | ordered, additive Cypher migrations (v1 … v3.x, DQ concept, demonstrator, consistency review) |
| `model_extension/reference/` | reference documentation, assumptions, schema, change-methods matrix, flexibility analysis, this document |
| `methods/onepagers/`, `methods/base_queries/` | one-pager and base query per assessment approach |
| `lca_bulk_load/` | ILCD/Sphera bulk load (channel A/B), single-package importer |
| `ea_neo4j_pipeline/` | RFLPV²/EA pipeline, incl. `profile_spec/` (specification, profile draft, example model) |
| `aas_interface/`, `dashboards/` | AAS exchange (white/grey/black box), NeoDash dashboards |

**Conventions:**
- No personal data, secrets, tokens, personal e-mail addresses,
  machine-specific paths or instance IDs.
- Scripts read the Neo4j access only from `NEO4J_URI` / `NEO4J_USER` /
  `NEO4J_PASSWORD`, never as an argument.
- **No** concrete ILCD datasets from licensed products — not even as
  generated import Cypher (`import_MAT_*.cypher`) or as a
  `snapshots/graph_full_*` dump. Only the pipeline + a synthetic example;
  the pipeline runs locally against your own downloads.
- A `README.md` per folder, in English (concept → data shape → reproduction,
  with a `> **Status:**` blockquote whose numbers are checked against a running
  instance).
- All repository content is English.

## 7. Access to the live DB

Directly via the `cypher-shell` bundled with Neo4j Desktop
(`bolt://localhost:7687`), not via an MCP server. Credentials only via
the environment variables `NEO4J_URI` / `NEO4J_USER` / `NEO4J_PASSWORD`, never on
disk. Example:

```bash
export NEO4J_URI=bolt://localhost:7687 NEO4J_USER=neo4j NEO4J_PASSWORD=...
cypher-shell -a "$NEO4J_URI" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" -f some_query.cypher
```

APOC 2026.07.1 (`apoc.meta.schema`, `apoc.export.cypher.all`,
`apoc.export.graphml.all`); `apoc.config.get`/`apoc.config.list` are **not**
available in this version.

## 8. Further documents

- `model_extension/reference/EXTENSION_REFERENCE.md` — consolidated schema/query/status reference
- `model_extension/reference/methods_change_sets.md` — change set per approach
- `model_extension/migrations/PLAN.md` — stage plan, snapshot procedure, status
- `model_extension/migrations/RUN_2026-08-27.md` — log of the first autonomous run (partial state)
- `ea_neo4j_pipeline/profile_spec/RFLPV2_Extension_Spec.md` — RFLPV² specification
