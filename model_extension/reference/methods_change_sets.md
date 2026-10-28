# Master-Spec: Änderungsmenge pro Bewertungsmethode

Stand: 2026-08-27 (Spec + Fortschritt jenes Laufs). Gehört zu
[`model_extension/migrations/PLAN.md`](../migrations/PLAN.md). Grundlage: Live-Inspektion
zum Ausgangszeitpunkt (2 721 Knoten / 79 647 Beziehungen) und das
Methodendiagramm (3 Paradigmen / 9 Gruppen / 29 Verfahren; nach der
KI-Entfernung 2026-08-29 sind 3.1.x/3.3.x raus → 7 Gruppen / 23 Verfahren).
**Aktueller Ist-Stand:** [`model_extension/reference/EXTENSION_REFERENCE.md`](EXTENSION_REFERENCE.md)
— Live-DB 2026-08-29: 5 620 Knoten / 86 635 Beziehungen / 6 Methoden.

Dieses Dokument sagt **pro Verfahren**, welche Knoten / Kanten / Properties /
Vokabulare / Daten / Queries nötig sind, in welcher Ausbaustufe sie liegen und
**welche anderen Verfahren dieselbe Änderung teilen**.

---

## 0. Lesehilfe

**Änderungs-Tokens**

| Token | Bedeutung |
|---|---|
| `P` | neue Property (Knoten oder Kante) |
| `V` | kontrollierte Werteliste zu einer Property |
| `R` | neuer Beziehungstyp |
| `N` | neues Label |
| `D` | Datenladung (kein Schema) |
| `Q` | nur Query, keine Schemaänderung |
| `~` | bestehendes normalisieren / korrigieren |

**Ausbaustufen** (siehe PLAN.md)

| Stufe | Box | Kurz |
|---|---|---|
| **v1** | black | Produktmodell + konkrete attribuierte Indikatoren + Reparierbarkeit |
| **v2** | grey | ILCD/EF3.1-Inventar + Rechenkern (`ImpactResult.value`, `lca_computed_ef31`) |
| **v3** | white | ILCD interpretierbar: `lca_generic($methodId)`, funkt. Einheit, Module, Kategorie-Hygiene, Methoden-Taxonomie, 2. LCIA-Methode |
| **v3.x** | white + Modul | komponierbare Methodenfamilien (a Zirkularität · b Kosten · c Szenario/Unsicherheit · d Provenienz/Deklaration) |

**Prinzip:** Migrationen laufen gegen die Live-DB; die Stufen-Snapshots sind
gefilterte Exporte desselben Standes. Jede Stufe ist streng additiv.

---

## 1. Querschnittliche Voraussetzungen (PRE)

Einmalig, tragen mehrere Verfahren gleichzeitig.

| ID | Stufe | Änderung | Tokens |
|---|---|---|---|
| **PRE‑1** | v2 | `P ImpactResult.value, .valueLow, .valueHigh, .computedAt, .provenance` + `V provenance=[LCI-calculated, measured, literature, ml-predicted, expert-estimate]` — heute hat `ImpactResult` **keinen** Zahlenwert | 5P, 1V |
| **PRE‑2** | v3 | `P Process.lifecycleModule` + `V` EN15804 `[A1,A2,A3,A1-A3,A4,A5,B1..B7,C1..C4,D]` + `D` Backfill ~55 Prozesse (Quelle: Freitext-Namen „… (EN15804 A1-A3)" + `processType`) + `~ Process.processType` (`EndOfLife` vs „End of Life") | 1P,1V,1D,1~ |
| **PRE‑3** | v3 | `P Assessment.functionalUnit, .referenceFlow, .referenceQuantity, .referenceUnit, .systemBoundary` + `V systemBoundary=[cradle-to-gate, cradle-to-grave, gate-to-gate, cradle-to-cradle]` | 5P,1V |
| **PRE‑4** | v3 | Methoden-Taxonomie: `N AssessmentApproach{id,name,level,code}` + `R (AssessmentApproach)-[:BROADER]->(AssessmentApproach)` + `R (Assessment)-[:APPLIES_APPROACH]->(AssessmentApproach)` + `D` 3 Paradigmen / 9 Gruppen / 29 Verfahren aus dem Diagramm | 1N,2R,1D |
| **PRE‑5** | v3 | `~` ImpactCategory-Hygiene: ~20 Waisen / Near-Duplikate zusammenführen (`IC_EF_CLIMATE_BIOGENIC` vs `IC_EF_CLIMATE_CHANGE_BIOGENIC`, 3× Ecotoxicity-freshwater …), `indicator`/`unit` normalisieren (teils zerrissen, z. B. `indicator=" freshwater"`) | 1~ (groß) |

