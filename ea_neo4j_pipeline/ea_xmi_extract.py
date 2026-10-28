"""
ea_xmi_extract.py

First step of the EA -> Neo4j pipeline (see ea_to_neo4j_mapping.md for the
complete mapping specification). Reads an XMI 2.1 export from Enterprise
Architect (Project > Model Exchange > Export Package to Native/XMI File,
format "XMI: 2.1", NOT "Native Format") and writes one CSV file per target
Neo4j label or relationship type to ea_extract/ --
GUIDs in them are already resolved to business keys (the *ID tags from the
RFLPV2 profile).

STATUS: Verified against a REAL EA export since 2026-08-28 (rflpv2_package.xml,
a test model with one element per stereotype + composition and
relationship edges). The actual structure differs from the originally
assumed format (see the git history for the old version):

- Stereotype applications are NOT <xmi:Extension> entries but separate
  elements in the profile's own XML namespace (declared on the root as
  xmlns:<ProfileName>="http://www.sparxsystems.com/profiles/<ProfileName>/1.0"),
  placed directly as siblings of the packagedElements inside <uml:Model>:

      <RFLPV2_Sustainability_Process_Extension:Logical_Element
          base_Class="EAID_..." __EAStereoName="Logical Element"
          logicalID="SP_PARALLEL"/>

  The local element name is the stereotype name with spaces -> underscores
  (for multi-word names, __EAStereoName additionally returns the real
  spaces). base_Class/base_Dependency/base_Activity points to the xmi:id
  of the base element. All other attributes are the tagged values that are
  actually set (empty tags are simply absent, no empty strings).

- Dependencies (for the 9 relationship stereotypes) are ordinary
  <packagedElement xmi:type="uml:Dependency" client="..." supplier="...">,
  client = source, supplier = target. The matching stereotype is attached
  separately via base_Dependency.

- Composition (Artifact/Assembly/Part) runs via <uml:Association> with two
  ends (memberEnd idrefs). IMPORTANT, the previous version had a wrong
  assumption here: the end with aggregation="composite" points to the CHILD
  (part), not to the parent -- the other end (aggregation="none") points to
  the parent (whole). Empirically verified on a real
  Artifact->Assembly->Part chain.

The <xmi:Extension extender="Enterprise Architect"> block (EA's internal
bookkeeping: xrefs, diagram style, redundant tag lists) is NOT
evaluated -- everything needed is already in the <uml:Model> part.

Usage:
    python ea_xmi_extract.py --input rflpv2_package.xml --out-dir ea_extract
    python ea_xmi_extract.py --input rflpv2_package.xml --out-dir ea_extract --debug
"""

import argparse
import csv
import os
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict, deque

NS_XMI = "http://schema.omg.org/spec/XMI/2.1"
NS_UML = "http://schema.omg.org/spec/UML/2.1"

# --- Mapping tables (see ea_to_neo4j_mapping.md, sections 2 & 3) --------

NODE_STEREOTYPE_TO_LABEL = {
    "Customer Need": "CustomerNeed",
    "Customer Requirement": "Requirement",
    "System Requirement": "Requirement",
    "Function": "Function",
    "Logical Element": "SolutionPrinciple",
    "Process Element": "Process",
    "Product Element": None,  # wird per Komposition zu Artifact/Assembly/Part aufgeloest
    "Test Case Description": "TestCaseDescription",
}

ID_TAG_BY_STEREOTYPE = {
    "Customer Need": "needID",
    "Customer Requirement": "customerRequirementID",
    "System Requirement": "systemRequirementID",
    "Function": "functionID",
    "Logical Element": "logicalID",
    "Process Element": "processID",
    "Product Element": "productID",
    "Test Case Description": "testCaseDescriptionID",
    "Test Case": "testCaseID",
    "Test Scenario": "testScenarioID",
    "Validation": "validationID",
    "Verification": "verificationID",
}

VERIFICATION_METHOD_STEREOTYPES = {"Analysis", "Demonstration", "Inspection", "Simulation", "Test"}
VERIFICATION_METHOD_BASE_LABEL = "Validation"

REQUIREMENT_LEVEL = {
    "Customer Requirement": "customer",
    "System Requirement": "system",
}

TAG_RENAME = {
    "Mainfeature": "mainFeature",
}

# Tags that EA supplies in addition to our own (inherited from the underlying
# SysML generalization, e.g. "id"/"text" from SysML::requirement,
# "isEncapsulated" from SysML::block) -- not part of our profile,
# ignored on import so the Neo4j schema is not polluted with EA-internal
# extra fields.
IGNORE_TAGS = {"id", "text", "isEncapsulated"}

DEPENDENCY_STEREOTYPES = {
    "Affects", "Applies", "Derives", "Realizes", "Refines", "Requires",
    "Satisfies", "Specifies", "Validates", "Verifies",
}

