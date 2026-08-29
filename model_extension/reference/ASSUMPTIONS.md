# Angenommene Kennwerte für den Anwendungsfall (Niryo-Ned2-Greifer)

Stand: 2026-08-27. Alle Werte sind **literaturbasierte Größenordnungs-Annahmen**
für die Fallstudie, dokumentiert damit sie später gegen ILCD/EF- bzw. EPD-Daten
ausgetauscht werden können. Jede Migration, die sie einspielt, setzt eine
`*Basis`-Property mit Verweis „ASSUMPTIONS.md".

Recherchehinweise: die exakten Zahlen liegen in kostenpflichtigen LCA-Datenbanken
(ecoinvent, Sphera/GaBi) bzw. herstellerspezifischen EPDs. Die hier verwendeten
Bereiche entsprechen gängiger LCA-Literatur (Plastics Europe Eco-profiles,
ecoinvent-Größenordnungen, Ashby „Materials and the Environment", peer-reviewte
AM-LCA-Studien). Quellen am Ende.

---

## 1. Werkstoff A1 (cradle-to-gate, Primärproduktion), kg CO₂-eq / kg

| Werkstoff | id | GWP A1 | Bereich Literatur | Anmerkung |
|---|---|---:|---|---|
| Aluminium 6061 (Strangpressprofil) | MAT_AL6061 | **9,67** | 8–12 | aus `PROC_ALU_EXTRUSION_EF` (validiert) |
| Aluminium 7075 | MAT_AL7075 | 9,67 | 8–12 | wie 6061 (Legierungsunterschied v2 nicht getrennt) |
| Baustahl / niedriglegiert | MAT_STEEL | 2,3 | 1,8–2,8 | Hochofenroute |
| Federstahl | MAT_SPRING | 2,8 | 2,3–3,3 | legiert |
| PA12 (Pulver, Neuware) | MAT_PA12 | 9,0 (Literal) / **6,48** (Proxy real) | 8–10 | Proxy = PlasticsEurope PA 6.6 EU-27 2011 (`PROC_PA66_PLASTICSEUROPE_EF`); PA12 real höher |
| PA11 (biobasiert) | MAT_PA11 | 5,5 (Literal) / **6,48** (Proxy real) | 4–7 | Proxy = PA 6.6 (fossil, überschätzt bio-PA11) |
| PETG | MAT_PETG | 4,0 | 3,5–4,5 | |
| PLA (biobasiert) | MAT_PLA | 2,7 | 2–3,5 | |
| ABS | MAT_ABS | ~~4,0~~ **3,14** | 3,5–4,5 | **real:** PlasticsEurope EU-27 2010 (`PROC_ABS_PLASTICSEUROPE_EF`) |
| ASA | MAT_ASA | 4,5 | 4–5 | Proxy ABS |
| Polycarbonat | MAT_PC | ~~5,5~~ **4,19** | 5–6,5 | **real:** PlasticsEurope EU-25 **2007**; neuere Eco-profiles ~7,7 |
| POM / Acetal | MAT_POM | ~~3,6~~ **3,26** | 3–5,5 | **real:** PlasticsEurope EU-27 2010 (`PROC_POM_PLASTICSEUROPE_EF`) |
| CF-verstärktes PA | MAT_CFPA | 24,0 | 18–30 | Kohlefaser dominiert (~20–25/kg Faser) |
| TPU 95A | MAT_TPU | 5,2 | 4,5–6 | |
| TPE | MAT_TPE | 4,2 | 3,5–5 | |
| Silikonkautschuk | MAT_SILICONE | 7,0 | 5–11 | breite Spanne |
| NBR-Kautschuk | MAT_NBR | 3,5 | 3–4 | |
| PU-Elastomer | MAT_PU | 4,5 | 4–5 | |

### Weitere EF3.1-Kategorien je kg Werkstoff (nur grobe Faktoren, Variante B)

Skaliert am Aluminium-Datensatz-Verhältnis (`PROC_ALU_EXTRUSION_EF`):
Versauerung ≈ GWP × 5,4·10⁻³ mol H⁺/kg CO₂-eq · Eutrophierung marin ≈ GWP × 1,07·10⁻³ ·
Photochem. Ozon ≈ GWP × 3,15·10⁻³ · Landnutzung ≈ GWP × 0,89 (dimensionslos) ·
Ozonabbau ≈ 0 · Feinstaub ≈ 0. Für Polymere/Elastomere sind diese Verhältnisse
weniger belastbar als für Metalle → Variante B ist als „volle Abdeckung, gemischte
Datenqualität" gekennzeichnet.

## 2. Fertigungsenergie A3 (Strom), kWh / kg Bauteil

