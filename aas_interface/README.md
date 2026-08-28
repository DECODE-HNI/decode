# AAS interface: exchanging sustainability data across organisations

How process and assessment data from the Ned2 knowledge graph can be
exchanged with partner organisations via the **Asset Administration Shell**
(AAS) — with three deliberately different levels of transparency versus
confidentiality, and a working import path back into Neo4j for all three.

> **Status:** no longer a thought experiment. All three box types have a
> real instance file, successfully loaded in AASX Package Explorer, built
> from values actually computed in the local Neo4j instance — and a working
> `AAS → Neo4j` import for all three, independently re-verified.

## One shell per asset

Real AAS practice (Catena-X, IDTA) models one Administration Shell per
individually identifiable asset — not one large AAS for an entire assembly.
Bill-of-materials relationships run through the **Hierarchical Structures
enabling BOM** submodel (IDTA 02011), which references child AAS IDs.

```
AAS_ASSY_PREC_AL7075                (assembly, matches r_12/r_13 HAS_COMPONENT)
 └─ Submodel: HierarchicalStructures
     ├─→ AAS_PART_PREC_AL7075_CONTACT     (contact element, material MAT_AL7075)
     └─→ AAS_PART_PREC_AL7075_INTERFACE   (interface part)

Applied processes (not a BOM member — APPLIES_TO on the part):
PROC_CNC, PROC_SCREW, PROC_FINISH, PROC_REPAIR
```

The consequence: White/Grey/Black Box is a property of **each individual**
AAS, not of the assembly as a whole. To compare the three approaches, the
same assembly (`ASSY_PREC_AL7075` → `PART_PREC_AL7075_CONTACT` +
`PART_PREC_AL7075_INTERFACE`, material `MAT_AL7075`, manufactured via
`PROC_CNC` + `PROC_SCREW` + `PROC_FINISH` + `PROC_REPAIR`) is built three
times, once per box type, at consistent depth across every part-shell.

## The three approaches

The axis isn't "more or fewer submodels" — it's a **trust and traceability**
scale: how tightly are the values declared in the AAS bound to the
underlying ILCD raw data?

| | White Box | Grey Box | Black Box |
|---|---|---|---|
| **Structure** | 1:1 isomorphic to ILCD (`Process`/`Flow`/`Exchange`/LCIA-result nesting) | Only the values needed downstream, each pointing at the exact spot in an attached ILCD file it was derived from | Generalised multi-indicator footprint format; an ILCD file may be attached but with **no** link to the declared values |
| **Attachment** | none needed | ILCD file attached | ILCD file optionally attached, unlinked |
| **Traceability** | fully recomputable | verifiable per declared value | not verifiable |
| **Disclosure** | maximum | targeted, controllable | minimal |
| **Real-world analogue** | full audit/research transparency | supplier states material + footprint, details confidential | Catena-X/WBCSD-PACT-style PCF exchange, EPD |

| Aspect | White Box | Grey Box | Black Box |
|---|---|---|---|
| Submodel | custom, ILCD-isomorphic (`Process`/`Flow`/`Exchange`/`LCIAResult` as nested SMCs) | slim result submodel + `File` element for the ILCD file | Environmental-Footprint submodel (modelled on IDTA 02093 EPD) + optional `File` |
| Linking mechanism | none needed — the structure *is* the information | `AnnotatedRelationshipElement` + `FragmentReference` | none — file is purely informational |
| PCF/footprint granularity | per unit process | 1–2 lifecycle modules (e.g. A1–A3), traceable | one aggregate value per indicator, cradle-to-gate |
| Standards referenced | IDTA 01001 metamodel (structural building blocks); no dedicated IDTA submodel | IDTA 01001 referencing (`FragmentReference`), IDTA 02023 Carbon Footprint as baseline | IDTA 02093 EPD (*in development*), interim EN 15804 / ISO 14025 indicator set |

## Worked example: White Box, step by step

The characterisation factors live in a **separate** LCIA-method dataset
(namespace `.../ILCD/LCIAMethod`), not in the `Process` dataset — the process
dataset only knows its exchanges and references flows by UUID:

