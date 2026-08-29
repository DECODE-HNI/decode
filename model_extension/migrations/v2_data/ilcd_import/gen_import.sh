#!/usr/bin/env bash
# gen_import.sh  --  turn a parsed ILCD package into an additive import .cypher
#
#   gen_import.sh <package-dir> <MATERIAL_ID> <PROXY true|false> "<rationale>" <PROC_ID> > import_x.cypher
#
# <package-dir> must already contain _parsed/{meta,exchanges,flowdefs}.tsv
# (run extract_package.pl first). Emits Cypher on stdout.
set -euo pipefail
DIR="${1:?package dir}"; MATID="${2:?material id}"; PROXY="${3:?true|false}"
RAT="${4:?rationale}"; PROCID="${5:?process id}"
P="$DIR/_parsed"
[ -f "$P/meta.tsv" ] || { echo "run extract_package.pl first" >&2; exit 1; }

get(){ awk -F'\t' -v k="$1" '$1==k{ print $2 }' "$P/meta.tsv"; }
UUID=$(get processUuid); VER=$(get dataSetVersion); NAME=$(get baseName)
RY=$(get referenceYear); LOC=$(get location); TYPE=$(get typeOfDataSet)
PRODU=$(get productFlowUuid); PRODA=$(get productAmount); VU=$(get validUntil)
DATE=$(date +%Y-%m-%d)
esc(){ sed "s/'/\\\\'/g"; }
NAME_E=$(printf '%s' "$NAME" | esc); RAT_E=$(printf '%s' "$RAT" | esc)

cat <<HDR
// ============================================================================
// $(basename "$0" .sh) output -- import ILCD package for $MATID
//   dataset : $NAME
//   uuid    : $UUID  (v$VER, $TYPE, $RY, $LOC, valid->$VU)
//   source  : PlasticsEurope Eco-profile, downloaded ILCD _dependencies package
// Additive. Re-runnable (MERGE). Generated $DATE.
// ============================================================================

// ---- 1. Process node -------------------------------------------------------
MERGE (p:Process {id:'$PROCID'})
  SET p.name              = '$NAME_E',
      p.processType        = 'RawMaterialProduction',
      p.datasetUuid        = '$UUID',
      p.dataSetVersion     = '$VER',
      p.referenceYear      = $( [ -n "$RY" ] && echo "$RY" || echo "null" ),
      p.dataSetValidUntil  = $( [ -n "$VU" ] && echo "$VU" || echo "null" ),
      p.geographicalLocation = '$LOC',
      p.dataSetOwner       = 'PlasticsEurope',
      p.dataSetType        = '$TYPE',
      p.lifecycleModule    = 'A1-A3',
      p.referenceUnit      = 'kg',
      p.referenceFlowUuid  = '$PRODU',
      p.provenance         = 'ILCD-package-import',
      p.importedAt         = '$DATE';

// ---- 2. Flow nodes (create the ones not yet in the graph) -----------------
UNWIND [
HDR

awk -F'\t' 'NR>1||1{
  gsub(/\\/,"",$2); gsub(/'"'"'/,"\\'"'"'",$2);
  printf "  {u:\"%s\", n:\"%s\", cas:\"%s\", ft:\"%s\"},\n", $1,$2,$3,$4
}' "$P/flowdefs.tsv" | sed '$ s/,$//'

cat <<'MID'
] AS fd
MERGE (f:Flow {id:fd.u})
  ON CREATE SET f.name = fd.n, f.casNumber = fd.cas, f.flowType = fd.ft,
                f.provenance = 'ILCD-package-import';

