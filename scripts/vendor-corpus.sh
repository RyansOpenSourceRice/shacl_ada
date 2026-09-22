#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# scripts/vendor-corpus.sh — vendor the pinned W3C SHACL test suite.
#
# Maintainer-only tool: the corpus is already vendored in the tree, so
# contributors never run this. Use it to re-pin the corpus when upstream
# moves, or to check integrity in CI:
#
#   scripts/vendor-corpus.sh                    # vendor at the upstream default branch tip
#   scripts/vendor-corpus.sh --ref <sha|tag>    # vendor at a specific upstream commit
#   scripts/vendor-corpus.sh --verify           # check the tree against corpora/SHA256SUMS
#
# Generated artifacts (regenerated on every vendor, never edited by hand):
#   corpora/PIN.md      — upstream URL, commit, date, scope, rules
#   corpora/SHA256SUMS  — integrity manifest over the vendored tree

set -euo pipefail

UPSTREAM="https://github.com/w3c/data-shapes"
DEFAULT_REF="gh-pages"
SUITE_DIR="data-shapes-test-suite"
CORPORA="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/corpora"
VENDORED="$CORPORA/$SUITE_DIR"
PIN="$CORPORA/PIN.md"
MANIFEST="$CORPORA/SHA256SUMS"

usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//'; }

mode="vendor"
ref="$DEFAULT_REF"
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="${2:?--ref needs a value}"; shift 2 ;;
    --verify) mode="verify"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1 (see --help)" >&2; exit 2 ;;
  esac
done

if [ "$mode" = "verify" ]; then
  [ -f "$PIN" ] || { echo "corpus not vendored: $PIN missing" >&2; exit 1; }
  [ -f "$CORPORA/SHA256SUMS" ] || { echo "integrity manifest missing: $CORPORA/SHA256SUMS" >&2; exit 1; }
  (cd "$CORPORA" && sha256sum --check SHA256SUMS) >&2
  echo "corpus integrity OK: $(wc -l < "$CORPORA/SHA256SUMS") files match the manifest"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "cloning $UPSTREAM (blobless, no checkout) ..."
git clone --filter=blob:none --no-checkout "$UPSTREAM" "$TMP/upstream" >/dev/null
git -C "$TMP/upstream" sparse-checkout init --cone
git -C "$TMP/upstream" sparse-checkout set "$SUITE_DIR/tests"
git -C "$TMP/upstream" checkout "$ref" >/dev/null 2>&1
SHA="$(git -C "$TMP/upstream" rev-parse HEAD)"

rm -rf "$VENDORED"
mkdir -p "$VENDORED"
cp -a "$TMP/upstream/$SUITE_DIR/tests" "$VENDORED/tests"

(cd "$CORPORA" && find "$SUITE_DIR" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)

cat > "$PIN" <<EOF
# Corpus pin

> SPDX-License-Identifier: Apache-2.0
>
> Provenance of the vendored corpus in \`$SUITE_DIR/\`. Regenerate with
> \`scripts/vendor-corpus.sh\`; never edit this file or the vendored tree by hand.

- Upstream: $UPSTREAM
- Ref vendored: $ref
- Commit: $SHA
- Vendored on: $(date -u +%F)
- Vendored paths: \`$SUITE_DIR/tests/\` (verbatim)
- Semantic anchor: W3C SHACL 1.0 Recommendation, 20 July 2017
- Integrity: \`SHA256SUMS\` beside this file; recheck with \`scripts/vendor-corpus.sh --verify\`

## Rules

- The vendored tree is verbatim upstream data. Suspected upstream defects are
  recorded here or handled in the conformance runner, never fixed by editing
  vendored files.
- Re-pinning is deliberate: run \`scripts/vendor-corpus.sh --ref <sha>\`, review
  the diff, and land it as a reviewed change. The pin is part of the
  conformance contract and moves only through a reviewed pull request.
EOF

echo "vendored $SUITE_DIR/tests at commit $SHA"
echo "  $(find "$VENDORED" -type f | wc -l) files, manifest $CORPORA/SHA256SUMS"
