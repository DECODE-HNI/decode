# Assumed values for the use case (Niryo-Ned2 gripper)

As of 2026-08-27. All values are **literature-based order-of-magnitude
assumptions** for the case study, documented so they can later be swapped for
ILCD/EF or EPD data. Every migration that loads one sets a `*Basis` property
pointing at "ASSUMPTIONS.md".

Research notes: the exact figures live in licensed LCA databases (ecoinvent,
Sphera/GaBi) or manufacturer-specific EPDs. The ranges used here match common LCA
literature (Plastics Europe Eco-profiles, ecoinvent orders of magnitude, Ashby
"Materials and the Environment", peer-reviewed AM-LCA studies). Sources at the
end.

---

## 1. Material A1 (cradle-to-gate, primary production), kg CO₂-eq / kg

| Material | id | GWP A1 | literature range | Note |
|---|---|---:|---|---|
| Aluminium 6061 (extrusion profile) | MAT_AL6061 | **9.67** | 8–12 | from `PROC_ALU_EXTRUSION_EF` (validated) |
| Aluminium 7075 | MAT_AL7075 | 9.67 | 8–12 | as 6061 (alloy difference not separated in v2) |
| Structural / low-alloy steel | MAT_STEEL | 2.3 | 1.8–2.8 | blast-furnace route |
| Spring steel | MAT_SPRING | 2.8 | 2.3–3.3 | alloyed |
| PA12 (powder, virgin) | MAT_PA12 | 9.0 (literal) / **6.48** (real proxy) | 8–10 | proxy = PlasticsEurope PA 6.6 EU-27 2011 (`PROC_PA66_PLASTICSEUROPE_EF`); real PA12 higher |
| PA11 (bio-based) | MAT_PA11 | 5.5 (literal) / **6.48** (real proxy) | 4–7 | proxy = PA 6.6 (fossil, overstates bio-PA11) |
| PETG | MAT_PETG | 4.0 | 3.5–4.5 | |
| PLA (bio-based) | MAT_PLA | 2.7 | 2–3.5 | |
| ABS | MAT_ABS | ~~4.0~~ **3.14** | 3.5–4.5 | **real:** PlasticsEurope EU-27 2010 (`PROC_ABS_PLASTICSEUROPE_EF`) |
| ASA | MAT_ASA | 4.5 | 4–5 | proxy ABS |
| Polycarbonate | MAT_PC | ~~5.5~~ **4.19** | 5–6.5 | **real:** PlasticsEurope EU-25 **2007**; newer eco-profiles ~7.7 |
| POM / acetal | MAT_POM | ~~3.6~~ **3.26** | 3–5.5 | **real:** PlasticsEurope EU-27 2010 (`PROC_POM_PLASTICSEUROPE_EF`) |
| CF-reinforced PA | MAT_CFPA | 24.0 | 18–30 | carbon fibre dominates (~20–25/kg fibre) |
| TPU 95A | MAT_TPU | 5.2 | 4.5–6 | |
| TPE | MAT_TPE | 4.2 | 3.5–5 | |
| Silicone rubber | MAT_SILICONE | 7.0 | 5–11 | wide spread |
| NBR rubber | MAT_NBR | 3.5 | 3–4 | |
| PU elastomer | MAT_PU | 4.5 | 4–5 | |

### Further EF3.1 categories per kg of material (rough factors only, Variant B)

Scaled from the aluminium dataset ratio (`PROC_ALU_EXTRUSION_EF`):
acidification ≈ GWP × 5.4e-3 mol H⁺/kg CO₂-eq · marine eutrophication ≈ GWP ×
1.07e-3 · photochemical ozone ≈ GWP × 3.15e-3 · land use ≈ GWP × 0.89
(dimensionless) · ozone depletion ≈ 0 · particulate matter ≈ 0. For
polymers/elastomers these ratios are less reliable than for metals → Variant B
is flagged "full coverage, mixed data quality".

### CAS normalisation, Variant A (consistency review F-03, as of 2026-08-29)

Several imported ILCD datasets store `Flow.casNumber` zero-padded
(`000124-38-9`). The original EF3.1 CF match did not normalise → affected flows
(incl. the steel CO₂ flow) stayed without an EF3.1 CF, while the ReCiPe import
(`norm_cas()`) did capture them. Correction
(`../migrations/consistency/fix_F03_cas_bridge.cypher`): `Flow.casNumberNorm`
(leading zeros stripped) + **530 EF3.1 CFs** bridged from the clean-CAS twin with
the same normalised CAS **and** the same substance name (`derived=true`, global
`location=''` factor). Assumption: same normalised CAS + same name = same
substance/compartment. Steel dataset then 14 instead of 8 EF3.1 categories, steel
CO₂ `perKg` 1.575 kg CO₂e/kg (plausible for structural steel sections).