Aktueller Kategorien-Zustand: 42 `ImpactCategory`-Knoten, davon 22 an `IAM_EF31`
gehängt (`HAS_CATEGORY`), 1 an `IAM_PCF`, 20 verwaist.

---

## 2. Paradigma „bilanzierende Ansätze" — Fokus, weitgehend im Modell

### 2.1 Lebenszyklusbasierte Umweltbewertung

#### Ökobilanzierung (LCA, ISO 14040/44)
- **Was:** Vollständige mehrkategorielle LCIA. `Artifact → ProcessPlan → CONTAINS_PROCESS → Process → HAS_FLOW → Flow → CHARACTERIZES → ImpactCategory`, gefiltert per Methode.
- **Stufe:** v2 (EF3.1, ein-Methoden-Rechnung) → v3 (methodenagnostisch)
- **Nutzt:** komplette ILCD-Struktur (2 102 `Flow`, 49 672 `HAS_FLOW`, 27 768 `CHARACTERIZES`), `IAM_EF31`
- **Δ Schema:** PRE‑1 (v2), PRE‑2/PRE‑3/PRE‑4/PRE‑5 (v3)
- **Δ Daten:** `D` restliche EF3.1-Kategorien an `HAS_CATEGORY` hängen, CF-Abdeckung prüfen
- **Basisquery:** v2 `lca_computed_ef31($artifactId)` = Σ `CONTAINS_PROCESS.share · HAS_FLOW.amount · CHARACTERIZES.factor` je Kategorie → `ImpactResult.value`; v3 `lca_generic($methodId, $artifactId)`
- **Änderungsmenge:** über PRE hinaus: 1D, 1Q (v2) + 1Q-Refactor (v3)
- **Betroffene Methoden:** alle folgenden LCA-Ableitungen (CF, H₂O, THG, CED) hängen an derselben Query + PRE‑1

#### Umweltfußabdruck CO₂ (Carbon Footprint, ISO 14067)
- **Was:** LCA-Teilmenge = nur Klimawandel-Kategorien (fossil / biogen / LULUC).
- **Stufe:** v2 (existiert als `IAM_PCF`) → v3 (Sub-Kategorien sauber)
- **Nutzt:** `IAM_PCF`, `IC_CLIMATE` + EF-Klima-Subkategorien
- **Δ Schema:** keine über PRE
- **Δ Daten:** `D` GWP-Subkategorien unter einem PCF-Approach bündeln
- **Basisquery:** `carbon_footprint.cypher` = `lca_generic` mit `methodId='IAM_PCF'`
- **Änderungsmenge:** 1D, 1Q
- **Betroffene Methoden:** THG-Bilanzierung (teilt GWP-Kategorien), EPD/DPP (berichtet PCF)

#### Umweltfußabdruck H₂O (Water Footprint, ISO 14046)
- **Was:** Teilmenge = Wassernutzung, regionalisiert.
- **Stufe:** v3
- **Nutzt:** `IC_EF_WATER_USE`, `CHARACTERIZES.location` (224 Regionen bereits vorhanden)
- **Δ Schema:** keine
- **Δ Daten:** `D` Methoden-Instanz `IAM_WATER` (AWARE) + `HAS_CATEGORY` → Wasserkat.; `D` AWARE-CF als `CHARACTERIZES{factor,location}` für Wasserflüsse; `Flow.category` „Wasser" prüfen
- **Basisquery:** `water_footprint.cypher`
- **Änderungsmenge:** 2D, 1Q
- **Betroffene Methoden:** —

#### Treibhausgasbilanzierung (GHG Protocol)
- **Was:** wie CF, aber nach **Scope 1/2/3** gegliedert statt nach Lebenszyklusmodulen.
- **Stufe:** v3
- **Nutzt:** GWP-Kategorien, `lca_generic`
- **Δ Schema:** `P Process.ghgScope` + `V [scope1,scope2,scope3]`; opt. `P Process.ghgScope3Category`
- **Δ Daten:** `D` ~55 Prozesse nach Scope klassifizieren
- **Basisquery:** `ghg_inventory.cypher` = GWP gruppiert nach `ghgScope`
- **Änderungsmenge:** 1–2P, 1V, 1D, 1Q
- **Betroffene Methoden:** teilt GWP-Kategorien mit CF; Klassifikator-Bauform identisch zu PRE‑2 (`lifecycleModule`)

