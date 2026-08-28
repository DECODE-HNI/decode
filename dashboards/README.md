# Dashboards: two roles, one graph

System Engineer and Sustainability Engineer look at the same graph, but with
different guiding questions. Rather than one dashboard with role-prefixed
pages, DECODE ships **two independent NeoDash dashboard files** — NeoDash has
no built-in grouping of pages into role tabs within a single file, so two
files is the honest fit, not a workaround.

> All numbers below were checked live against the running Neo4j instance —
> none are estimated.

## Roles

| | System Engineer | Sustainability Engineer |
|---|---|---|
| **Guiding question** | Is the product designed so it can be repaired, maintained, and scaled into variants? | What's each variant's environmental impact across its life cycle, and how trustworthy are the numbers behind it? |
| **Looks at** | Variant catalogue & design status, requirements traceability (met / conceptual / open), joining technique, material diversity, spare-part capability | Impact results & data coverage per assessment, EN 15804 / EF 3.1 indicators, repair-vs-remanufacture balance, traceability, data quality / pedigree |
| **File** | `neodash_dashboard_ned2_system_engineer.json` (3 pages) | `neodash_dashboard_ned2_sustainability_engineer.json` (4 pages) |

**Tool choice: NeoDash.** Connects directly over Bolt to the local instance;
every tile is its own Cypher query; no separate backend needed.

## System Engineer — 3 pages

**Page 1 — Catalogue overview.** 43 variants total, 24 requirements, a
38/5 candidate-vs-official-reference split. Mass is only recorded for the 5
official reference variants (manufacturer datasheet, data quality
`DQ_MANUF` = 5/5); all 38 candidate variants show it as genuinely open — a
visible backlog rather than a silently skipped value.

**Page 2 — Repairability & requirements.** 100% of variants use reversible
joining (screws, not adhesive/welding) and 100% have a modelled
service/repair process — but requirements traceability tells a very
different story. Of 43 variants, how many have a `SATISFIES_REQUIREMENT`
proof for each requirement:

| Requirement | Variants with proof |
|---|---|
| Replaceable jaws | 12 |
| Low material diversity | 11 |
| Recyclable structural material | 9 |
| Repairability | 3 |
| Reversible joining | 1 |
| Design for disassembly | 1 |

An apparent contradiction that's actually a documentation backlog:
structurally, 100% of variants use a screw connection, but only 1 of 43 has
that formally proven as `REQ_REV_JOIN`. The engineering is there; the
requirements documentation lags behind it.

## Sustainability Engineer — 4 pages

**Page 1 — Data coverage.** Of 43 variant screenings in the catalogue,
exactly **one** — `ASS_PREC_AL7075` — has real, computed impact values. The
other 42 are `not calculated`. (A 44th assessment node exists from the AAS
import test run, `EXT_BLACK_AAS_…`, reported separately as "computed (AAS
import)" rather than inflating the screening rate.) This coverage number is
deliberately page 1, not a footnote.

**Page 2 — PREC_AL7075 real example.**

| | CO₂ |
|---|---|
| New manufacture (A1–A3: CNC + screw + finish) | 9.178 kg CO2-eq |
| Repair (B4: replace contact element) | 9.155 kg CO2-eq |

Repair-benefit ratio = 1 − (repair CO₂ / new-manufacture CO₂) = **0.25%**.
Repair saves almost nothing here — the footprint is dominated by the CNC
aluminium-7075 blank, not the screw joint; manufacturing a replacement part
costs almost as much as the whole part. Once more variants get real values,
the same metric automatically ranks "repair worth it" vs. "remanufacture
worth it" across the catalogue. Five of the ten EN15804/EF3.1 indicators for
this example: Climate change (GWP) 9.178 kg CO2-eq, EF-Resource use fossils
114.44 MJ, EF-Water use 562.45 m³ world-eq, EF-Eutrophication terrestrial
1.575 mol N-eq, EF-Acidification 1.061 mol H+-eq.

**Page 3 — Data quality & traceability.** All four core processes' input
flows trace to `Sphera Managed LCA Content` as their reference source.
Correction versus an earlier version of this page: `Process.traceabilityLevel`
and `Process.source` are empty on all four core processes — the real
provenance sits one level down, on the `Flow` nodes. What's "declared" isn't
the background data itself but the quantity per process step (e.g. 3.6 MJ
electricity for CNC milling).

**Page 4 — Impact-category explorer.** 28 `ImpactCategory` nodes, searchable
by name/indicator/unit — consolidated down from 42 (see the data-quality
finding below).

## Reality check: three findings from building the queries

Two fixed at the source, one still open because the data simply doesn't
exist yet:

1. **Repairability is structurally present but never quantified — open.**
   `CP_DISASSEMBLY` is declared as a relevant property on 37 artifacts, but
   not one of them carries a value or a specification. No score exists yet,
   so the dashboards show proxy signals instead of inventing a number. See
   "Rethinking repairability" below.
2. **`Material.recycledContent_pct` held density values, not
   percentages — fixed.** The 5 generic ILCD/IDEMAT background materials
   (lead, copper, steel, zinc, aluminium) showed values like 11340 or 7850 —
   densities in kg/m³. Root cause: an unescaped comma in the name field
   during CSV import (e.g. `Lead (generic, ILCD/IDEMAT)` without quoting).
   Source and live data are corrected: names properly quoted,
   `recycledContent_pct` now honestly reads *unknown* instead of a wrong
   number.
3. **42 `ImpactCategory` nodes, real redundancy — fixed.** An inconsistent
   EF3.1 import had stored the same indicator under several IDs (e.g.
   `IC_EF_CLIMATE_FOSSIL` and `IC_EF_CLIMATE_CHANGE_FOSSIL` — same indicator,
   same unit, different ID; 11 groups, some duplicated 2×, some 3×).
   Consolidated to 28 unique categories: one canonical node per group kept,
   `HAS_CATEGORY` edges rewired, duplicates deleted. `CHARACTERIZES` and
   `DECLARES` were never affected (27,768 and 10 edges respectively,
   identical before and after).

## Rethinking repairability

Three concrete ways to compute a real repairability score instead of relying
on proxy signals, none implemented yet:

- **A — Disassembly time & tool class per joint.** Minutes per separation
  step plus required tool class (toolless / standard tool / special tool) on
  `PROC_SCREW` & co. — directly compatible with EN 45554 and iFixit's tool
  criterion.
- **B — Spare-part availability & price.** Already captured as a signal for
  `FEAT_PRINTABLE` variants (an STL file present = available); purchased
  parts currently have no price/lead-time data at all.
- **C — A value on `CP_DISASSEMBLY` itself.** The property already exists as
  an attachment point (37 artifacts) — it just needs a real measured value or
  a documented assessment method behind it.

## Setup

1. Open NeoDash — locally, via Docker, or at `neodash.graphapp.io`. Connects
   directly over Bolt; no separate server needed.
2. Connect to the instance: Bolt URI, user `neo4j`, your password.
3. **Import Dashboard** → load whichever file matches your role — not both
   into the same view.
4. Switch roles either via NeoDash's own dashboard management (saved
   dashboards to choose from) or simply two browser tabs, one per file — both
   connect independently to the same instance.

The full query catalogue (all 28 tiles, in plain Cypher) is documented
inline in each `.json` dashboard file's tile definitions.
