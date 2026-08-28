"""
neo4j_to_ea_export.py

Dritte Komponente der EA <-> Neo4j Pipeline (siehe ea_to_neo4j_mapping.md,
Abschnitt 7 -- "Ruecklauf: Neo4j -> EA"). Liest den AKTUELLEN Stand des
bestehenden Neo4j-Wissensgraphen rein lesend aus und erzeugt daraus eine
XMI-2.1-Datei im selben Dialekt, den ea_xmi_extract.py einliest und der gegen
den echten EA-Export rflpv2_package.xml verifiziert wurde. Die Datei ist zum
Import in EA gedacht ueber Project > Model Exchange > Import Package from XMI.

Richtung: Neo4j -> EA (Bootstrap/Spiegelung des Ist-Zustands). Das ist NICHT
die Umkehrung von ea_to_neo4j_load.py -- es wird nichts in Neo4j veraendert.

Zugangsdaten NUR ueber Umgebungsvariablen (nie als Skript-Argument, nie
hartkodiert), wie bei den anderen Skripten dieser Pipeline:
    NEO4J_URI       z.B. bolt://localhost:7687
    NEO4J_USER      z.B. neo4j
    NEO4J_PASSWORD

WICHTIG -- vor dem Import in EA lesen:
- EAs XMI-Import matched Elemente nur ueber ihre GUID (xmi:id), nicht ueber
  Business-Keys/Namen. Dieses Skript vergibt deterministische IDs
  ("EAID_<BusinessKey>"), die bei erneutem Lauf stabil bleiben. Euer
  bestehendes rflpv2.qea-Projekt hat aber FUNC_GRASP, SP_PARALLEL,
  ART_CUSTOM/ASSY_CUSTOM/PART_CUSTOM_CONTACT, REQ_COMPAT bereits von Hand
  angelegt, mit eigenen, ZUFAELLIGEN GUIDs. Ein Import dieser Datei in
  DASSELBE Projekt legt fuer diese Elemente DUPLIKATE an statt sie zu mergen.
  Empfehlung: Import in ein NEUES, leeres EA-Projekt (mit importiertem
  RFLPV2-Profil), um den echten Ist-Zustand des Graphen sauber zu spiegeln.
  rflpv2.qea bleibt euer separates Hand-Testprojekt.
- Umfang (28.08.2026 im Chat entschieden): voller Graph, keine Filterung.
- Requirement-Level: alle bestehenden :Requirement-Knoten werden als
  System Requirement exportiert -- strukturell begruendet, nicht geraten:
  alle 24 haben eine SPECIFIED_BY-Kante zu einer quantifizierten/technischen
  Specification (valueNumber+unit+toleranceMin/Max bzw. "engineering
  target/criterion"-Rollentext), das ist die Signatur bereits formalisierter,
  abgeleiteter Requirements -- nicht die von rohen, unformalisierten
  Kundenwuenschen (:CustomerNeed gibt es im Bestand ohnehin noch nicht,
  0 Knoten). Siehe ea_to_neo4j_mapping.md Abschnitt 7 fuer die Herleitung.
- Bekannte, bewusste Luecken (Neo4j-Properties ohne Tag im RFLPV2-Profil,
  werden NICHT exportiert, gehen also beim Roundtrip nicht "verloren" im
  Sinne von geloescht -- sie bleiben in Neo4j, tauchen nur in EA nicht auf):
  Function.input/output/constraintText, SolutionPrinciple.physicalPrinciple/
  status, Process.technology/geographicalLocation/dataAcquisition/status/
  source/sourceDatabase/referenceYear, Artifact/Assembly/Part.variant(Family)/
  manufacturer/mass_g/opening_mm/tcp_mm/evidenceLevel/validationRequired/
  description/status, Requirement.requirementType/statement/priority/status
  (priority ist in Neo4j ein String-Enum "must"/"should", das Profil-Tag
  requirementPriority ist aber vom Typ Real -- keine verlustfreie 1:1-
  Umwandlung ohne erfundene Skala, deshalb bewusst leer gelassen statt
  geraten). Freitext (z.B. Requirement.statement) hat aktuell KEIN
  verifiziertes Ziel im XMI-Dialekt (EA-Notes-Encoding beim Schreiben wurde
  in dieser Pipeline noch nie empirisch geprueft) -- absichtlich ausgelassen
  statt einer ungetesteten XML-Struktur geraten.

Aufruf:
    pip install neo4j
    $env:NEO4J_URI = "bolt://localhost:7687"
    $env:NEO4J_USER = "neo4j"
    $env:NEO4J_PASSWORD = "..."
    python neo4j_to_ea_export.py --out rflpv2_from_neo4j.xml
"""

