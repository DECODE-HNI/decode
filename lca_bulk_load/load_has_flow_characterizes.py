"""
load_has_flow_characterizes.py

Channel B of the Neo4j model rebuild: loads HAS_FLOW and CHARACTERIZES directly
via the Bolt driver, because the Neo4j Data Importer merges relationships only on
(from, to, type) and therefore silently collapses parallel edges that differ in
substance between the same pair of nodes (see README.md in this folder,
two-channel design).

HAS_FLOW is merged on the property `exchangeId` (MERGE key),
CHARACTERIZES on the combination (flow id, category id, location). Both
uniqueness rules are additionally enforced by a Neo4j constraint:
exchangeId is already globally unique; for CHARACTERIZES a synthetic
characterizesId = "<flowId>|<categoryId>|<location>" is written along,
because a relationship constraint can only check its own properties, not
end-node combinations.

Prerequisite: channel A (Data Importer ZIP) has already been imported --
all Process/Flow/ImpactCategory nodes must exist, otherwise the MATCH clauses
fail (missing nodes are not created automatically).

Credentials ONLY via environment variables (never as a script argument, never
hard-coded):
    NEO4J_URI       e.g. neo4j+s://xxxx.databases.neo4j.io
    NEO4J_USER      e.g. neo4j
    NEO4J_PASSWORD

Usage:
    pip install neo4j
    export NEO4J_URI=...        (PowerShell: $env:NEO4J_URI = "...")
    export NEO4J_USER=neo4j
    export NEO4J_PASSWORD=...
    python load_has_flow_characterizes.py --has-flow r_40_HAS_FLOW_Process_TO_Flow.csv --characterizes r_41_CHARACTERIZES_Flow_TO_ImpactCategory.csv

Before the actual load, ALL existing HAS_FLOW and CHARACTERIZES edges are
deleted (full rebuild) -- nodes stay untouched. Use --no-wipe to skip this.
"""

import argparse
import csv
import os
import sys
import time


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


def chunked(seq, size):
    for i in range(0, len(seq), size):
        yield seq[i : i + size]


HAS_FLOW_QUERY = """
UNWIND $rows AS row
MATCH (p:Process {id: row.from_id})
MATCH (f:Flow {id: row.to_id})
MERGE (p)-[r:HAS_FLOW {exchangeId: row.exchangeId}]->(f)
SET r.amount = toFloat(row.amount),
    r.unit = row.unit,
    r.direction = row.direction,
    r.location = row.location,
    r.quantitativeReference = (row.quantitativeReference = 'true'),
    r.ratioToReference = toFloat(row.ratioToReference),
    r.dataMaturity = row.dataMaturity,
    r.referenceYear = row.referenceYear,
    r.uncertainty = CASE WHEN row.uncertainty = '' THEN null ELSE toFloat(row.uncertainty) END,
    r.comment = row.comment
"""

CHARACTERIZES_QUERY = """
UNWIND $rows AS row
MATCH (f:Flow {id: row.from_id})
MATCH (c:ImpactCategory {id: row.to_id})
MERGE (f)-[r:CHARACTERIZES {location: row.location}]->(c)
SET r.factor = toFloat(row.factor),
    r.characterizesId = f.id + '|' + c.id + '|' + row.location
"""

WIPE_HAS_FLOW = "MATCH ()-[r:HAS_FLOW]->() CALL (r) { DELETE r } IN TRANSACTIONS OF 2000 ROWS"
WIPE_CHARACTERIZES = "MATCH ()-[r:CHARACTERIZES]->() CALL (r) { DELETE r } IN TRANSACTIONS OF 2000 ROWS"

# Uniqueness constraints: HAS_FLOW.exchangeId is globally unique by
# construction. CHARACTERIZES is only unique via (flow, impact category,
# location) -- so write the synthetic characterizesId above and constrain
# ON THAT (a relationship constraint can only check its own properties,
# not end-node combinations).
CREATE_CONSTRAINTS = [
    "CREATE CONSTRAINT has_flow_exchangeid_unique IF NOT EXISTS "
    "FOR ()-[r:HAS_FLOW]-() REQUIRE r.exchangeId IS UNIQUE",
    "CREATE CONSTRAINT characterizes_id_unique IF NOT EXISTS "
    "FOR ()-[r:CHARACTERIZES]-() REQUIRE r.characterizesId IS UNIQUE",
]


def run_batches(driver, database, query, rows, batch_size, label):
    total = len(rows)
    done = 0
    t0 = time.time()
    with driver.session(database=database) as session:
        for batch in chunked(rows, batch_size):
            session.run(query, rows=batch).consume()
            done += len(batch)
            elapsed = time.time() - t0
            rate = done / elapsed if elapsed > 0 else 0
            print(f"  [{label}] {done}/{total} ({rate:.0f} rows/s)")
    print(f"[{label}] fertig: {total} Zeilen in {time.time()-t0:.1f}s")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--has-flow", required=True, help="Pfad zur konsolidierten r_HAS_FLOW_Process_TO_Flow.csv")
    ap.add_argument("--characterizes", required=True, help="Pfad zur konsolidierten r_CHARACTERIZES_Flow_TO_ImpactCategory.csv")
    ap.add_argument("--database", default="neo4j", help="Zieldatenbank (Default: neo4j)")
    ap.add_argument("--batch-size", type=int, default=500)
    ap.add_argument("--no-wipe", action="store_true", help="Do NOT delete existing HAS_FLOW/CHARACTERIZES edges beforehand")
    args = ap.parse_args()

    driver = get_driver()
    driver.verify_connectivity()
    print("Connected to Neo4j.")

    with driver.session(database=args.database) as session:
        for stmt in CREATE_CONSTRAINTS:
            session.run(stmt).consume()
    print("Eindeutigkeits-Constraints angelegt (exchangeId, characterizesId).")

    if not args.no_wipe:
        print("Loesche bestehende HAS_FLOW/CHARACTERIZES-Kanten (Full-Rebuild)...")
        with driver.session(database=args.database) as session:
            session.run(WIPE_HAS_FLOW).consume()
            session.run(WIPE_CHARACTERIZES).consume()
        print("Deleted.")
    else:
        print("--no-wipe set: existing edges are kept (MERGE only, no prior deletion).")

    has_flow_rows = read_rows(args.has_flow)
    print(f"HAS_FLOW: {len(has_flow_rows)} Zeilen aus {args.has_flow} gelesen.")
    run_batches(driver, args.database, HAS_FLOW_QUERY, has_flow_rows, args.batch_size, "HAS_FLOW")

    cf_rows = read_rows(args.characterizes)
    print(f"CHARACTERIZES: {len(cf_rows)} Zeilen aus {args.characterizes} gelesen.")
    run_batches(driver, args.database, CHARACTERIZES_QUERY, cf_rows, args.batch_size, "CHARACTERIZES")

    with driver.session(database=args.database) as session:
        result = session.run(
            "MATCH ()-[r]->() WHERE type(r) IN ['HAS_FLOW','CHARACTERIZES'] "
            "RETURN type(r) AS relType, count(r) AS n ORDER BY relType"
        )
        print("\nControl count after completion:")
        for record in result:
            print(f"  {record['relType']}: {record['n']}")

    driver.close()


if __name__ == "__main__":
    main()
