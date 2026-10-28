// ea_new_labels_constraints.cypher
//
// Uniqueness constraints for the Neo4j labels newly introduced by the EA->Neo4j pipeline
// (RFLPV2_Extension_Profile_V006), because there is no existing counterpart for them
// (see ea_to_neo4j_mapping.md, section 2).
// Created automatically by ea_to_neo4j_load.py on start
// (IF NOT EXISTS) -- this file is the manual reference, analogous to
// add_constraints.cypher for channel B.

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
