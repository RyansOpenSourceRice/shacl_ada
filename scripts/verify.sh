#!/usr/bin/env bash
#  Local-first CI gate for SHACL_Ada: build, two-phase SPARK proof,
#  unit tests, and corpus conformance. Runs before every push; the
#  hosted pipelines carry only the light signals (gitleaks, pre-commit).
#
#  The proof runs in two phases: the full run proves every check, and
#  two large postconditions that time out in the full-run context are
#  re-proven standalone with --limit-region, the gnatprove-documented
#  workflow for context-explosion cases. Both phases must be clean.
set -euo pipefail
cd "$(dirname "$0")/.."

alr --non-interactive build

mkdir -p proof/obj
gnatprove -P proof/spark_core.gpr -U --level=3 --timeout=300 -j2 \
  > proof/obj/proof-phase1.log
gnatprove -P proof/spark_core.gpr -U --level=3 --timeout=300 \
  --limit-region=shacl_ada-eval.ads:103:17 \
  --limit-region=shacl_ada-eval.ads:126:17 \
  > proof/obj/proof-phase2.log
if grep -qE "medium: |high: " proof/obj/proof-phase1.log proof/obj/proof-phase2.log; then
  echo "SPARK proof incomplete:" >&2
  grep -E "medium: |high: " proof/obj/proof-phase1.log proof/obj/proof-phase2.log >&2
  exit 1
fi

(
  cd tests
  alr --non-interactive build
  alr --non-interactive exec -- bin/shapes_tests
  alr --non-interactive exec -- bin/conformance \
    ../corpora/data-shapes-test-suite/tests/core/complex/personexample.ttl \
    ../corpora/data-shapes-test-suite/tests/core/complex/personexample.ttl
)

echo "verify: ok"