### 2.2 Stoff- und ressourcenbezogene Bilanzierung

#### Stoff- & Materialstromanalyse (MFA)
- **Was:** Massenbilanz der Flüsse durch eine definierte Systemgrenze.
- **Stufe:** v3
- **Nutzt:** `HAS_FLOW{amount,unit,direction}`, `Flow.flowType`, `Flow.referenceUnit`, `Material.density_kg_m3`, `CONTAINS_PROCESS.sequence`
- **Δ Schema:** `P Flow.balanceRole` + `V [input,product,coproduct,emission,waste,resource]`; opt. `N SystemBoundary` + `R (Assessment)-[:HAS_BOUNDARY]->(SystemBoundary)` + `R (SystemBoundary)-[:INCLUDES]->(Process)`
- **Δ Daten:** `D` Flüsse taggen; Volumen→Masse über `referenceUnit` + Dichte
- **Basisquery:** `mfa_balance.cypher` = Masse ein/aus je Prozess, Δ = Imbalance
- **Änderungsmenge:** 1P, 1V, 1D, 1Q (+ opt 1N, 2R)
- **Betroffene Methoden:** Zirkularität (nutzt Materialanteile), MFCA (dieselbe Flussklassifikation product/loss)

#### Schadstoffbilanzierung
- **Was:** Filter auf gefährliche Stoffe, Summe je Substanz/Kompartiment.
- **Stufe:** v3
- **Nutzt:** `Flow.casNumber`, `Flow.category`, `HAS_FLOW.amount`
- **Δ Schema:** `P Flow.hazardClass` (String[]) + `V [SVHC,CMR,PBT,vPvB,GHS-H…]` **oder** `N HazardStatement{code,ghs}` + `R (Flow)-[:HAS_HAZARD]->(HazardStatement)`
- **Δ Daten:** `D` gefährliche Flüsse annotieren (Teilmenge mit CAS)
- **Basisquery:** `pollutant_inventory.cypher`
- **Änderungsmenge:** 1P, 1V, 1D, 1Q *(oder 1N, 1R, 1D, 1Q)*
- **Betroffene Methoden:** Digitaler Produktpass (SVHC-Meldung), Humantoxizitäts-Kategorien (Plausibilisierung)