| Prozess | id | kWh/kg | Bereich | Anmerkung |
|---|---|---:|---|---|
| Multi Jet Fusion | PROC_MJF | 15 | 10–25 | inkl. Aufheizen/Abkühlen, mittlere Packdichte |
| Selective Laser Sintering | PROC_SLS | 30 | 20–50 | Kammerheizung dominiert |
| Fused Filament Fabrication | PROC_FFF | 20 | 10–30 | langsam, geringe Leistung |
| CNC-Fräsen | PROC_CNC | 20 | 10–30 | + Materialverschnitt (s. u.) |
| Laserschneiden | PROC_LASER | 8 | 5–15 | |
| Blechbiegen | PROC_BEND | 2 | 1–3 | |
| Silikonguss | PROC_SILCAST | 4 | 2–5 | Härteofen |
| Elastomerformung | PROC_RUBBER | 5 | 3–8 | |
| Umspritzen | PROC_OVERMOLD | 6 | 4–8 | |
| Alu-Guss + Zerspanung | PROC_ALU_CAST_MACHINING | 15 | 10–20 | |
| Alu-Blechumformung | PROC_ALU_SHEET_STAMPING | 3 | 2–5 | |

CNC-Verschnittfaktor: fertige Masse × 1,8 Rohmaterial (subtraktiv, kleine Teile).
AM-Prozesse: Materialfaktor 1,1 (Stützen/Überschuss).

## 3. Strom-Emissionsfaktor, kg CO₂-eq / kWh

| Netz | Wert | Bereich | Prozessknoten |
|---|---:|---|---|
| DE-Netzmix (Standard) | 0,38 | 0,35–0,42 | Bezug 2021–2024 |
| DE-Grünstrom | 0,04 | 0,03–0,05 | `PROC_ELECTRICITY_GREEN_GRID_MIX_DE` |
| CN-Netzmix | 0,58 | 0,55–0,65 | `PROC_ELECTRICITY_GRID_MIX_CN` |
| EU-Durchschnitt | 0,28 | 0,25–0,32 | — |

Standard-Szenario `SC_BASELINE` = DE-Netzmix. Alternativen als `ModelScenario`
(`SC_GRID_CN`, `SC_GRID_EU`, `SC_GREEN_ELECTRICITY`).

## 4. Bauteilmasse

| Bauteilklasse | Basis |
|---|---|
| Kontaktteil (43×, `partType='Jaw/Finger/Cup/Pole'`, hat Geometrie) | Bounding-Box-Volumen × Füllfaktor × Dichte |
| Füllfaktor CNC | 0,55 (gefräste Taschen) |
| Füllfaktor MJF/SLS/FFF | 0,40 (Druck, oft Infill/hohl) |
| Füllfaktor Silikon-/Elastomerguss | 0,85 (massiv) |
| Schnittstellenteil (43×, `partType='Interface'`, keine Geometrie) | Typ-Default: 20 g (Polymer), 35 g (Metall) — „typischer Werkzeug-Adapter" |
| Stückzahl | `HAS_COMPONENT.quantity` (Kontakt meist 2, Schnittstelle 1) |

Plausibilisierung gegen die 5 bekannten `Artifact.mass_g` (19,5–115 g).

## 5. Zirkularität (verfeinert ggü. v3.a-Klassendefaults)

| Werkstoffklasse | Recyclat-Anteil (typ.) | EoL-Recyclingrate | Wiederverwendung |
|---|---:|---:|---:|
| Aluminium | 0,35 (Profil, EN15804 A1-A3) | 0,90 | 0,05 |
| Stahl | 0,40 | 0,85 | 0,05 |
| Technische Thermoplaste (PA/PC/POM/ABS/ASA/PETG) | 0,05 | 0,20 (mechanisch begrenzt) | 0,00 |
| PLA | 0,00 | 0,10 (industrielle Kompostierung, kein Recycling) | 0,00 |
| Elastomere (Silikon/TPU/TPE/NBR/PU) | 0,00 | 0,10 | 0,00 |
| Faserverbund (CF-PA) | 0,00 | 0,05 | 0,00 |

Nutzungsdauer Greifer-Backe: Design 3 a, Referenz 3 a (Nutzenfaktor neutral).
Wechselbacken (`FEAT_PRINTABLE`) / Schnellwechsel (`FEAT_EASY`): Design 5 a.

## 6. ReCiPe 2016 Midpoint (Hierarchist) — 18 Kategorien

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

Repräsentative Charakterisierungsfaktoren (IPCC AR5 GWP100 / ReCiPe H):
CO₂ = 1 · CH₄ (fossil) = 29,8 · CH₄ (biogen) = 27,0 · N₂O = 273 · SF₆ = 25200 ·
Terrestrische Versauerung: SO₂ = 1,0 · NOx = 0,36 · NH₃ = 1,96 ·
Feinstaub: PM2.5 = 1,0 · SO₂ = 0,29 · NOx = 0,11 · NH₃ = 0,24 ·
Marine Eutrophierung: N-total = 1,0 · NOx = 0,04 ·
Süßwasser-Eutrophierung: P-total = 1,0 · Fossile Ressourcen: Rohöl ≈ 1,0 kg oil eq/kg,
Erdgas ≈ 0,84, Steinkohle ≈ 0,49.