// ---- 3. HAS_FLOW exchanges (skip the reference product row) --------------
UNWIND [
MID

# exchanges: internalId, dir, amount, flowUuid, shortDesc  -> derive compartment
awk -F'\t' -v prod="$PRODU" '
function comp(s,  c){
  c="";
  if (s ~ /Emissions to air/)          c="emission/air";
  else if (s ~ /Emissions to fresh water/) c="emission/water";
  else if (s ~ /Emissions to sea water/)   c="emission/seawater";
  else if (s ~ /Emissions to .*soil/)      c="emission/soil";
  else if (s ~ /resources from ground/)    c="resource/ground";
  else if (s ~ /resources from air/)       c="resource/air";
  else if (s ~ /resources from water/)     c="resource/water";
  return c;
}
$4!=prod && $4 ~ /^[0-9a-f-]{36}$/ {
  a=$3; if(a=="")a="0";
  printf "  {u:\"%s\", amt:%s, dir:\"%s\", cmp:\"%s\"},\n", $4, a, tolower($2), comp($5)
}' "$P/exchanges.tsv" | sed '$ s/,$//'

cat <<MID2
] AS ex
MATCH (p:Process {id:'$PROCID'}), (f:Flow {id:ex.u})
MERGE (p)-[hf:HAS_FLOW]->(f)
  SET hf.amount = ex.amt, hf.direction = ex.dir, hf.unit = 'kg',
      hf.compartment = ex.cmp, hf.source = 'PlasticsEurope $NAME_E eco-profile';

// ---- 4. Characterisation harmonisation ----------------------------------
// For emission flows on this process that carry a CAS but no CHARACTERIZES yet,
// copy factors from an already-characterised DB flow with the same CAS and the
// same broad compartment. Biogenic <-> biogenic guarded.
MATCH (p:Process {id:'$PROCID'})-[hf:HAS_FLOW]->(f:Flow)
WHERE hf.compartment STARTS WITH 'emission'
  AND coalesce(f.casNumber,'') <> ''
  AND NOT replace(f.casNumber,' ','') IN ['124-38-9','74-82-8']   // GHGs -> step 5 override
  AND NOT (f)-[:CHARACTERIZES]->()
WITH f, hf, replace(f.casNumber,' ','') AS cas
MATCH (src:Flow)-[c:CHARACTERIZES]->(ic:ImpactCategory)
WHERE src <> f
  AND replace(coalesce(src.casNumber,''),' ','') = cas
  AND ( (toLower(f.name) CONTAINS 'biogenic') = (toLower(src.name) CONTAINS 'biogenic') )
  AND NOT toLower(src.name) CONTAINS 'land use'
  AND NOT toLower(src.name) CONTAINS 'land-use'
WITH f, ic, head(collect(c)) AS c
MERGE (f)-[nc:CHARACTERIZES]->(ic)
  ON CREATE SET nc.factor = c.factor, nc.location = coalesce(c.location,''),
                nc.source = 'harmonised via CAS', nc.derived = true;

// ---- 5. explicit overrides for unspecified fossil GHGs ------------------
UNWIND [ {cas:'124-38-9', src:'carbon dioxide (fossil)'},
         {cas:'74-82-8',  src:'methane (fossil)'} ] AS ov
MATCH (p:Process {id:'$PROCID'})-[hf:HAS_FLOW]->(f:Flow)
WHERE replace(coalesce(f.casNumber,''),' ','') = ov.cas
  AND hf.compartment STARTS WITH 'emission'
  AND NOT toLower(f.name) CONTAINS 'biogenic'
  AND NOT (f)-[:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})
MATCH (src:Flow {name:ov.src})-[c:CHARACTERIZES]->(ic:ImpactCategory)
MERGE (f)-[nc:CHARACTERIZES]->(ic)
  ON CREATE SET nc.factor = c.factor, nc.location = coalesce(c.location,''),
                nc.source = 'override ' + ov.src, nc.derived = true;

// ---- 5b. non-CAS alias harmonisation (name + compartment) --------------
// The PlasticsEurope packages emit a few elementary flows with no CAS that
// step 4 cannot reach. Bridge them to the EF3.1 set by fixed alias->canonical
// flow UUID. Additive, idempotent; only fires for aliases present in the graph.
// (>10um particulates deliberately excluded -- EF3.1 CF is 0; COD/BOD excluded
//  -- no EF3.1/ReCiPe category is driven by them.)
UNWIND [
  {alias:'08a91e70-3ddc-11dd-9501-0050c2490048', canon:'08a91e70-3ddc-11dd-91be-0050c2490048'}, // PM2.5-PM10 -> PM10
  {alias:'08a91e70-3ddc-11dd-9155-0050c2490048', canon:'08a91e70-3ddc-11dd-a302-0050c2490048'}  // VOC -> NMVOC
] AS m
MATCH (canon:Flow {id:m.canon})-[cc:CHARACTERIZES]->(ic:ImpactCategory)
      <-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_EF31'})
