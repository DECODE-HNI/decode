# Dataset map: missing ILCD / Sphera datasets per model material

As of 2026-08-28. Purpose: for every material/process in the gripper model that
still has **no real dataset** (currently only a literature literal in Variant B),
name the **designation** under which it can be found in the **Sphera base
database** (*Managed LCA Content* / formerly *GaBi Professional* + *Extension
DB VII: Plastics*) or on a freely accessible **ILCD node**.

## Two user decisions (2026-08-28)

1. **Data variant from v3 on:** the standard is the **ILCD-style representation
   on real datasets** (`dataVariant='A-realdataset'`), backed by Sphera MLC. The
   literal variant (`dataVariant='B-literal'`) stays only as a **base/fallback**
   so every method can compute where no real dataset exists (yet).
2. **Cost dimension stays lean:** only `Material.unitCost` placeholders, **no**
   `CostItem`/`HAS_COST` node model (v3.b variant B is not pursued).

## Done (2026-08-28): 4 real PlasticsEurope datasets loaded

Via the free PlasticsEurope ILCD packages + the `ilcd_import/` pipeline:

| Material | process node | GWP A1-A3 real | was literal |
|---|---|---:|---:|
| `MAT_ABS` | `PROC_ABS_PLASTICSEUROPE_EF` (EU-27, 2010) | 3.14 kg CO₂e/kg | 4.0 |
| `MAT_PC` | `PROC_PC_PLASTICSEUROPE_EF` (EU-25, 2007) | 4.19 | 5.5 |
| `MAT_POM` | `PROC_POM_PLASTICSEUROPE_EF` (EU-27, 2010) | 3.26 | 3.6 |
| `MAT_PA12`/`MAT_PA11` (proxy) | `PROC_PA66_PLASTICSEUROPE_EF` (EU-27, 2011) | 6.48 | 9.0 / 5.5 |

Details: `ilcd_import/CHANGELOG.md`. The rest of the table below is still open.

## Constraint (2026-08-28): Sphera **base version** only

The user has **only the Professional / base database** (no *Extension DB VII:
Plastics*, no *Premium Plastics*). Consequences:

- **Present in the base** (production data, since they feed many product
  systems): PE (LD/LLD/HD), PP, PS (GPPS/HIPS/EPS), PVC, **PET**, **ABS**,
  **PC**, **PA 6**, **PA 6.6** (possibly PA 6.12), PMMA, PUR (rigid/flexible
  foam) + precursors (polyol, MDI, TDI), SBR; plus all **metals**,
  **electricity**, **transport**, **machining/injection moulding**
  (manufacturing).
- **Not in the base** (would need Extension VII / XII / fibre-reinforced):
  **POM, PA 11, PA 12, PLA, PETG-specific, ASA-specific, TPU, TPE variants,
  silicone rubber, NBR, carbon fibre / CFRP**.

**Way out for the missing ones:** the **PlasticsEurope Eco-profiles** are
**licence-independent and free** (EPLCA / soda4LCA node, openLCA import), ILCD
format — exactly the v3 target form. Through them **POM, PC, ABS, PA 6, PA 6.6,
PET, PS, PVC, PP** and others are directly obtainable, even without the Sphera
Plastics extension. The rest (PLA, PA 11/12, ASA, PETG, TPU, TPE, silicone, NBR,
CF-PA) stays a **documented proxy** in Variant A (`proxy:true` +
`proxyRationale`) **or** on the Variant-B literal.

## Naming conventions

**ILCD / PlasticsEurope Eco-profiles** (free via EPLCA / soda4LCA node, e.g.
`plasticseurope.lca-data.com`, `eplca.jrc.ec.europa.eu`) — this is the form
Sphera takes over in aggregated shape:
> `<polymer> granulate (<abbr>); <technology>; production mix, at plant | at producer` · Location `EU-25/EU-27/EU-28/RER`

**Sphera MLC / GaBi** (licensed, search in the Sphera client):
> `<region>: <material> Granulate (<abbr>) <provider>`  ·  provider historically `PlasticsEurope` → `ts` → **`Sphera`**
> region usually `EU-28` (polymers), `DE` (electricity/processing), `GLO` (metals).

