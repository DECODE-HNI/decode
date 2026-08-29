# PRE-5 — ImpactCategory-Hygiene · Änderungsprotokoll

## 2026-08-27

`migration_pre5.cypher`

### Problem

Der Graph führte **zwei parallele EF3.1-Kategoriesätze**:
- **Methoden-Slot-Knoten** (`HAS_CATEGORY` von `IAM_EF31`, aber 0 `CHARACTERIZES`-Faktoren,
  zerrissene `indicator`/`unit`-Felder) — z. B. `IC_EF_ECOTOX_FRESHWATER`, `IC_EF_HUMANTOX_CANCER`,
  `IC_EF_CLIMATE_FOSSIL`, `IC_EF_RESOURCE_FOSSILS`.
- **Faktor-tragende Knoten** (die echten Charakterisierungsfaktoren, **nicht** an die Methode
  gehängt) — `IC_EF_ECOTOXICITY_FRESHWATER` (863), `IC_EF_HUMAN_TOXICITY_CANCER` (291),
  `IC_EF_CLIMATE_CHANGE_FOSSIL` (33) …

Deshalb rechnete `lca_generic` nur 7 Kategorien (jene, die Methodenlink **und** Faktoren
auf demselben Knoten hatten).

### Fix

12 Merge-Gruppen: je den faktor-tragenden Knoten behalten, die Slot-Knoten mit
`apoc.refactor.mergeNodes({properties:'discard', mergeRels:true})` hineinführen
(überträgt `HAS_CATEGORY` + `FOR_CATEGORY`, dedupliziert). Danach `name`/`indicator`/`unit`
auf 19 kanonischen Knoten normalisiert; `IAM_EF31` an den vollen kanonischen
Midpoint-Satz gehängt.

### Ergebnis

| | vorher | nachher |
|---|---:|---:|
| `ImpactCategory` (ohne ReCiPe) | 44 | **29** (15 Slots absorbiert) |
| EF3.1-Kategorien mit Faktoren | 7 | **19** |
| `CHARACTERIZES` gesamt | 27 769 | 27 589 (−180 = Dedup auf den zusammengeführten Toxizitäts-/Ressourcen-Knoten, 0,6 %) |

**Die 7 rechnenden Kernkategorien** (Klima, Versauerung, Eutroph. marin, Landnutzung,
Ozonabbau, Feinstaub, Photochem. Ozon) sind **unverändert** — kein Faktorverlust dort.
`lca_generic('IAM_EF31')` liefert nun 19 Kategorien je Gripper.

### Betroffene Methoden

Alle mehrkategoriellen LCIA-Verfahren (LCA, ReCiPe/CML-Load). Voraussetzung für die
volle EF3.1-Kategorienabdeckung. Kein Einfluss auf CF (nur Klima), MCI, Reparierbarkeit.

### Rollback

Nicht automatisch (Merge ist destruktiv) — aus Snapshot wiederherstellen. Die
Kernkategorien-Faktoren sind nachweislich unangetastet.
