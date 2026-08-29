# v1 (black box) — change log

## 2026-08-27 — Repairability formalised + concrete indicators

Migration: `migration_v1.cypher` · base query: `repairability.cypher`
Pre-fix: `../_fixes/fix_generic_materials.cypher`

### Artifacts touched

| Artifact | Change | Kind |
|---|---|---|
| `HAS_COMPONENT` (edge) | new properties `connectionType`, `reversible`, `toolless`, `evidenceLevel`, `evidenceRef` — set on all 129 edges | additive rel property |
| `Artifact` (node) | new properties `disassemblyReversibility`, `componentCount`, `distinctMaterialCount`, `toollessRobotInterface`, `replaceableContactElement`, `repairabilityClass`, `repairabilityMethod` — on all 43 nodes | additive node property (literal, computed) |
| `HAS_PROPERTY` → `CP_DISASSEMBLY` | added for the 5 missing artifacts (38 → 43) | catalogue completion |
| `Process PROC_SCREW` | *read*, not changed — its `joiningType` moved onto `HAS_COMPONENT` | source |
| `MAT_*_GENERIC` (5 material nodes) | CSV column offset fixed: `name`, `materialType='metal'`, `density_kg_m3` set, `recycledContent_pct=NULL`, `dataQualityNote` | data correction (pre-existing) |

### Result

`repairabilityClass` distribution over 43 artifacts: **A = 1, B = 12, C = 30.**
`disassemblyReversibility` = 1.0 throughout (every build type is fully
separable — screw or magnet quick-change). The spread today comes solely from
the features `FEAT_EASY` (toolless, 5×) and `FEAT_PRINTABLE` (replaceable jaws,
9×); a finer spread only emerges once non-separable joins (e.g. glued contact
pads) are modelled as their own connections.

### Affected methods (change-→-method matrix)

| Change | needed by | used by | reported in |
|---|---|---|---|
| `HAS_COMPONENT.connectionType/reversible` | repairability/disassembly (v1) | circularity/MCI (v3.a — material separation / recycling yield); consequential LCA / EoL routes (v3 — reuse/remanufacture) | Digital Product Passport (v3.d) |
| `Artifact.repairabilityClass` and other indicators | repairability (v1) | circularity/MCI (v3.a — `componentCount`, `distinctMaterialCount`) | EPD/DPP (v3.d) |
| `MAT_*_GENERIC` fix (`density_kg_m3`, `recycledContent_pct`) | every inventory-based method from v2 on (volume→mass conversion); circularity/MCI (v3.a — `recycledContent` must not be a null value) | — | — |

### Rollback

See the comment block at the end of `migration_v1.cypher`. All changes are
`REMOVE`- / `SET`-reversible; no nodes or edges deleted.
