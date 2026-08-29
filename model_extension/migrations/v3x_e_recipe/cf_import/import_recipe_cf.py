#!/usr/bin/env python3
"""
import_recipe_cf.py -- populate the ReCiPe 2016 Midpoint (H) characterisation
factors for the flows that already exist in the gripper knowledge graph.

Module v3.e created `IAM_RECIPE` + its 18 `ImpactCategory` nodes but filled
characterisation factors only for climate (`IC_RECIPE_GW`, approximated as
EF3.1 GWP x 1.06). This script fills the remaining 17 categories (and, with
--supersede-gw, replaces the climate approximation with real ReCiPe CFs).

Source of the factors: the free openLCA "LCIA Methods" JSON-LD package
(GreenDelta), method "ReCiPe 2016 Midpoint (H)". The package is NOT
redistributed with this repo; download it yourself and pass it with
--openlca-zip. Only the CFs for flows that this graph actually uses end up in
the database (a few thousand `CHARACTERIZES` edges), never the full CF table.

Matching (factor -> graph Flow node), per category class:

  robust    GW OD IR OF_HH OF_EC PM TA FE ME
            match by CAS number; value = median of the CFs whose compartment
            bucket matches the Flow's modal HAS_FLOW compartment, else median
            of the air CFs, else median of all. These categories are only
            weakly compartment-sensitive.
  strict    TET FET MET HCT HNCT   (USEtox-family, kg 1,4-DCB)
            match by CAS AND compartment bucket. If the Flow has no resolvable
            compartment, it is skipped -- an air CF must not stand in for a
            water or soil emission here (orders-of-magnitude error).
  resource  FRS MRS LU WC
            the driving flows are resource / land-occupation flows with no CAS;
            match by normalised flow name. Partial by nature.

Everything is strictly additive: an existing `(f)-[:CHARACTERIZES]->(ic)` is
never touched. Re-runnable (MERGE on a deterministic characterizesId).

Credentials for --load / --read-db come from NEO4J_URI / NEO4J_USER /
NEO4J_PASSWORD only (DECODE convention).

Usage
-----
    python import_recipe_cf.py \
        --openlca-zip "openLCA LCIA Methods 2.7.3 2025-03-07.zip" \
        --flows db_cas_flows.tsv \
        --out recipe_cf.cypher [--supersede-gw]

    # or read the flow list straight from the database and load the result:
    python import_recipe_cf.py --openlca-zip PACK.zip --read-db --load

`db_cas_flows.tsv` (when not using --read-db) has one row per graph Flow:
    <flowId>\t<casNumber>\t<name>\t<comma-separated HAS_FLOW.compartment values>
produced by  cf_import/export_flows.cypher .
"""
import argparse
import json
import os
import re
import statistics
import sys
import zipfile
from collections import defaultdict

VARIANTS = {"H", "I", "E"}

CATMAP = {
    "Global warming": "IC_RECIPE_GW",
    "Stratospheric ozone depletion": "IC_RECIPE_OD",
    "Ionizing radiation": "IC_RECIPE_IR",
    "Ozone formation, Human health": "IC_RECIPE_OF_HH",
    "Fine particulate matter formation": "IC_RECIPE_PM",
    "Ozone formation, Terrestrial ecosystems": "IC_RECIPE_OF_EC",
    "Terrestrial acidification": "IC_RECIPE_TA",
    "Freshwater eutrophication": "IC_RECIPE_FE",
    "Marine eutrophication": "IC_RECIPE_ME",
    "Terrestrial ecotoxicity": "IC_RECIPE_TET",
    "Freshwater ecotoxicity": "IC_RECIPE_FET",
    "Marine ecotoxicity": "IC_RECIPE_MET",
    "Human carcinogenic toxicity": "IC_RECIPE_HCT",
    "Human non-carcinogenic toxicity": "IC_RECIPE_HNCT",
    "Land use": "IC_RECIPE_LU",
    "Mineral resource scarcity": "IC_RECIPE_MRS",
    "Fossil resource scarcity": "IC_RECIPE_FRS",
    "Water consumption": "IC_RECIPE_WC",
}
ROBUST = {"IC_RECIPE_GW", "IC_RECIPE_OD", "IC_RECIPE_IR", "IC_RECIPE_OF_HH",
          "IC_RECIPE_OF_EC", "IC_RECIPE_PM", "IC_RECIPE_TA", "IC_RECIPE_FE",
          "IC_RECIPE_ME"}
STRICT = {"IC_RECIPE_TET", "IC_RECIPE_FET", "IC_RECIPE_MET",
          "IC_RECIPE_HCT", "IC_RECIPE_HNCT"}
