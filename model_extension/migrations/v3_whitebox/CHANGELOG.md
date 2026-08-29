# v3 (white box) — change log

## 2026-08-27 — ILCD made interpretable & method-exchangeable (v3-minimal, first slice)

Migration: `migration_v3.cypher` · base query: `lca_generic.cypher`
(replaces the hardwired `lca_computed_ef31.cypher` from v2)

### Scope of this slice

| Building block | Content |
|---|---|
| **PRE-2** | `Process.lifecycleModule` (EN 15804) on all 55 processes + casing normalisation of `processType` |
| **PRE-3** | functional unit / reference flow / system boundary formalised on all 48 `Assessment` |
| **PRE-4** | `AssessmentApproach` taxonomy: 3 paradigms / 9 groups / 29 methods + `BROADER` + `APPLIES_APPROACH` *(later reduced to 7 groups / 23 methods by the KI/ML removal — see `../consistency/`)* |
| **`lca_generic($methodId)`** | method-parameterised base query — a new method is pure data, zero schema change |

### Deferred to a v3 follow-up slice

- **PRE-5** ImpactCategory hygiene (~20 orphans / near-duplicates, edge remapping) — does not block the current computation (the 7 computed categories are cleanly linked) but is the riskiest change → done separately.
- **Second full LCIA method** (ReCiPe/CML) — no characterisation data available. Method exchange demonstrated instead with the existing `IAM_EF31` ↔ `IAM_PCF` via `lca_generic`.

### Artifacts touched / new

| Artifact | Change | Scope |
|---|---|---|
| `Process` (node) | `lifecycleModule` + `lifecycleModuleBasis` | 55: A1=32, A1-A3=4, A3=13, B1=1, B4=1, C3=4 |
| `Process.processType` | `~` "End of Life" → "EndOfLife" (casing) | 2 nodes |
| `Assessment` (5 EF3.1) | `systemBoundary` → vocabulary value `cradle-to-gate`, free text moved to `systemBoundaryNote`; + `referenceFlow`, `referenceQuantity`, `referenceUnit` | 5 |
| `Assessment` (43 PCF) | `functionalUnit`, `systemBoundary`, `referenceFlow`, `referenceQuantity`, `referenceUnit` (intent declaration) | 43 |
| **`AssessmentApproach`** (label) | **new** — 41 nodes (3+9+29), `{id,name,level,code}` | 41 |
| **`BROADER`** (relationship type) | **new** — method→group→paradigm | 38 |
| **`APPLIES_APPROACH`** (relationship type) | **new** — assessment→method | 48 (5→"life-cycle assessment", 43→"carbon footprint CO2") |

**Live DB:** 2 802 nodes (+41) / 79 815 relationships (+86).

### Evidence: method exchange (white-box core)

Same aluminium A1 inventory, `$methodId` as a parameter:

| `lca_generic($methodId)` | Result |
|---|---|
| `'IAM_EF31'` | 35 rows (5 grippers × 7 categories), climate values identical to the `ImpactResult.value` stored in v2 |
| `'IAM_PCF'` | 5 rows (climate change only), values identical — **zero schema change** on the method switch |

Example V-groove jaws / Al6061: climate 0.345 · acidification 1.86e-3 ·
marine eutrophication 3.69e-4 · land use 0.307 · photochemical ozone 1.09e-3
(ozone depletion, particulate matter ≈ 0).
*Land use should still be treated with caution (regionalised factors averaged).*

### Affected methods (change-→-method matrix)

| Change | needed by | used by |
|---|---|---|
| `Process.lifecycleModule` | EPD/EN 15804, GHG inventory (module breakdown), MFA | consequential LCA (stage assignment), Digital Product Passport |
| `Assessment.functionalUnit` / `systemBoundary` | LCA, CF, all inventory methods; EPD | comparability check between assessments; eco-efficiency (reference quantity) |
| `AssessmentApproach` taxonomy + `APPLIES_APPROACH` | every method in the diagram (makes each explicitly addressable in the graph) | reporting/navigation |
| `lca_generic($methodId)` | LCA, CF, H₂O, GHG, CED (all via a method filter) | hotspot, scenario/sensitivity analysis (compute on the same query) |

### Rollback

Comment block at the end of `migration_v3.cypher`. Additive apart from the
`processType` casing normalisation (2 nodes, partly reversible).