#### Kumulierter Energieverbrauch (CED / KEA, VDI 4600)
- **Was:** Summe Primärenergie, erneuerbar / nicht erneuerbar.
- **Stufe:** v3
- **Nutzt:** `IC_ENERGY` („Energy demand", MJ), `lca_generic`
- **Δ Schema:** `P Flow.energyResourceType` + `V [renewable,non-renewable,nuclear]`
- **Δ Daten:** `D` Methoden-Instanz `IAM_CED`; 3 Kategorie-Instanzen (CED-total/-ren/-nonren); `D` CED-CF als `CHARACTERIZES{factor}` ab Primärenergie-Ressourcenflüssen
- **Basisquery:** `ced.cypher` = `lca_generic` mit `methodId='IAM_CED'`
- **Änderungsmenge:** 1P, 1V, 3D, 1Q
- **Betroffene Methoden:** Ökoeffizienz (kann CED als Nenner nutzen), prospektive LCA (Energiemix-Szenarien)

#### Zirkularitätsbewertung (MCI, Ellen MacArthur)  → **Modul v3.a**
- **Was:** Materialkreislauf-Index je Bauteil, massengewichtet je Artefakt.
- **Stufe:** v3.a
- **Nutzt:** `USES_MATERIAL.fraction`, `Material.recycledContent_pct` (Achtung: real überall NULL), `HAS_COMPONENT.quantity`, `Artifact.componentCount`/`distinctMaterialCount`/`disassemblyReversibility` (aus v1!), `Process{processType:'EndOfLife'}` + `CONTAINS_PROCESS.share`
- **Δ Schema:** `P Material.recyclingRate, .recyclability, .reusability`; `P Artifact.designLifetime, .usageIntensity, .referenceLifetime`; `N EndOfLifeRoute{id,name,type}` + `R (Material)-[:HAS_EOL_ROUTE{fraction}]->(EndOfLifeRoute)` *(oder* `P Process.eolRouteType` *nutzen)*
- **Δ Daten:** `D` 1 Kategorie-Instanz `IC_CIRCULARITY{indicator:'MCI',unit:'dimensionless'}`; Kreislaufparameter für ~23 `Material`; EoL-Anteile; `D` echte `recycledContent_pct`-Werte (Datenlücke!)
- **Basisquery:** `mci.cypher` = V (Virgin), W (Waste), Nutzenfaktor, LFI, MCI
- **Änderungsmenge:** ~6P, (1N + 1R oder 1P), 2D, 1Q
- **Betroffene Methoden:** nutzt v1-Reparierbarkeit; speist EPD/DPP; konsequenzielle LCA (Modul D / vermiedene Last)

### 2.3 Integrierte ökologisch-ökonomische Bilanzierung  → **Modul v3.b (Prototyp)**

**Kostendimension** (heute **keine** ökonomische Property im Graphen):

| Variante | Änderung | Für |
|---|---|---|
| **A schlank** | `P Material.unitCost,.costUnit`; `P Process.unitCost,.costUnit`; `P CONTAINS_PROCESS.costShare`; `P HAS_FLOW.unitCost` | Ökoeffizienz, grobe Kostensicht |
| **B strukturiert** *(empfohlen)* | `N CostItem{category,amount,currency,perUnit}` + `R (Process\|Part\|Material\|Flow)-[:HAS_COST]->(CostItem)` + `V category=[material,energy,system,waste-management,capital,labour]` | MFCA (braucht Kostenarten-Trennung), hybride LCA |

#### Materialfluss-Kostenrechnung (MFCA, ISO 14051)
- **Was:** Kosten je Materialstrom, Produktpfad vs. Verlustpfad.
- **Stufe:** v3.b
- **Nutzt:** Kosten-B, `HAS_FLOW.amount`, `Flow.flowType`
- **Δ Schema:** Kosten-B + `P Flow.mfcaClass` + `V [product, material-loss]`
- **Δ Daten:** `D` CostItems je Prozess; Output-Flüsse klassifizieren
- **Basisquery:** `mfca.cypher` = Inputkosten → Produkt- vs. Verlustpfad nach Massenanteil; „Kosten des Abfalls" hochrollen
- **Änderungsmenge:** [1N,1R,1V] + 1P, 1V, 1D, 1Q
- **Betroffene Methoden:** Ökoeffizienz (Wertbasis), hybride LCA (monetäre I-O), MFA (Fluss product/loss)

#### Ökoeffizienz-Bewertung (ISO 14045)
- **Was:** Umweltwirkung ÷ Produkt-/Systemwert.
- **Stufe:** v3.b
- **Nutzt:** LCA-Ergebnis (v2/v3) + Kosten oder Preis
- **Δ Schema:** `P Assessment.productSystemValue, .productSystemValueUnit`
- **Δ Daten:** `D` 1 Kategorie-Instanz `IC_ECOEFF`; Wertbasis wählen (MFCA-Kosten / Preis / funktionaler Output)
- **Basisquery:** `eco_efficiency.cypher` = gewählte `ImpactResult.value` ÷ `productSystemValue`
- **Änderungsmenge:** 2P, 1D, 1Q
- **Betroffene Methoden:** abhängig von LCA + MFCA

#### Umwelt-ökonomische Gesamtrechnung (SEEA)
- **Was:** volkswirtschaftliches Konten-Framework.
- **Stufe:** — (nicht im KG rechnen)
- **Δ Schema:** nur Doku-Hook: `N ExternalFramework{id,name,url}` + `R (Assessment)-[:REPORTS_TO]->(ExternalFramework)`
- **Basisquery:** —
- **Änderungsmenge:** 1N, 1R, 0 Rechnung
- **Betroffene Methoden:** —

---

## 3. Paradigma „datenbasierte Ansätze" — kompakt, kein Fokus jetzt

**Baustein C — Parameter-/Szenario-Layer** (Voraussetzung für 3.1 tw., 3.2, 3.3), **Modul v3.c**:
`N ModelScenario{id,name,type,horizonYear}` · `N Parameter{id,name,unit,baseValue}` ·
`N ParameterValue{value,unit}` · `R (Parameter)-[:PARAM_OF]->(Process\|Part\|Material\|Assessment)` ·
`R (ModelScenario)-[:SETS]->(ParameterValue)` · `R (ParameterValue)-[:FOR]->(Parameter)` ·
`R (Assessment)-[:UNDER_SCENARIO]->(ModelScenario)` · `P ImpactResult.scenarioRef`
→ **3N, 4R, 1P**. Wichtig: getrennt von den bestehenden Greif-`Scenario`s (17×, `scenarioType:'gripping'`).

### 3.1 Prospektive lebenszyklusbasierte Umweltbewertung

| Verfahren | Stufe | Δ über Baustein C | Menge | Betroffene Methoden |
|---|---|---|---|---|
| **prospektive Ökobilanzierung** | v3.c | `P ModelScenario.horizonYear`; `D` szenario-überschriebene Hintergrundwerte | 1P, 1D, 1Q | CED (Energiemix), konsequenzielle LCA |
| **dynamische Ökobilanzierung** | v3.c+ | `P HAS_FLOW.emissionTiming`; `R (Flow)-[:CHARACTERIZES_DYNAMIC{timeHorizon,factor}]->(ImpactCategory)`; `D` zeitaufgelöste CF | 1P, 1R, 1D, 1Q *(größer)* | CF (GWP-Zeithorizont) |
| **konsequenzielle Ökobilanzierung** | v3.c | `P Process.modelingApproach` + `V [attributional,consequential]`; `R (Process)-[:SUBSTITUTES{ratio}]->(Process)`; `R (Process)-[:AVOIDS]->(Flow)`; `D` Marginalprozesse | 1P, 1V, 2R, 1D, 1Q | Zirkularität (Modul D), prospektive LCA |
| **hybride Ökobilanzierung** | v3.b+c | `N EEIOSector{id,name,region,emissionIntensity,unit}` + `R (Process)-[:COMPLEMENTED_BY{monetaryAmount,currency}]->(EEIOSector)` + Kosten-B; `D` Sektorintensitäten | 1N, 1R, 1D, 1Q *(niedrige Prio)* | MFCA (monetäre Basis) |

### 3.2 Szenariobasierte Umweltbewertung

| Verfahren | Stufe | Δ über Baustein C | Menge | Betroffene Methoden |
|---|---|---|---|---|
| **Szenario-gestützte Bewertung** | v3.c | `D` Szenarienset | 1D, 1Q | alle v3.c-Verfahren |
| **Cross-Impact-Wirkungsanalyse** | v3.c | `R (Parameter\|Function\|ImpactCategory)-[:INFLUENCES{sign,strength}]->(…)`; `D` Einflussmatrix | 1R, 1D, 1Q | Wirkkettenanalyse |
| **Robustheits- und Resilienzanalyse** | v3.c | keine; opt. `P Assessment.robustnessIndex` | 0–1P, 1Q | Unsicherheits-/Sensitivitätsanalyse |

### 3.3 Wirkungs- und Unsicherheitsanalysen

| Verfahren | Stufe | Δ | Menge | Betroffene Methoden |
|---|---|---|---|---|
| **Wirkkettenanalyse** | v3 / v3.d | `R (ImpactResult)-[:BASED_ON]->(Feature\|CoreProperty\|DataItem)` (Gap 4); `Q` variable-length Pfad `Requirement→…→ImpactCategory` | 1R, 1Q | Cross-Impact |
| **Unsicherheits- & Sensitivitätsanalyse** | v3.c | `P HAS_FLOW.uncertaintyDistribution` + `V [lognormal,normal,uniform,triangular]`, `.uncertaintyGSD/.min/.max`; `P CHARACTERIZES.uncertainty`; `P Parameter.uncertainty*`; `Q` OAT-Sensitivität | ~5P, 1V, 1Q | Robustheit; Basis: `HAS_FLOW.uncertainty` zu 82 % gefüllt (40 671/49 672) |
| **Hotspot-Analyse** | v2 | keine; `Q` Beitrags-Ranking Prozesse/Flüsse je Kategorie | 1Q | alle LCA-Verfahren |

---

## 4. Provenienz + Deklaration  → **Modul v3.d**

> **2026-08-29:** Das Paradigma „lernende Ansätze" (KI/ML — Umweltwirkungs­prognosen,
> KI-LCA-Modellierung, Ersatz-/Näherungsmodelle, lernende Szenario-Modelle,
> prädiktive Umweltfolgeabschätzungen, automatisierte Designempfehlung) ist nach
> Nutzerentscheidung **nicht** Teil der Fallstudie und aus Graph und Doku
> entfernt — `model_extension/migrations/consistency/remove_ki_stubs.cypher`. Was aus dem
> ursprünglichen v3.d-Andockpunkt-Set **bleibt** (weil umgesetzt und
> KI-unabhängig):

