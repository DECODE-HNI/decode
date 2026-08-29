#!/usr/bin/env bash
# ============================================================================
# check_tools.sh  --  consistency review, Layer 3 (tool consistency)
# ----------------------------------------------------------------------------
# Proves that the generating tools and the persisted graph still agree:
#
#   1  idempotency   -- every re-runnable migration, run a 2nd time, makes no
#                       structural change (0 created / 0 deleted nodes & rels;
#                       re-SET properties are allowed)
#   2  output stability -- the verification RETURN blocks of refresh_variantA /
#                       refresh_recipe / 03_compute_dq are identical run-to-run
#   3  drift        -- check_tools_drift.cypher: the live generic recompute
#                       equals IR_EF31A_* / IR_RECIPE_* (0 rows = pass)
#   4  recipe importer -- import_recipe_cf.py re-run against the current flow
#                       list + openLCA pack regenerates exactly the ReCiPe CF
#                       set already loaded (per-category counts match)
#   5  base queries -- every base_queries/*.cypher executes without error under
#                       representative parameters
#
# Read-mostly: sections 1-2 re-run idempotent migrations (no net change; a
# headline node/rel count guard brackets the run). Nothing here is a fix.
#
# Env (standard DECODE variables):
#   NEO4J_PASSWORD  (required)  DBMS password -- never passed as an argument
#   NEO4J_URI       (default bolt://localhost:7687)
#   NEO4J_USER      (default neo4j)
#   CQ              path to the cypher-shell wrapper   (default: <this dir>/cq.sh)
#   PYTHON          python with the neo4j driver       (default: python3 / python)
#   OPENLCA_ZIP     openLCA "LCIA Methods" pack for section 4 (section 4 SKIPs if unset)
#
# `cypher-shell` must be on PATH. Run from anywhere:
#   NEO4J_PASSWORD=... bash check_tools.sh
# ============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MV="$(cd "$HERE/.." && pwd)"                       # model_extension/migrations/
REPO="$(cd "$MV/../.." && pwd)"                    # repo root
CQ="${CQ:-$HERE/cq.sh}"
PYTHON="${PYTHON:-$(command -v python3 || command -v python || echo python3)}"
OPENLCA_ZIP="${OPENLCA_ZIP:-}"
WORK="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/l3.$$)")"
mkdir -p "$WORK"

if [ -z "${NEO4J_PASSWORD:-}" ]; then echo "NEO4J_PASSWORD not set" >&2; exit 2; fi
if [ ! -f "$CQ" ]; then echo "cq.sh not found at: $CQ" >&2; exit 2; fi

PASS=0; FAIL=0; SKIP=0
declare -a RESULTS
rec()  { RESULTS+=("$1"); if [ "${1:0:4}" = "PASS" ]; then PASS=$((PASS+1)); elif [ "${1:0:4}" = "SKIP" ]; then SKIP=$((SKIP+1)); else FAIL=$((FAIL+1)); fi; }

cy()   { CQ_FMT="${2:-plain}" bash "$CQ" "$1"; }               # file, [fmt]
cyq()  { printf '%s\n' "$1" > "$WORK/_q.cypher"; CQ_FMT="${2:-plain}" bash "$CQ" "$WORK/_q.cypher"; }

headline() { cyq "MATCH (n) WITH count(n) AS nodes MATCH ()-[r]->() RETURN nodes, count(r) AS rels;" plain | tail -n1; }

echo "== Layer 3: tool consistency ==  work dir: $WORK"
BEFORE="$(headline)"; echo "headline before: $BEFORE"

# --- re-runnable migrations, in dependency order ---------------------------
MIGR=(
  "v2_data/ilcd_import/refresh_variantA.cypher"
  "v3x_e_recipe/cf_import/refresh_recipe.cypher"
  "dq_concept/01_criteria_catalogue.cypher"
  "dq_concept/02_phase_targets.cypher"
  "dq_concept/03_compute_dq.cypher"
  "demonstrator/00_mci_rollup.cypher"
  "demonstrator/01_sustainability_requirements.cypher"
  "demonstrator/02_verification_layer.cypher"
  "demonstrator/03_declarations.cypher"
  "demonstrator/04_scenario_coverage.cypher"
)
# migrations that DELETE+recreate derived edges by design -> judge by output
# stability (§2), not by structural no-op (§1)
REBUILDS="dq_concept/03_compute_dq.cypher"

