# RFLPV² sustainability extension: specification, profile draft, example instance

The tool-neutral reference for the sustainability layer DECODE adds to the RFLPV²
SysML profile (HNI's Requirements–Functional–Logical–Product–Verification approach
for CPS engineering): which tags and stereotypes were added or renamed, how each of
them maps to the Neo4j knowledge graph, and which parts are implemented,
documented-only, or still open.

> **Status:** `RFLPV2_Extension_Spec.md` is the consolidated, final specification as
> of 2026-08-29. It is currently **German** (English translation pending). The two
> XML files are the **early best-effort XMI draft** of the profile and an example
> instance derived from it; the draft was not tested against a live Enterprise
> Architect instance (see §9 of the spec). The profile that *was* built and validated
> in EA lives one level up:
> [`RFLPV2_Extension_Profile_V009.xml`](../RFLPV2_Extension_Profile_V009.xml),
> [`RFLPV2_Toolbox_v003.xml`](../RFLPV2_Toolbox_v003.xml) and
> [`RFLPV2_MDG_v010.xml`](../RFLPV2_MDG_v010.xml).

## Files

| File | Role |
|---|---|
| `RFLPV2_Extension_Spec.md` | The specification: the `Physical Element` → `Product Element` rename and its new tags (`materialRef`, `realizationType`); the sustainability tags on `System Requirement`; the tag semantics of `Process Element`; the verification layer (`Test Case`, `Test Case Description`, `Test Scenario`); the SysML ↔ Neo4j mapping table with status markers (✅ implemented · 🕓 documented target state · 💡 open proposal); and the limits of importing an XMI profile into EA. |
| `RFLPV2_Extension_Profile.xml` | Early UML 2 / XMI 2.1 draft of the extension profile, with tags modelled as regular `uml:Property` elements (Cameo style). For use in EA, the V009 profile / v010 MDG one level up supersede it. |
| `RFLPV2_Example_Model.xml` | Example instance model for the draft profile: aluminium gripper jaw → extrusion process → GWP requirement → limit-check test case. Its header comment (German) states that `processRef`, `materialRef`, the part/requirement IDs and the threshold value are plausible but **unverified placeholders** that must be matched against a live graph before use. |

## How it connects to the rest of the repository

- **Neo4j side:** the verification chain of spec §6 (`TestCase` → `Assessment` →
  `ImpactResult`) is implemented in
  [`model_extension/migrations/demonstrator/`](../../model_extension/migrations/demonstrator/);
  the mapping table in §7 names the graph property each SysML tag lands in.
- **EA side:** the profile, toolbox and the EA ⇄ Neo4j scripts are described in the
  [parent README](../README.md) and in [`ea_to_neo4j_mapping.md`](../ea_to_neo4j_mapping.md).
