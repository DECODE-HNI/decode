# Datensatz-Landkarte: fehlende ILCD-/Sphera-Datensätze je Modellwerkstoff

Stand 2026-08-28. Zweck: für jeden Werkstoff/Prozess im Greifermodell, der noch
**keinen realen Datensatz** hat (aktuell nur Literatur-Literal in Variante B),
die **Bezeichnung** benennen, unter der er in der **Sphera-Basis-Datenbank**
(*Managed LCA Content* / früher *GaBi Professional* + *Extension DB VII: Plastics*)
bzw. in einem frei zugänglichen **ILCD-Knoten** zu finden ist.

## Zwei vom Nutzer entschiedene Festlegungen (2026-08-28)

1. **Datenvariante ab v3:** Standard ist die **ILCD-nahe Repräsentation auf realen
   Datensätzen** (`dataVariant='A-realdataset'`), gestützt auf Sphera MLC. Die
   Literal-Variante (`dataVariant='B-literal'`) bleibt nur als **Grundlage/Fallback**,
   damit jede Methode dort rechnen kann, wo (noch) kein realer Datensatz vorliegt.
2. **Kostendimension bleibt schlank:** nur `Material.unitCost`-Platzhalter, **kein**
   `CostItem`/`HAS_COST`-Knotenmodell (v3.b-Variante B wird nicht weiterverfolgt).

## Erledigt (2026-08-28): 4 reale PlasticsEurope-Datensätze eingespielt

Über die freien PlasticsEurope-ILCD-Pakete + die Pipeline `ilcd_import/`:

| Material | Prozessknoten | GWP A1-A3 real | war Literal |
|---|---|---:|---:|
| `MAT_ABS` | `PROC_ABS_PLASTICSEUROPE_EF` (EU-27, 2010) | 3,14 kg CO₂e/kg | 4,0 |
| `MAT_PC` | `PROC_PC_PLASTICSEUROPE_EF` (EU-25, 2007) | 4,19 | 5,5 |
| `MAT_POM` | `PROC_POM_PLASTICSEUROPE_EF` (EU-27, 2010) | 3,26 | 3,6 |
| `MAT_PA12`/`MAT_PA11` (Proxy) | `PROC_PA66_PLASTICSEUROPE_EF` (EU-27, 2011) | 6,48 | 9,0 / 5,5 |

Details: `ilcd_import/CHANGELOG.md`. Rest der Tabelle unten weiterhin offen.

## Randbedingung (2026-08-28): nur Sphera-**Basisversion**

Der Nutzer hat **nur die Professional-/Basis-Datenbank** (kein *Extension DB VII:
Plastics*, keine *Premium Plastics*). Folgen:

- **In der Basis vorhanden** (Produktionsdaten, da sie viele Produktsysteme speisen):
  PE (LD/LLD/HD), PP, PS (GPPS/HIPS/EPS), PVC, **PET**, **ABS**, **PC**,
  **PA 6**, **PA 6.6** (ggf. PA 6.12), PMMA, PUR (Hart-/Weichschaum) + Vorprodukte
  (Polyol, MDI, TDI), SBR; dazu alle **Metalle**, **Strom**, **Transport**,
  **Zerspanung/Spritzguss** (Manufacturing).
- **Nicht in der Basis** (bräuchte Extension VII / XII / Fibre-reinforced):
  **POM, PA 11, PA 12, PLA, PETG-spezifisch, ASA-spezifisch, TPU, TPE-Varianten,
  Silikonkautschuk, NBR, Kohlefaser/CFK**.

**Ausweg für die fehlenden:** die **PlasticsEurope Eco-profiles** sind
**lizenzunabhängig frei** (EPLCA-/soda4LCA-Knoten, openLCA-Import), ILCD-Format —
also genau die v3-Zielform. Darüber sind u. a. **POM, PC, ABS, PA 6, PA 6.6, PET,
PS, PVC, PP** direkt beziehbar, auch ohne Sphera-Plastics-Extension. Der Rest
(PLA, PA 11/12, ASA, PETG, TPU, TPE, Silikon, NBR, CF-PA) bleibt **dokumentierter
Proxy** in Variante A (`proxy:true` + `proxyRationale`) **oder** auf Variante-B-Literal.

## Namenskonventionen

**ILCD / PlasticsEurope Eco-profiles** (frei über EPLCA-/soda4LCA-Knoten,
z. B. `plasticseurope.lca-data.com`, `eplca.jrc.ec.europa.eu`) — das ist die
Form, die Sphera aggregiert übernimmt:
> `<Polymer> granulate (<Abk.>); <Technologie>; production mix, at plant | at producer` · Location `EU-25/EU-27/EU-28/RER`

**Sphera MLC / GaBi** (lizenzpflichtig, im Sphera-Client suchen):
> `<Region>: <Werkstoff> Granulate (<Abk.>) <Provider>`  ·  Provider historisch `PlasticsEurope` → `ts` → **`Sphera`**
> Region meist `EU-28` (Polymere), `DE` (Strom/Verarbeitung), `GLO` (Metalle).