echo; echo "-- §1/§2  re-run each migration twice --------------------------------"
for rel in "${MIGR[@]}"; do
  f="$MV/$rel"
  [ -f "$f" ] || { rec "SKIP  §1 $rel  (file missing)"; continue; }
  CQ_FMT=verbose bash "$CQ" "$f" > "$WORK/r1_$(echo "$rel" | tr / _).txt" 2>&1
  CQ_FMT=verbose bash "$CQ" "$f" > "$WORK/r2_$(echo "$rel" | tr / _).txt" 2>&1
  r2="$WORK/r2_$(echo "$rel" | tr / _).txt"

  # §1 structural no-op on the 2nd run: no "Created/Deleted/Added N" with N>0
  if echo "$REBUILDS" | grep -qF "$rel"; then
    rec "SKIP  §1 $rel  (rebuilds derived edges by design -- see §2)"
  else
    struct="$(grep -oE '(Added|Created|Deleted) [0-9]+ (nodes|relationships|labels)' "$r2" | grep -vE ' 0 ' || true)"
    if [ -z "$struct" ]; then rec "PASS  §1 $rel  idempotent (2nd run: no structural change)"
    else rec "FAIL  §1 $rel  2nd run changed the graph: $(echo "$struct" | tr '\n' ';')"; fi
  fi

  # §2 output stability: the RETURN tables must match between the two runs
  norm() { grep -E '^[|+]' "$1" | sed -E 's/after [0-9]+ ms//g'; }
  if diff <(norm "$WORK/r1_$(echo "$rel" | tr / _).txt") <(norm "$r2") >/dev/null 2>&1; then
    rec "PASS  §2 $rel  verification output stable run-to-run"
  else
    rec "FAIL  §2 $rel  verification output differs between runs (see $WORK)"
  fi
done

# --- §3  drift: live recompute vs persisted IR ---------------------------
echo; echo "-- §3  drift  (check_tools_drift.cypher) ----------------------------"
CQ_FMT=verbose bash "$CQ" "$HERE/check_tools_drift.cypher" > "$WORK/drift.txt" 2>&1
drows="$(grep -cE '^\| (D3\.[0-9])' "$WORK/drift.txt" || true)"
if [ "${drows:-0}" -eq 0 ]; then
  rec "PASS  §3 drift  every persisted IR_EF31A_* / IR_RECIPE_* equals the live recompute"
else
  rec "FAIL  §3 drift  $drows tool<->DB disagreement row(s) -- see $WORK/drift.txt"
fi

# --- §4  recipe importer re-run ---------------------------------------------
echo; echo "-- §4  import_recipe_cf.py re-run ----------------------------------"
if [ ! -f "$OPENLCA_ZIP" ]; then
  rec "SKIP  §4 import_recipe_cf.py  (openLCA pack not at: $OPENLCA_ZIP)"
elif [ ! -x "$PYTHON" ] && [ ! -f "$PYTHON" ]; then
  rec "SKIP  §4 import_recipe_cf.py  (python not at: $PYTHON)"
