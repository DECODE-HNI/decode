#!/usr/bin/env python3
"""
import_ilcd_package.py -- add ONE ILCD process package to the Ned2 graph.

The bulk seed load (../ -- lca_bulk_load/) builds the graph's process/flow/impact
backbone from a fixed set of Sphera packages. This script is the *incremental*
counterpart: point it at a single ILCD `_dependencies` package (one process +
all referenced flows/units/sources), and it emits an additive, re-runnable
Cypher migration that

  1. creates a :Process node carrying the ILCD metadata,
  2. creates any :Flow nodes not already in the graph,
  3. links them with :HAS_FLOW {amount, direction, compartment},
  4. HARMONISES characterisation: older eco-profile packages name the
     impact-driving emissions as "carbon dioxide (Emissions to air,
     unspecified)" etc., while the graph's CHARACTERIZES factors hang off the
     canonical "carbon dioxide (fossil)" variant -- step 4/5 bridge that by
     CAS number + compartment (biogenic<->biogenic guarded, land-use CO2
     excluded); newer re-exports already match by UUID and step 4/5 is a no-op,
  5. wires (:Material)-[:MODELED_BY {dataVariant:'A-realdataset'}]->(:Process).

After importing one or more packages, run `refresh_variant_a.cypher` once to
recompute the Variant-A (real-dataset) EF3.1 results across every gripper.

Credentials, when --load is used, come from NEO4J_URI / NEO4J_USER /
NEO4J_PASSWORD environment variables only -- never arguments (DECODE convention).

Usage
-----
    python import_ilcd_package.py PACKAGE \
        --material MAT_ABS --proc-id PROC_ABS_PLASTICSEUROPE_EF \
        --proxy false --rationale "PlasticsEurope ABS eco-profile, EU-27 2010" \
        [--out import_MAT_ABS.cypher] [--load]

PACKAGE is either a `<uuid>_dependencies.zip` or an already-extracted directory
that contains `ILCD/processes/`.  A tiny synthetic package lives in `example/`.
"""
import argparse
import os
import re
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET

# ILCD namespaces are declared per-file and vary; strip them and match locally.
_TAG = re.compile(r"\{.*\}")


def _local(tag):
    return _TAG.sub("", tag)


def _find(el, path):
    """find by local-name path, e.g. 'processInformation/dataSetInformation/name/baseName'."""
    cur = [el]
    for part in path.split("/"):
        nxt = []
        for c in cur:
            nxt += [ch for ch in c if _local(ch.tag) == part]
        cur = nxt
    return cur


def _text(el, path):
    hits = _find(el, path)
    return hits[0].text.strip() if hits and hits[0].text else ""


def parse_process(proc_xml):
    root = ET.parse(proc_xml).getroot()
    meta = {}
    meta["uuid"] = _text(root, "processInformation/dataSetInformation/common:UUID") \
        or _text(root, "processInformation/dataSetInformation/UUID")
    meta["name"] = _text(root, "processInformation/dataSetInformation/name/baseName")
    meta["version"] = ""
    for pub in _find(root, "administrativeInformation/publicationAndOwnership"):
        meta["version"] = _text(pub, "common:dataSetVersion") or _text(pub, "dataSetVersion")
    meta["referenceYear"] = _text(root, "processInformation/time/common:referenceYear") \
        or _text(root, "processInformation/time/referenceYear")
    meta["validUntil"] = _text(root, "processInformation/time/common:dataSetValidUntil") \
        or _text(root, "processInformation/time/dataSetValidUntil")
    loc = _find(root, "processInformation/geography/locationOfOperationSupplyOrProduction")
    meta["location"] = loc[0].get("location", "") if loc else ""
    meta["typeOfDataSet"] = _text(root, "modellingAndValidation/LCIMethodAndAllocation/typeOfDataSet")
    ref_iid = _text(root, "processInformation/quantitativeReference/referenceToReferenceFlow")

    exchanges = []
    for ex in _find(root, "exchanges/exchange"):
        iid = ex.get("dataSetInternalID", "")
        ref = _find(ex, "referenceToFlowDataSet")
        uuid = ref[0].get("refObjectId", "") if ref else ""
        short = ""
        if ref:
            sd = _find(ref[0], "common:shortDescription") or _find(ref[0], "shortDescription")
            if sd and sd[0].text:
                short = re.sub(r"\s+", " ", sd[0].text).strip()
        direction = _text(ex, "exchangeDirection")
        amount = _text(ex, "resultingAmount") or _text(ex, "meanAmount")
        exchanges.append(dict(iid=iid, uuid=uuid, short=short,
                              direction=direction, amount=amount))
    meta["productFlowUuid"] = next(
        (e["uuid"] for e in exchanges if e["iid"] == ref_iid), "")
    return meta, exchanges