```xml
<!-- process_PROC_ALU_CAST_MACHINING.xml (namespace .../ILCD/Process) -->
<processDataSet>
  <exchanges>
    <exchange dataSetInternalID="1">
      <referenceToFlowDataSet refObjectId="7b1e9d4a-..."/>
      <exchangeDirection>Input</exchangeDirection>
      <meanAmount>2.35</meanAmount>  <!-- Electricity, grid mix DE -->
    </exchange>
    <exchange dataSetInternalID="12">
      <referenceToFlowDataSet refObjectId="ab129e3d-..."/>
      <exchangeDirection>Output</exchangeDirection>
      <meanAmount>1.42</meanAmount>  <!-- Carbon dioxide, fossil, to air -->
    </exchange>
  </exchanges>
</processDataSet>
```

`ilcd_to_csv_v2.ps1` (in `../lca_bulk_load/`) already derives the keys that
show up unchanged in both the graph and the AAS: `exchangeId =
"<processId>#<dataSetInternalID>"`, and, on load,
`characterizesId = flowId + '|' + categoryId + '|' + location`. The White-Box
AAS reuses `exchangeId`/`characterizesId` **verbatim** as property values
instead of reinventing them — its `semanticId` is deliberately a project-own
URN, since no official IDTA submodel exists for ILCD process data.

**Shared flows are referenced, not duplicated.** A flow like "Electricity,
grid mix DE" is used by many processes. Copying it into every process
submodel would let copies drift apart once a source updates. So, mirroring
ILCD itself (exchanges reference flows by UUID rather than embedding them), a
reused flow gets its **own AAS**, referenced by other process shells via
`ReferenceElement`. Only elementary flows with no independent asset character
(like the CO2 emission above) are referenced inline by UUID, without their
own shell.

## Grey Box: FragmentReference

The AAS metamodel (IDTA 01001, Part 1) has a `KeyType` called
**`FragmentReference`** — a key that must, per spec, follow a key of type
`File` or `Blob`. That's exactly the pointer mechanism Grey Box needs; it
didn't need to be invented. The real semantic IDs for the PCF fields come
from the official IDTA 02023 template.

## Neo4j mapping: import & export

Export is equally simple for all three approaches — a projection of however
much detail already exists. Import is the interesting problem: how much of
the process chain can be reconstructed depends on the box type. Every
imported node carries a `traceabilityLevel` property (`"white"` / `"grey"` /
`"black"`).

| Box | Export (graph → AAS) | Import (AAS → graph) |
|---|---|---|
| White | full serialisation of the `Process`/`Flow` subgraph as nested SMCs | full reconstruction of `Process`/`Flow`/`HAS_FLOW`/`CHARACTERIZES` — like a tenth ILCD source package |
| Grey | aggregate values + generated ILCD file + `FragmentReference` links | `Assessment` from the declared value; referenced fragments optionally re-checked against the graph |
| Black | aggregate values across several indicators, ILCD file optionally attached unlinked | `Assessment` + one `DECLARES` edge per indicator to `ImpactCategory` (not `CHARACTERIZES`, to keep *computed* vs. *declared* distinguishable); attached file stored as an opaque blob, not parsed |

`aas_to_neo4j_import.ps1` reads one of the three instance files, detects the
box type from the submodel `idShort`, and generates a Cypher script.
**Design decision:** imported nodes get an `EXT_` prefix plus
`sourceAAS`/`traceabilityLevel` properties, rather than silently merging into
the internal `PROC_CNC`/`ASS_PREC_AL7075` nodes — externally received data
describing the same real-world fact isn't automatically identical to the
internal modelling of it. `Flow` nodes (real UUIDs) are the exception and are
reused unchanged, since they're globally shared reference identities, not an
organisation-internal construct.

Verified results, all three box types:

| Box | Import result |
|---|---|
| White | 4 `EXT_` process nodes (`PROC_CNC`/`SCREW`/`FINISH`/`REPAIR`) + every exchange reconstructed as `HAS_FLOW`, plus 2 `ImpactResult` nodes from `CarbonFootprintSummary` |
| Grey | 1 `ImpactResult` (`traceabilityLevel:'grey'`) + **both `FragmentReference`s resolved against the graph**: `VERIFIED_AGAINST` edges show `resolvedFromProcess = 'PROC_CNC'` with the exact correct quantities (1 kg / 3.6 MJ) |
| Black | 1 `Assessment` with all ten indicators as flat, camelCase properties (`gwpTotal`, `odp`, …), attached file stored as a string, not parsed |