else
  : "${NEO4J_URI:=bolt://localhost:7687}" ; : "${NEO4J_USER:=neo4j}" ; export NEO4J_URI NEO4J_USER NEO4J_PASSWORD
  "$PYTHON" "$MV/v3x_e_recipe/cf_import/import_recipe_cf.py" \
      --openlca-zip "$OPENLCA_ZIP" --read-db \
      --out "$WORK/recipe_cf.rerun.cypher" > "$WORK/recipe_stdout.txt" 2> "$WORK/recipe_stderr.txt"
  rc=$?
  if [ $rc -ne 0 ]; then
    rec "FAIL  §4 importer exited $rc -- see $WORK/recipe_stderr.txt"
  else
    # per-(flow,category) reconciliation: the importer's load guard is
    # WHERE NOT (f)-[:CHARACTERIZES]->(ic), so compare the pair SET, not tags.
    grep -oE '\{fid:"[^"]+", ic:"IC_RECIPE_[A-Z_]+"' "$WORK/recipe_cf.rerun.cypher" \
      | sed -E 's/\{fid:"//; s/", ic:"/\t/; s/"$//' | tr -d '\r' | sort -u > "$WORK/prop_pairs.tsv"
    cyq "MATCH (f:Flow)-[c:CHARACTERIZES]->(ic:ImpactCategory) WHERE ic.id STARTS WITH 'IC_RECIPE_'
         RETURN f.id + '\t' + ic.id AS pair;" plain \
      | tail -n +2 | tr -d '"\r' | sort -u > "$WORK/db_pairs.tsv"
    recon=$(comm -12 "$WORK/prop_pairs.tsv" "$WORK/db_pairs.tsv" | wc -l)
    newp=$(comm -23  "$WORK/prop_pairs.tsv" "$WORK/db_pairs.tsv" | tee "$WORK/recipe_would_create.tsv" | wc -l)
    orph=$(comm -13  "$WORK/prop_pairs.tsv" "$WORK/db_pairs.tsv" | tee "$WORK/recipe_orphans.tsv" | wc -l)
    orph_nonIR=$(grep -vc 'IC_RECIPE_IR' "$WORK/recipe_orphans.tsv" || true)
    # known post-hygiene baseline (consistency finding F-11): 35 IR CFs no longer
    # bucketable (radionuclide kBq flows, HAS_FLOW.compartment NULL) + 17 CFs the
    # importer would add on hygiene-split #u=kg siblings that post-date the load.
    if [ "$newp" -le 17 ] && [ "$orph" -le 35 ] && [ "${orph_nonIR:-0}" -eq 0 ]; then
      rec "PASS  §4 importer re-run: $recon/$(wc -l < "$WORK/db_pairs.tsv") ReCiPe CFs reconcile; $orph IR orphans + $newp would-add, all within the known F-11 post-hygiene baseline"
    else
      rec "FAIL  §4 importer re-run drift beyond F-11 baseline: reconcile $recon, would-create $newp (>17?), orphans $orph (non-IR $orph_nonIR) -- see $WORK/recipe_{would_create,orphans}.tsv"
    fi
  fi
fi

# --- §5  base-query smoke test -------------------------------------------
echo; echo "-- §5  base_queries/*.cypher smoke test ----------------------------"
BQ="$REPO/methods/base_queries"
PRE=":param artifactId => 'ART_V_AL';
:param methodId => 'IAM_EF31';
:param dataVariant => 'A-realdataset';
:param resultType => 'Climate change';
:param phase => 'PH_SCREENING';
:param assessmentId => 'ASSESS_EF31A_ART_V_AL';
:param timeHorizon => 100;
:param leverId => 'MAT_PA12';
:param mode => 'lever';
:param electricityCF => 0.38;
:param hazardOnly => false;
:param topN => 25;
:param delta => 0.1;
"
for q in "$BQ"/*.cypher; do
  name="$(basename "$q")"
  { printf '%s\n' "$PRE"; cat "$q"; } > "$WORK/bq_$name"
  out="$(CQ_FMT=plain bash "$CQ" "$WORK/bq_$name" 2>&1)"
  if echo "$out" | grep -qiE 'Neo\.(Client|Database|Transient)Error|Invalid input|Expected parameter|Unknown function|Variable .* not defined|SyntaxError'; then
    rec "FAIL  §5 $name  -> $(echo "$out" | grep -iE 'error|expected parameter|invalid input' | head -n1)"
  else
    rec "PASS  §5 $name"
  fi
done

# --- also run lca_generic (base query, lives under model_versions) --------
{ printf '%s\n' "$PRE"; cat "$MV/v3_whitebox/lca_generic.cypher"; } > "$WORK/bq_lca_generic.cypher"
out="$(CQ_FMT=plain bash "$CQ" "$WORK/bq_lca_generic.cypher" 2>&1)"
if echo "$out" | grep -qiE 'Neo\.(Client|Database|Transient)Error|Invalid input|Expected parameter'; then
  rec "FAIL  §5 lca_generic.cypher (\$methodId=IAM_EF31) -> $(echo "$out" | grep -iE 'error' | head -n1)"
else
  rec "PASS  §5 lca_generic.cypher (\$methodId=IAM_EF31)"
fi

# --- guard: headline unchanged -----------------------------------------
AFTER="$(headline)"; echo; echo "headline after:  $AFTER"
if [ "$BEFORE" = "$AFTER" ]; then rec "PASS  §0 headline node/rel count unchanged by the re-runs"
else rec "FAIL  §0 headline changed: $BEFORE  ->  $AFTER"; fi

# --- summary ----------------------------------------------------------
echo; echo "==================== Layer 3 summary ===================="
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo "--------------------------------------------------------"
echo "  PASS $PASS   FAIL $FAIL   SKIP $SKIP"
echo "  artifacts: $WORK"
[ "$FAIL" -eq 0 ]