import argparse
import os
import re
import sys
from xml.sax.saxutils import quoteattr

NAMESPACE_PREFIX = "RFLPV2_Sustainability_Process_Extension"
NAMESPACE_URI = f"http://www.sparxsystems.com/profiles/{NAMESPACE_PREFIX}/1.0"

# Neo4j-Label -> Export-Spezifikation. "query" liefert je Zeile mindestens
# id/name; alles unter "tag" ist ein zusaetzliches Tagged-Value-Attribut auf
# der Stereotyp-Anwendung (EA-Tag-Name -> Cypher-Alias in derselben Zeile).
NODE_SPECS = [
    {
        "neo4j_label": "Function",
        "stereotype": "Function",
        "id_tag": "functionID",
        "query": "MATCH (n:Function) RETURN n.id AS id, n.name AS name, "
                 "n.functionType AS functionType ORDER BY n.id",
        "tags": ["functionType"],
    },
    {
        "neo4j_label": "SolutionPrinciple",
        "stereotype": "Logical Element",
        "id_tag": "logicalID",
        "query": "MATCH (n:SolutionPrinciple) RETURN n.id AS id, n.name AS name, "
                 "n.solutionType AS logicalType ORDER BY n.id",
        "tags": ["logicalType"],
    },
    {
        "neo4j_label": "Process",
        "stereotype": "Process Element",
        "id_tag": "processID",
        "query": "MATCH (n:Process) RETURN n.id AS id, n.name AS name, "
                 "n.processType AS processType ORDER BY n.id",
        "tags": ["processType"],
    },
    {
        "neo4j_label": "Artifact",
        "stereotype": "Product Element",
        "id_tag": "productID",
        "query": "MATCH (n:Artifact) RETURN n.id AS id, n.name AS name, "
                 "n.artifactType AS productType ORDER BY n.id",
        "tags": ["productType"],
    },
    {
        "neo4j_label": "Assembly",
        "stereotype": "Product Element",
        "id_tag": "productID",
        "query": "MATCH (n:Assembly) RETURN n.id AS id, n.name AS name, "
                 "n.assemblyType AS productType ORDER BY n.id",
        "tags": ["productType"],
    },
    {
        "neo4j_label": "Part",
        "stereotype": "Product Element",
        "id_tag": "productID",
        "query": "MATCH (n:Part) RETURN n.id AS id, n.name AS name, "
                 "n.partType AS productType ORDER BY n.id",
        "tags": ["productType"],  # materialRef wird separat ergaenzt, siehe load_materials()
    },
    {
        "neo4j_label": "Requirement",
        "stereotype": "System Requirement",
        "id_tag": "systemRequirementID",
        "query": "MATCH (n:Requirement) RETURN n.id AS id, n.name AS name ORDER BY n.id",
        "tags": [],
    },
    # Neue Labels -- aktuell 0 Knoten im Bestand (nur ueber EA neu angelegt),
    # hier vorbereitet, damit kuenftige Daten ohne Skriptaenderung mitlaufen.
    {
        "neo4j_label": "CustomerNeed",
        "stereotype": "Customer Need",
        "id_tag": "needID",
        "query": "MATCH (n:CustomerNeed) RETURN n.id AS id, n.name AS name ORDER BY n.id",
        "tags": [],
    },
    {
        "neo4j_label": "TestCase",
        "stereotype": "Test Case",
        "id_tag": "testCaseID",
        "query": "MATCH (n:TestCase) RETURN n.id AS id, n.name AS name ORDER BY n.id",
        "tags": [],
    },
    {
        "neo4j_label": "TestCaseDescription",
        "stereotype": "Test Case Description",
        "id_tag": "testCaseDescriptionID",
        "query": "MATCH (n:TestCaseDescription) RETURN n.id AS id, n.name AS name ORDER BY n.id",
        "tags": [],
    },
    {
        "neo4j_label": "TestScenario",
        "stereotype": "Test Scenario",
        "id_tag": "testScenarioID",
        "query": "MATCH (n:TestScenario) RETURN n.id AS id, n.name AS name ORDER BY n.id",
        "tags": [],
    },
    {
        "neo4j_label": "Validation",
        "stereotype": "Validation",
        "id_tag": "validationID",
        "query": "MATCH (n:Validation) RETURN n.id AS id, n.name AS name ORDER BY n.id",
        "tags": [],
    },
    {
        "neo4j_label": "Verification",
        "stereotype": "Verification",
        "id_tag": "verificationID",
        "query": "MATCH (n:Verification) RETURN n.id AS id, n.name AS name ORDER BY n.id",
        "tags": [],
    },
]