### Non-CAS flow harmonisation, Variant A (as of 2026-08-29)

For the real ILCD datasets, CAS-less alias emission flows are bridged to the
canonical EF3.1 factors over name + compartment
(`../migrations/v2_data/ilcd_import/harmonize_noncas.cypher`):

- `particles (PM2.5 - PM10)` gets the CF of `particles (PM10)` (5.48544e-5
  disease incidence/kg) — the DB label "PM10" there means the **2.5–10 µm
  fraction**, so the alias is name-equivalent, not a proxy.
- `volatile organic compound` is treated as an older label of
  `non-methane volatile organic compounds` and inherits **all** of its EF3.1 CFs
  (POCP 1.0; the carried USEtox ecotox./human-tox. factors have high
  uncertainty but are consistent with the canonical NMVOC flow).
- **Assumption (`confidence:'low'`, `proxy:true`)**: `Particulates (unspecified)`
  and `Dust (unspecified)` get the PM10-fraction CF. Rationale: EPD/PEF practice
  assigns unspecified particulates to the thoracic fraction absent a size
  figure; the amounts here are a small remainder next to the explicitly split
  fractions.
- **Not** bridged: `particles (> PM10)` (EF3.1 CF of the > 10 µm fraction = 0)
  and `chemical/biological oxygen demand` (no EF3.1 or ReCiPe 2016 category is
  driven by COD/BOD; EF freshwater eutrophication is P-based, marine N-based).

Precision: `refresh_variantA.cypher` stores the results with `round(…,12)`
instead of `round(…,6)`, otherwise particulate matter (~1e-8), human toxicity
(~1e-10…1e-8) and ozone depletion (~1e-12) would flatten to 0.0.

## 2. Manufacturing energy A3 (electricity), kWh / kg part

| Process | id | kWh/kg | range | Note |
|---|---|---:|---|---|
| Multi Jet Fusion | PROC_MJF | 15 | 10–25 | incl. warm-up/cool-down, medium pack density |
| Selective Laser Sintering | PROC_SLS | 30 | 20–50 | chamber heating dominates |
| Fused Filament Fabrication | PROC_FFF | 20 | 10–30 | slow, low power |
| CNC milling | PROC_CNC | 20 | 10–30 | + material scrap (below) |
| Laser cutting | PROC_LASER | 8 | 5–15 | |
| Sheet bending | PROC_BEND | 2 | 1–3 | |
| Silicone casting | PROC_SILCAST | 4 | 2–5 | curing oven |
| Elastomer moulding | PROC_RUBBER | 5 | 3–8 | |
| Overmoulding | PROC_OVERMOLD | 6 | 4–8 | |
| Al casting + machining | PROC_ALU_CAST_MACHINING | 15 | 10–20 | |
| Al sheet forming | PROC_ALU_SHEET_STAMPING | 3 | 2–5 | |

CNC scrap factor: finished mass × 1.8 raw material (subtractive, small parts).
AM processes: material factor 1.1 (supports/excess).

## 3. Electricity emission factor, kg CO₂-eq / kWh

| Grid | Value | range | process node |
|---|---:|---|---|
| DE grid mix (standard) | 0.38 | 0.35–0.42 | reference 2021–2024 |
| DE green electricity | 0.04 | 0.03–0.05 | `PROC_ELECTRICITY_GREEN_GRID_MIX_DE` |
| CN grid mix | 0.58 | 0.55–0.65 | `PROC_ELECTRICITY_GRID_MIX_CN` |
| EU average | 0.28 | 0.25–0.32 | — |

Default scenario `SC_BASELINE` = DE grid mix. Alternatives as `ModelScenario`
(`SC_GRID_CN`, `SC_GRID_EU`, `SC_GREEN_ELECTRICITY`).

## 4. Part mass

| Part class | basis |
|---|---|
| contact part (43×, `partType='Jaw/Finger/Cup/Pole'`, has geometry) | bounding-box volume × fill factor × density |
| fill factor CNC | 0.55 (milled pockets) |
| fill factor MJF/SLS/FFF | 0.40 (print, often infill/hollow) |
| fill factor silicone/elastomer cast | 0.85 (solid) |
| interface part (43×, `partType='Interface'`, no geometry) | type default: 20 g (polymer), 35 g (metal) — "typical tool adapter" |
| quantity | `HAS_COMPONENT.quantity` (contact usually 2, interface 1) |

Sanity-checked against the 5 known `Artifact.mass_g` (19.5–115 g).

## 5. Circularity (refined vs the v3.a class defaults)

