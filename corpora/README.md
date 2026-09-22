# Test corpus

> SPDX-License-Identifier: Apache-2.0
>
> Conformance corpus for shacl_ada: the pinned W3C SHACL test suite, vendored in-tree so a plain clone carries everything needed to validate.

## Source

- Suite: [w3c/data-shapes](https://github.com/w3c/data-shapes) — the SHACL test-suite data and manifest that accompany the W3C SHACL 1.0 Recommendation.
- Semantic anchor: the W3C SHACL 1.0 Recommendation (20 July 2017). The vendored commit is recorded in `PIN.md` (the script records it from a real clone; the SHA is never written from memory).

## Layout

```
corpora/
  PIN.md                        # upstream URL, ref, commit, date, scope, rules
  SHA256SUMS                    # integrity manifest over the vendored tree
  data-shapes-test-suite/
    tests/                      # verbatim upstream tree (core/, sparql/, manifest.ttl)
```

The `tests/` scope covers the whole suite, including the SHACL-AF (`sparql/`) cases; scope selection (Core) is a runner concern, not a data-editing concern. The suite's website styling and implementation reports are not part of the corpus and are not vendored.

## Pin policy

- Vendoring and re-pinning go through `scripts/vendor-corpus.sh` (`--ref <sha|tag>` to pin a specific commit); it regenerates `PIN.md` and the manifest. Contributors never vendor — the corpus is already in the tree.
- Integrity: `SHA256SUMS` covers every vendored file; `scripts/vendor-corpus.sh --verify` rechecks it (CI does this on every change touching `corpora/`).
- Re-pinning is deliberate and reviewed: run the script with `--ref <sha>`, review the diff, land it as a PR. Upstream drift is checked on demand with the `workflow_dispatch` run of the `corpus` workflow — no scheduled jobs (§9).

## Verbatim rule

The vendored tree is upstream data, and the pre-commit hygiene hooks exclude it from mutation for that reason. Suspected upstream defects are recorded in `PIN.md` or handled in the conformance runner — never fixed by editing vendored files.

## License

The vendored suite carries its upstream terms, recorded in `THIRD_PARTY_NOTICES.md` (W3C Software and Document License). This directory carries no license file of its own that would override those terms.