Im Sphera-Client nach dem **Kurzzeichen in Klammern** (`(PC)`, `(POM)`, `(ABS)`)
oder dem Klartext suchen und auf **jüngstes Referenzjahr** + **`Sphera`-Provider**
filtern.

---

## Polymere / Elastomere — mit Basis-Randbedingung

Spalte **Bezug**: `Basis` = in Sphera-Professional erwartbar · `PE-frei` = über die
freien PlasticsEurope-Eco-profiles (EPLCA/soda4LCA) · `Proxy` = kein realer
Datensatz, Näherung nötig · `Literal` = auf Variante-B-Literal belassen.

| Modell-id | akt. GWP-Literal | Bezug | Datensatz / Suchname | Anmerkung |
|---|---:|---|---|---|
| `MAT_ABS` | 4,0 | Basis **oder** PE-frei | Sphera: `EU-28: Acrylonitrile-Butadiene-Styrene Granulate (ABS) Sphera` · PE-frei: `Acrylonitrile butadiene styrene (ABS); … production mix, at producer` — EU-27, 2010 | direkter Datensatz |
| `MAT_PC` | 5,5 | Basis **oder** PE-frei | Sphera: `EU-28: Polycarbonate Granulate (PC) Sphera` · PE-frei: `Polycarbonate granulate (PC); technology mix; production mix, at plant` — EU-25 (UUID `c4161063-3fde-4540-ad1c-f2da1828bf7b`) | direkter Datensatz |
| `MAT_POM` | 3,6 | **PE-frei** (nicht in Basis) | `Polyoxymethylene (POM); 1 kg primary POM "at gate" … Europe-27` (UUID `e3b65970-3420-43e6-8265-131ef3485c27`) | POM nur über PlasticsEurope, nicht in Sphera-Basis |
| `MAT_PA12` | 9,0 | **Proxy** / Literal | Proxy: `PA 6` (Basis/PE-frei) × 1,15–1,25 Aufschlag; oder EPD Evonik VESTAMID | PA 12 nicht in Basis, kein freies Eco-profile |
| `MAT_PA11` | 5,5 | **Proxy** / Literal | Proxy: bio-PA (`PA 4.10` castor, GLAD) oder `PA 6`; sonst Literal 5,5 | biobasiert, keine freie Quelle |
| `MAT_PETG` | 4,0 | **Proxy** | `PET amorphous` / `PET bottle grade` (Basis/PE-frei) als Näherung | kein dediziertes PETG in Basis |
| `MAT_PLA` | 2,7 | Literal / freie Sonderquelle | NatureWorks Ingeo LCI (frei, US) oder Literal 2,7 | fossiler Proxy sinnlos; bio-Datensatz oder Literal |
| `MAT_ASA` | 4,5 | **Proxy** | `ABS` (Basis) + kleiner Acrylat-Aufschlag | ASA standardmäßig als ABS-Proxy |
| `MAT_CFPA` | 24,0 | **teil-Proxy** | Matrix: `PA 6` (Basis/PE-frei); Faser: Kohlefaser **nicht in Basis** → Literal ~22–25 kg CO₂e/kg Faser; Massenmix ~30/70 | GWP faserdominiert; Faseranteil bleibt Literal |
| `MAT_NBR` | 3,5 | **Proxy** / Literal | Proxy: `SBR` (falls in Basis) + Acrylnitril-Aufschlag; sonst Literal 3,5 | NBR nicht in Basis |
| `MAT_SILICONE` | 7,0 | prüfen / Literal | in Basis ggf. `Polydimethylsiloxane (PDMS)` / `Silicone` — sonst Literal 7,0 | Basis-Bestand unsicher, im Client prüfen |
| `MAT_TPU` | 5,2 | **Proxy** | `PUR flexible foam` / `PU elastomer` (falls in Basis) als Näherung; sonst Literal | TPU-spezifisch nicht in Basis |
| `MAT_TPE` | 4,2 | **Proxy** / Literal | `PS`/`SBS` (Basis) als Näherung; sonst Literal 4,2 | |
| `MAT_PU` (Guss-Elastomer) | 4,5 | **Basis** (Näherung) | `Polyurethane flexible foam` bzw. `Polyol` + `MDI/TDI` + Verarbeitung (alle Basis) | PUR-Kette in Basis vorhanden |

## Metalle, Strom, Fertigung — **alle in der Basis**

Diese Bereiche deckt die Sphera-Professional-Basis gut ab; hier ist **keine
Extension nötig**.

