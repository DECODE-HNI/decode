// ea_new_labels_constraints.cypher
//
// Uniqueness-Constraints fuer die Neo4j-Labels, die durch die EA->Neo4j-Pipeline
// (RFLPV2_Extension_Profile_V006) neu hinzukommen, weil es dafuer noch kein
// Bestands-Gegenstueck gibt (siehe ea_to_neo4j_mapping.md, Abschnitt 2).
// Werden von ea_to_neo4j_load.py beim Start automatisch angelegt
// (IF NOT EXISTS) -- diese Datei ist die manuelle Referenz, analog zu
// add_constraints.cypher fuer Kanal B.

CREATE CONSTRAINT customerneed_id_unique IF NOT EXISTS
FOR (n:CustomerNeed) REQUIRE n.id IS UNIQUE;

CREATE CONSTRAINT testcase_id_unique IF NOT EXISTS
FOR (n:TestCase) REQUIRE n.id IS UNIQUE;

CREATE CONSTRAINT testcasedescription_id_unique IF NOT EXISTS
FOR (n:TestCaseDescription) REQUIRE n.id IS UNIQUE;

CREATE CONSTRAINT testscenario_id_unique IF NOT EXISTS
FOR (n:TestScenario) REQUIRE n.id IS UNIQUE;

CREATE CONSTRAINT validation_id_unique IF NOT EXISTS
FOR (n:Validation) REQUIRE n.id IS UNIQUE;

CREATE CONSTRAINT verification_id_unique IF NOT EXISTS
FOR (n:Verification) REQUIRE n.id IS UNIQUE;
