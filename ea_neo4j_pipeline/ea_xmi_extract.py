"""
ea_xmi_extract.py

Erster Schritt der EA -> Neo4j Pipeline (siehe ea_to_neo4j_mapping.md fuer die
vollstaendige Mapping-Spezifikation). Liest einen XMI-2.1-Export aus Enterprise
Architect (Project > Model Exchange > Export Package to Native/XMI File,
Format "XMI: 2.1", NICHT "Native Format") und schreibt fuer jedes Ziel-
Neo4j-Label bzw. jeden Beziehungstyp eine eigene CSV-Datei nach ea_extract/ --
GUIDs sind darin bereits zu Business-Keys (den *ID-Tags aus dem RFLPV2-Profil)
aufgeloest.

STATUS: Ab 28.08.2026 gegen einen ECHTEN EA-Export verifiziert (rflpv2_package.xml,
ein Testmodell mit einem Element je Stereotyp + Kompositions- und
Beziehungs-Kanten). Die tatsaechliche Struktur unterscheidet sich vom
urspruenglich angenommenen Format (siehe Git-Historie fuer die alte Version):

- Stereotyp-Anwendungen sind KEINE <xmi:Extension>-Eintraege, sondern eigene
  Elemente im Profil-eigenen XML-Namespace (deklariert am Root als
  xmlns:<ProfilName>="http://www.sparxsystems.com/profiles/<ProfilName>/1.0"),
  direkt als Geschwister der packagedElements innerhalb von <uml:Model>:

      <RFLPV2_Sustainability_Process_Extension:Logical_Element
          base_Class="EAID_..." __EAStereoName="Logical Element"
          logicalID="SP_PARALLEL"/>

  Der lokale Elementname ist der Stereotypname mit Leerzeichen->Unterstrich
  (bei mehrwortigen Namen zusaetzlich per __EAStereoName mit echten
  Leerzeichen zurueckgegeben). base_Class/base_Dependency/base_Activity
  verweist auf die xmi:id des Basis-Elements. Alle uebrigen Attribute sind
  die tatsaechlich gesetzten Tagged Values (leere Tags fehlen einfach, keine
  leeren Strings).

- Dependencies (fuer die 9 Beziehungs-Stereotypen) sind normale
  <packagedElement xmi:type="uml:Dependency" client="..." supplier="...">,
  client = Source, supplier = Target. Das zugehoerige Stereotyp haengt separat
  per base_Dependency dran.

- Komposition (Artifact/Assembly/Part) laeuft ueber <uml:Association> mit zwei
  Enden (memberEnd-Idrefs). WICHTIG, hier gab es eine falsche Annahme in der
  Vorversion: das Ende mit aggregation="composite" zeigt auf das KIND (Part),
  nicht auf den Elternteil -- das andere Ende (aggregation="none") zeigt auf
  den Elternteil (Whole). Empirisch verifiziert an einer echten
  Artifact->Assembly->Part-Kette.

Der <xmi:Extension extender="Enterprise Architect">-Block (EAs interne
Bookhaltung: xrefs, Diagrammstil, redundante Tag-Listen) wird NICHT
ausgewertet -- alles Noetige steht bereits im <uml:Model>-Teil.

Aufruf:
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

# --- Mapping-Tabellen (siehe ea_to_neo4j_mapping.md, Abschnitt 2 & 3) --------

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

# Tags, die EA zusaetzlich zu unseren eigenen mitliefert (geerbt von der
# darunterliegenden SysML-Generalisierung, z.B. "id"/"text" von SysML::requirement,
# "isEncapsulated" von SysML::block) -- kein Bestandteil unseres Profils,
# werden beim Import ignoriert, um das Neo4j-Schema nicht mit EA-internen
# Zusatzfeldern zu verunreinigen.
IGNORE_TAGS = {"id", "text", "isEncapsulated"}

DEPENDENCY_STEREOTYPES = {
    "Affects", "Derives", "Realizes", "Refines", "Requires",
    "Satisfies", "Specifies", "Validates", "Verifies",
}

REL_TARGET_OVERRIDE = {
    ("Realizes", "Logical Element", "Function"): "REALIZES_FUNCTION",
    ("Realizes", "Product Element", "Logical Element"): "REALIZES_PRINCIPLE",
}
REQUIREMENT_STEREOTYPES = {"Customer Requirement", "System Requirement"}


def local_name(tag):
    return tag.split("}", 1)[-1] if tag.startswith("{") else tag


def local_type_name(xmi_type_value):
    """xmi:type-Attributwerte sind einfache 'prefix:LocalName'-Strings (z.B.
    'uml:Class'), KEIN ElementTree-Tag mit {namespace}-Praefix -- deshalb
    eigene Funktion statt local_name()."""
    return xmi_type_value.split(":", 1)[-1] if xmi_type_value else xmi_type_value


def namespace_uri(tag):
    return tag[1:].split("}", 1)[0] if tag.startswith("{") else None


OMG_SCHEMA_PREFIX = "http://schema.omg.org/spec/"


def detect_profile_namespaces(path):
    """Liest alle xmlns:PREFIX-Deklarationen im gesamten Dokument, ausser
    OMG-Standard-Namespaces (xmi/uml, auch bei abweichender Trailing-Slash-
    Schreibweise an anderer Stelle im Dokument) und xsi -- das sind die
    angewendeten Profil-Namespaces (i.d.R. genau einer)."""
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
        # Manche Exporte nutzen uml:Model ohne Praefix-Kollision -- Fallback
        for child in root:
            if local_name(child.tag) == "Model":
                model = child
                break
    if model is None:
        print("FEHLER: kein <uml:Model> gefunden -- ist das eine gueltige XMI-2.1-Datei "
              "(Export ueber 'Export Package to Native/XMI File', Format XMI 2.1)?", file=sys.stderr)
        sys.exit(1)

    profile_uris = detect_profile_namespaces(path)
    if debug:
        print(f"[debug] erkannte Profil-Namespace(s): {profile_uris}", file=sys.stderr)
    if not profile_uris:
        print("WARNUNG: kein Profil-Namespace am Root gefunden -- vermutlich wurden im "
              "exportierten Package gar keine RFLPV2-Stereotypen verwendet.", file=sys.stderr)

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
        # Stereotyp-Anwendungen sind direkte Kinder von <uml:Model> im Profil-Namespace
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
                print(f"WARNUNG: Stereotyp-Element <{local}> ohne erkennbares base_*-Attribut "
                      f"uebersprungen: {top_child.attrib}", file=sys.stderr)
                continue
            tags = {
                k: v for k, v in top_child.attrib.items()
                if k != "__EAStereoName" and not k.startswith("base_") and k not in IGNORE_TAGS
            }
            stereo_apps.append({"base_id": base_id, "stereotype": stereotype_name, "tags": tags})
        else:
            walk(top_child)

    # Komposition: pro Association die beiden Enden ueber memberEnd aufloesen.
    # Das Ende mit aggregation="composite" zeigt auf das KIND (Part), das
    # andere Ende auf den Elternteil (Whole) -- empirisch verifiziert, siehe
    # Docstring oben.
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
            print(f"[debug] Association {assoc.get('{%s}id' % NS_XMI)} nicht als "
                  f"Komposition erkannt (ends={ends})", file=sys.stderr)

    return base_elements, stereo_apps, dependencies, composite_edges


def assign_product_element_labels(stereo_by_base_id, composite_edges):
    """Root (keine eingehende Komposition) -> Artifact, Tiefe 1 -> Assembly,
    Tiefe >=2 -> Part. Warnt bei Tiefe > 2."""
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
                print(f"WARNUNG: Product-Element {pid} liegt in Kompositionstiefe {d} (>2) -- "
                      f"wird trotzdem als Part eingestuft, bestehendes Schema ist strikt "
                      f"dreistufig (Artifact/Assembly/Part).", file=sys.stderr)
            label_by_id[pid] = "Part"
    return label_by_id


def resolve_node_id(base_id, stereotype, tags):
    tag_name = ID_TAG_BY_STEREOTYPE.get(stereotype)
    if tag_name and tags.get(tag_name):
        return tags[tag_name]
    print(f"WARNUNG: kein Business-Key-Tag fuer Element {base_id} (Stereotyp={stereotype}) "
          f"gesetzt -- verwende EA-GUID als id.", file=sys.stderr)
    return base_id


def build_node_rows(base_elements, stereo_apps, product_labels, stereo_by_base_id):
    rows_by_label = defaultdict(list)
    id_by_base_id = {}  # base_id -> (label, node_id)

    for app in stereo_apps:
        base_id = app["base_id"]
        stereotype = app["stereotype"]
        if stereotype in DEPENDENCY_STEREOTYPES:
            continue  # Beziehungen werden separat behandelt

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
            print(f"WARNUNG: materialRef gesetzt auf {label}-Knoten {node_id} -- wird nur "
                  f"fuer Part-Knoten als USES_MATERIAL-Kante umgesetzt, hier ignoriert.",
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
    # base_id (der Dependency selbst) -> Stereotyp-Name, ueber base_Dependency
    dep_stereotype_by_id = {app["base_id"]: app["stereotype"] for app in dependency_apps}
    for dep_id, client_id, supplier_id in dependencies:
        dep_stereotype = dep_stereotype_by_id.get(dep_id)
        if dep_stereotype not in DEPENDENCY_STEREOTYPES:
            continue
        if client_id not in id_by_base_id or supplier_id not in id_by_base_id:
            print(f"WARNUNG: {dep_stereotype}-Connector {dep_id} verweist auf ein Element "
                  f"ohne bekanntes Ziel-Label (client={client_id}, supplier={supplier_id}) "
                  f"-- uebersprungen.", file=sys.stderr)
            continue
        src_label, from_id = id_by_base_id[client_id]
        tgt_label, to_id = id_by_base_id[supplier_id]
        src_stereo = stereo_by_base_id[client_id]["stereotype"] if client_id in stereo_by_base_id else src_label
        tgt_stereo = stereo_by_base_id[supplier_id]["stereotype"] if supplier_id in stereo_by_base_id else tgt_label
        rel_type, is_fallback = classify_relationship(dep_stereotype, src_stereo, tgt_stereo)
        if is_fallback:
            print(f"HINWEIS: {dep_stereotype} zwischen {src_stereo} und {tgt_stereo} passt zu "
                  f"keiner bekannten Bestands-Zielregel -- lande auf Fallback-Typ :{rel_type}.",
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
    print(f"{len(base_elements)} Basis-Elemente, {len(stereo_apps)} Stereotyp-Anwendungen, "
          f"{len(dependencies)} Dependencies, {len(composite_edges)} Komposition-Kanten gelesen.")

    # stereo_by_base_id: base_id -> stereo_app (fuer Knoten); Dependency-
    # Anwendungen getrennt gefuehrt, da sie nicht per Knoten-base_id passen
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
        print("\nWARNUNG: keine Knoten extrahiert. Bitte mit --debug erneut laufen lassen.",
              file=sys.stderr)


if __name__ == "__main__":
    main()