# (Cypher fuer Source->Target, EA-Dependency-Stereotyp)
DEPENDENCY_SPECS = [
    ("MATCH (a:SolutionPrinciple)-[:REALIZES_FUNCTION]->(b:Function) "
     "RETURN a.id AS source_id, b.id AS target_id ORDER BY a.id, b.id", "Realizes"),
    ("MATCH (a:Artifact)-[:REALIZES_PRINCIPLE]->(b:SolutionPrinciple) "
     "RETURN a.id AS source_id, b.id AS target_id ORDER BY a.id, b.id", "Realizes"),
    ("MATCH (a:Artifact)-[:SATISFIES_REQUIREMENT]->(b:Requirement) "
     "RETURN a.id AS source_id, b.id AS target_id ORDER BY a.id, b.id", "Satisfies"),
]

COMPOSITION_QUERIES = [
    "MATCH (p:Artifact)-[:HAS_COMPONENT]->(c:Assembly) "
    "RETURN p.id AS parent_id, c.id AS child_id ORDER BY p.id, c.id",
    "MATCH (p:Assembly)-[:HAS_COMPONENT]->(c:Part) "
    "RETURN p.id AS parent_id, c.id AS child_id ORDER BY p.id, c.id",
]

MATERIAL_QUERY = (
    "MATCH (p:Part)-[:USES_MATERIAL]->(m:Material) "
    "RETURN p.id AS part_id, m.id AS material_id ORDER BY p.id"
)


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


def sanitize_id(business_key):
    return re.sub(r"[^A-Za-z0-9_]", "_", business_key)


def eaid_for(business_key):
    return f"EAID_{sanitize_id(business_key)}"


def assoc_id(parent_key, child_key):
    return f"EAID_ASSOC_{sanitize_id(parent_key)}_{sanitize_id(child_key)}"


def dep_id(stereotype, source_key, target_key):
    return f"EAID_DEP_{stereotype.upper()}_{sanitize_id(source_key)}_{sanitize_id(target_key)}"


def attr(name, value):
    """Liefert ' name="wert"' oder '' bei leerem Wert -- nur nicht-leere
    Tagged Values erscheinen als Attribute, analog zum echten EA-Export."""
    if value is None or value == "":
        return ""
    return f' {name}={quoteattr(str(value))}'


def stereotype_app_xml(stereotype_name, base_attr_name, base_id, tag_attrs):
    tag_name = stereotype_name.replace(" ", "_")
    line = f'\t\t<{NAMESPACE_PREFIX}:{tag_name} {base_attr_name}="{base_id}"'
    if " " in stereotype_name:
        line += f' __EAStereoName={quoteattr(stereotype_name)}'
    for k, v in tag_attrs.items():
        line += attr(k, v)
    line += "/>\n"
    return line


