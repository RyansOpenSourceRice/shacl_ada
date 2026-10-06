#!/usr/bin/env bash
#  Local-first CI gate for SHACL_Ada: build, two-phase SPARK proof,
#  unit tests, and corpus conformance. Runs before every push; the
#  hosted pipelines carry only the light signals (gitleaks, pre-commit).
#
#  The proof runs in two phases: the full run carries two large
#  postconditions (Check_Property at shacl_ada-eval.ads:177, Check_Kind
#  at shacl_ada-eval.ads:199) whose in-context proof is
#  context-explosion-bound; they are re-proven standalone with
#  --limit-region, the gnatprove-documented workflow for such cases.
#  Phase 1 tolerates unproved checks only inside those two instantiated
#  units; phase 2 must be fully clean.
set -euo pipefail
cd "$(dirname "$0")/.."

alr --non-interactive build

mkdir -p proof/obj
gnatprove -P proof/spark_core.gpr -U --level=3 --timeout=300 -j2 \
  > proof/obj/proof-phase1.log
gnatprove -P proof/spark_core.gpr -U --level=3 --timeout=300 \
  --limit-region=shacl_ada-eval.ads:177:4 \
  --limit-region=shacl_ada-eval.ads:199:4 \
  > proof/obj/proof-phase2.log
if grep -qE "high: " proof/obj/proof-phase1.log; then
  echo "SPARK phase 1: high-severity check failures:" >&2
  grep -E "high: " proof/obj/proof-phase1.log >&2
  exit 1
fi
if grep "not proved," proof/obj/gnatprove/gnatprove.out \
     | grep -vE "Proof_Eval\.Check_(Property|Kind) at shacl_ada-eval\.ads:"; then
  echo "SPARK phase 1: unproved checks outside the declared marginal units:" >&2
  exit 1
fi
if grep -qE "medium: |high: " proof/obj/proof-phase2.log; then
  echo "SPARK phase 2: limit-region proof incomplete:" >&2
  grep -E "medium: |high: " proof/obj/proof-phase2.log >&2
  exit 1
fi

(
  cd tests
  alr --non-interactive build
  alr --non-interactive exec -- bin/shapes_tests
  alr --non-interactive exec -- bin/conformance \
    ../corpora/data-shapes-test-suite/tests/core/complex/personexample.ttl \
    ../corpora/data-shapes-test-suite/tests/core/complex/personexample.ttl
  ulimit -s 65536
  alr --non-interactive exec -- bin/eval_tests \
    ../corpora/data-shapes-test-suite/tests/core
)

echo "verify: ok"
