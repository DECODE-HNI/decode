"""
neo4j_to_ea_export.py

Third component of the EA <-> Neo4j pipeline (see ea_to_neo4j_mapping.md,
section 7 -- "Return path: Neo4j -> EA"). Reads the CURRENT state of the
existing Neo4j knowledge graph (read-only) and generates an XMI 2.1 file from it
in the same dialect that ea_xmi_extract.py reads and that was verified against
the real EA export rflpv2_package.xml. The file is meant to be imported into EA
via Project > Model Exchange > Import Package from XMI.

Direction: Neo4j -> EA (bootstrap/mirroring of the current state). This is NOT
the inverse of ea_to_neo4j_load.py -- nothing in Neo4j is changed.

Credentials ONLY via environment variables (never as a script argument, never
hard-coded), as with the other scripts of this pipeline:
    NEO4J_URI       e.g. bolt://localhost:7687
    NEO4J_USER      e.g. neo4j
    NEO4J_PASSWORD

IMPORTANT -- read before importing into EA:
- EA's XMI import matches elements only via their GUID (xmi:id), not via
  business keys/names. This script assigns deterministic IDs
  ("EAID_<BusinessKey>") that stay stable on re-runs. An existing hand-built
  EA project, however, contains elements such as FUNC_GRASP, SP_PARALLEL,
  ART_CUSTOM/ASSY_CUSTOM/PART_CUSTOM_CONTACT, REQ_COMPAT created by hand with
  their own, RANDOM GUIDs. Importing this file into the SAME project creates
  DUPLICATES for those elements instead of merging them.
  Recommendation: import into a NEW, empty EA project (with the imported
  RFLPV2 profile) to mirror the graph's actual current state cleanly.
  The reference project rflpv2.qea remains a separate hand-built test project.
- Scope (decided 2026-08-28): full graph, no filtering.
- Requirement level: all existing :Requirement nodes are exported as
  System Requirement -- structurally justified, not guessed:
  all 24 have a SPECIFIED_BY edge to a quantified/technical
  Specification (valueNumber+unit+toleranceMin/Max or an "engineering
  target/criterion" role text), which is the signature of already formalised,
  derived requirements -- not of raw, unformalised
  customer wishes (:CustomerNeed does not exist in the data yet,
  0 nodes). See ea_to_neo4j_mapping.md section 7 for the derivation.
- Known, deliberate gaps (Neo4j properties without a tag in the RFLPV2 profile,
  NOT exported, so they are not "lost" on a round trip in the sense of
  deleted -- they stay in Neo4j, they just do not show up in EA):
  Function.input/output/constraintText, SolutionPrinciple.physicalPrinciple/
  status, Process.technology/geographicalLocation/dataAcquisition/status/
  source/sourceDatabase/referenceYear, Artifact/Assembly/Part.variant(Family)/
  manufacturer/mass_g/opening_mm/tcp_mm/evidenceLevel/validationRequired/
  description/status, Requirement.requirementType/statement/priority/status
  (priority is a string enum "must"/"should" in Neo4j, but the profile tag
  requirementPriority is of type Real -- no lossless 1:1
  conversion without an invented scale, hence deliberately left empty instead of
  guessed). Free text (e.g. Requirement.statement) currently has NO
  verified target in the XMI dialect (EA's notes encoding on write
  has never been checked empirically in this pipeline) -- deliberately omitted
  rather than guessing an untested XML structure.

Diagram (added 2026-08-28 on explicit request -- even if it looks somewhat
cluttered, the whole graph is wanted on a diagram in EA at least once):
in addition to the bare model elements this generates a
single diagram with EVERY node and EVERY edge, in a simple
row grid per stereotype category (Function/Logical Element/Process
Element/Product Element/System Requirement/...). No claim to a pretty
layout -- a starting point for further work with EA's own "Layout
Diagram". The XML format of the diagram block (<xmi:Extension>/<diagrams>,
DUID-based element-to-edge linking) was verified character by character
against a real EA export (rflpv2_package.xml) -- see
build_diagram_xml() for the derivation. NOT yet verified is whether
the <diagrams> block *without* the accompanying <elements>/<connectors>
blocks that EA's own exporter additionally writes suffices on import;
plain element creation without any <xmi:Extension> demonstrably works
(rflpv2_merge_test.xml), the diagram is the still untested part. Can be
switched off with --no-diagram if the import runs cleaner without a diagram.

Usage:
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

# Neo4j label -> export specification. "query" returns at least id/name per row;
# everything under "tag" is an additional tagged-value attribute on
# the stereotype application (EA tag name -> Cypher alias in the same row).
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
        "tags": ["productType"],  # materialRef is added separately, see load_materials()
    },
    {
        "neo4j_label": "Requirement",
        "stereotype": "System Requirement",
        "id_tag": "systemRequirementID",
        "query": "MATCH (n:Requirement) RETURN n.id AS id, n.name AS name ORDER BY n.id",
        "tags": [],
    },
    # New labels -- currently 0 nodes in the data (only created via EA),
    # prepared here so that future data flows through without script changes.
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
        print(f"Missing environment variables: {', '.join(missing)}", file=sys.stderr)
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
    """Returns ' name="value"' or '' for an empty value -- only non-empty
    tagged values appear as attributes, analogous to the real EA export."""
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
    """Reads all nodes per NODE_SPECS entry. Returns:
    nodes_by_spec[i] = [ {id, name, ...tags} ], business_id_set (for the duplicate check)."""
    nodes_by_spec = []
    seen_ids = {}
    for spec in NODE_SPECS:
        rows = list(session.run(spec["query"]))
        parsed = []
        for r in rows:
            bid = r["id"]
            if bid in seen_ids and seen_ids[bid] != spec["neo4j_label"]:
                print(f"WARNING: business key {bid!r} appears under both "
                      f"{seen_ids[bid]} and {spec['neo4j_label']} -- "
                      f"collision, second occurrence is exported anyway.",
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
    # Check the tree assumption: every child should have exactly one parent.
    parent_of = {}
    for parent_id, child_id in edges:
        if child_id in parent_of and parent_of[child_id] != parent_id:
            print(f"WARNING: {child_id!r} has more than one composition parent "
                  f"({parent_of[child_id]!r} and {parent_id!r}) -- only the first is "
                  f"exported as composition, the tree assumption no longer holds.",
                  file=sys.stderr)
            continue
        parent_of[child_id] = parent_id
    print(f"  Composition (HAS_COMPONENT): {len(parent_of)} parent-child edges")
    return parent_of


def fetch_materials(session):
    rows = list(session.run(MATERIAL_QUERY))
    by_part = {}
    for r in rows:
        by_part.setdefault(r["part_id"], []).append(r["material_id"])
    material_ref = {}
    for part_id, mats in by_part.items():
        if len(mats) > 1:
            print(f"WARNING: part {part_id!r} has {len(mats)} USES_MATERIAL edges "
                  f"({mats}) -- data quality problem (a part should have exactly one "
                  f"material), materialRef is NOT set instead of guessing.",
                  file=sys.stderr)
            continue
        material_ref[part_id] = mats[0]
    print(f"  USES_MATERIAL: {len(material_ref)} parts with a unique material")
    return material_ref


def fetch_dependencies(session):
    deps = []
    for query, stereotype in DEPENDENCY_SPECS:
        rows = list(session.run(query))
        deps.append((stereotype, [(r["source_id"], r["target_id"]) for r in rows]))
        print(f"  {stereotype} ({query.split('[:')[1].split(']')[0]}): {len(rows)} Kanten")
    return deps


# --- Diagram layout: simple row grid per stereotype category ---------------
# Box size (90x70) and column spacing are taken exactly from a real
# EA diagram (rflpv2_package.xml, all 15 test elements were 90x70),
# not invented.
DIAGRAM_BOX_W, DIAGRAM_BOX_H = 90, 70
DIAGRAM_COL_GAP, DIAGRAM_ROW_GAP = 40, 40
DIAGRAM_COL_PITCH = DIAGRAM_BOX_W + DIAGRAM_COL_GAP
DIAGRAM_ROW_PITCH = DIAGRAM_BOX_H + DIAGRAM_ROW_GAP
DIAGRAM_COLS_PER_BAND = 22
DIAGRAM_BAND_GAP = 150

# Diagram style blobs copied verbatim from a real EA XMI 2.1 export
# (rflpv2_package.xml, diagram "Package1") -- opaque, EA-internal
# display settings unrelated to concrete elements, hence reusable unchanged
# for every generated diagram.
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
    """8-hex-character 'display unit ID', as EA assigns them inside a diagram to link
    edges with their two endpoint shapes (see style=
    "DUID=..." on shapes and "EOID=...;SOID=..." on edges in
    rflpv2_package.xml). Only has to be unique within the diagram,
    need not match the real xmi:id -- derived deterministically from the
    business key (CRC32), with a collision fallback."""
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
        return ""  # endpoint not placed on the diagram -- should not happen
    return (
        '\t\t\t\t\t<element geometry="SX=0;SY=0;EX=0;EY=0;EDGE=4;$LLB=;LLT=;LMT=;'
        'LMB=;LRT=;LRB=;IRHS=;ILHS=;Path=;" '
        f'subject="{connector_xid}" '
        f'style="Mode=3;EOID={target_duid};SOID={source_duid};Color=-1;LWidth=0;Hidden=0;"/>\n'
    )


# Seven diagrams instead of one (2026-08-28, on request): one
# requirements diagram plus six BDD diagrams, one per
# NODE_SPECS category (split following the Sparx sketch -- Req./Fun./Log./
# Prod./Proc./TestC./TestScr., connected by relationship tables instead of in-diagram
# edges, see README). "neo4j_labels" chooses which
# NODE_SPECS entries (in emission order, one band each) land on
# this diagram; "internal_composition" switches on the HAS_COMPONENT
# composition edges for the product element diagram (the only
# edges in this data model that lie entirely WITHIN one category --
# all dependencies such as Realizes/Satisfies cross categories
# and are therefore deliberately NOT drawn on any of these diagrams,
# see ea_to_neo4j_mapping.md).
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
    """Elements + (for the product element diagram) composition edges for
    ONE diagram. node_rows_by_label: [(neo4j_label, rows)], one band each."""
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
                continue  # parent/child not on this diagram -- skip
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
    """Builds the <xmi:Extension>/<diagrams> block with the 7 diagrams from
    DIAGRAM_SPECS (see there). Each diagram gets its own,
    independent row-grid layout (bands per NODE_SPECS category
    within the diagram, e.g. Artifact/Assembly/Part as 3 bands in the
    product element diagram). No claim to a pretty layout, just
    a reproducible starting point (can be refined further in EA via "Layout Diagram").

    `deps` is accepted but deliberately NOT drawn on any of the 7
    diagrams -- all dependency relationships in this
    data model connect two different categories (e.g. Realizes:
    Logical Element -> Function), so on none of the strictly
    single-category diagrams can both endpoints exist. The edges
    still exist completely in the model (via build_xmi()) and are
    visible in EA at any time via an element's relationships or a
    relationship matrix -- just not as a line on one of
    these diagrams.

    Edge direction for the (only drawn) edge kind, composition:
    SOID=child (the end with aggregation="composite"), EOID=parent --
    the same rule as for the ownedEnd/ownedAttribute ends in build_xmi(),
    empirically verified on rflpv2_package.xml (there the composition
    Block5->Block6->Block7: the <connectors> source was always the child)."""
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
                     help="Do not generate an EA diagram, only the bare model elements "
                          "(e.g. if the import with a diagram block causes problems)")
    args = ap.parse_args()

    driver = get_driver()
    driver.verify_connectivity()
    print("Connected to Neo4j.\n")

    with driver.session(database=args.database) as session:
        print("Reading nodes:")
        nodes_by_spec = fetch_nodes(session)
        print("\nReading composition/material/relationships:")
        parent_of = fetch_composition(session)
        material_ref = fetch_materials(session)
        deps = fetch_dependencies(session)

    driver.close()

    xmi = build_xmi(nodes_by_spec, parent_of, material_ref, deps, with_diagram=not args.no_diagram)
    with open(args.out, "w", encoding="cp1252", errors="xmlcharrefreplace") as f:
        f.write(xmi)

    total_nodes = sum(len(rows) for rows in nodes_by_spec)
    total_deps = sum(len(pairs) for _, pairs in deps)
    print(f"\nDone: {args.out}")
    print(f"  {total_nodes} nodes, {len(parent_of)} composition edges, {total_deps} relationships")
    if not args.no_diagram:
        print(f"  + {len(DIAGRAM_SPECS)} diagrams (Requirements, Functions, Logical Elements, "
              f"Product Structure incl. composition edges, Processes, Test Cases, Test Scenarios) "
              f"(--no-diagram to switch off)")


if __name__ == "__main__":
    main()