`P ImpactResult.confidence` (+ `.provenance` aus PRE‑1) ·
Gap 4 `R (ImpactResult)-[:BASED_ON]->(Feature|CoreProperty|DataItem)` ·
`N Declaration{id,type:[EPD,DPP],standard,functionalUnit,validFrom,validUntil}`
+ `R (Declaration)-[:DECLARES]->(Artifact)` + `R (Declaration)-[:REPORTS]->(ImpactResult)` ·
`P Requirement.sustainabilityIndicatorRef/Threshold/Operator/Unit/Scope` (aus RFLPV²-Spec).

| Verfahren | Stufe | Beitrag im KG | Menge |
|---|---|---|---|
| **Digitaler Produktpass** | v3.d | `Declaration{type:'DPP'}` — Reporting-Sicht über Material, Rezyklat, EoL, PCF, SVHC, Reparierbarkeit (v1!) | teilt `Declaration` mit EPD |
| **Umwelt-Wissensgraph** | — | *ist dieses Projekt* — Substrat, keine Änderung | 0 |

EPD (EN 15804) ist kein eigenes Diagramm-Blatt, fällt aber mit `Declaration{type:'EPD'}`
+ PRE‑2 (Module) + PRE‑3 (funkt. Einheit) automatisch mit ab.

---

