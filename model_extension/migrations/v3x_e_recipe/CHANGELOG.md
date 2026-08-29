# Module v3.e — ReCiPe 2016 Midpoint (H) · Änderungsprotokoll

## 2026-08-27

`migration_v3e.cypher`

### Zweck

Zweite LCIA-Methode als Beleg für „neue Methode = reine Daten, null Query-Änderung".
`lca_generic($methodId='IAM_RECIPE')` funktioniert unverändert.

### Neu

| Artefakt | Umfang |
|---|---|
| `ImpactAssessmentMethod` `IAM_RECIPE` | ReCiPe 2016 midpoint, Hierarchist; `methodFamily='ReCiPe'` |
| `ImpactCategory` `IC_RECIPE_*` | **18 Midpoint-Kategorien** (Global warming, Stratospheric ozone depletion, Ionizing radiation, Ozone formation HH/EC, Fine PM, Terrestrial acidification, Freshwater/Marine eutrophication, 3× Ecotoxicity, 2× Human toxicity, Land use, Mineral/Fossil resource scarcity, Water consumption) |
| `HAS_CATEGORY` | 18 (`IAM_RECIPE` → alle `IC_RECIPE_*`) |
| `APPLIES_APPROACH` | `IAM_RECIPE` → `APM_LCA` |
| `CHARACTERIZES` → `IC_RECIPE_GW` | 38 Faktoren, **approximiert** aus den EF3.1-Klimafaktoren × 1,06 (ReCiPe-H Climate-Carbon-Feedback-Zuschlag), `source`-Property vermerkt |

### Abdeckung

- **Klimakategorie (`IC_RECIPE_GW`): rechenbar** — `lca_generic('IAM_RECIPE')` liefert
  Klimawerte für alle Gripper mit `MODELED_BY`-Werkstoff (Al, PA, Stahl), Werte ≈ 1,06 ×
  EF3.1-Klima.
- **17 weitere Kategorien: nur strukturell** — Knoten + `HAS_CATEGORY` vorhanden, Faktoren
  noch nicht befüllt (Datenaufgabe, siehe ASSUMPTIONS.md 6 für repräsentative CF).

### Methodenagnostik-Nachweis

Drei LCIA-Methoden über dieselbe Query: `lca_generic('IAM_EF31')` (19 Kat.),
`lca_generic('IAM_PCF')` (1 Kat.), `lca_generic('IAM_RECIPE')` (1 Kat. befüllt).
Kein Schema- oder Query-Eingriff beim Hinzufügen von ReCiPe.

### Rollback

Kommentarblock am Ende der Migration (Faktoren + Kategorien + Methode löschen).