MATCH (alias:Flow {id:m.alias})
WHERE NOT (alias)-[:CHARACTERIZES]->(ic)
MERGE (alias)-[nc:CHARACTERIZES {characterizesId: m.alias + '|' + ic.id + '|'}]->(ic)
  ON CREATE SET nc.factor = cc.factor, nc.location = coalesce(cc.location,''),
                nc.source = 'harmonised via non-CAS name+compartment',
                nc.harmonisedFrom = m.canon, nc.derived = true;
UNWIND ['38a9d121-fc90-45c7-9ea7-11a9a3b68041','4f520365-e5ce-486a-ab24-1703f5b2297d'] AS aliasId
MATCH (canon:Flow {id:'08a91e70-3ddc-11dd-91be-0050c2490048'})
      -[cc:CHARACTERIZES]->(ic:ImpactCategory {id:'IC_EF_PARTICULATE_MATTER'})
MATCH (alias:Flow {id:aliasId})
WHERE NOT (alias)-[:CHARACTERIZES]->(ic)
MERGE (alias)-[nc:CHARACTERIZES {characterizesId: aliasId + '|IC_EF_PARTICULATE_MATTER|'}]->(ic)
  ON CREATE SET nc.factor = cc.factor, nc.location = '',
                nc.source = 'proxy: unspecified particulates -> PM10 CF',
                nc.harmonisedFrom = '08a91e70-3ddc-11dd-91be-0050c2490048',
                nc.proxy = true, nc.confidence = 'low', nc.derived = true;

// ---- 6. MODELED_BY (Variant A) ----------------------------------------
MATCH (m:Material {id:'$MATID'}), (p:Process {id:'$PROCID'})
MERGE (m)-[r:MODELED_BY]->(p)
  SET r.proxy = $PROXY, r.proxyRationale = '$RAT_E',
      r.lifecycleModule = 'A1-A3', r.datasetUuid = '$UUID',
      r.dataVariant = 'A-realdataset';

// ---- 7. verification: per-kg climate for this dataset ----------------
MATCH (p:Process {id:'$PROCID'})-[hf:HAS_FLOW]->(f:Flow)
WITH f, sum(hf.amount) AS amt
MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory {id:'IC_CLIMATE'})
WITH f, amt, head([x IN collect(c) WHERE coalesce(x.location,'')='']) AS c0
RETURN '$MATID' AS material, round(sum(amt * c0.factor),4) AS gwp_A1_kgCO2e_per_kg,
       count(f) AS climateFlows;

// ---- 8. verification: all method categories via same logic ----------
MATCH (p:Process {id:'$PROCID'})-[hf:HAS_FLOW]->(f:Flow)
WITH f, sum(hf.amount) AS amt
MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory)<-[:HAS_CATEGORY]-(:ImpactAssessmentMethod {id:'IAM_EF31'})
WITH ic, f, amt, [x IN collect(c) WHERE coalesce(x.location,'')=''][0].factor AS fac
RETURN ic.id AS category, round(sum(amt * fac),6) AS perKg ORDER BY category;

// ---- rollback --------------------------------------------------------
// MATCH (m:Material {id:'$MATID'})-[r:MODELED_BY]->(p:Process {id:'$PROCID'}) DELETE r;
// MATCH (p:Process {id:'$PROCID'})-[hf:HAS_FLOW]->() DELETE hf;
// MATCH (:Flow)-[nc:CHARACTERIZES {derived:true}]->() DELETE nc;   // careful: also removes other packages' derived
// MATCH (p:Process {id:'$PROCID'}) DELETE p;
MID2
