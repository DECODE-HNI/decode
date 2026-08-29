# v1 (black box) — Änderungsprotokoll

## 2026-08-27 — Reparierbarkeit formalisiert + konkrete Indikatoren

Migration: `migration_v1.cypher` · Basisquery: `repairability.cypher`
Vorab-Fix: `../_fixes/fix_generic_materials.cypher`

### Berührte Artefakte

| Artefakt | Änderung | Art |
|---|---|---|
| `HAS_COMPONENT` (Kante) | neue Properties `connectionType`, `reversible`, `toolless`, `evidenceLevel`, `evidenceRef` — auf allen 129 Kanten gesetzt | additive Rel-Property |
| `Artifact` (Knoten) | neue Properties `disassemblyReversibility`, `componentCount`, `distinctMaterialCount`, `toollessRobotInterface`, `replaceableContactElement`, `repairabilityClass`, `repairabilityMethod` — auf allen 43 Knoten | additive Node-Property (literal, berechnet) |
| `HAS_PROPERTY` → `CP_DISASSEMBLY` | für die 5 fehlenden Artefakte ergänzt (38 → 43) | Katalog-Vervollständigung |
| `Process PROC_SCREW` | *gelesen*, nicht geändert — `joiningType` daraus auf `HAS_COMPONENT` umgehängt | Quelle |
| `MAT_*_GENERIC` (5 Material-Knoten) | CSV-Spaltenversatz behoben: `name`, `materialType='metal'`, `density_kg_m3` gesetzt, `recycledContent_pct=NULL`, `dataQualityNote` | Datenkorrektur (Vorbestand) |

### Ergebnis

`repairabilityClass`-Verteilung über 43 Artefakte: **A = 1, B = 12, C = 30.**
`disassemblyReversibility` = 1.0 durchgängig (alle Bauformen vollständig lösbar —
Schraub- bzw. Magnet-Schnellwechsel). Spreizung kommt heute allein aus den
Features `FEAT_EASY` (werkzeuglos, 5×) und `FEAT_PRINTABLE` (Wechseljaws, 9×);
eine feinere Spreizung entsteht erst, wenn nicht-lösbare Fügungen (z. B. geklebte
Kontaktpads) als eigene Verbindungen modelliert werden.

### Betroffene Methoden (Änderungs-→-Methoden-Matrix)

| Änderung | benötigt von | genutzt von | berichtet in |
|---|---|---|---|
| `HAS_COMPONENT.connectionType/reversible` | Reparierbarkeit/Demontage (v1) | Zirkularität/MCI (v3.a — Materialtrennung/Recyclingausbeute); konsequenzielle LCA / EoL-Routen (v3 — Reuse/Remanufacture) | Digitaler Produktpass (v3.d) |
| `Artifact.repairabilityClass` u. a. Indikatoren | Reparierbarkeit (v1) | automatisierte Designempfehlung (v3.d — Schwellen auf Requirement); Zirkularität/MCI (v3.a — `componentCount`, `distinctMaterialCount`) | EPD/DPP (v3.d) |
| `MAT_*_GENERIC`-Fix (`density_kg_m3`, `recycledContent_pct`) | jede inventarbasierte Methode ab v2 (Volumen↔Masse-Umrechnung); Zirkularität/MCI (v3.a — `recycledContent` darf nicht Müllwert sein) | — | — |

### Rollback

Siehe Kommentarblock am Ende von `migration_v1.cypher`. Alle Änderungen sind
`REMOVE`- bzw. `SET`-reversibel; keine Knoten/Kanten gelöscht.