| Modell-Element | Basis-Suchname | Anmerkung |
|---|---|---|
| `MAT_STEEL`, `MAT_SPRING` | `GLO: Steel sections (worldsteel) Sphera` / `EU-28: Steel low-alloyed Sphera` | bereits `MODELED_BY PROC_STEEL_SECTIONS_ILCD` — Konsistenz prüfen |
| `MAT_AL6061/7075` | `GLO: Aluminium ingot mix Sphera` + `Aluminium extrusion profile Sphera` | bereits `MODELED_BY PROC_ALU_EXTRUSION_EF` |
| `MAT_*_GENERIC` Kupfer / Zink / Blei | `GLO: Copper mix (99,999 %) Sphera` · `GLO: Zinc slab (SHG) Sphera` · `GLO: Lead (99,995 %) Sphera` | Metalle sind in der Basis vollständig |
| NdFeB-Magnet (aus v3.g Cross-Impact) | ggf. *Data-on-Demand*; sonst Proxy Nd + Fe + B + Sinterstrom | Magnetdatensatz evtl. nicht in Basis |
| `PROC_CNC` (Zerspanen) | `DE: Aluminium / steel cutting (milling) Sphera` **oder** `DE: Electricity grid mix` + Schneidöl + Spanverlust | Modellansatz (energyIntensity) ist bereits gleichwertig |
| Spritzguss (falls modelliert) | `DE: Plastic injection moulding Sphera` | pro kg Formteil |
| `PROC_FFF`, `PROC_SLS`, `PROC_MJF` | **kein Datensatz — auch nicht in Extensions** | additive Fertigung: Modellansatz `energyIntensity_kWh_per_kg` + Strom beibehalten (Faludi/Kellens) |
| `PROC_RUBBER`, `PROC_SILCAST`, `PROC_OVERMOLD` | Strom + Vulkanisation selbst modelliert | |
| Strom DE (`FLOW_ELECTRICITY`, CF 0,38) | `DE: Electricity grid mix Sphera` (1kV–60kV) | ersetzt den 0,38-Literal |
| Strom „grün" (CF 0,04) | `DE: Electricity from wind power Sphera` / `… hydro power Sphera` | für das `DE_green`-Szenario |

---

## Wie einspielen (v3-Standard)

Zwei Quellen für Variante A: (a) **Sphera-Basis** — Metalle, Strom, Fertigung,
ABS, PC, PA 6/6.6, PET, PE/PP/PS/PVC, PUR-Kette; (b) **PlasticsEurope Eco-profiles**
(frei) — u. a. **POM**, sowie PC/ABS/PA 6/PA 6.6/PET falls in der Basis unpassend.
Der Rest bleibt Proxy (`proxy:true`) oder Variante-B-Literal.

Je realem Datensatz einen `Process`-Knoten mit **ILCD-Metadaten** anlegen bzw.
ergänzen: `uuid`, `dataSetVersion`, `referenceYear`, `geographicalLocation`,
`technologyDescription`, `dataSetOwner` (`PlasticsEurope`/`Sphera`),
`referenceUnit='kg'`, `lifecycleModule='A1-A3'`. Dann in **Variante A**:

```cypher
MATCH (m:Material {id:'MAT_PC'}), (p:Process {id:'PROC_PC_GRANULATE_SPHERA'})
MERGE (m)-[:MODELED_BY {proxy:false, lifecycleModule:'A1-A3',
        proxyRationale:'PlasticsEurope PC granulate, EU, via Sphera MLC'}]->(p);
```

Die `ASSESS_EF31A_*` / `IR_EF31A_*`-Ergebnisse (Variante A) rechnen dann über
`lca_generic('IAM_EF31', $artifactId)` automatisch mit; Variante B bleibt als
Fallback bestehen. Konfidenz **niedrig** (ASA, PETG, TPE) heißt: Proxy sichtbar
als `proxy:true` + `proxyRationale` markieren.

## Quellen

- [PlasticsEurope Eco-profiles set](https://plasticseurope.org/sustainability/circularity/life-cycle-thinking/eco-profiles-set/)
- [PlasticsEurope Public LCI Database — PC granulate (PC)](https://plasticseurope.lca-data.com/datasetdetail/process.xhtml?uuid=c4161063-3fde-4540-ad1c-f2da1828bf7b&version=00.00.000)
- [PlasticsEurope Public LCI Database — Polyoxymethylene (POM)](https://plasticseurope.lca-data.com/datasetdetail/process.xhtml?lang=en&uuid=e3b65970-3420-43e6-8265-131ef3485c27&version=01.00.000)
- [Sphera Managed LCA Content — Übersicht](https://sphera.com/solutions/product-stewardship/life-cycle-assessment-software-and-data/managed-lca-content/)
- [Sphera LCA-Datenbank-Browser](https://lcadatabase.sphera.com/)
- [Sphera MLC 2025.1 Update](https://sphera.com/resources/blog/spheras-mlc-database-update-2025-1-explained/)
- [GaBi Extension database VII: Plastics (LCI-Doku)](https://gabi.sphera.com/support/gabi/gabi-database-2020-lci-documentation/extension-database-vii-plastics/)
- [openLCA Nexus — GaBi](https://nexus.openlca.org/database/GaBi)