| Material class | recycled content (typ.) | EoL recycling rate | reuse |
|---|---:|---:|---:|
| aluminium | 0.35 (profile, EN15804 A1-A3) | 0.90 | 0.05 |
| steel | 0.40 | 0.85 | 0.05 |
| engineering thermoplastics (PA/PC/POM/ABS/ASA/PETG) | 0.05 | 0.20 (mechanically limited) | 0.00 |
| PLA | 0.00 | 0.10 (industrial composting, no recycling) | 0.00 |
| elastomers (silicone/TPU/TPE/NBR/PU) | 0.00 | 0.10 | 0.00 |
| fibre composite (CF-PA) | 0.00 | 0.05 | 0.00 |

Gripper-jaw service life: design 3 y, reference 3 y (utility factor neutral).
Replaceable jaws (`FEAT_PRINTABLE`) / quick-change (`FEAT_EASY`): design 5 y.

## 6. ReCiPe 2016 Midpoint (Hierarchist) — 18 categories

Global warming (kg CO₂ eq) · Stratospheric ozone depletion (kg CFC-11 eq) ·
Ionizing radiation (kBq Co-60 eq) · Ozone formation, human health (kg NOx eq) ·
Fine particulate matter formation (kg PM2.5 eq) · Ozone formation, terrestrial
ecosystems (kg NOx eq) · Terrestrial acidification (kg SO2 eq) · Freshwater
eutrophication (kg P eq) · Marine eutrophication (kg N eq) · Terrestrial
ecotoxicity (kg 1,4-DCB) · Freshwater ecotoxicity (kg 1,4-DCB) · Marine
ecotoxicity (kg 1,4-DCB) · Human carcinogenic toxicity (kg 1,4-DCB) · Human
non-carcinogenic toxicity (kg 1,4-DCB) · Land use (m²a crop eq) · Mineral
resource scarcity (kg Cu eq) · Fossil resource scarcity (kg oil eq) · Water
consumption (m³).

Representative characterisation factors (IPCC AR5 GWP100 / ReCiPe H):
CO₂ = 1 · CH₄ (fossil) = 29.8 · CH₄ (biogenic) = 27.0 · N₂O = 273 · SF₆ = 25200 ·
terrestrial acidification: SO₂ = 1.0 · NOx = 0.36 · NH₃ = 1.96 ·
particulate matter: PM2.5 = 1.0 · SO₂ = 0.29 · NOx = 0.11 · NH₃ = 0.24 ·
marine eutrophication: N-total = 1.0 · NOx = 0.04 ·
freshwater eutrophication: P-total = 1.0 · fossil resources: crude oil ≈ 1.0 kg
oil eq/kg, natural gas ≈ 0.84, hard coal ≈ 0.49.

**Implemented (2026-08-29):** instead of these hand values, a **full CF import**
from the free openLCA "LCIA Methods" pack (`ReCiPe 2016 Midpoint (H)`), matched
onto the graph flows by CAS + compartment resp. resource name
(`../migrations/v3x_e_recipe/cf_import/`). **16 of 18 categories compute** and are
persisted as `ASSESS_RECIPE_A_*` per gripper. The climate approximation
(EF3.1 × 1.06) was replaced with real ReCiPe GW CFs. **Not populated:** fossil
resource scarcity (graph flows `crude oil`/`natural gas`/… carry mixed units
MJ/kg on the same flow node) and land use (almost no land-occupation flows in the
graph). Both stay structural.

## 7. Cross-impact matrix (v3.g, `INFLUENCES`)

Qualitative, engineering-reasoned influence relationships between design levers
(`Feature`, `CoreProperty`, `Material` class) and impact categories, and between
categories. Convention: `sign '+'` = the lever **improves** the sustainability
result of the target category (lower burden resp. higher circularity/
repairability), `sign '-'` = **worsens** it; `strength` 1 = weak, 2 = medium,
3 = strong.