def parse_flows(flows_dir):
    defs = {}
    if not os.path.isdir(flows_dir):
        return defs
    for fn in os.listdir(flows_dir):
        if not fn.endswith(".xml"):
            continue
        try:
            root = ET.parse(os.path.join(flows_dir, fn)).getroot()
        except ET.ParseError:
            continue
        uuid = _text(root, "flowInformation/dataSetInformation/common:UUID") \
            or _text(root, "flowInformation/dataSetInformation/UUID")
        if not uuid:
            continue
        name = _text(root, "flowInformation/dataSetInformation/name/baseName")
        cas = ""
        for di in _find(root, "flowInformation/dataSetInformation"):
            cas = _text(di, "CASNumber") or _text(di, "common:other/CASNumber") or cas
        cas = re.sub(r"^0+", "", cas.strip())
        ftype = _text(root, "modellingAndValidation/LCIMethod/typeOfDataSet")
        defs[uuid] = dict(name=name, cas=cas, ftype=ftype or "Elementary flow")
    return defs


def compartment(short):
    s = short.lower()
    if "emissions to air" in s or "emission to air" in s:
        return "emission/air"
    if "emissions to fresh water" in s or "emissions to freshwater" in s:
        return "emission/water"
    if "emissions to sea water" in s:
        return "emission/seawater"
    if "emissions to" in s and "soil" in s:
        return "emission/soil"
    if "resources from ground" in s:
        return "resource/ground"
    if "resources from air" in s:
        return "resource/air"
    if "resources from water" in s:
        return "resource/water"
    return ""


def esc(v):
    return v.replace("\\", "").replace("'", "\\'")