The Grey-Box result is the actual proof of the concept: the
`FragmentReference` `ilcd:exchange:PROC_CNC#0` from the AAS file was
independently resolved against — and confirmed the exact quantity in — the
`HAS_FLOW` edge already present in the graph. That's the "targeted
traceability" Grey Box promises, actually recomputed rather than merely
claimed.

## Standards referenced

| IDTA No. | Title | Status | Role in this concept |
|---|---|---|---|
| 01001-3-0 | AAS Metamodel, Part 1 | Published | Source of the `FragmentReference` mechanism (Grey Box) |
| 02011-1 | Hierarchical Structures enabling BOM | Published v1.1 | AAS network / assembly referencing |
| 02003 | Generic Frame for Technical Data | Published v2.0.1 | Technical-data submodel for material/part properties |
| 02023 | Carbon Footprint | Published v1.0 | Baseline PCF structure, model for Grey-Box aggregate values |
| 02093 | Environmental Product Declaration (EPD) | *in development* | Model for the Black-Box multi-indicator format; field structure not yet public |

**Principle held throughout:** exact `semanticId`/`idShort` values are taken
only from official templates, never invented — this applies to every future
instance file too.

## Files

| File | Box | Role |
|---|---|---|
| `aas_instance_whitebox_prec_al7075_contact.json` | White | Full ILCD-isomorphic AAS instance for `PART_PREC_AL7075_CONTACT` |
| `aas_instance_greybox_prec_al7075_contact.json` | Grey | Aggregate PCF value + `FragmentReference` provenance |
| `aas_instance_blackbox_prec_al7075_contact.json` | Black | Ten-indicator EPD-style footprint |
| `aas_instance_*_import.cypher` | — | Generated import scripts (one per box type) that load the corresponding instance's data back into Neo4j with `EXT_` provenance |
| `aas_to_neo4j_import.ps1` | — | Generates a fresh import script from any instance file: detects box type from the submodel `idShort`, handles all three |

## Reproducing this for a different part

1. **ILCD raw data → CSV**: see [`../lca_bulk_load/`](../lca_bulk_load/).
2. **Check the upstream chain exists**: an engineering process isn't
   automatically connected to characterised ILCD elementary flows.
   ```cypher
   MATCH (p:Process)-[hf:HAS_FLOW]->(f:Flow)-[c:CHARACTERIZES]->(ic:ImpactCategory)
   RETURN p, f, ic
   ```
   Nothing back means the chain is missing — find a matching library process
   with the same reference quantity/unit and rewire, keeping `exchangeId`
   (see `../lca_bulk_load/close_upstream_gap_proc_cnc.cypher` as a template).
3. **Computed value → AAS instance**: carry graph values 1:1 into the JSON
   structure (see the White-Box example above). Three pitfalls that only
   surfaced when loading into AASX Package Explorer, not from the public
   docs: `SubmodelElementList` requires `typeValueListElement`;
   `Property.value` is always a string, even for `valueType: xs:double`;
   `submodels` references on the shell are `ModelReference`, while
   `semanticId` is `ExternalReference`.
4. **Validate**: open in AASX Package Explorer. Errors surface one at a time;
   the path in the error log (e.g.
   `submodels[0].submodelElements[1].value[0].value[2]`) points exactly
   where to fix the JSON — work through them top to bottom.
5. **Reverse: AAS → Neo4j**:
   ```powershell
   ./aas_to_neo4j_import.ps1 -JsonPath <file>.json
   ```
   generates a Cypher script (review it before running) executed via
   `cypher-shell -f <script>.cypher`.

   Three real pitfalls found building this script, not concept problems:
   global uniqueness constraints (e.g. on `exchangeId`) apply to imported
   data too — reusing an AAS's value unchanged collides with the original
   edge, hence the `EXT_` prefix + `sourceExchangeId` property; PowerShell's
   `-match` is case-*insensitive* by default, which silently defeats a
   CamelCase-split regex — use `-cmatch`; `Set-Content -Encoding UTF8` under
   Windows PowerShell 5.1 writes a BOM that `cypher-shell` rejects with a
   syntax error — write via `[System.IO.File]::WriteAllLines` with a
   BOM-free `UTF8Encoding` instead.