| Lever | Category | sign·strength | Rationale |
|---|---|---|---|
| replaceable printed contact jaw (`FEAT_PRINTABLE`) | repairability | +3 | field swap without a spare-parts store |
| " | circularity | +2 | print on demand, no shelf scrap |
| " | climate | −1 | an extra polymer part + FFF energy |
| toolless robot interface (`FEAT_EASY`) | repairability | +3 | fast reversible assembly |
| " | circularity | +2 | non-destructive disassembly → material separation |
| magnetic contact face (`FEAT_MAGNET`) | repairability | +3 | quick change |
| " | resources (minerals/metals) | −2 | rare earths (Nd, Dy) |
| " | circularity | −1 | NdFeB hard to separate/recycle |
| friction pad / soft contact (`FEAT_RUBBER`/`FEAT_SOFT`) | circularity | −2 | thermoset elastomer, low MCI |
| disassemblability (`CP_DISASSEMBLY`) | repairability / circularity | +3 / +2 | common cause, design for disassembly |
| material class metal | circularity / climate | +3 / −2 | recyclable (MCI ≈ 0.65) ↔ primary Al 9.67 + machining loss |
| material class composite (CF-PA) | climate / circularity | −3 / −3 | ≈ 24 kg CO₂e/kg, no recycling path (MCI ≈ 0.14) |
| material class elastomer | circularity | −3 | thermoset (MCI ≈ 0.16) |
| circularity → climate | | +2 | higher recycled content lowers A1 GWP |
| repairability → climate | | +2 | lifetime extension amortises embodied emissions |
| repairability → circularity | | +3 | common cause |
| circularity → resources (minerals/metals) | | +3 | secondary metal displaces primary extraction |

Recycled aluminium (scenario `SC_RECYCLED_ALU`): recycled-content-adjusted A1
factor = 9.67·(1−rc) + 0.55·rc with rc = 0.75 → **2.83 kg CO₂e/kg** (primary
9.67; remelt secondary aluminium ≈ 0.5–0.6 kg CO₂e/kg).

## 8. Data quality (`dq_concept/`, as of 2026-08-29)

The DQ layer follows the published HNI concept (Rarbach / Gräßler / Pottebaum):
ISO 14044 §6.3.6 criteria, split into **inherent** (accuracy, completeness,
methodological consistency, comparability, uncertainty) and **system**
(temporal / geographical / technological representativeness); a **0..4 pedigree
scale with 4 = optimal**; **no aggregation formula** — the quality of a dataset
against a phase is its worst criterion versus that phase's target value.

**Study frame for the auto scoring:** reference year **2026**, target geography
**DE** (EU / RER = "good", not optimal).

**Auto bands (assumptions, tunable):**

| Criterion | Rule |
|---|---|
| `DQC_TEMP` | dataset age ≤ 3 y → 4, ≤ 6 → 3, ≤ 10 → 2, ≤ 15 → 1, else 0 (Weidema temporal correlation, inverted) |
| `DQC_GEO` | DE → 4; EU/RER → 3; GLO/RoW → 2; other single country → 1; none → 0 |
| `DQC_TECH` | real dataset → 4; nearest real proxy → 3; generic → 2; cross-material → 1 |
| `DQC_COMP` | EF3.1 category coverage ≥ 95 % → 4 … ≥ 50 % → 1, else 0 |
| `DQC_CONS` | share of harmonised/proxy CFs ≤ 2 % → 4 … > 25 % → 1 |
| `DQC_COMPAB` | `lifecycleModule`+`dataSetType` → 3 (cap), module only → 2, else 1 |
| `DQC_ACC`, `DQC_UNC` | manual (expert at the gate), `score = null` |

**Phase target matrix** (`DQPhase-[:TARGETS]->`): default values, `basis =
'default'` — to be tuned against the published phase target values. See
[`../migrations/dq_concept/README.md`](../migrations/dq_concept/README.md).

**State of the demonstrator:** the free PlasticsEurope / ILCD eco-profiles
(2007–2011) carry `DQC_TEMP` 0–1; so no assessment passes the design or
declaration gate (binding constraint: dataset age). Screening: 121 / 155.

## Sources (research entry points)

- Plastics Europe, Eco-profiles / Environmental Product Declarations (polymer GWP ranges).
- ecoinvent v3 orders of magnitude (metals, electricity mixes).
- Ashby, "Materials and the Environment: Eco-informed Material Choice", 2nd ed. (embodied-carbon ranges).
- Faludi et al. / Kellens et al., LCA of additive manufacturing (specific energy use SLS/MJF/FFF): [PMC6947159](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6947159/), [S2666790821000288](https://www.sciencedirect.com/science/article/pii/S2666790821000288).
- Huijbregts et al., "ReCiPe2016", Int J LCA 2017: [10.1007/s11367-016-1246-y](https://link.springer.com/article/10.1007/s11367-016-1246-y); RIVM Report 2016-0104: [rivm.nl](https://www.rivm.nl/bibliotheek/rapporten/2016-0104.pdf).
- ReCiPe 2016 category list: [Earthster KB](https://docs.earthster.org/en/articles/6827227-recipe-2016-impact-categories).
- German Environment Agency (UBA), electricity-mix emission factor for Germany (annual update).
- IPCC AR5 (2013), GWP100 values.
- EN 15804+A2 (module definitions, EPD reference frame).
- Ellen MacArthur Foundation / Granta, "Material Circularity Indicator" methodology (2019).
