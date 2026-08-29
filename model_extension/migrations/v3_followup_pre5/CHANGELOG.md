# PRE-5 — ImpactCategory hygiene · change log

## 2026-08-27

`migration_pre5.cypher`

### Problem

The graph carried **two parallel EF3.1 category sets**:
- **method-slot nodes** (`HAS_CATEGORY` from `IAM_EF31`, but 0 `CHARACTERIZES`
  factors, torn `indicator`/`unit` fields) — e.g. `IC_EF_ECOTOX_FRESHWATER`,
  `IC_EF_HUMANTOX_CANCER`, `IC_EF_CLIMATE_FOSSIL`, `IC_EF_RESOURCE_FOSSILS`.
- **factor-bearing nodes** (the real characterisation factors, **not** attached
  to the method) — `IC_EF_ECOTOXICITY_FRESHWATER` (863),
  `IC_EF_HUMAN_TOXICITY_CANCER` (291), `IC_EF_CLIMATE_CHANGE_FOSSIL` (33) …

So `lca_generic` computed only 7 categories (those with both the method link
**and** factors on the same node).

### Fix

12 merge groups: keep the factor-bearing node, fold the slot node into it with
`apoc.refactor.mergeNodes({properties:'discard', mergeRels:true})` (carries
`HAS_CATEGORY` + `FOR_CATEGORY`, deduplicates). Then normalise
`name`/`indicator`/`unit` on 19 canonical nodes; attach `IAM_EF31` to the full
canonical midpoint set.

### Result

| | before | after |
|---|---:|---:|
| `ImpactCategory` (excl. ReCiPe) | 44 | **29** (15 slots absorbed) |
| EF3.1 categories with factors | 7 | **19** |
| `CHARACTERIZES` total | 27 769 | 27 589 (−180 = dedup on the merged toxicity/resource nodes, 0.6 %) |

**The 7 computing core categories** (climate, acidification, marine
eutrophication, land use, ozone depletion, particulate matter, photochemical
ozone) are **unchanged** — no factor loss there. `lca_generic('IAM_EF31')` now
returns 19 categories per gripper.

*(A later LCI-hygiene cleanup, C1/C2, removes 8 further orphan categories → 21;
see `../v2_data/lci_hygiene/`.)*

### Affected methods

All multi-category LCIA methods (LCA, ReCiPe/CML load). Prerequisite for full
EF3.1 category coverage. No effect on CF (climate only), MCI, repairability.

### Rollback

Not automatic (the merge is destructive) — restore from a snapshot. The
core-category factors are demonstrably untouched.