def fetch_nodes(session):
    """Liest alle Knoten je NODE_SPECS-Eintrag. Rueckgabe:
    nodes_by_spec[i] = [ {id, name, ...tags} ], business_id_set (fuer Duplikat-Check)."""
    nodes_by_spec = []
    seen_ids = {}
    for spec in NODE_SPECS:
        rows = list(session.run(spec["query"]))
        parsed = []
        for r in rows:
            bid = r["id"]
            if bid in seen_ids and seen_ids[bid] != spec["neo4j_label"]:
                print(f"WARNUNG: Business-Key {bid!r} taucht sowohl unter "
                      f"{seen_ids[bid]} als auch {spec['neo4j_label']} auf -- "
                      f"Kollision, zweites Vorkommen wird trotzdem exportiert.",
                      file=sys.stderr)
            seen_ids[bid] = spec["neo4j_label"]
            parsed.append(dict(r))
        nodes_by_spec.append(parsed)
        print(f"  {spec['neo4j_label']}: {len(parsed)} Knoten")
    return nodes_by_spec


def fetch_composition(session):
    edges = []
    for q in COMPOSITION_QUERIES:
        edges.extend((r["parent_id"], r["child_id"]) for r in session.run(q))
    # Baum-Annahme pruefen: jedes Kind sollte genau einen Elternteil haben.
    parent_of = {}
    for parent_id, child_id in edges:
        if child_id in parent_of and parent_of[child_id] != parent_id:
            print(f"WARNUNG: {child_id!r} hat mehr als einen Komposition-Elternteil "
                  f"({parent_of[child_id]!r} und {parent_id!r}) -- nur der erste wird "
                  f"als Komposition exportiert, keine Baum-Annahme mehr erfuellt.",
                  file=sys.stderr)
            continue
        parent_of[child_id] = parent_id
    print(f"  Komposition (HAS_COMPONENT): {len(parent_of)} Eltern-Kind-Kanten")
    return parent_of


def fetch_materials(session):
    rows = list(session.run(MATERIAL_QUERY))
    by_part = {}
    for r in rows:
        by_part.setdefault(r["part_id"], []).append(r["material_id"])
    material_ref = {}
    for part_id, mats in by_part.items():
        if len(mats) > 1:
            print(f"WARNUNG: Part {part_id!r} hat {len(mats)} USES_MATERIAL-Kanten "
                  f"({mats}) -- Datenqualitaetsproblem (ein Part sollte genau ein "
                  f"Material haben), materialRef wird NICHT gesetzt statt zu raten.",
                  file=sys.stderr)
            continue
        material_ref[part_id] = mats[0]
    print(f"  USES_MATERIAL: {len(material_ref)} Parts mit eindeutigem Material")
    return material_ref


def fetch_dependencies(session):
    deps = []
    for query, stereotype in DEPENDENCY_SPECS:
        rows = list(session.run(query))
        deps.append((stereotype, [(r["source_id"], r["target_id"]) for r in rows]))
        print(f"  {stereotype} ({query.split('[:')[1].split(']')[0]}): {len(rows)} Kanten")
    return deps