In the Sphera client, search for the **abbreviation in brackets** (`(PC)`,
`(POM)`, `(ABS)`) or the plain text and filter for the **most recent reference
year** + the **`Sphera` provider**.

---

## Polymers / elastomers — with the base-version constraint

Column **Source**: `Base` = expected in Sphera Professional · `PE-free` = via the
free PlasticsEurope Eco-profiles (EPLCA/soda4LCA) · `Proxy` = no real dataset,
approximation needed · `Literal` = leave on the Variant-B literal.

| Model id | current GWP literal | Source | Dataset / search name | Note |
|---|---:|---|---|---|
| `MAT_ABS` | 4.0 | Base **or** PE-free | Sphera: `EU-28: Acrylonitrile-Butadiene-Styrene Granulate (ABS) Sphera` · PE-free: `Acrylonitrile butadiene styrene (ABS); … production mix, at producer` — EU-27, 2010 | direct dataset |
| `MAT_PC` | 5.5 | Base **or** PE-free | Sphera: `EU-28: Polycarbonate Granulate (PC) Sphera` · PE-free: `Polycarbonate granulate (PC); technology mix; production mix, at plant` — EU-25 (UUID `c4161063-3fde-4540-ad1c-f2da1828bf7b`) | direct dataset |
| `MAT_POM` | 3.6 | **PE-free** (not in base) | `Polyoxymethylene (POM); 1 kg primary POM "at gate" … Europe-27` (UUID `e3b65970-3420-43e6-8265-131ef3485c27`) | POM only via PlasticsEurope, not in the Sphera base |
| `MAT_PA12` | 9.0 | **Proxy** / literal | proxy: `PA 6` (base/PE-free) × 1.15–1.25 uplift; or EPD Evonik VESTAMID | PA 12 not in base, no free eco-profile |
| `MAT_PA11` | 5.5 | **Proxy** / literal | proxy: bio-PA (`PA 4.10` castor, GLAD) or `PA 6`; else literal 5.5 | bio-based, no free source |
| `MAT_PETG` | 4.0 | **Proxy** | `PET amorphous` / `PET bottle grade` (base/PE-free) as an approximation | no dedicated PETG in the base |
| `MAT_PLA` | 2.7 | Literal / free special source | NatureWorks Ingeo LCI (free, US) or literal 2.7 | fossil proxy pointless; bio dataset or literal |
| `MAT_ASA` | 4.5 | **Proxy** | `ABS` (base) + small acrylate uplift | ASA proxied as ABS by default |
| `MAT_CFPA` | 24.0 | **partial proxy** | matrix: `PA 6` (base/PE-free); fibre: carbon fibre **not in base** → literal ~22–25 kg CO₂e/kg fibre; mass mix ~30/70 | GWP fibre-dominated; fibre share stays a literal |
| `MAT_NBR` | 3.5 | **Proxy** / literal | proxy: `SBR` (if in base) + acrylonitrile uplift; else literal 3.5 | NBR not in base |
| `MAT_SILICONE` | 7.0 | check / literal | in the base possibly `Polydimethylsiloxane (PDMS)` / `Silicone` — else literal 7.0 | base coverage uncertain, check in the client |
| `MAT_TPU` | 5.2 | **Proxy** | `PUR flexible foam` / `PU elastomer` (if in base) as an approximation; else literal | TPU-specific not in base |
| `MAT_TPE` | 4.2 | **Proxy** / literal | `PS`/`SBS` (base) as an approximation; else literal 4.2 | |
| `MAT_PU` (cast elastomer) | 4.5 | **Base** (approximation) | `Polyurethane flexible foam` or `Polyol` + `MDI/TDI` + processing (all base) | PUR chain present in the base |

## Metals, electricity, manufacturing — **all in the base**

The Sphera Professional base covers these areas well; **no extension needed**.