def build_cypher(meta, exchanges, flowdefs, material, proc_id, proxy, rationale):
    from datetime import date
    today = date.today().isoformat()
    L = []
    a = L.append
    a("// ============================================================================")
    a(f"// import_ilcd_package.py output -- {material} <- {meta['name']}")
    a(f"//   dataset : {meta['uuid']} (v{meta['version']}, {meta['typeOfDataSet']}, "
      f"{meta['referenceYear']}, {meta['location']})")
    a("//   source  : local ILCD _dependencies package. Additive, re-runnable (MERGE).")
    a(f"//   generated {today}")
    a("// ============================================================================")
    a("")
    a("// ---- 1. Process node ----")
    a(f"MERGE (p:Process {{id:'{proc_id}'}})")
    a(f"  SET p.name='{esc(meta['name'])}', p.processType='RawMaterialProduction',")
    a(f"      p.datasetUuid='{meta['uuid']}', p.dataSetVersion='{meta['version']}',")
    ry = meta["referenceYear"] or "null"
    vu = meta["validUntil"] or "null"
    a(f"      p.referenceYear={ry}, p.dataSetValidUntil={vu},")
    a(f"      p.geographicalLocation='{esc(meta['location'])}', p.dataSetOwner='ILCD package',")
    a(f"      p.dataSetType='{esc(meta['typeOfDataSet'])}', p.lifecycleModule='A1-A3',")
    a("      p.referenceUnit='kg', p.provenance='ILCD-package-import',")
    a(f"      p.importedAt='{today}';")
    a("")
    a("// ---- 2. Flow nodes (create the ones not yet in the graph) ----")
    a("UNWIND [")
    rows = []
    for u, d in sorted(flowdefs.items()):
        rows.append(f'  {{u:"{u}", n:"{esc(d["name"])}", cas:"{d["cas"]}", ft:"{esc(d["ftype"])}"}}')
    a(",\n".join(rows))
    a("] AS fd")
    a("MERGE (f:Flow {id:fd.u})")
    a("  ON CREATE SET f.name=fd.n, f.casNumber=fd.cas, f.flowType=fd.ft,")
    a("                f.provenance='ILCD-package-import';")
    a("")
    a("// ---- 3. HAS_FLOW exchanges (reference product skipped) ----")
    a("UNWIND [")
    rows = []
    for e in exchanges:
        if e["uuid"] == meta["productFlowUuid"] or not e["uuid"]:
            continue
        amt = e["amount"] or "0"
        rows.append(f'  {{u:"{e["uuid"]}", amt:{amt}, dir:"{e["direction"].lower()}", '
                    f'cmp:"{compartment(e["short"])}"}}')
    a(",\n".join(rows))
    a("] AS ex")
    a(f"MATCH (p:Process {{id:'{proc_id}'}}), (f:Flow {{id:ex.u}})")
    a("MERGE (p)-[hf:HAS_FLOW]->(f)")
    a(f"  SET hf.amount=ex.amt, hf.direction=ex.dir, hf.unit='kg', hf.compartment=ex.cmp,")
    a(f"      hf.source='{esc(meta['name'])} (ILCD package)';")
    a("")
    a("// ---- 4. characterisation harmonisation (CAS + compartment) ----")
    a(f"MATCH (p:Process {{id:'{proc_id}'}})-[hf:HAS_FLOW]->(f:Flow)")
    a("WHERE hf.compartment STARTS WITH 'emission' AND coalesce(f.casNumber,'') <> ''")
    a("  AND NOT replace(f.casNumber,' ','') IN ['124-38-9','74-82-8']")
    a("  AND NOT (f)-[:CHARACTERIZES]->()")
    a("WITH f, replace(f.casNumber,' ','') AS cas")
    a("MATCH (src:Flow)-[c:CHARACTERIZES]->(ic:ImpactCategory)")
    a("WHERE src <> f AND replace(coalesce(src.casNumber,''),' ','') = cas")
    a("  AND ((toLower(f.name) CONTAINS 'biogenic') = (toLower(src.name) CONTAINS 'biogenic'))")
    a("  AND NOT toLower(src.name) CONTAINS 'land use' AND NOT toLower(src.name) CONTAINS 'land-use'")
    a("WITH f, ic, head(collect(c)) AS c")
    a("MERGE (f)-[nc:CHARACTERIZES]->(ic)")
    a("  ON CREATE SET nc.factor=c.factor, nc.location=coalesce(c.location,''),")
    a("                nc.source='harmonised via CAS', nc.derived=true;")
    a("")
    a("// ---- 5. override: unspecified fossil CO2 / CH4 -> fossil variant ----")
    a("UNWIND [{cas:'124-38-9', src:'carbon dioxide (fossil)'},")
    a("        {cas:'74-82-8',  src:'methane (fossil)'}] AS ov")
    a(f"MATCH (p:Process {{id:'{proc_id}'}})-[hf:HAS_FLOW]->(f:Flow)")
    a("WHERE replace(coalesce(f.casNumber,''),' ','') = ov.cas")
    a("  AND hf.compartment STARTS WITH 'emission' AND NOT toLower(f.name) CONTAINS 'biogenic'")
    a("  AND NOT (f)-[:CHARACTERIZES]->(:ImpactCategory {id:'IC_CLIMATE'})")
    a("MATCH (src:Flow {name:ov.src})-[c:CHARACTERIZES]->(ic:ImpactCategory)")
    a("MERGE (f)-[nc:CHARACTERIZES]->(ic)")
    a("  ON CREATE SET nc.factor=c.factor, nc.location=coalesce(c.location,''),")
    a("                nc.source='override '+ov.src, nc.derived=true;")
    a("")
    a("// ---- 6. MODELED_BY (Variant A) ----")
    a(f"MATCH (m:Material {{id:'{material}'}}), (p:Process {{id:'{proc_id}'}})")
    a("MERGE (m)-[r:MODELED_BY]->(p)")
    a(f"  SET r.proxy={str(proxy).lower()}, r.proxyRationale='{esc(rationale)}',")
    a(f"      r.lifecycleModule='A1-A3', r.datasetUuid='{meta['uuid']}', r.dataVariant='A-realdataset';")
    a("")
    a("// ---- 7. verification: per-kg climate + full EF3.1 category vector ----")
    a(f"MATCH (p:Process {{id:'{proc_id}'}})-[hf:HAS_FLOW]->(f:Flow)")
    a("WITH f, sum(hf.amount) AS amt")
    a("MATCH (f)-[c:CHARACTERIZES]->(ic:ImpactCategory {id:'IC_CLIMATE'})")
    a("WITH f, amt, [x IN collect(c) WHERE coalesce(x.location,'')=''][0].factor AS fac")
    a(f"RETURN '{material}' AS material, round(sum(amt*fac),4) AS gwp_A1_kgCO2e_per_kg, count(f) AS climateFlows;")
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("package", help="<uuid>_dependencies.zip or an extracted package dir")
    ap.add_argument("--material", required=True, help="target Material.id, e.g. MAT_ABS")
    ap.add_argument("--proc-id", required=True, help="Process.id to create, e.g. PROC_ABS_PLASTICSEUROPE_EF")
    ap.add_argument("--proxy", choices=["true", "false"], default="false",
                    help="is this dataset a proxy for the material? (default false)")
    ap.add_argument("--rationale", required=True, help="proxyRationale / provenance sentence")
    ap.add_argument("--out", help="write Cypher here (default: import_<material>.cypher)")
    ap.add_argument("--load", action="store_true",
                    help="also execute against NEO4J_URI/USER/PASSWORD via the Bolt driver")
    args = ap.parse_args()

    pkg = args.package
    tmp = None
    if pkg.lower().endswith(".zip"):
        tmp = tempfile.mkdtemp(prefix="ilcd_")
        with zipfile.ZipFile(pkg) as z:
            z.extractall(tmp)
        pkg = tmp
    proc_files = []
    for base, _, files in os.walk(pkg):
        if os.path.basename(base) == "processes":
            proc_files += [os.path.join(base, f) for f in files if f.endswith(".xml")]
    if len(proc_files) != 1:
        sys.exit(f"expected exactly one process XML under {pkg}/ILCD/processes/, found {len(proc_files)}")
    flows_dir = os.path.join(os.path.dirname(os.path.dirname(proc_files[0])), "flows")

    meta, exchanges = parse_process(proc_files[0])
    flowdefs = parse_flows(flows_dir)
    # make sure every referenced flow has at least a stub def
    for e in exchanges:
        flowdefs.setdefault(e["uuid"], dict(name=e["short"].split(" (")[0] or e["uuid"],
                                            cas="", ftype="Elementary flow"))

    cypher = build_cypher(meta, exchanges, flowdefs, args.material,
                          args.proc_id, args.proxy == "true", args.rationale)
    out = args.out or f"import_{args.material}.cypher"
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(cypher)
    print(f"wrote {out}  ({len(exchanges)} exchanges, {len(flowdefs)} flow defs, "
          f"product={meta['productFlowUuid']})", file=sys.stderr)

    if args.load:
        try:
            from neo4j import GraphDatabase
        except ImportError:
            sys.exit("--load needs the neo4j driver: pip install neo4j")
        uri = os.environ["NEO4J_URI"]
        user = os.environ["NEO4J_USER"]
        pw = os.environ["NEO4J_PASSWORD"]
        drv = GraphDatabase.driver(uri, auth=(user, pw))
        with drv.session() as s:
            for stmt in [x for x in cypher.split(";\n") if x.strip() and not x.strip().startswith("//")]:
                s.run(stmt)
        drv.close()
        print("loaded into", uri, file=sys.stderr)

    if tmp:
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