RESOURCE = {"IC_RECIPE_FRS", "IC_RECIPE_MRS", "IC_RECIPE_LU", "IC_RECIPE_WC"}

# The fossil-resource flows in this graph carry no CAS and their names do not
# match the openLCA "..., in ground" naming, so map them explicitly. Values are
# ReCiPe 2016 mass-basis CFs (kg oil eq / kg); crude oil / natural gas / hard
# coal follow ASSUMPTIONS.md sec.6, brown coal / peat are the ReCiPe defaults.
RESOURCE_ALIASES = {
    "IC_RECIPE_FRS": {
        "crude oil": 1.0,
        "natural gas": 0.84,
        "hard coal": 0.49,
        "brown coal": 0.33,
        "peat": 0.16,
    },
}

_CAS = re.compile(r"(\d{1,7})-(\d{2})-(\d)")


def norm_cas(c):
    if not c:
        return None
    m = _CAS.fullmatch(c.strip())
    if not m:
        return None
    return f"{int(m.group(1))}-{m.group(2)}-{m.group(3)}"


def norm_name(n):
    return re.sub(r"\s+", " ", (n or "").strip().lower())


# openLCA's ReCiPe pack ships country / region-regionalised copies of many
# elementary flows ("Ammonia, RER", "Ammonia, US", ...) that share the parent
# CAS. Only the un-suffixed flow carries the canonical global CF; the regional
# spread is huge and a median across it is meaningless. Drop the suffixed ones.
_REGION_SUFFIX = re.compile(r",\s*[A-Z]{2,3}$")


def is_regionalised(name):
    return bool(_REGION_SUFFIX.search((name or "").strip()))


def olca_bucket(catstr):
    s = (catstr or "").lower()
    if "emission to air" in s:
        return "air"
    if "emission to water" in s:
        return "sea" if ("ocean" in s or "sea" in s) else "water"
    if "emission to soil" in s:
        return "soil"
    if "resource" in s:
        return "resource"
    return "other"


def db_bucket(comps):
    cs = [c for c in comps.split(",") if c]
    order = [("emission/air", "air"), ("emission/seawater", "sea"),
             ("emission/water", "water"), ("emission/soil", "soil"),
             ("resource", "resource")]
    for pref, b in order:
        if any(c.startswith(pref) for c in cs):
            return b
    return "other"


def load_recipe(zip_path, variant):
    z = zipfile.ZipFile(zip_path)
    method = None
    want = f"ReCiPe 2016 Midpoint ({variant})"
    for n in z.namelist():
        if n.startswith("lcia_methods/") and n.endswith(".json"):
            d = json.loads(z.read(n))
            if d.get("name") == want:
                method = d
                break
    if not method:
        sys.exit(f"method '{want}' not found in {zip_path}")

    flow_cas = {}

    def cas_of(fid, inline):
        v = norm_cas(inline)
        if v:
            return v
        if fid in flow_cas:
            return flow_cas[fid]
        try:
            fd = json.loads(z.read(f"flows/{fid}.json"))
            v = norm_cas(fd.get("cas"))
        except KeyError:
            v = None
        flow_cas[fid] = v
        return v

    by_cas = defaultdict(lambda: defaultdict(list))   # ic -> cas -> [(bucket,val)]
    by_name = defaultdict(dict)                        # ic -> name -> val (first)
    for c in method["impactCategories"]:
        cd = json.loads(z.read(f"lcia_categories/{c['@id']}.json"))
        ic = CATMAP.get(cd["name"])
        if not ic:
            continue
        for f in cd.get("impactFactors", []):
            fl = f["flow"]
            if is_regionalised(fl.get("name")):
                continue
            val = f["value"]
            b = olca_bucket(fl.get("category"))
            cas = cas_of(fl["@id"], fl.get("cas"))
            if cas:
                by_cas[ic][cas].append((b, val))
            nm = norm_name(fl.get("name"))
            if nm and nm not in by_name[ic]:
                by_name[ic][nm] = val
    return by_cas, by_name


# Each of these categories has one dominant emission compartment: a flow that
# carries the right CAS but no resolvable compartment is almost certainly an
# emission to that medium, so its CF may stand in. IR is genuinely mixed and
# the USEtox categories are too compartment-sensitive -- no blind fallback for
# those.
DOMINANT_COMPARTMENT = {
    "IC_RECIPE_GW": "air", "IC_RECIPE_OD": "air", "IC_RECIPE_OF_HH": "air",
    "IC_RECIPE_OF_EC": "air", "IC_RECIPE_PM": "air", "IC_RECIPE_TA": "air",
    "IC_RECIPE_FE": "water", "IC_RECIPE_ME": "water",
}