## 5. Konsolidierte Bausteine über die 5 bekannten Gaps hinaus

Die 5 „Flexibilitäts-Gaps" aus der ursprünglichen Analyse:
1 `Process.lifecycleModule` · 2 funktionale Einheit · 3 `ASSESSES` auf Part/Material/Process/ProcessPlan erweitern ·
4 `ImpactResult -[:BASED_ON]->` · 5 Property-Ergänzungen (recyclability, Lebensdauer, Verbindungstyp).

Zusätzlich aus dem Methodendiagramm:

| # | Baustein | Stufe | Freischaltet | Aufwand |
|---|---|---|---|---|
| **A** | Methoden-Taxonomie als Daten (`AssessmentApproach`) | v3 (PRE‑4) | jede der 29 Methoden explizit im Graphen | klein |
| **L** | `ImpactResult.value` (+ Intervall, `computedAt`) | v2 (PRE‑1) | jede quantitative Methode + alle Downstream-Analysen | klein, essenziell |
| **M** | ImpactCategory-Hygiene | v3 (PRE‑5) | verlässliche Mehrkategorien-Methoden (EF3.1, ReCiPe, CML) | mittel |
| **C** | Parameter-/Modellszenario-Layer | v3.c | ganzes Paradigma „datenbasiert" | groß, hoher Hebel |
| **B** | Ökonomische Dimension (`CostItem`) | v3.b | MFCA, Ökoeffizienz, hybride LCA | groß |
| **D** | Zeitdimension (Emissionszeitpunkt, zeitabh. CF) | v3.c+ | dynamische & prospektive LCA | mittel–groß |
| **E** | Unsicherheits-Metadaten (`{distribution,params}`) | v3.c | Unsicherheit/Sensitivität, Robustheit | mittel (Basis 82 % gefüllt) |
| **F** | Klassifikator-Tags (Scope 1/2/3, attributional/consequential, Wasser-Knappheit) | v3 | THG-Bilanz, konseq. LCA, Wasserfußabdruck | klein |
| **G** | `SUBSTITUTES`/`AVOIDS`-Kante | v3.c | konsequenzielle LCA, Zirkularität Modul D | klein |
| **H** | `INFLUENCES{sign,strength}`-Kante | v3.c | Cross-Impact-Analyse | klein |
| **J** | `ImpactResult.provenance` + `confidence` (allgemein, nicht KI-spezifisch) | v3.d | Herkunftskennzeichnung aller Ergebnisse | klein |
| **K** | `Declaration`/`Report`-Knoten | v3.d | EPD, Digitaler Produktpass | mittel |
| **I** | EEIO-Sektordaten | v3.b+c | hybride LCA | groß, niedrige Prio |

---

## 6. Reihenfolge

