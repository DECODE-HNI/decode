# `v2-data` — Änderungsprotokoll (LCI-Vervollständigung)

## 2026-08-27 — Massen, Fertigungsenergie, zwei Datenvarianten

Alle Werte literaturbasiert, dokumentiert in `../ASSUMPTIONS.md`. Reihenfolge:
`1_masses` → `1b_masses_fix_cups` → `2_manufacturing_energy` → `3_material_gwp_literals`
→ `4A_realonly` **und** `4B_full_coverage` (parallele Varianten).

### Gemeinsame Basis

| Artefakt | Änderung |
|---|---|
| `Part.mass_g` + `massBasis` | **alle 86 Teile**. Kontaktteile (43) aus Bounding-Box-Geometrie × Füllfaktor (CNC 0,55 / Druck 0,40 / Guss 0,85 / Laser 0,90) × Dichte; Saugnäpfe über π/4·d²·h × 0,30; Schnittstellenteile (43) Typ-Default 20 g Polymer / 35 g Metall. Greifermasse berechnet 20–61 g (Plausibilisierung: 5 bekannte `Artifact.mass_g` 19,5–115 g inkl. Antrieb). |
| `Process.energyIntensity_kWh_per_kg` + `materialFactor` + `energyBasis` | 11 Fertigungsprozesse (MJF 15 · SLS 30 · FFF 20 · CNC 20 · … kWh/kg; CNC-Verschnitt 1,8) |
| `Flow FLOW_ELECTRICITY` +`gwp_kgCO2e_per_kWh_{DE,DE_green,CN,EU}` | 0,38 / 0,04 / 0,58 / 0,28 |
| `(FLOW_ELECTRICITY)-[:CHARACTERIZES]->(IC_CLIMATE)` | `factor=0,38`, `location='DE'` — Strom bekommt einen Klimafaktor |
| Manufacturing-Template-Flüsse (`FLOW_PA12`, `FLOW_ELECTRICITY` …) | reale (repräsentative) Mengen statt Platzhalter `1.0` |
| `Material` +`gwp_A1_kgCO2e_per_kg`, `ef31_categories`/`ef31_factors_A1` (Parallel-Arrays, kein Map-Typ in Neo4j), `gwpBasis` | 18 reale Materialien |
| `Material` circularity refinement | `recycledContentAssumed`/`recyclingRate`/`reusability` je Werkstoffklasse aus ASSUMPTIONS.md 5 (verfeinert ggü. v3.a-Defaults) |

### Variante A — `4A_realonly.cypher` (nur reale ILCD-Datensätze)

`(:Material)-[:MODELED_BY]->(:Process)` **nur** wo ein Datensatz im Graphen existiert:
- Aluminium (`MAT_AL6061/7075` → `PROC_ALU_EXTRUSION_EF`, aus v2)
- Stahl (`MAT_STEEL/SPRING` → `PROC_STEEL_SECTIONS_ILCD`)
- Polyamid (`MAT_PA12/PA11` → `PROC_PA66_GRANULATE_MIX`, Proxy, Chemie abweichend)

`Assessment`/`ImpactResult` mit `dataVariant='A-realdataset'`, 43 Gripper × 8 Kategorien
(nur Teile mit modelliertem Werkstoff tragen bei — Elastomere, PETG, POM, PC, ABS, ASA,
PLA, CF-PA bleiben ohne Beitrag). Klima 0,16–0,54 kg CO₂-eq/Gripper.

### Variante B — `4B_full_coverage.cypher` (Literaturwerte, volle Abdeckung)

Alle 43 Gripper, EF3.1 **A1 (alle Werkstoffe) + A3 (Stromklima)** aus den Per-kg-Literalen.
`dataVariant='B-literal'`. Klima **0,34–1,01 kg CO₂-eq/Gripper** (Ø 0,50). Basisquery
`lca_from_literals.cypher` (Parameter `$electricityCF`). EF3.1-Nicht-Klima-Faktoren sind
aus dem Al-Datensatz-Verhältnis skaliert → für Polymere/Elastomere schwach, entsprechend
gekennzeichnet.

### Vergleich (V-groove Al6061, Klimawandel)

| Rechnung | kg CO₂-eq |
|---|---:|
| v2 (nur Alu-Kontaktteile, A1) | 0,345 |
| Variante A (Alu + PA-Schnittstelle + Stahl, A1) | 0,540 |
| Variante B (alle Werkstoffe A1 + A3 Strom, Literal) | 1,009 |

### Entscheidung offen

**A vs. B** — A ist rigoros (nur reale Datensätze, Teilabdeckung), B ist vollständig
(alle Gripper bewertbar, gemischte Datenqualität). Beide liegen parallel im Graphen
(`dataVariant`-Property). Später entscheiden, welche der Fallstudien-Standard wird;
Empfehlung: **B** als Arbeitsstand für „alle Verfahren auf allen Greifern", **A** als
belastbarer Kern für Kernaussagen.

### Live-DB nach v2-data

3 648 Knoten / 81 937 Beziehungen. `Assessment` 182 (96 + 43 A + 43 B),
`ImpactResult` 771 (126 + 344 A + 301 B). 0 label-lose Knoten, 0 Teile ohne Masse.
