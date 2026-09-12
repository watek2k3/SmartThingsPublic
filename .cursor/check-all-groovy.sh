#!/usr/bin/env bash
#
# Syntax-check every (or a subset of) *.groovy file in the repository using the
# same logic as .githooks/pre-commit: run `groovyc` and treat only errors that
# are NOT "unable to resolve class" (the SmartThings runtime DSL) as failures.
#
# Usage:
#   .cursor/check-all-groovy.sh                 # check all tracked *.groovy files
#   .cursor/check-all-groovy.sh path/a.groovy   # check specific files
set -uo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  mapfile -t FILES < <(find devicetypes smartapps -name '*.groovy' | sort)
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

TOTAL=0
FAILED=0
for DTH in "${FILES[@]}"; do
  TOTAL=$((TOTAL + 1))
  ERRORS=$(groovyc -d "$WORKDIR" "$DTH" 2>&1 | grep ".groovy:")
  IMPORTANT_ERRORS=$(echo "$ERRORS" | grep -v "unable")
  if [ "${#IMPORTANT_ERRORS}" -ne 0 ]; then
    FAILED=$((FAILED + 1))
    echo "FAIL: $DTH"
    echo "$IMPORTANT_ERRORS"
  fi
done

echo "======================================================================="
echo "Checked ${TOTAL} file(s); ${FAILED} with disqualifying syntax errors."
[ "$FAILED" -eq 0 ]
