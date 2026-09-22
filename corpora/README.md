# Test corpus

> SPDX-License-Identifier: Apache-2.0
>
> Conformance corpus for shacl_ada: the pinned W3C SHACL test suite.

## Source

- Suite: [w3c/data-shapes](https://github.com/w3c/data-shapes) — the SHACL test-suite data and manifest that accompany the W3C SHACL 1.0 Recommendation.
- Semantic anchor: the W3C SHACL 1.0 Recommendation (20 July 2017). The suite commit to vendor is recorded in `PIN.md` at vendoring time (pin first, then vendor, so the corpus is reproducible).

## Pin policy

`PIN.md` records, for the vendored corpus: the upstream repository URL, the commit SHA, and the vendoring date. The corpus is vendored verbatim — no editorial changes to upstream test data; failures that turn out to be upstream issues are recorded here and handled in the conformance runner, not by editing the vendored files.

## Layout

When vendored:

```
corpora/
  PIN.md              # upstream URL, commit SHA, vendoring date
  data-shacl-test-suite/
    ...               # verbatim upstream tree
```

## License note

The vendored suite carries its upstream terms; before vendoring, the applicable upstream license text is added to `THIRD_PARTY_NOTICES.md` and this directory carries no license file of its own that would override it.
