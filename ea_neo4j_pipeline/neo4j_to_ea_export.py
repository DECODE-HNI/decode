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

Diagramm (28.08.2026 ergaenzt, auf ausdruecklichen Wunsch -- "auch wenn das
etwas unuebersichtlich erscheint, brauchen wir auch einmal das ganze
Diagramm in EA"): erzeugt zusaetzlich zu den nackten Modellelementen ein
einziges Diagramm mit JEDEM Knoten und JEDER Kante, in einem einfachen
Zeilen-Raster je Stereotyp-Kategorie (Function/Logical Element/Process
Element/Product Element/System Requirement/...). Kein Anspruch auf huebsches
Layout -- Ausgangspunkt zum Weiterbearbeiten per EAs eigenem "Layout
Diagram". Das XML-Format des Diagramm-Blocks (<xmi:Extension>/<diagrams>,
DUID-basierte Element-zu-Kante-Verknuepfung) wurde Zeichen fuer Zeichen
gegen einen echten EA-Export (rflpv2_package.xml) verifiziert -- siehe
build_diagram_xml() fuer die Herleitung. NICHT verifiziert ist bisher, ob
der <diagrams>-Block *ohne* die begleitenden <elements>/<connectors>-
Bloecke, die EAs eigener Exporter zusaetzlich schreibt, beim Import genuegt;
einfache Elementerzeugung ganz ohne <xmi:Extension> funktioniert nachweislich
(rflpv2_merge_test.xml), das Diagramm ist der noch ungetestete Teil. Mit
--no-diagram abschaltbar, falls der Import ohne Diagramm sauberer laeuft.

Aufruf:
    pip install neo4j
    $env:NEO4J_URI = "bolt://localhost:7687"
    $env:NEO4J_USER = "neo4j"
    $env:NEO4J_PASSWORD = "..."
    python neo4j_to_ea_export.py --out rflpv2_from_neo4j.xml
