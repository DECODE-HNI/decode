# LCI hygiene pass

One-off cleanup of import-parser damage in the LCI layer. The Sphera /
PlasticsEurope exports were ingested by a pipeline whose CSV/TSV parser
mishandled commas and semicolons inside substance names, and merged flows
booked in different units onto a single `Flow` node.

> **Status:** applied 2026-08-29. 0 mixed-unit flows remain, 0 non-CAS
> `casNumber` values remain, ~7 670 blank `HAS_FLOW.compartment` values
> backfilled, 27 shattered-fragment flows quarantined. Live DB 5 524 nodes /
> 89 441 relationships, 0 label-less, 0 calc-without-value. Verified against a
> running Neo4j 5 instance.

## What `lci_hygiene.cypher` does

| Part | Action | Result effect |
|---|---|---|
| **P1** | non-CAS `casNumber` values (units, compartment strings, name fragments, `""`) moved to `casNumberRaw`, field nulled, `dataFlag` set | none (`casNumber` is not used in the calculation) |
| **P2** | land-use flows: the `Occupation, ` / `Transformation, ` name prefix the parser stripped is restored (`nameRaw` kept); the unit moved out of `casNumber`; `HAS_FLOW.compartment` set to `resource/land` | none (CF match already worked by land-use category) |
| **P3** | **unit-split**: a `Flow` booked in more than one unit is split into one node per unit (`<id>#u=<unit>`), so `sum(hf.amount)` is dimensionally clean. The characterised node keeps the unit its CF expects — `kBq` for ionising radiation, `MJ` for fossil resource use, otherwise the modal unit; off-unit exchanges move to an uncharacterised sibling | **corrects ionising radiation and fossil resource use** (see below) |
| **P4** | blank `HAS_FLOW.compartment` backfilled from the flow's unambiguous modal compartment (only when the flow has exactly one non-blank compartment elsewhere) | minor accuracy gain for compartment-sensitive CFs |
| **P5** | blank compartment on characterised air-emission outputs backfilled from a curated name rule (CO2, CH4, SO2, NOx, NH3, NMVOC, PM, …) | minor accuracy gain |
| **P6** | flows whose name is a shattered fragment (`"1"`, `"(2"`, `"2-chloro-N-(2"`) are flagged `excludeFromCalc` and their spurious `CHARACTERIZES` edges (121) deleted | removes ~1 % noise from the aluminium dataset's freshwater ecotoxicity |

Every part writes an audit property (`casNumberRaw`, `nameRaw`, `splitFrom`,
`dataFlag`, `compartmentSource`, `excludeFromCalc`) and has a rollback block at
the end of the file. Re-runnable.

## Result deltas (43 grippers, Variant A)

| Category | before | after | why |
|---|---|---|---|
| EF3.1 Ionising radiation (kBq U235 eq) | 0.020 – 0.049 | **0.0046** – 0.049 | kg-booked radionuclide masses (e.g. 0.83 "kg" caesium-137) no longer multiplied by a kBq-basis CF |
| ReCiPe Ionising radiation (kBq Co-60 eq) | 0.0039 – 0.0095 | **0.0** – **0.0035** | same; the result was ~18× inflated on average |
| EF3.1 Freshwater ecotoxicity (CTUe) | … – 1.3408 | … – 1.3408 | shattered-flow noise removed (~0.003 %) |
| EF3.1 Human toxicity, cancer | vmax 5.0E-10 | vmax 4.0E-10 | shattered-flow noise removed |

Climate, acidification, eutrophication, particulate matter, photochemical
ozone, land use, water use and the remaining toxicity categories are
unchanged — the pass has no collateral effect on them.

## Known follow-ups (out of scope here)

- **EF3.1 "Resource use, fossils"** now over-reports for the ABS and PC
  datasets (ART_FLAT_ABS ≈ 23 MJ, ART_PREC_PC ≈ 16 MJ). Two causes, both
  pre-existing CF problems that the unit-split exposed rather than created:
  `uranium` (nuclear primary energy, MJ) carries an `IC_EF_EF_RESOURCE_USE_FOSSILS`
  CF of 1.0, and the PlasticsEurope fossil inventory itself mixes MJ values
  labelled as kg. Needs a dedicated fossil-resource CF review.
- `IC_RECIPE_FRS` and `IC_RECIPE_LU` stay structural — the fossil kg amounts
  are not trustworthy enough to attach a mass-basis CF, and there are almost
  no land-occupation flows. (A calorific-value CF addendum was drafted and
  withdrawn for the same reason.)
- `IC_EF_EF_RESOURCE_USE_MINERALS_AND_METALS` still has a negative minimum
  across the 43 grippers — a separate CF/sign bug, untouched.
- ~18 900 blank-compartment output edges remain, on flows that never carry a
  compartment anywhere (mostly obscure trace organics); not backfillable
  without the source packages.
