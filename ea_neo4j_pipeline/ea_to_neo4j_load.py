"""
ea_to_neo4j_load.py

Second step of the EA -> Neo4j pipeline (see ea_to_neo4j_mapping.md).
Loads the CSVs produced by ea_xmi_extract.py (ea_extract/ea_<Label>.csv for
nodes, ea_extract/ea_rel_<TYPE>.csv for relationships) into the existing
Neo4j instance via the Bolt driver. Deliberately kept dumb -- all label/type
decisions and the GUID resolution already happened in the extractor.

Credentials ONLY via environment variables (never as a script argument, never
hard-coded), analogous to load_has_flow_characterizes.py:
    NEO4J_URI       e.g. bolt://localhost:7687
    NEO4J_USER      e.g. neo4j
    NEO4J_PASSWORD

MERGE behaviour:
- Nodes: MERGE on (label, id), then SET n += row (the CSV only contains
  non-empty properties, see ea_xmi_extract.py) -- existing nodes (e.g.
  FUNC_GRASP) are enriched, not replaced.
- Process Element (-> :Process): additional :REFERENCES edge if processRef
  is set and differs from the node's own id (see mapping doc, section 4).
- Product Element at part level: :USES_MATERIAL edge to the material named in
  materialRef, if set (the target material must already exist -- no
  auto-creation, MATCH instead of MERGE). This replaces any existing
  :USES_MATERIAL edge of the part to a DIFFERENT material -- a part does not
  consist of two materials at once, materialRef is the sole source of truth
  for this assignment, not additive.
- Relationships from ea_rel_*.csv: MERGE on (from_id, to_id, type) -- sufficient
  for EA traces without known parallel-edge issues (unlike HAS_FLOW/CHARACTERIZES
  in channel B, see ../lca_bulk_load/README.md).

ONLY nodes/edges from the CSVs are merged -- nothing is deleted.
A full rebuild as in channel B is deliberately not provided here, because EA data
arrives incrementally from a running SysML model.

Usage:
    pip install neo4j
    $env:NEO4J_URI = "bolt://localhost:7687"
    $env:NEO4J_USER = "neo4j"
    $env:NEO4J_PASSWORD = "..."
    python ea_to_neo4j_load.py --extract-dir ea_extract
"""

import argparse
import csv
import glob
import os
import sys
import time

# Tags of type "Real" or "Boolean" in the RFLPV2 profile -- converted before loading
# so that they do not end up as strings in the graph.
REAL_PROPERTIES = {
    "requirementParameter", "requirementPriority", "sustainabilityThreshold",
    "costs", "validationParameter", "verificationParameter",
}
BOOLEAN_PROPERTIES = {"safetyCritical"}

NEW_LABEL_CONSTRAINTS = [
    ("CustomerNeed", "customerneed_id_unique"),
    ("TestCase", "testcase_id_unique"),
    ("TestCaseDescription", "testcasedescription_id_unique"),
    ("TestScenario", "testscenario_id_unique"),
    ("Validation", "validation_id_unique"),
    ("Verification", "verification_id_unique"),
]


