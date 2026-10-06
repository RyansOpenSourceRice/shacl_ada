#!/usr/bin/env bash
#  Local-first CI gate for SHACL_Ada: build, two-phase SPARK proof,
#  unit tests, and corpus conformance. Runs before every push; the
#  hosted pipelines carry only the light signals (gitleaks, pre-commit).
#
#  The proof runs in two phases: the full run carries two large
#  postconditions (Check_Property, Check_Kind — declared at
#  shacl_ada-eval.ads:200 and :222) whose in-context proof is
#  context-explosion-bound; they are re-proven standalone with
#  --limit-subp, the gnatprove-documented workflow for such cases.
#  Phase 1 tolerates unproved checks only inside those two instantiated
#  units; phase 2 must be fully clean.
set -euo pipefail
cd "$(dirname "$0")/.."

alr --non-interactive build

mkdir -p proof/obj
gnatprove -P proof/spark_core.gpr -U --level=3 --timeout=300 -j2 \
  > proof/obj/proof-phase1.log
#  Failed checks print to stderr, never to the redirected logs; the
#  summary file is the authority for both phases, snapshotted per run.
cp proof/obj/gnatprove/gnatprove.out proof/obj/summary-phase1.out
gnatprove -P proof/spark_core.gpr -U --level=3 --timeout=300 \
  --limit-subp=shacl_ada-eval.ads:200 \
  --limit-subp=shacl_ada-eval.ads:222 \
  > proof/obj/proof-phase2.log
#  Phase 1 tolerates unproved checks only inside the two declared
#  marginal units; anything else fails the gate.
if grep "not proved," proof/obj/summary-phase1.out \
     | grep -vE "Proof_Eval\.Check_(Property|Kind) at shacl_ada-eval\.ads:"
then
  echo "SPARK phase 1: unproved checks outside the declared marginal units:" >&2
  grep "not proved," proof/obj/summary-phase1.out \
    | grep -vE "Proof_Eval\.Check_(Property|Kind) at shacl_ada-eval\.ads:" >&2
  exit 1
fi
#  Phase 2 must be fully clean.
if grep "not proved," proof/obj/gnatprove/gnatprove.out; then
  echo "SPARK phase 2: limit-subp proof incomplete:" >&2
  grep "not proved," proof/obj/gnatprove/gnatprove.out >&2
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
