# Consistency review — check harness

Read-only harness for the staged consistency review. **All four layers run
(2026-08-29).** Re-run after every fix and record the delta in
[`FINDINGS.md`](FINDINGS.md).

| layer | file | scope | status |
|---|---|---|---|
| **1 methodical building blocks** | `check_meta.cypher` (+ manual diff) | live-DB census vs `EXTENSION_REFERENCE.md` counts, `graph_schema_v3x.json`, `change_method_matrix.csv`, method one-pagers, `base_queries/README.md` | **done** 2026-08-29 |
| **2 model consistency** | `check_model.cypher` | live graph: structural integrity, referential integrity, result completeness & value sanity, cross-script agreement, vocabulary/enum, demonstrator chain, stale results | **done** 2026-08-29 — 8 findings, see `FINDINGS.md` / `CHANGELOG.md` |
| **3 tool consistency** | `check_tools.sh` + `check_tools_drift.cypher` | re-run every `refresh_*` / `compute_dq` / `import_recipe_cf.py`; idempotency (2nd run = no structural change); output stability; `lca_generic` / refresh core vs persisted `IR_*`; every base query executes | **done** 2026-08-29 — 43 PASS / 0 FAIL / 1 by-design skip; 1 finding (**F-11**, pinned baseline) |
| **4 logical DECODE embedding** | `check_decode.cypher` (+ `check_decode_oneshot.cypher`) | RFLPV² spec §7 mapping row-by-row; verification-chain reachability (8-gripper slice, both directions); `ExternalFramework` `MAPS_TO` coverage; DPP/EPD path; additive & non-breaking | **done** 2026-08-29 — 21 checks pass; DE-01 + DE-02 fixed; KI/ML removed (`remove_ki_stubs.cypher`) |

Not a software-integration test — Layer 4 checks the graph is a faithful
**logical** target for the RFLPV² profile and the reporting frameworks.

Fix files (applied): `fix_F02_assessment_edges.cypher`,
`fix_F03_cas_bridge.cypher`, `fix_F05_units.cypher`,
`fix_DE02_framework_nodes.cypher`, `remove_ki_stubs.cypher` (has a rollback
block). F-01 lives in the two `refresh_*` files. F-11 accepted. Full status:
`FINDINGS.md`.

## Run

`cypher-shell` must be on `PATH`. Connection comes from the standard
environment variables (`NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD`); `cq.sh`
in this folder is a thin wrapper around them.

```bash
export NEO4J_PASSWORD='...'          # NEO4J_URI / NEO4J_USER default to bolt://localhost:7687 / neo4j
CQ_FMT=verbose ./cq.sh check_meta.cypher
CQ_FMT=verbose ./cq.sh check_model.cypher
CQ_FMT=verbose ./cq.sh check_tools_drift.cypher
CQ_FMT=verbose ./cq.sh check_decode.cypher
bash check_tools.sh                  # re-runs the idempotent migrations; a headline node/rel guard brackets the run
```

`check_model.cypher` returns one row per check: `check`, `n`, `expect`. A row
where `n <> expect` (and `expect <> 'info'`) is a finding. An empty result for a
check means it passed.

### Running it yourself in Neo4j Browser

The multi-statement files need Browser's "multi statement query editor" setting.
To avoid that, use the **one-shot** variants — a single `UNION ALL` query that
returns **only the rows needing attention**:

| file | meaning of an empty result |
|---|---|
| `check_model_oneshot.cypher` | Layer 2 clean (currently returns 2 `info` rows: C3 = 8 negative results, C4 = 4 CF-less categories) |
| `check_decode_oneshot.cypher` | Layer 4 clean (currently returns 1 `info` row: N4 = 35 new-label nodes) |

Paste the whole file, run once. Empty table = clean. Every row shown is a
finding (`n <> expect`) or a non-zero `info` row you just note. For `check_meta.cypher`
the useful one-line check is its **first statement (M1)** — the headline counts,
which must match `EXTENSION_REFERENCE.md` (5 620 / 86 635 / 39 / 54 / 39, plus the
`flow_casnorm` index → 42 indexes).

## Method

Detection is mechanical (this harness). Every finding is then triaged —
fix now / defer / accept-and-document. [`FINDINGS.md`](FINDINGS.md) is the
working record and carries the decision + status per finding;
[`CHANGELOG.md`](CHANGELOG.md) records what each fix changed on the live DB.