def get_driver():
    from neo4j import GraphDatabase

    uri = os.environ.get("NEO4J_URI")
    user = os.environ.get("NEO4J_USER")
    password = os.environ.get("NEO4J_PASSWORD")
    missing = [n for n, v in [("NEO4J_URI", uri), ("NEO4J_USER", user), ("NEO4J_PASSWORD", password)] if not v]
    if missing:
        print(f"Missing environment variables: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)
    return GraphDatabase.driver(uri, auth=(user, password))


def read_rows(path):
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        return list(reader)


def coerce_row(row):
    out = {}
    for k, v in row.items():
        if v is None or v == "":
            continue
        if k in REAL_PROPERTIES:
            try:
                out[k] = float(v)
            except ValueError:
                print(f"WARNING: {k}={v!r} cannot be parsed as a number, stays a string.", file=sys.stderr)
                out[k] = v
        elif k in BOOLEAN_PROPERTIES:
            out[k] = str(v).strip().lower() == "true"
        else:
            out[k] = v
    return out


def chunked(seq, size):
    for i in range(0, len(seq), size):
        yield seq[i : i + size]


def run_batches(driver, database, query, rows, batch_size, label):
    if not rows:
        return
    total = len(rows)
    done = 0
    t0 = time.time()
    with driver.session(database=database) as session:
        for batch in chunked(rows, batch_size):
            session.run(query, rows=batch).consume()
            done += len(batch)
    print(f"  [{label}] {done}/{total} rows in {time.time()-t0:.1f}s")


NODE_MERGE_QUERY = """
UNWIND $rows AS row
MERGE (n:`{label}` {{id: row.id}})
SET n += row
"""

PROCESS_REFERENCES_QUERY = """
UNWIND $rows AS row
WITH row WHERE row.processRef IS NOT NULL AND row.processRef <> row.id
MATCH (p:Process {id: row.id})
MATCH (ref:Process {id: row.processRef})
MERGE (p)-[:REFERENCES]->(ref)
"""

PART_USES_MATERIAL_QUERY = """
UNWIND $rows AS row
WITH row WHERE row.materialRef IS NOT NULL
MATCH (part:Part {id: row.id})
OPTIONAL MATCH (part)-[oldRel:USES_MATERIAL]->(oldMat:Material)
WHERE oldMat.id <> row.materialRef
FOREACH (_ IN CASE WHEN oldRel IS NOT NULL THEN [1] ELSE [] END | DELETE oldRel)
WITH row, part
OPTIONAL MATCH (mat:Material {id: row.materialRef})
FOREACH (_ IN CASE WHEN mat IS NOT NULL THEN [1] ELSE [] END |
    MERGE (part)-[:USES_MATERIAL]->(mat)
)
WITH row, mat WHERE mat IS NULL
RETURN row.id AS part_id, row.materialRef AS missing_material_ref
"""

REL_MERGE_QUERY_TEMPLATE = """
UNWIND $rows AS row
MATCH (a {{id: row.from_id}})
MATCH (b {{id: row.to_id}})
MERGE (a)-[r:`{rel_type}`]->(b)
SET r.sourceStereotype = row.sourceStereotype,
    r.targetStereotype = row.targetStereotype
"""


def load_nodes(driver, database, extract_dir, batch_size):
    node_files = sorted(glob.glob(os.path.join(extract_dir, "ea_*.csv")))
    node_files = [f for f in node_files if "ea_rel_" not in os.path.basename(f)]
    id_index = {}  # label -> set(ids), for the final check

    for path in node_files:
        label = os.path.basename(path)[len("ea_"):-len(".csv")]
        rows = [coerce_row(r) for r in read_rows(path)]
        print(f"{label}: {len(rows)} rows from {path}")
        query = NODE_MERGE_QUERY.format(label=label)
        run_batches(driver, database, query, rows, batch_size, label)
        id_index[label] = {r["id"] for r in rows}

        if label == "Process":
            run_batches(driver, database, PROCESS_REFERENCES_QUERY, rows, batch_size, "Process.REFERENCES")
        if label == "Part":
            with driver.session(database=database) as session:
                for batch in chunked(rows, batch_size):
                    result = session.run(PART_USES_MATERIAL_QUERY, rows=batch)
                    for record in result:
                        print(f"  WARNING: materialRef={record['missing_material_ref']!r} on "
                              f"part {record['part_id']} points to no existing "
                              f":Material -- edge not created.", file=sys.stderr)
    return id_index


def load_relationships(driver, database, extract_dir, batch_size):
    rel_files = sorted(glob.glob(os.path.join(extract_dir, "ea_rel_*.csv")))
    for path in rel_files:
        rel_type = os.path.basename(path)[len("ea_rel_"):-len(".csv")]
        rows = read_rows(path)
        print(f":{rel_type}: {len(rows)} rows from {path}")
        query = REL_MERGE_QUERY_TEMPLATE.format(rel_type=rel_type)
        run_batches(driver, database, query, rows, batch_size, rel_type)


def ensure_constraints(driver, database):
    with driver.session(database=database) as session:
        for label, name in NEW_LABEL_CONSTRAINTS:
            session.run(
                f"CREATE CONSTRAINT {name} IF NOT EXISTS "
                f"FOR (n:{label}) REQUIRE n.id IS UNIQUE"
            ).consume()
    print(f"{len(NEW_LABEL_CONSTRAINTS)} uniqueness constraints for new labels ensured.")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--extract-dir", default="ea_extract", help="Directory with the ea_xmi_extract.py output")
    ap.add_argument("--database", default="neo4j")
    ap.add_argument("--batch-size", type=int, default=500)
    ap.add_argument("--skip-constraints", action="store_true")
    args = ap.parse_args()

    if not os.path.isdir(args.extract_dir):
        print(f"ERROR: {args.extract_dir} does not exist -- run ea_xmi_extract.py first.", file=sys.stderr)
        sys.exit(1)

    driver = get_driver()
    driver.verify_connectivity()
    print("Connected to Neo4j.")

    if not args.skip_constraints:
        ensure_constraints(driver, args.database)

    load_nodes(driver, args.database, args.extract_dir, args.batch_size)
    load_relationships(driver, args.database, args.extract_dir, args.batch_size)

    with driver.session(database=args.database) as session:
        result = session.run(
            "MATCH (n) WHERE n.sourceStereotype IS NOT NULL "
            "RETURN labels(n) AS labels, n.sourceStereotype AS stereotype, count(*) AS n "
            "ORDER BY labels, stereotype"
        )
        print("\nControl count (EA-imported nodes only, identified by sourceStereotype):")
        for record in result:
            print(f"  {record['labels']} <- {record['stereotype']}: {record['n']}")

    driver.close()


if __name__ == "__main__":
    main()