REL_TARGET_OVERRIDE = {
    ("Realizes", "Logical Element", "Function"): "REALIZES_FUNCTION",
    ("Realizes", "Product Element", "Logical Element"): "REALIZES_PRINCIPLE",
    ("Applies", "Process Element", "Product Element"): "APPLIES_TO",
}
REQUIREMENT_STEREOTYPES = {"Customer Requirement", "System Requirement"}


def local_name(tag):
    return tag.split("}", 1)[-1] if tag.startswith("{") else tag


def local_type_name(xmi_type_value):
    """xmi:type attribute values are plain 'prefix:LocalName' strings (e.g.
    'uml:Class'), NOT an ElementTree tag with a {namespace} prefix -- hence a
    separate function instead of local_name()."""
    return xmi_type_value.split(":", 1)[-1] if xmi_type_value else xmi_type_value


def namespace_uri(tag):
    return tag[1:].split("}", 1)[0] if tag.startswith("{") else None


OMG_SCHEMA_PREFIX = "http://schema.omg.org/spec/"


def detect_profile_namespaces(path):
    """Reads all xmlns:PREFIX declarations in the whole document except
    OMG standard namespaces (xmi/uml, also with a differing trailing-slash
    spelling elsewhere in the document) and xsi -- these are the
    applied profile namespaces (usually exactly one)."""
    uris = set()
    for event, ns in ET.iterparse(path, events=("start-ns",)):
        prefix, uri = ns
        if uri.startswith(OMG_SCHEMA_PREFIX) or prefix == "xsi":
            continue
        uris.add(uri)
    return uris


def parse_xmi(path, debug=False):
    tree = ET.parse(path)
    root = tree.getroot()
    model = root.find("{%s}Model" % NS_UML)
    if model is None:
        # Some exports use uml:Model without a prefix collision -- fallback
        for child in root:
            if local_name(child.tag) == "Model":
                model = child
                break
    if model is None:
        print("ERROR: no <uml:Model> found -- is this a valid XMI 2.1 file "
              "(export via 'Export Package to Native/XMI File', format XMI 2.1)?", file=sys.stderr)
        sys.exit(1)

    profile_uris = detect_profile_namespaces(path)
    if debug:
        print(f"[debug] erkannte Profil-Namespace(s): {profile_uris}", file=sys.stderr)
    if not profile_uris:
        print("WARNING: no profile namespace found on the root -- probably no "
              "RFLPV2 stereotypes were used in the exported package at all.", file=sys.stderr)

    base_elements = {}   # xmi:id -> {"name":.., "xmi_type":..}
    dependencies = []    # (dep_id, client_id, supplier_id)
    associations = []    # <packagedElement xmi:type="uml:Association"> Elemente
    all_ends = {}        # end_id -> {"aggregation":.., "type": type_id}
    stereo_apps = []     # {"base_id":.., "stereotype":.., "tags": {...}}

    def walk(el):
        xmi_type = el.get("{%s}type" % NS_XMI)
        el_id = el.get("{%s}id" % NS_XMI)
        if xmi_type is not None:
            local_type = local_type_name(xmi_type)
            if local_type in ("Class", "Activity", "Operation") and el_id:
                base_elements[el_id] = {"name": el.get("name") or "", "xmi_type": local_type}
            elif local_type == "Dependency" and el_id:
                dependencies.append((el_id, el.get("client"), el.get("supplier")))
            elif local_type == "Association":
                associations.append(el)
            elif local_type == "Property" and el_id:
                end_type_el = el.find("type")
                type_id = end_type_el.get("{%s}idref" % NS_XMI) if end_type_el is not None else None
                all_ends[el_id] = {"aggregation": el.get("aggregation", "none"), "type": type_id}
        for child in el:
            walk(child)

    for top_child in model:
        # Stereotype applications are direct children of <uml:Model> in the profile namespace
        uri = namespace_uri(top_child.tag)
        if uri in profile_uris:
            local = local_name(top_child.tag)
            stereotype_name = top_child.get("__EAStereoName") or local.replace("_", " ")
            base_id = None
            for attr_name, attr_val in top_child.attrib.items():
                if attr_name.startswith("base_"):
                    base_id = attr_val
                    break
            if base_id is None:
                print(f"WARNING: stereotype element <{local}> without a recognisable base_* attribute "
                      f"skipped: {top_child.attrib}", file=sys.stderr)
                continue
            tags = {
                k: v for k, v in top_child.attrib.items()
                if k != "__EAStereoName" and not k.startswith("base_") and k not in IGNORE_TAGS
            }
            stereo_apps.append({"base_id": base_id, "stereotype": stereotype_name, "tags": tags})
        else:
            walk(top_child)

    # Composition: resolve the two ends of each association via memberEnd.
    # The end with aggregation="composite" points to the CHILD (part), the
    # other end to the parent (whole) -- empirically verified, see the
    # docstring above.
    composite_edges = []  # (parent_id, child_id)
    for assoc in associations:
        member_ids = [
            me.get("{%s}idref" % NS_XMI)
            for me in assoc.findall("memberEnd")
        ]
        ends = [all_ends[mid] for mid in member_ids if mid in all_ends]
        composite_end = next((e for e in ends if e["aggregation"] == "composite"), None)
        other_end = next((e for e in ends if e is not composite_end), None)
        if composite_end and other_end and composite_end["type"] and other_end["type"]:
            composite_edges.append((other_end["type"], composite_end["type"]))
        elif debug:
            print(f"[debug] Association {assoc.get('{%s}id' % NS_XMI)} not recognised as a "
                  f"composition (ends={ends})", file=sys.stderr)

    return base_elements, stereo_apps, dependencies, composite_edges