## 7. Cross-Impact-Matrix (v3.g, `INFLUENCES`)

Qualitative, ingenieurmäßig begründete Wirkbeziehungen zwischen Design-Hebeln
(`Feature`, `CoreProperty`, `Material`-Klasse) und Wirkungskategorien sowie
zwischen Kategorien. Konvention: `sign '+'` = der Hebel **verbessert** das
Nachhaltigkeitsergebnis der Zielkategorie (geringere Last bzw. höhere
Zirkularität/Reparierbarkeit), `sign '-'` = **verschlechtert** es;
`strength` 1 = schwach, 2 = mittel, 3 = stark.

| Hebel | Kategorie | sign·strength | Begründung |
|---|---|---|---|
| Ersetzbare gedruckte Kontaktbacke (`FEAT_PRINTABLE`) | Reparierbarkeit | +3 | Feldtausch ohne Ersatzteillager |
| " | Zirkularität | +2 | Print-on-demand, kein Lagerausschuss |
| " | Klima | −1 | zusätzliches Polymerteil + FFF-Energie |
| Werkzeuglose Roboterschnittstelle (`FEAT_EASY`) | Reparierbarkeit | +3 | schnelle reversible Montage |
| " | Zirkularität | +2 | zerstörungsfreie Demontage → Materialtrennung |
| Magnetische Kontaktfläche (`FEAT_MAGNET`) | Reparierbarkeit | +3 | Schnellwechsel |
| " | Ressourcen (Mineralien/Metalle) | −2 | Seltene Erden (Nd, Dy) |
| " | Zirkularität | −1 | NdFeB schwer trennbar/recycelbar |
| Reibpad / weicher Kontakt (`FEAT_RUBBER`/`FEAT_SOFT`) | Zirkularität | −2 | Duroplast-Elastomer, niedriger MCI |
| Demontagefähigkeit (`CP_DISASSEMBLY`) | Reparierbarkeit / Zirkularität | +3 / +2 | gemeinsame Ursache Design-for-Disassembly |
| Werkstoffklasse Metall | Zirkularität / Klima | +3 / −2 | recycelbar (MCI ≈ 0,65) ↔ Primär-Al 9,67 + Zerspanungsverlust |
| Werkstoffklasse Verbund (CF-PA) | Klima / Zirkularität | −3 / −3 | ≈ 24 kg CO₂e/kg, kein Recyclingpfad (MCI ≈ 0,14) |
| Werkstoffklasse Elastomer | Zirkularität | −3 | Duroplast (MCI ≈ 0,16) |
| Zirkularität → Klima | | +2 | höherer Recyclatanteil senkt A1-GWP |
| Reparierbarkeit → Klima | | +2 | Lebensdauerverlängerung amortisiert graue Emissionen |
| Reparierbarkeit → Zirkularität | | +3 | gemeinsame Ursache |
| Zirkularität → Ressourcen (Mineralien/Metalle) | | +3 | Sekundärmetall verdrängt Primärabbau |

Recyclat-Aluminium (Szenario `SC_RECYCLED_ALU`): recyclat-angepasster A1-Faktor
= 9,67·(1−rc) + 0,55·rc mit rc = 0,75 → **2,83 kg CO₂e/kg** (Primär 9,67; Remelt-
Sekundäraluminium ≈ 0,5–0,6 kg CO₂e/kg).

## Quellen (Rechercheeinstieg)

- Plastics Europe, Eco-profiles / Environmental Product Declarations (Polymer-GWP-Bereiche).
- ecoinvent v3 Größenordnungen (Metalle, Strommixe).
- Ashby, „Materials and the Environment: Eco-informed Material Choice", 2nd ed. (Werkstoff-Embodied-Carbon-Bereiche).
- Faludi et al. / Kellens et al., LCA additiver Fertigung (spezifischer Energieverbrauch SLS/MJF/FFF): [PMC6947159](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6947159/), [S2666790821000288](https://www.sciencedirect.com/science/article/pii/S2666790821000288).
- Huijbregts et al., „ReCiPe2016", Int J LCA 2017: [10.1007/s11367-016-1246-y](https://link.springer.com/article/10.1007/s11367-016-1246-y); RIVM-Report 2016-0104: [rivm.nl](https://www.rivm.nl/bibliotheek/rapporten/2016-0104.pdf).
- ReCiPe-2016-Kategorienliste: [Earthster KB](https://docs.earthster.org/en/articles/6827227-recipe-2016-impact-categories).
- Umweltbundesamt, Strommix-Emissionsfaktor Deutschland (jährliche Fortschreibung).
- IPCC AR5 (2013), GWP100-Werte.
- EN 15804+A2 (Modul-Definitionen, EPD-Bezugsrahmen).
- Ellen MacArthur Foundation / Granta, „Material Circularity Indicator" Methodology (2019).
