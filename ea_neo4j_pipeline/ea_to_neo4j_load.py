"""
ea_to_neo4j_load.py

Zweiter Schritt der EA -> Neo4j Pipeline (siehe ea_to_neo4j_mapping.md).
Laedt die von ea_xmi_extract.py erzeugten CSVs (ea_extract/ea_<Label>.csv fuer
Knoten, ea_extract/ea_rel_<TYPE>.csv fuer Beziehungen) per Bolt-Treiber in die
bestehende Neo4j-Instanz. Bewusst dumm gehalten -- alle Label-/Typ-Entscheidungen
und die GUID-Aufloesung sind bereits im Extraktor passiert.

Zugangsdaten NUR ueber Umgebungsvariablen (nie als Skript-Argument, nie
hartkodiert), analog zu load_has_flow_characterizes.py:
    NEO4J_URI       z.B. bolt://localhost:7687
    NEO4J_USER      z.B. neo4j
    NEO4J_PASSWORD

MERGE-Verhalten:
- Knoten: MERGE auf (Label, id), danach SET n += row (nur nicht-leere Properties
  sind im CSV enthalten, siehe ea_xmi_extract.py) -- bestehende Knoten (z.B.
  FUNC_GRASP) werden angereichert, nicht ersetzt.
- Process Element (-> :Process): zusaetzliche :REFERENCES-Kante, wenn processRef
  gesetzt ist und vom eigenen id abweicht (siehe Mapping-Doku Abschnitt 4).
- Product Element auf Part-Ebene: :USES_MATERIAL-Kante zum in materialRef
  genannten Material, wenn gesetzt (Ziel-Material muss bereits existieren --
  kein Auto-Anlegen, MATCH statt MERGE). Ersetzt dabei jede zuvor bestehende
  :USES_MATERIAL-Kante des Parts zu einem ANDEREN Material -- ein Part
  besteht nicht aus zwei Materialien gleichzeitig, materialRef ist die
  alleinige Quelle der Wahrheit fuer diese Zuordnung, nicht additiv.
- Beziehungen aus ea_rel_*.csv: MERGE auf (from_id, to_id, Typ) -- fuer
  EA-Traces ohne bekannte Parallelkanten-Problematik ausreichend (anders als
  HAS_FLOW/CHARACTERIZES in Kanal B, siehe HANDOFF_CONTEXT_V2.md Abschnitt 4).

Es werden NUR Knoten/Kanten aus den CSVs gemerged -- nichts wird geloescht.
Ein Full-Rebuild wie bei Kanal B ist hier bewusst nicht vorgesehen, da EA-Daten
inkrementell aus einem laufenden SysML-Modell kommen.

Aufruf:
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

# Tags mit Typ "Real" bzw. "Boolean" im RFLPV2-Profil -- werden vor dem Laden
# konvertiert, damit sie nicht als String im Graphen landen.
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
        print(f"Fehlende Umgebungsvariablen: {', '.join(missing)}", file=sys.stderr)
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
                print(f"WARNUNG: {k}={v!r} nicht als Zahl parsbar, bleibt String.", file=sys.stderr)
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
    print(f"  [{label}] {done}/{total} Zeilen in {time.time()-t0:.1f}s")


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
    id_index = {}  # label -> set(ids), fuer die Abschlusskontrolle

    for path in node_files:
        label = os.path.basename(path)[len("ea_"):-len(".csv")]
        rows = [coerce_row(r) for r in read_rows(path)]
        print(f"{label}: {len(rows)} Zeilen aus {path}")
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
                        print(f"  WARNUNG: materialRef={record['missing_material_ref']!r} auf "
                              f"Part {record['part_id']} verweist auf kein bestehendes "
                              f":Material -- Kante nicht angelegt.", file=sys.stderr)
    return id_index


def load_relationships(driver, database, extract_dir, batch_size):
    rel_files = sorted(glob.glob(os.path.join(extract_dir, "ea_rel_*.csv")))
    for path in rel_files:
        rel_type = os.path.basename(path)[len("ea_rel_"):-len(".csv")]
        rows = read_rows(path)
        print(f":{rel_type}: {len(rows)} Zeilen aus {path}")
        query = REL_MERGE_QUERY_TEMPLATE.format(rel_type=rel_type)
        run_batches(driver, database, query, rows, batch_size, rel_type)


def ensure_constraints(driver, database):
    with driver.session(database=database) as session:
        for label, name in NEW_LABEL_CONSTRAINTS:
            session.run(
                f"CREATE CONSTRAINT {name} IF NOT EXISTS "
                f"FOR (n:{label}) REQUIRE n.id IS UNIQUE"
            ).consume()
    print(f"{len(NEW_LABEL_CONSTRAINTS)} Uniqueness-Constraints fuer neue Labels sichergestellt.")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--extract-dir", default="ea_extract", help="Verzeichnis mit ea_xmi_extract.py-Ausgabe")
    ap.add_argument("--database", default="neo4j")
    ap.add_argument("--batch-size", type=int, default=500)
    ap.add_argument("--skip-constraints", action="store_true")
    args = ap.parse_args()

    if not os.path.isdir(args.extract_dir):
        print(f"FEHLER: {args.extract_dir} existiert nicht -- erst ea_xmi_extract.py laufen lassen.", file=sys.stderr)
        sys.exit(1)

    driver = get_driver()
    driver.verify_connectivity()
    print("Verbindung zu Neo4j hergestellt.")

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
        print("\nKontrollzaehlung (nur EA-importierte Knoten, per sourceStereotype erkennbar):")
        for record in result:
            print(f"  {record['labels']} <- {record['stereotype']}: {record['n']}")

    driver.close()


if __name__ == "__main__":
    main()