"""

import argparse
import datetime
import os
import re
import sys
import zlib
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
    ("MATCH (a:Process)-[:APPLIES_TO]->(b:Part) "
     "RETURN a.id AS source_id, b.id AS target_id ORDER BY a.id, b.id", "Applies"),
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


# --- Diagramm-Layout: einfaches Zeilen-Raster je Stereotyp-Kategorie -------
# Box-Groesse (90x70) und Spaltenabstand sind exakt aus einem echten
# EA-Diagramm (rflpv2_package.xml, alle 15 Test-Elemente waren 90x70)
# uebernommen, nicht erfunden.
DIAGRAM_BOX_W, DIAGRAM_BOX_H = 90, 70
DIAGRAM_COL_GAP, DIAGRAM_ROW_GAP = 40, 40
DIAGRAM_COL_PITCH = DIAGRAM_BOX_W + DIAGRAM_COL_GAP
DIAGRAM_ROW_PITCH = DIAGRAM_BOX_H + DIAGRAM_ROW_GAP
DIAGRAM_COLS_PER_BAND = 22
DIAGRAM_BAND_GAP = 150

# Verbatim aus einem echten EA-XMI-2.1-Export kopierte Diagramm-Stil-Blobs
# (rflpv2_package.xml, Diagramm "Package1") -- opake, EA-interne
# Anzeigeeinstellungen ohne Bezug zu konkreten Elementen, deshalb unveraendert
# fuer jedes selbst erzeugte Diagramm wiederverwendbar.
_DIAGRAM_STYLE1 = (
    "ShowPrivate=1;ShowProtected=1;ShowPublic=1;HideRelationships=0;Locked=0;"
    "Border=1;HighlightForeign=1;PackageContents=1;SequenceNotes=0;"
    "ScalePrintImage=0;PPgs.cx=0;PPgs.cy=0;DocSize.cx=827;DocSize.cy=1169;"
    "ShowDetails=0;Orientation=P;Zoom=100;ShowTags=0;OpParams=1;"
    "VisibleAttributeDetail=0;ShowOpRetType=1;ShowIcons=1;CollabNums=0;"
    "HideProps=0;ShowReqs=0;ShowCons=0;PaperSize=9;HideParents=0;UseAlias=0;"
    "HideAtts=0;HideOps=0;HideStereo=0;HideElemStereo=0;ShowTests=0;"
    "ShowMaint=0;ConnectorNotation=UML 2.1;ExplicitNavigability=0;ShowShape=1;"
    "AllDockable=0;AdvancedElementProps=1;AdvancedFeatureProps=1;"
    "AdvancedConnectorProps=1;m_bElementClassifier=1;SPT=1;ShowNotes=0;"
    "SuppressBrackets=0;SuppConnectorLabels=0;PrintPageHeadFoot=0;ShowAsList=0;"
)
_DIAGRAM_STYLE2 = (
    "ExcludeRTF=0;DocAll=0;HideQuals=0;AttPkg=1;ShowTests=0;ShowMaint=0;"
    "SuppressFOC=1;MatrixActive=0;SwimlanesActive=1;KanbanActive=0;"
    "MatrixLineWidth=1;MatrixLineClr=0;MatrixLocked=0;TConnectorNotation=UML 2.1;"
    "TExplicitNavigability=0;AdvancedElementProps=1;AdvancedFeatureProps=1;"
    "AdvancedConnectorProps=1;m_bElementClassifier=1;SPT=1;"
    "MDGDgm=Document Templates::Document Templates;MDGView=Complete;STBLDgm=;"
    "ShowNotes=0;VisibleAttributeDetail=0;ShowOpRetType=1;SuppressBrackets=0;"
    "SuppConnectorLabels=0;PrintPageHeadFoot=0;ShowAsList=0;"
    "SuppressedCompartments=;Theme=:119;"
)
_DIAGRAM_SWIMLANE_FONT = (
    "SwimlaneFont=lfh:-13,lfw:0,lfi:0,lfu:0,lfs:0,lfface:Calibri,lfe:0,lfo:0,"
    "lfchar:1,lfop:0,lfcp:0,lfq:0,lfpf=0,lfWidth=0;"
)
_DIAGRAM_SWIMLANES = (
    "locked=false;orientation=0;width=0;inbar=false;names=false;color=-1;"
    "bold=false;fcol=0;tcol=-1;ofCol=-1;ufCol=-1;hl=1;ufh=0;hh=0;cls=0;bw=0;"
    "hli=0;bro=0;" + _DIAGRAM_SWIMLANE_FONT
)
_DIAGRAM_MATRIXITEMS = (
    "locked=false;matrixactive=false;swimlanesactive=true;kanbanactive=false;"
    "width=1;clrLine=0;"
)
_DIAGRAM_PERSISTENTSTYLE = (
    "DGS=On=0:CNT=8:W=120:H=40:SG=0:SGH=0:AEB=0:;AR=0;DCL=0;" + _DIAGRAM_SWIMLANES
    + ";Swimlanes=" + _DIAGRAM_SWIMLANES + ";"
)


def duid_for(business_key, used):
    """8-Hex-Zeichen 'Display Unit ID', wie EA sie diagrammintern vergibt, um
    Kanten mit ihren beiden Endpunkt-Shapes zu verknuepfen (siehe style=
    "DUID=..." auf Shapes bzw. "EOID=...;SOID=..." auf Kanten in
    rflpv2_package.xml). Muss nur innerhalb des Diagramms eindeutig sein,
    nicht mit der echten xmi:id uebereinstimmen -- deterministisch aus dem
    Business-Key abgeleitet (CRC32), mit Kollisions-Fallback."""
    base = zlib.crc32(business_key.encode("utf-8")) & 0xFFFFFFFF
    bump = 0
    while True:
        candidate = f"{(base + bump) & 0xFFFFFFFF:08X}"
        if candidate not in used:
            used.add(candidate)
            return candidate
        bump += 1


def _diagram_connector_xml(connector_xid, source_duid, target_duid):
    if source_duid is None or target_duid is None:
        return ""  # Endpunkt nicht auf dem Diagramm platziert -- sollte nicht vorkommen
    return (
        '\t\t\t\t\t<element geometry="SX=0;SY=0;EX=0;EY=0;EDGE=4;$LLB=;LLT=;LMT=;'
        'LMB=;LRT=;LRB=;IRHS=;ILHS=;Path=;" '
        f'subject="{connector_xid}" '
        f'style="Mode=3;EOID={target_duid};SOID={source_duid};Color=-1;LWidth=0;Hidden=0;"/>\n'
    )


# Sieben Diagramme statt einem (28.08.2026, auf Wunsch): ein
# Requirements-Diagramm plus sechs BDD-Diagramme, je eins pro
# NODE_SPECS-Kategorie (aufgeteilt nach Sparx-Skizze -- Req./Fun./Log./
# Prod./Proc./TestC./TestScr., durch Relationstabellen statt In-Diagramm-
# Kanten verbunden, siehe README). "neo4j_labels" waehlt, welche
# NODE_SPECS-Eintraege (in Emission-Reihenfolge, je ein eigenes Band) auf
# diesem Diagramm landen; "internal_composition" schaltet fuer das Product-
# Element-Diagramm die HAS_COMPONENT-Kompositionskanten dazu (die einzigen
# Kanten in diesem Datenmodell, die vollstaendig INNERHALB einer Kategorie
# liegen -- alle Dependencies wie Realizes/Satisfies sind kategorieuebergreifend
# und werden deshalb bewusst NICHT auf eines dieser Diagramme gezeichnet,
# siehe ea_to_neo4j_mapping.md).
DIAGRAM_SPECS = [
    ("EAID_DIAGRAM_REQUIREMENTS", "Requirements", ["Requirement"], False),
    ("EAID_DIAGRAM_FUNCTIONS", "Functions (BDD)", ["Function"], False),
    ("EAID_DIAGRAM_LOGICAL", "Logical Elements (BDD)", ["SolutionPrinciple"], False),
    ("EAID_DIAGRAM_PRODUCT", "Product Structure (BDD)", ["Artifact", "Assembly", "Part"], True),
    ("EAID_DIAGRAM_PROCESSES", "Processes (BDD)", ["Process"], False),
    ("EAID_DIAGRAM_TESTCASES", "Test Cases (BDD)", ["TestCase"], False),
    ("EAID_DIAGRAM_TESTSCENARIOS", "Test Scenarios (BDD)", ["TestScenario"], False),
]


def _one_diagram_xml(xmi_id, name, node_rows_by_label, parent_of, internal_composition):
    """Elemente + (fuer das Product-Element-Diagramm) Kompositionskanten fuer
    EIN Diagramm. node_rows_by_label: [(neo4j_label, rows)], je ein Band."""
    used_duids = set()
    duid_by_id = {}
    shape_elements = []
    y = 40
    seqno = 0

    for _label, rows in node_rows_by_label:
        if not rows:
            continue
        for i, row in enumerate(rows):
            bid = row["id"]
            col = i % DIAGRAM_COLS_PER_BAND
            r = i // DIAGRAM_COLS_PER_BAND
            x = 40 + col * DIAGRAM_COL_PITCH
            top = y + r * DIAGRAM_ROW_PITCH
            duid = duid_for(bid, used_duids)
            duid_by_id[bid] = duid
            seqno += 1
            shape_elements.append(
                f'\t\t\t\t\t<element geometry="Left={x};Top={top};Right={x + DIAGRAM_BOX_W};'
                f'Bottom={top + DIAGRAM_BOX_H};" subject="{eaid_for(bid)}" seqno="{seqno}" '
                f'style="DUID={duid};HideIcon=0;"/>\n'
            )
        rows_in_band = -(-len(rows) // DIAGRAM_COLS_PER_BAND)  # ceil
        y += rows_in_band * DIAGRAM_ROW_PITCH + DIAGRAM_BAND_GAP

    connector_elements = []
    if internal_composition:
        placed = set(duid_by_id.keys())
        for child_id, parent_id in parent_of.items():
            if child_id not in placed or parent_id not in placed:
                continue  # Elternteil/Kind nicht auf diesem Diagramm -- ueberspringen
            aid = assoc_id(parent_id, child_id)
            connector_elements.append(
                _diagram_connector_xml(aid, duid_by_id.get(child_id), duid_by_id.get(parent_id))
            )

    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    return (
        f'\t\t\t<diagram xmi:id="{xmi_id}">\n'
        '\t\t\t\t<model package="EAPK_NEO4J_IMPORT" localID="1" owner="EAPK_NEO4J_IMPORT"/>\n'
        f'\t\t\t\t<properties name={quoteattr(name)} type="Logical"/>\n'
        f'\t\t\t\t<project author="neo4j_to_ea_export" version="1.0" created="{now}" modified="{now}"/>\n'
        f'\t\t\t\t<style1 value="{_DIAGRAM_STYLE1}"/>\n'
        f'\t\t\t\t<style2 value="{_DIAGRAM_STYLE2}"/>\n'
        f'\t\t\t\t<swimlanes value="{_DIAGRAM_SWIMLANES}"/>\n'
        f'\t\t\t\t<matrixitems value="{_DIAGRAM_MATRIXITEMS}"/>\n'
        '\t\t\t\t<extendedProperties/>\n'
        f'\t\t\t\t<persistentstyle value="{_DIAGRAM_PERSISTENTSTYLE}"/>\n'
        '\t\t\t\t<xrefs/>\n'
        '\t\t\t\t<elements>\n'
        + "".join(shape_elements) + "".join(connector_elements) +
        '\t\t\t\t</elements>\n'
        '\t\t\t</diagram>\n'
    )


def build_diagram_xml(nodes_by_spec, parent_of, deps):
    """Baut den <xmi:Extension>/<diagrams>-Block mit den 7 Diagrammen aus
    DIAGRAM_SPECS (siehe dort). Jedes Diagramm bekommt sein eigenes,
    unabhaengiges Zeilen-Raster-Layout (Baender je NODE_SPECS-Kategorie
    innerhalb des Diagramms, z.B. Artifact/Assembly/Part als 3 Baender im
    Product-Element-Diagramm). Kein Anspruch auf ein huebsches Layout, nur
    ein reproduzierbarer Ausgangspunkt (in EA per "Layout Diagram"
    weiter verfeinerbar).

    `deps` wird entgegengenommen, aber bewusst NICHT auf eines der 7
    Diagramme gezeichnet -- alle Dependency-Beziehungen in diesem
    Datenmodell verbinden zwei verschiedene Kategorien (z.B. Realizes:
    Logical Element -> Function), koennen also auf keinem der strikt
    einkategorigen Diagramme ueberhaupt beide Endpunkte haben. Die Kanten
    existieren weiterhin vollstaendig im Modell (ueber build_xmi()) und sind
    in EA jederzeit ueber die Relationships eines Elements oder eine
    Relationship-Matrix sichtbar -- nur eben nicht als Linie auf einem
    dieser Diagramme.

    Kanten-Richtung fuer die (einzige gezeichnete) Kantenart, Komposition:
    SOID=Kind (das Ende mit aggregation="composite"), EOID=Elternteil --
    dieselbe Regel wie bei den ownedEnd/ownedAttribute-Enden in build_xmi(),
    empirisch an rflpv2_package.xml verifiziert (dortige Komposition
    Block5->Block6->Block7: <connectors>-Quelle war jeweils das Kind)."""
    rows_by_label = {spec["neo4j_label"]: rows for spec, rows in zip(NODE_SPECS, nodes_by_spec)}

    diagram_blocks = []
    for xmi_id, name, labels, internal_composition in DIAGRAM_SPECS:
        node_rows_by_label = [(label, rows_by_label.get(label, [])) for label in labels]
        diagram_blocks.append(
            _one_diagram_xml(xmi_id, name, node_rows_by_label, parent_of, internal_composition)
        )

    return (
        '\t<xmi:Extension extender="Enterprise Architect" extenderID="6.5">\n'
        '\t\t<diagrams>\n'
        + "".join(diagram_blocks) +
        '\t\t</diagrams>\n'
        '\t</xmi:Extension>\n'
    )


def build_xmi(nodes_by_spec, parent_of, material_ref, deps, with_diagram=True):
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
    diagram_xml = build_diagram_xml(nodes_by_spec, parent_of, deps) if with_diagram else ""

    footer = (
        "\t\t</packagedElement>\n"
        + "".join(stereo_lines)
        + "\t</uml:Model>\n"
        + diagram_xml
        + "</xmi:XMI>\n"
    )

    body = "".join(class_lines) + "".join(assoc_lines) + "".join(dep_lines)
    return header + body + footer


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="rflpv2_from_neo4j.xml", help="Ausgabedatei (XMI 2.1)")
    ap.add_argument("--database", default="neo4j")
    ap.add_argument("--no-diagram", action="store_true",
                     help="Kein EA-Diagramm erzeugen, nur die nackten Modellelemente "
                          "(z.B. falls der Import mit Diagramm-Block Probleme macht)")
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

    xmi = build_xmi(nodes_by_spec, parent_of, material_ref, deps, with_diagram=not args.no_diagram)
    with open(args.out, "w", encoding="cp1252", errors="xmlcharrefreplace") as f:
        f.write(xmi)

    total_nodes = sum(len(rows) for rows in nodes_by_spec)
    total_deps = sum(len(pairs) for _, pairs in deps)
    print(f"\nFertig: {args.out}")
    print(f"  {total_nodes} Knoten, {len(parent_of)} Kompositionskanten, {total_deps} Beziehungen")
    if not args.no_diagram:
        print(f"  + {len(DIAGRAM_SPECS)} Diagramme (Requirements, Functions, Logical Elements, "
              f"Product Structure inkl. Kompositionskanten, Processes, Test Cases, Test Scenarios) "
              f"(--no-diagram zum Abschalten)")


if __name__ == "__main__":
    main()
