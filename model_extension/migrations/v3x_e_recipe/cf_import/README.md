# ReCiPe 2016 characterisation-factor import

Module v3.e added the second LCIA method `IAM_RECIPE` (ReCiPe 2016 Midpoint,
Hierarchist) with its 18 `ImpactCategory` nodes, but filled characterisation
factors for climate only (as EF3.1 GWP x 1.06). This folder fills the rest.

> **Status:** 16 of 18 ReCiPe categories carry factors. 2045 `CHARACTERIZES
> {method:'IAM_RECIPE'}` edges over the flows the graph actually uses; 43
> `ASSESS_RECIPE_A_*` assessments + 688 `IR_RECIPE_*` results (16 categories x
> 43 grippers). Fossil resource scarcity and land use stay structural (see
> *Known gaps*). Verified against a live Neo4j 5 instance, 2026-08-29.

## Concept

`lca_generic.cypher` is method-agnostic: it keys on `$methodId ->
HAS_CATEGORY -> CHARACTERIZES`. So a fully populated second method is purely a
data task — attach `CHARACTERIZES {factor}` edges from the graph's `Flow` nodes
to the `IC_RECIPE_*` categories, and every downstream query (LCA, hotspot,
robustness, DPP) can compare EF3.1 against ReCiPe with no code change.

## Data shape

Source: the free **openLCA "LCIA Methods" package** (GreenDelta, JSON-LD ZIP),
method `ReCiPe 2016 Midpoint (H)` — 130 210 factors keyed by openLCA flow
UUID + name + compartment, most carrying a CAS number. The package is **not**
redistributed here; download it and pass it with `--openlca-zip`. Only the
factors for flows already in the graph are written to the database.

`import_recipe_cf.py` matches each graph `Flow` to a ReCiPe factor:

| category class | flows | match rule |
|---|---|---|
| robust — GW, OD, IR, OF_HH, OF_EC, PM, TA, FE, ME | by **CAS**; value = median of the CFs whose compartment bucket equals the flow's modal `HAS_FLOW.compartment`, else the category's dominant medium (air, or water for FE/ME) |
| strict — TET, FET, MET, HCT, HNCT (USEtox) | by **CAS and compartment**; no fallback — an air CF must not stand in for a water or soil emission |
| resource — MRS | by normalised **flow name**; only flows booked purely in `kg` |

Region-suffixed package copies (`Ammonia, RER`, `Ammonia, US`, ...) are
discarded — only the global CF per substance is used (e.g. NH3 -> terrestrial
acidification 1.96, SO2 -> fine particulate matter 0.29).

Each edge carries `method:'IAM_RECIPE'`, `derived:true`, `source`, and
`matchedBy` (`CAS+air`, `CAS+water`, `CAS+air-fallback`, `name`, ...).

## Reproduction

```bash
# 1. export the flow list the matcher needs (flowId, CAS, name, compartments, units)
cypher-shell -a "$NEO4J_URI" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
    --format plain -f export_flows.cypher > db_all_flows.tsv

# 2. generate the additive migration (Bolt creds are only needed for --read-db / --load)
python import_recipe_cf.py \
    --openlca-zip "openLCA LCIA Methods 2.7.3 2025-03-07.zip" \
    --flows db_all_flows.tsv \
    --out recipe_cf.cypher \
    --supersede-gw          # replace the v3.e EF3.1x1.06 climate factors with real ReCiPe GW CFs

# 3. apply it, then persist per-gripper results
cypher-shell ... -f recipe_cf.cypher
cypher-shell ... -f refresh_recipe.cypher
```

`import_recipe_cf.py --read-db --load` does steps 1–2 and the apply in one go
via the Bolt driver (`pip install neo4j`). Everything is strictly additive and
re-runnable: an existing `(f)-[:CHARACTERIZES]->(ic)` is never overwritten, and
the `characterizesId` MERGE key makes a second run a no-op.

The generated `recipe_cf.cypher` carries real ReCiPe 2016 factor values from the
openLCA pack and is therefore **not** committed (`.gitignore`d). Only
[`recipe_cf.EXAMPLE.cypher`](recipe_cf.EXAMPLE.cypher) — a synthetic, ~8-row
shape example with invented UUIDs and placeholder factors — is in the repo.

## Reproducibility note (consistency review, finding F-11)

This importer is **not idempotent against the current graph**, because the
LCI-hygiene unit split and the CAS normalisation reshaped `Flow` / `HAS_FLOW`
*after* the CF layer was built. Re-running `--read-db` today reconciles
**2013 of 2048** persisted `IC_RECIPE_*` `CHARACTERIZES` pairs exactly; the rest:

- **35 `IC_RECIPE_IR` CFs cannot be regenerated.** The radionuclide flows
  (`carbon-14`, `cesium-137`, …; unit `kBq`; one `Flow` node per compartment)
  now have `HAS_FLOW.compartment = NULL`. `export_flows.cypher` reads the bucket
  only from `HAS_FLOW.compartment`, and `choose()` has no dominant-compartment
  fallback for IR, so a re-run buckets only 1 of 36. The persisted CFs and the
  `IC_RECIPE_IR` results computed from them stay valid (the Layer-3 drift check
  is clean) — they are simply frozen against an importer that can no longer
  produce them.
- **17 CFs a re-load would newly add**, all on flows that post-date the CF load:
  5 × `IC_RECIPE_FRS` on the unit-split mass siblings `crude oil#u=kg` /
  `natural gas#u=kg` / `hard coal#u=kg` / `brown coal#u=kg` / `peat#u=kg` via
  `RESOURCE_ALIASES`, plus 1 `MRS` (`uranium#u=kg`), 1 `WC` (`water`), and
  10 USEtox (`dichloromethane`, two `Flow` nodes).

**Decision (accepted, 2026-08-29):** no change now. The persisted ReCiPe CF
layer is internally consistent and every result derived from it is correct; a
full graph rebuild runs this importer *after* the hygiene pass and regenerates
cleanly. `consistency/check_tools.sh` §4 pins the 2013 / 35 / 17 baseline so the
gap stays visible if it grows.

## Known gaps

- **Fossil resource scarcity (`IC_RECIPE_FRS`)** — historically the fossil
  resource flows (`crude oil`, `natural gas`, `hard coal`, ...) were booked in
  **mixed units** on one shared `Flow` node, so no per-kg CF could attach. The
  LCI-hygiene unit split has since separated the mass siblings
  (`crude oil#u=kg`, ...), and `RESOURCE_ALIASES` in this script *would* now
  populate 5 FRS CFs on a re-run — but these are **deliberately not loaded**
  (see *Reproducibility note* above): the fossil-resource amounts remain
  unreliable (as-kg-labelled MJ upstream) and consistency finding F-08 keeps
  `IC_RECIPE_FRS` at 0 CFs by decision. Still structural in practice.
- **Land use (`IC_RECIPE_LU`)** — the graph carries almost no land-occupation
  flows and the few present have unusable `casNumber` values. Left structural.
- **Water consumption (`IC_RECIPE_WC`)** — thin (7 flows): only water flows
  booked purely in kg match; ReCiPe's WC sign convention rules out name
  matching.
- The USEtox categories (TET/FET/MET/HCT/HNCT) are covered only where a flow's
  compartment is resolvable; blank-compartment emissions are skipped there.
