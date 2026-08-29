#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# cq.sh -- tiny cypher-shell wrapper used by check_tools.sh and by hand.
#
# Reads the connection from the standard DECODE environment variables:
#   NEO4J_URI       (default bolt://localhost:7687)
#   NEO4J_USER      (default neo4j)
#   NEO4J_PASSWORD  (required)
#
# `cypher-shell` must be on PATH (it ships with every Neo4j install under
# bin/). Output format: plain (default) or set CQ_FMT=verbose.
#
#   ./cq.sh path/to/file.cypher      # run a file
#   ./cq.sh "MATCH (n) RETURN count(n);"   # run a literal statement
# ---------------------------------------------------------------------------
: "${NEO4J_URI:=bolt://localhost:7687}"
: "${NEO4J_USER:=neo4j}"
if [ -z "${NEO4J_PASSWORD:-}" ]; then
  echo "cq.sh: NEO4J_PASSWORD is not set" >&2
  exit 2
fi
FMT="${CQ_FMT:-plain}"
if ! command -v cypher-shell >/dev/null 2>&1; then
  echo "cq.sh: cypher-shell not found on PATH" >&2
  exit 2
fi
if [ -n "${1:-}" ] && [ -f "$1" ]; then
  cypher-shell -a "$NEO4J_URI" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" --format "$FMT" -f "$1" 2>&1
else
  cypher-shell -a "$NEO4J_URI" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" --format "$FMT" "$1" 2>&1
fi