def choose(ic, dbk, vals_by_bucket):
    """-> (value, matchedBy) or (None, None)"""
    if dbk != "other" and dbk in vals_by_bucket:
        return statistics.median(vals_by_bucket[dbk]), f"CAS+{dbk}"
    if ic in STRICT:
        return None, None            # USEtox: compartment must line up exactly
    dom = DOMINANT_COMPARTMENT.get(ic)
    if dom and dom in vals_by_bucket:
        return statistics.median(vals_by_bucket[dom]), f"CAS+{dom}-fallback"
    return None, None


def match(flows, by_cas, by_name):
    """flows: list of (fid, casRaw, name, compsStr, unitsStr). -> list of dict rows."""
    rows = []
    for rec in flows:
        fid, cas_raw, name, comps = rec[0], rec[1], rec[2], rec[3]
        units = rec[4] if len(rec) > 4 else ""
        cas = norm_cas(cas_raw)
        dbk = db_bucket(comps)
        nm = norm_name(name)
        unit_set = {u.strip().lower() for u in units.split(",") if u.strip()}
        # a per-kg CF may only be applied to a flow booked purely in kg (or with
        # no unit recorded). A flow that appears in MJ, Bq, m3, ... -- or in
        # mixed units across processes, e.g. "MJ,kg" for a primary-energy
        # uranium entry -- is an energy / activity accounting flow and a per-kg
        # CF would be a unit error. IR (Bq) and WC (m3) are the two categories
        # whose own reference flow is not a mass, so they are exempt.
        is_mass = unit_set <= {"kg"}
        NONMASS_OK = {"IC_RECIPE_IR", "IC_RECIPE_WC"}
        for ic in CATMAP.values():
            if not is_mass and ic not in NONMASS_OK:
                continue
            if ic in RESOURCE:
                # resource / land CFs are per kg (or m2a / m3); a flow booked in
                # MJ, Bq, ... is an energy / activity accounting entry, not a
                # mass extraction -- never characterise it here.
                if not is_mass:
                    continue
                v = by_name.get(ic, {}).get(nm)
                mb = "name"
                if v is None:
                    for pref, av in RESOURCE_ALIASES.get(ic, {}).items():
                        if nm.startswith(pref):
                            v, mb = av, "alias"
                            break
                if v is not None:
                    rows.append(dict(fid=fid, ic=ic, v=v, mb=mb))
                continue
            cand = by_cas.get(ic, {}).get(cas) if cas else None
            if not cand:
                continue
            vbb = defaultdict(list)
            for b, val in cand:
                vbb[b].append(val)
            v, mb = choose(ic, dbk, vbb)
            if v is not None:
                rows.append(dict(fid=fid, ic=ic, v=v, mb=mb))
    return rows


CY_HEADER = """// ============================================================================
// recipe_cf.cypher  --  generated by import_recipe_cf.py
// ReCiPe 2016 Midpoint (H) characterisation factors for graph flows,
// from the openLCA LCIA Methods package. Strictly additive, re-runnable.
// ============================================================================
"""

CY_SUPERSEDE_GW = """// --- supersede the v3.e climate approximation (EF3.1 GWP x 1.06) -------------
MATCH (:Flow)-[c:CHARACTERIZES]->(:ImpactCategory {id:'IC_RECIPE_GW'})
WHERE c.source STARTS WITH 'approximated from EF3.1'
DELETE c;
"""

CY_BATCH = """UNWIND $rows AS r
MATCH (f:Flow {id:r.fid}), (ic:ImpactCategory {id:r.ic})
WHERE NOT (f)-[:CHARACTERIZES]->(ic)
MERGE (f)-[c:CHARACTERIZES {characterizesId: r.fid + '|' + r.ic + '|'}]->(ic)
  ON CREATE SET c.factor = r.v, c.location = '', c.method = 'IAM_RECIPE',
                c.source = 'ReCiPe 2016 Midpoint (H) / openLCA LCIA pack',
                c.matchedBy = r.mb, c.derived = true;
"""

CY_VERIFY = """// --- coverage ---------------------------------------------------------------
MATCH (m:ImpactAssessmentMethod {id:'IAM_RECIPE'})-[:HAS_CATEGORY]->(ic:ImpactCategory)
OPTIONAL MATCH (f:Flow)-[c:CHARACTERIZES]->(ic)
RETURN ic.id AS category, count(DISTINCT f) AS charFlows
ORDER BY category;
"""