def assign_product_element_labels(stereo_by_base_id, composite_edges):
    """Root (no incoming composition) -> Artifact, depth 1 -> Assembly,
    depth >=2 -> Part. Warns for depth > 2."""
    product_ids = {
        base_id for base_id, app in stereo_by_base_id.items()
        if app["stereotype"] == "Product Element"
    }
    children_of = defaultdict(list)
    has_parent = set()
    for parent, child in composite_edges:
        if parent in product_ids and child in product_ids:
            children_of[parent].append(child)
            has_parent.add(child)

    roots = [pid for pid in product_ids if pid not in has_parent]
    depth = {}
    q = deque((r, 0) for r in roots)
    while q:
        el_id, d = q.popleft()
        if el_id in depth:
            continue
        depth[el_id] = d
        for child in children_of.get(el_id, []):
            q.append((child, d + 1))
    for pid in product_ids:
        depth.setdefault(pid, 0)

    label_by_id = {}
    for pid, d in depth.items():
        if d == 0:
            label_by_id[pid] = "Artifact"
        elif d == 1:
            label_by_id[pid] = "Assembly"
        else:
            if d > 2:
                print(f"WARNING: product element {pid} sits at composition depth {d} (>2) -- "
                      f"classified as Part anyway, the existing schema is strictly "
                      f"three-level (Artifact/Assembly/Part).", file=sys.stderr)
            label_by_id[pid] = "Part"
    return label_by_id


def resolve_node_id(base_id, stereotype, tags):
    tag_name = ID_TAG_BY_STEREOTYPE.get(stereotype)
    if tag_name and tags.get(tag_name):
        return tags[tag_name]
    print(f"WARNING: no business-key tag set for element {base_id} (stereotype={stereotype}) "
          f"-- using the EA GUID as id.", file=sys.stderr)
    return base_id


def build_node_rows(base_elements, stereo_apps, product_labels, stereo_by_base_id):
    rows_by_label = defaultdict(list)
    id_by_base_id = {}  # base_id -> (label, node_id)

    for app in stereo_apps:
        base_id = app["base_id"]
        stereotype = app["stereotype"]
        if stereotype in DEPENDENCY_STEREOTYPES:
            continue  # relationships are handled separately

        if stereotype == "Product Element":
            label = product_labels.get(base_id, "Artifact")
        elif stereotype in VERIFICATION_METHOD_STEREOTYPES:
            label = VERIFICATION_METHOD_BASE_LABEL
        elif stereotype in ("Validation", "Verification"):
            label = stereotype
        elif stereotype == "Test Case":
            label = "TestCase"
        elif stereotype == "Test Scenario":
            label = "TestScenario"
        elif stereotype in NODE_STEREOTYPE_TO_LABEL:
            label = NODE_STEREOTYPE_TO_LABEL[stereotype]
        else:
            continue

        tags = {TAG_RENAME.get(k, k): v for k, v in app["tags"].items()}
        node_id = resolve_node_id(base_id, stereotype, tags)
        id_by_base_id[base_id] = (label, node_id)

        name = base_elements.get(base_id, {}).get("name", "")
        row = {"id": node_id, "name": name, "sourceStereotype": stereotype}
        row.update(tags)

        if stereotype in REQUIREMENT_LEVEL:
            row["level"] = REQUIREMENT_LEVEL[stereotype]
        if stereotype in VERIFICATION_METHOD_STEREOTYPES:
            row["method"] = stereotype
        if stereotype == "Product Element" and label != "Part" and row.get("materialRef"):
            print(f"WARNING: materialRef set on {label} node {node_id} -- it is only "
                  f"applied to Part nodes as a USES_MATERIAL edge, ignored here.",
                  file=sys.stderr)

        rows_by_label[label].append(row)

    return rows_by_label, id_by_base_id