def build_xmi(nodes_by_spec, parent_of, material_ref, deps):
    child_ids = set(parent_of.keys())

    class_lines = []
    stereo_lines = []

    for spec, rows in zip(NODE_SPECS, nodes_by_spec):
        for row in rows:
            bid = row["id"]
            xid = eaid_for(bid)
            name = row.get("name") or bid

            extra = ""
            if bid in child_ids:
                parent_id = parent_of[bid]
                aid = assoc_id(parent_id, bid)
                extra = (
                    f'\t\t\t\t<ownedAttribute xmi:type="uml:Property" xmi:id="{aid}_DST" '
                    f'visibility="public" association="{aid}" isStatic="false" '
                    f'isReadOnly="false" isDerived="false" isOrdered="false" '
                    f'isUnique="true" isDerivedUnion="false" aggregation="none">\n'
                    f'\t\t\t\t\t<type xmi:idref="{eaid_for(parent_id)}"/>\n'
                    f'\t\t\t\t</ownedAttribute>\n'
                )

            if extra:
                class_lines.append(
                    f'\t\t\t<packagedElement xmi:type="uml:Class" xmi:id="{xid}" '
                    f'name={quoteattr(name)} visibility="public">\n{extra}\t\t\t</packagedElement>\n'
                )
            else:
                class_lines.append(
                    f'\t\t\t<packagedElement xmi:type="uml:Class" xmi:id="{xid}" '
                    f'name={quoteattr(name)} visibility="public"/>\n'
                )

            tag_attrs = {spec["id_tag"]: bid}
            for tag_name in spec["tags"]:
                tag_attrs[tag_name] = row.get(tag_name)
            if spec["neo4j_label"] == "Part" and bid in material_ref:
                tag_attrs["materialRef"] = material_ref[bid]

            stereo_lines.append(
                stereotype_app_xml(spec["stereotype"], "base_Class", xid, tag_attrs)
            )

    assoc_lines = []
    for child_id, parent_id in parent_of.items():
        aid = assoc_id(parent_id, child_id)
        assoc_lines.append(
            f'\t\t\t<packagedElement xmi:type="uml:Association" xmi:id="{aid}" visibility="public">\n'
            f'\t\t\t\t<memberEnd xmi:idref="{aid}_DST"/>\n'
            f'\t\t\t\t<memberEnd xmi:idref="{aid}_SRC"/>\n'
            f'\t\t\t\t<ownedEnd xmi:type="uml:Property" xmi:id="{aid}_SRC" visibility="public" '
            f'association="{aid}" isStatic="false" isReadOnly="false" isDerived="false" '
            f'isOrdered="false" isUnique="true" isDerivedUnion="false" aggregation="composite">\n'
            f'\t\t\t\t\t<type xmi:idref="{eaid_for(child_id)}"/>\n'
            f'\t\t\t\t</ownedEnd>\n'
            f'\t\t\t</packagedElement>\n'
        )

    dep_lines = []
    for stereotype, pairs in deps:
        for source_id, target_id in pairs:
            did = dep_id(stereotype, source_id, target_id)
            dep_lines.append(
                f'\t\t\t<packagedElement xmi:type="uml:Dependency" xmi:id="{did}" '
                f'visibility="public" client="{eaid_for(source_id)}" '
                f'supplier="{eaid_for(target_id)}"/>\n'
            )
            stereo_lines.append(stereotype_app_xml(stereotype, "base_Dependency", did, {}))

    header = (
        "<?xml  version='1.0' encoding='windows-1252' ?>\n"
        '<xmi:XMI xmlns:xmi="http://schema.omg.org/spec/XMI/2.1" xmi:version="2.1" '
        'xmlns:uml="http://schema.omg.org/spec/UML/2.1" '
        f'xmlns:{NAMESPACE_PREFIX}="{NAMESPACE_URI}">\n'
        '\t<xmi:Documentation exporter="Enterprise Architect" exporterVersion="6.5" exporterID="1721"/>\n'
        '\t<uml:Model xmi:type="uml:Model" name="EA_Model" visibility="public">\n'
        '\t\t<packagedElement xmi:type="uml:Package" xmi:id="EAPK_NEO4J_IMPORT" '
        'name="Neo4jImport" visibility="public">\n'
    )
    footer = (
        "\t\t</packagedElement>\n"
        + "".join(stereo_lines)
        + "\t</uml:Model>\n"
        "</xmi:XMI>\n"
    )

    body = "".join(class_lines) + "".join(assoc_lines) + "".join(dep_lines)
    return header + body + footer


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="rflpv2_from_neo4j.xml", help="Ausgabedatei (XMI 2.1)")
    ap.add_argument("--database", default="neo4j")
    args = ap.parse_args()

    driver = get_driver()
    driver.verify_connectivity()
    print("Verbindung zu Neo4j hergestellt.\n")

    with driver.session(database=args.database) as session:
        print("Lese Knoten:")
        nodes_by_spec = fetch_nodes(session)
        print("\nLese Komposition/Material/Beziehungen:")
        parent_of = fetch_composition(session)
        material_ref = fetch_materials(session)
        deps = fetch_dependencies(session)

    driver.close()

    xmi = build_xmi(nodes_by_spec, parent_of, material_ref, deps)
    with open(args.out, "w", encoding="cp1252", errors="xmlcharrefreplace") as f:
        f.write(xmi)

    total_nodes = sum(len(rows) for rows in nodes_by_spec)
    total_deps = sum(len(pairs) for _, pairs in deps)
    print(f"\nFertig: {args.out}")
    print(f"  {total_nodes} Knoten, {len(parent_of)} Kompositionskanten, {total_deps} Beziehungen")


if __name__ == "__main__":
    main()