CY_ROLLBACK = """// --- rollback -------------------------------------------------------------
// MATCH (:Flow)-[c:CHARACTERIZES {method:'IAM_RECIPE'}]->() DELETE c;
"""


def as_cypher_literal(rows):
    parts = []
    for r in rows:
        parts.append(
            '{fid:%s, ic:%s, v:%r, mb:%s}'
            % (json.dumps(r["fid"]), json.dumps(r["ic"]), r["v"], json.dumps(r["mb"]))
        )
    return "[\n  " + ",\n  ".join(parts) + "\n]"


def emit_cypher(rows, supersede_gw, chunk=2000):
    out = [CY_HEADER]
    if supersede_gw:
        out.append(CY_SUPERSEDE_GW)
    for i in range(0, len(rows), chunk):
        blk = rows[i:i + chunk]
        stmt = CY_BATCH.replace("$rows", as_cypher_literal(blk))
        out.append(stmt)
    out.append(CY_VERIFY)
    out.append(CY_ROLLBACK)
    return "\n".join(out)


def read_flows_db():
    from neo4j import GraphDatabase
    drv = GraphDatabase.driver(os.environ["NEO4J_URI"],
                               auth=(os.environ["NEO4J_USER"], os.environ["NEO4J_PASSWORD"]))
    q = """
    MATCH (p:Process)-[hf:HAS_FLOW]->(f:Flow)
    WITH f, collect(DISTINCT hf.compartment) AS comps, collect(DISTINCT hf.unit) AS units
    RETURN f.id AS fid, coalesce(f.casNumber,'') AS cas, coalesce(f.name,'') AS name,
           reduce(s='', x IN comps | s + CASE WHEN s='' THEN '' ELSE ',' END + coalesce(x,'')) AS comps,
           reduce(s='', x IN units | s + CASE WHEN s='' THEN '' ELSE ',' END + coalesce(x,'')) AS units
    """
    with drv.session() as s:
        flows = [(r["fid"], r["cas"], r["name"], r["comps"], r["units"]) for r in s.run(q)]
    drv.close()
    return flows


def read_flows_tsv(path):
    flows = []
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n").strip('"')
        if "\t" not in line or line.startswith("row"):
            continue
        p = line.split("\t")
        while len(p) < 5:
            p.append("")
        flows.append((p[0], p[1], p[2], p[3], p[4]))
    return flows


def _strip_comment_lines(block):
    return "\n".join(ln for ln in block.splitlines() if not ln.lstrip().startswith("//")).strip()


def load_cypher(text):
    from neo4j import GraphDatabase
    drv = GraphDatabase.driver(os.environ["NEO4J_URI"],
                               auth=(os.environ["NEO4J_USER"], os.environ["NEO4J_PASSWORD"]))
    stmts = [_strip_comment_lines(s) for s in text.split(";\n")]
    stmts = [s for s in stmts if s]
    with drv.session() as s:
        for st in stmts:
            s.run(st if st.endswith(";") else st + ";")
    drv.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--openlca-zip", required=True)
    ap.add_argument("--variant", default="H", choices=sorted(VARIANTS))
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--flows", help="TSV flow list (see module docstring)")
    src.add_argument("--read-db", action="store_true",
                     help="read the flow list from NEO4J_URI/USER/PASSWORD via Bolt")
    ap.add_argument("--out", help="write the generated Cypher here")
    ap.add_argument("--load", action="store_true", help="also execute it via Bolt")
    ap.add_argument("--supersede-gw", action="store_true",
                    help="replace the v3.e EF3.1x1.06 climate factors with real ReCiPe GW CFs")
    a = ap.parse_args()

    by_cas, by_name = load_recipe(a.openlca_zip, a.variant)
    flows = read_flows_db() if a.read_db else read_flows_tsv(a.flows)
    rows = match(flows, by_cas, by_name)

    per_cat = defaultdict(int)
    per_mode = defaultdict(int)
    for r in rows:
        per_cat[r["ic"]] += 1
        per_mode[r["mb"]] += 1
    sys.stderr.write(f"flows in: {len(flows)}   CHARACTERIZES rows: {len(rows)}\n")
    sys.stderr.write(f"match modes: {dict(per_mode)}\n")
    for ic in CATMAP.values():
        sys.stderr.write(f"  {ic:16s} {per_cat[ic]:5d}\n")

    text = emit_cypher(rows, a.supersede_gw)
    if a.out:
        open(a.out, "w", encoding="utf-8").write(text)
        sys.stderr.write(f"wrote {a.out} ({len(text)} bytes)\n")
    if a.load:
        load_cypher(text)
        sys.stderr.write("loaded via Bolt\n")
    if not a.out and not a.load:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