def classify_relationship(dep_stereotype, src_stereotype, tgt_stereotype):
    override = REL_TARGET_OVERRIDE.get((dep_stereotype, src_stereotype, tgt_stereotype))
    if override:
        return override, False
    if dep_stereotype == "Satisfies" and tgt_stereotype in REQUIREMENT_STEREOTYPES:
        return "SATISFIES_REQUIREMENT", False
    if dep_stereotype in ("Satisfies", "Realizes"):
        return dep_stereotype.upper(), True
    return dep_stereotype.upper(), False


def build_relationship_rows(dependencies, dependency_apps, stereo_by_base_id, id_by_base_id):
    rows_by_type = defaultdict(list)
    # base_id (of the dependency itself) -> stereotype name, via base_Dependency
    dep_stereotype_by_id = {app["base_id"]: app["stereotype"] for app in dependency_apps}
    for dep_id, client_id, supplier_id in dependencies:
        dep_stereotype = dep_stereotype_by_id.get(dep_id)
        if dep_stereotype not in DEPENDENCY_STEREOTYPES:
            continue
        if client_id not in id_by_base_id or supplier_id not in id_by_base_id:
            print(f"WARNING: {dep_stereotype} connector {dep_id} refers to an element "
                  f"without a known target label (client={client_id}, supplier={supplier_id}) "
                  f"-- skipped.", file=sys.stderr)
            continue
        src_label, from_id = id_by_base_id[client_id]
        tgt_label, to_id = id_by_base_id[supplier_id]
        src_stereo = stereo_by_base_id[client_id]["stereotype"] if client_id in stereo_by_base_id else src_label
        tgt_stereo = stereo_by_base_id[supplier_id]["stereotype"] if supplier_id in stereo_by_base_id else tgt_label
        rel_type, is_fallback = classify_relationship(dep_stereotype, src_stereo, tgt_stereo)
        if is_fallback:
            print(f"NOTE: {dep_stereotype} between {src_stereo} and {tgt_stereo} matches "
                  f"no known target rule of the existing graph -- lands on fallback type :{rel_type}.",
                  file=sys.stderr)
        rows_by_type[rel_type].append({
            "from_id": from_id, "to_id": to_id,
            "sourceStereotype": src_stereo, "targetStereotype": tgt_stereo,
        })
    return rows_by_type


def write_csv(path, rows, leading_fields=("id", "name", "sourceStereotype")):
    if not rows:
        return
    fieldnames = list(dict.fromkeys(
        list(leading_fields) + [k for row in rows for k in row.keys()]
    ))
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input", required=True, help="Pfad zum EA-XMI-2.1-Export")
    ap.add_argument("--out-dir", default="ea_extract", help="Zielverzeichnis fuer die CSVs")
    ap.add_argument("--debug", action="store_true")
    args = ap.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    base_elements, stereo_apps, dependencies, composite_edges = parse_xmi(args.input, args.debug)
    print(f"Read {len(base_elements)} base elements, {len(stereo_apps)} stereotype applications, "
          f"{len(dependencies)} dependencies, {len(composite_edges)} composition edges.")

    # stereo_by_base_id: base_id -> stereo_app (for nodes); dependency
    # applications are kept separately because they do not match by node base_id
    stereo_by_base_id = {}
    dependency_apps = []
    for app in stereo_apps:
        if app["stereotype"] in DEPENDENCY_STEREOTYPES:
            dependency_apps.append(app)
        else:
            stereo_by_base_id[app["base_id"]] = app

    product_labels = assign_product_element_labels(stereo_by_base_id, composite_edges)
    rows_by_label, id_by_base_id = build_node_rows(base_elements, stereo_apps, product_labels, stereo_by_base_id)

    for label, rows in sorted(rows_by_label.items()):
        write_csv(os.path.join(args.out_dir, f"ea_{label}.csv"), rows)
        print(f"  {label}: {len(rows)} Zeilen -> {args.out_dir}/ea_{label}.csv")

    rows_by_type = build_relationship_rows(dependencies, dependency_apps, stereo_by_base_id, id_by_base_id)
    for rel_type, rows in sorted(rows_by_type.items()):
        write_csv(
            os.path.join(args.out_dir, f"ea_rel_{rel_type}.csv"),
            rows,
            leading_fields=("from_id", "to_id", "sourceStereotype", "targetStereotype"),
        )
        print(f"  :{rel_type}: {len(rows)} Zeilen -> {args.out_dir}/ea_rel_{rel_type}.csv")

    if not rows_by_label:
        print("\nWARNING: no nodes extracted. Please re-run with --debug.",
              file=sys.stderr)


if __name__ == "__main__":
    main()