> **Fortschritt 2026-08-27 (autonomer Lauf):** vollständig umgesetzt —
> v1 · v2-minimal · v3-minimal · v3.x-Module **a–e** (a Zirkularität/MCI ·
> b Kosten/MFCA-Prototyp · c Parameter-/Szenario-/Unsicherheits-Layer ·
> d Provenienz + Reparierbarkeit-als-Ergebnis + EPD/DPP · **e ReCiPe 2016 Midpoint**) ·
> **v2-data** (Part-Massen aller 86 Teile, Fertigungsenergie, Werkstoff-GWP-Literale;
> Varianten **A** real-only und **B** Literal-Vollabdeckung, parallel via `dataVariant`) ·
> **PRE‑5** (ImpactCategory 44→29 kanonisiert, EF3.1 rechnet 19 statt 7 Kategorien) ·
> Reparaturpass `v3x_repair.cypher`.
> Doku: `model_extension/reference/EXTENSION_REFERENCE.md`, `ASSUMPTIONS.md`,
> `model_extension/reference/graph_schema_v3x.json`, `methods/onepagers/` (jetzt 23),
> `model_extension/reference/change_method_matrix.csv`, je Modul `CHANGELOG.md`.
> **Live-DB (Endstand 2026-08-29, nach v3.f–i · LCI-Hygiene · DQ-Konzept ·
> Demonstrator-Scheibe · Konsistenzprüfung Ebene 1–4 · KI-Entfernung):**
> 5 620 Knoten / 86 635 Beziehungen / 39 Labels / 54 Beziehungstypen /
> 39 Constraints, 6 `ImpactAssessmentMethod`, 0 Inkonsistenzen.
> **Entscheidung Datenvariante A vs. B:** getroffen (2026-08-28) — Variante A ist
> Fallstudien-Standard, B bleibt Fallback (siehe `model_extension/migrations/PLAN.md`).
> **Offene Datenaufgaben:** echte ILCD/EPD-Datensätze für Nicht-Al/Stahl-Werkstoffe;
> ReCiPe-Faktoren für die 17 Nicht-Klima-Kategorien; Basisqueries + Daten für die
> Nicht-LCIA-Verfahren (1.1.3/1.1.4/1.2.1–3/1.3.1–2/2.x).

1. **PRE** (v2: PRE‑1 · v3: PRE‑2…PRE‑5) → schaltet LCA, CF, Hotspot, Methoden-Taxonomie frei
2. **v2** Rechenkern + `lca_computed_ef31` → Vergleichbarkeit
3. **v3** `lca_generic` + 2. LCIA-Methode (ReCiPe/CML als reine Daten) → Interpretierbarkeit
4. **v3 P1-Rest**: H₂O, THG, MFA, Schadstoff, CED (je 1P–1V–wenige D–1Q)
5. **v3.a** Zirkularität → **v3.b** Kosten-Prototyp → **v3.c** Parameter-/Szenario-Layer → **v3.d** Andockpunkte
6. dynamische/hybride LCA + volle Cross-Impact: dokumentierte Erweiterungspfade

Reparierbarkeit / Demontage (strukturell-qualitativer Index) ist bereits **v1**
(`migration_v1.cypher`, `repairability.cypher`), Klassen A/B/C. Verfeinerungen
(gewichtete eDIM, Verbinderzahl, Werkzeugklassen) = optionales v3.x.

---

## 7. Offene Datenlücken (Live-Befund 2026-08-27)

| Lücke | Betrifft |
|---|---|
| `Material.recycledContent_pct` bei **allen** realen Materialien NULL | Zirkularität/MCI, Rezyklat-Indikator, EPD/DPP |
| `ImpactResult` ohne Zahlenwert (`status:"not calculated"`) | jede quantitative Methode → PRE‑1 |
| `Process.lifecycleModule` fehlt; nur Freitext-Namen + uneinheitlicher `processType` | EN15804-Staging, EPD, THG, MFA → PRE‑2 |
| keine ökonomische Property | ganze Gruppe 2.3 → Baustein B |
| `Scenario` = nur Greifszenarien | Paradigma „datenbasiert" braucht separaten `ModelScenario` → Baustein C |
| ImpactCategory: 20 Waisen / Near-Duplikate, `indicator`/`unit` teils zerrissen | EF3.1/ReCiPe/CML → PRE‑5 |
| `CHARACTERIZES` ohne Unsicherheit | Sensitivitätsanalyse → Baustein E |