| Model element | base search name | Note |
|---|---|---|
| `MAT_STEEL`, `MAT_SPRING` | `GLO: Steel sections (worldsteel) Sphera` / `EU-28: Steel low-alloyed Sphera` | already `MODELED_BY PROC_STEEL_SECTIONS_ILCD` — check consistency |
| `MAT_AL6061/7075` | `GLO: Aluminium ingot mix Sphera` + `Aluminium extrusion profile Sphera` | already `MODELED_BY PROC_ALU_EXTRUSION_EF` |
| `MAT_*_GENERIC` copper / zinc / lead | `GLO: Copper mix (99.999 %) Sphera` · `GLO: Zinc slab (SHG) Sphera` · `GLO: Lead (99.995 %) Sphera` | metals are fully covered in the base |
| NdFeB magnet (from v3.g cross-impact) | possibly *data on demand*; else proxy Nd + Fe + B + sintering electricity | magnet dataset possibly not in the base |
| `PROC_CNC` (machining) | `DE: Aluminium / steel cutting (milling) Sphera` **or** `DE: Electricity grid mix` + cutting oil + chip loss | the model approach (energyIntensity) is already equivalent |
| Injection moulding (if modelled) | `DE: Plastic injection moulding Sphera` | per kg of moulded part |
| `PROC_FFF`, `PROC_SLS`, `PROC_MJF` | **no dataset — not in the extensions either** | additive manufacturing: keep the `energyIntensity_kWh_per_kg` + electricity approach (Faludi/Kellens) |
| `PROC_RUBBER`, `PROC_SILCAST`, `PROC_OVERMOLD` | electricity + vulcanisation modelled directly | |
| electricity DE (`FLOW_ELECTRICITY`, CF 0.38) | `DE: Electricity grid mix Sphera` (1kV–60kV) | replaces the 0.38 literal |
| electricity "green" (CF 0.04) | `DE: Electricity from wind power Sphera` / `… hydro power Sphera` | for the `DE_green` scenario |

---

## How to load (v3 standard)

Two sources for Variant A: (a) **Sphera base** — metals, electricity,
manufacturing, ABS, PC, PA 6/6.6, PET, PE/PP/PS/PVC, PUR chain; (b)
**PlasticsEurope Eco-profiles** (free) — including **POM**, and PC/ABS/PA 6/PA
6.6/PET where the base version does not fit. The rest stays a proxy
(`proxy:true`) or a Variant-B literal.

Per real dataset, create or extend a `Process` node with **ILCD metadata**:
`uuid`, `dataSetVersion`, `referenceYear`, `geographicalLocation`,
`technologyDescription`, `dataSetOwner` (`PlasticsEurope`/`Sphera`),
`referenceUnit='kg'`, `lifecycleModule='A1-A3'`. Then in **Variant A**:

```cypher
MATCH (m:Material {id:'MAT_PC'}), (p:Process {id:'PROC_PC_GRANULATE_SPHERA'})
MERGE (m)-[:MODELED_BY {proxy:false, lifecycleModule:'A1-A3',
        proxyRationale:'PlasticsEurope PC granulate, EU, via Sphera MLC'}]->(p);
```

The `ASSESS_EF31A_*` / `IR_EF31A_*` results (Variant A) then compute
automatically via `lca_generic('IAM_EF31', $artifactId)`; Variant B stays as a
fallback. Confidence **low** (ASA, PETG, TPE) means: mark the proxy visibly as
`proxy:true` + `proxyRationale`.

## Sources

- [PlasticsEurope Eco-profiles set](https://plasticseurope.org/sustainability/circularity/life-cycle-thinking/eco-profiles-set/)
- [PlasticsEurope Public LCI Database — PC granulate (PC)](https://plasticseurope.lca-data.com/datasetdetail/process.xhtml?uuid=c4161063-3fde-4540-ad1c-f2da1828bf7b&version=00.00.000)
- [PlasticsEurope Public LCI Database — Polyoxymethylene (POM)](https://plasticseurope.lca-data.com/datasetdetail/process.xhtml?lang=en&uuid=e3b65970-3420-43e6-8265-131ef3485c27&version=01.00.000)
- [Sphera Managed LCA Content — overview](https://sphera.com/solutions/product-stewardship/life-cycle-assessment-software-and-data/managed-lca-content/)
- [Sphera LCA database browser](https://lcadatabase.sphera.com/)
- [Sphera MLC 2025.1 update](https://sphera.com/resources/blog/spheras-mlc-database-update-2025-1-explained/)
- [GaBi Extension database VII: Plastics (LCI documentation)](https://gabi.sphera.com/support/gabi/gabi-database-2020-lci-documentation/extension-database-vii-plastics/)
- [openLCA Nexus — GaBi](https://nexus.openlca.org/database/GaBi)
