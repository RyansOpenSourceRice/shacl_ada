# DESIGN.md

> **Audience:** the next maintainer re-deriving the architecture. Answers "why is this library shaped this way?" — not "what does it ship?" (that is `SPECIFICATION.md`).

## What this project is

A linkable W3C SHACL 1.0 Core validator in SPARK for Ada. The repository currently carries its standards, quality gates, crate scaffold, and tracked plan; the validator is the build-out that follows (`ROADMAP.md`).

## Why SPARK, and why an OS-free core

SHACL validation is a contract check: it either proves that a data graph conforms or produces the exact violations. A validator whose own behavior is unproven is a weak tool for that job. The design inverts the usual shape:

- The **validator core is a pure SPARK computation** over bounded memory — no I/O, no filesystem, no clock, no OS calls. Its inputs are in-memory graph and shape structures; its output is a report structure. Pure cores can be proven (gnatprove targets Silver: absence of runtime errors on the proved units), embedded (bare metal to servers), and reused (the same core under different parsers and report serializers).
- **Parsing stays at the edge.** RDF syntax handling comes from the sibling Ada RDF library `flyology_rdf` (decision: `flyology_rdf` as the RDF syntax layer). SHACL semantics are the hard, domain-specific part; RDF syntax is solved once. The validator consumes an already-built graph.

Consequences: the library links anywhere Ada links, its memory use is bounded by the input graph size, and the proof story covers the parts that matter — the semantic core.

## Why W3C SHACL 1.0 Core first

Core defines the shapes graph, the constraint components, and the validation-report vocabulary. Conformance against Core is checkable via the pinned W3C test suite (`corpora/`) and provable via SPARK. SHACL-AF adds rules, recursion control, annotations, and node expressions — a second language on top. AF is explicitly out of scope until Core is proven and conformant; extending a proven core beats proving twice the surface at once.

## Why Apache-2.0

Per preferences.md §18, libraries take the Apache family: corporate-friendly, linkable from proprietary and copyleft code alike, and the default that maximizes adoption for a component meant to be embedded in other tools. This is the documented per-project license switch the template convention expects (solutions take the GNU family; libraries do not). Recorded as `Decision: Apache-2.0 license` in `project.ontology.ttl`.

## Why GitHub as the hosting forge

The audience is Ada/SPARK and Alire users — an ecosystem whose discovery path (Alire index, GitHub-hosted crates, GitHub Actions CI) is GitHub-native. preferences.md §27 makes GitLab the default home for owned open-source projects and treats GitHub as a publishing/mirroring target; this library's discovery runs through the language ecosystem instead (§26: discovery via the language package index), so the forge follows the audience. The decision and the alternative are recorded in the ontology.

## Why the corpus is vendored in-tree with an integrity manifest

The corpus (w3c/data-shapes SHACL suite data) is vendored **in-tree**, as large formal projects vendor conformance corpora: a verbatim snapshot with recorded provenance (`corpora/PIN.md` — upstream URL, ref, commit, date, scope), a repeatable fetch/refresh script (`scripts/vendor-corpus.sh`), and an integrity manifest (`SHA256SUMS`) with a verify mode so any edit to the oracle data is detectable. The alternatives were rejected deliberately:

- **Git submodule** — rejected: clone friction (`--recurse-submodules` for every consumer), greyed-out data on the forge web UI, and awkward tool integration. The pin guarantee is preserved without those costs because the script records a real clone SHA and the manifest covers every file.
- **Fetch-on-demand in CI** — rejected: a conformance corpus that is not in the tree is not reproducible; a plain clone must carry everything needed to validate.
- **Automatic upstream re-pinning** — rejected: the pin *is* the contract; adopting a newer suite is a deliberate, reviewed change (script + PR). CI verifies integrity and reports drift on demand (`workflow_dispatch`), it never moves the pin.

The pre-commit hygiene hooks exclude the vendored paths from mutation — rewriting upstream data would break the manifest and the verbatim rule.

## Why pre-commit is the single gate

The `.pre-commit-config.yaml` is the only configuration for Gitleaks, spellcheck, and linting. CI runs `pre-commit run --all-files` against the same file (§9). A parallel CI/CD-only secret-scan or spell-check step was **rejected**: two configs for the same tool guarantee drift, and drift between what a developer runs locally and what gates their merge is treated as a bug.

## Why cspell + Vale, not Codespell

§9 names Codespell as the required spell-check tool; this project uses **cspell** (spelling) plus **Vale** (prose style) instead. Reasons:

- **cspell** covers project vocabulary (SHACL terms, Ada/Alire/GNAT names) via a checked-in word list and integrates with editors.
- **Vale** adds the grammar-style layer (banned promotional/AI-slop phrasing per §23, sentence-case headings, repeated words). Its style is self-contained (`styles/Template/`).

**This is a documented deviation from §9, pending an upstream preferences update (§34 is operator-driven).** When §9 changes, the ROADMAP drift row is removed.

## Why OpenGrep runs from a system binary

OpenGrep is the required static scanner (§29). It is not published on PyPI, and its upstream pre-commit hook file still installs the Semgrep package it forked from. So the project ships OpenGrep as a `repo: local` / `language: system` hook and installs the standalone binary explicitly (install script in CI, `CONTRIBUTING.md` for local setup). Fail-closed: without the binary, the hook fails rather than silently skipping the scan. Rules come from the pinned `p/security-audit` registry ruleset.

## Why the Ada toolchain job is not in CI yet

There is no implementation to compile. When the first validator code lands, an `alr build` + `gnatprove` job joins the pipeline (same shape as the other host-native jobs), and the pre-commit gate gains the Ada lint hooks that prove worth their setup cost. Until then the skip is documented here per §29 — not silently dropped.

## Why a pointer skill instead of a preferences copy

Copying `preferences.md` into this repository would require the §27 byte-identical sync rule on every upstream update — guaranteed drift. The pointer skill (`.agents/skills/ryans-ontology-access/`) routes agents to the global ontologies (Jena MCP servers) and this repo's ontology file instead.

## Root-directory budget

§29 targets at most 8 files and 8 directories at the root. This repository intentionally exceeds it: the standards files are the content a library repo needs at its root, and grouping them away would break the §29 convention that they live at the root. Overflow is documented here per §29; additions to the root get weighed against this budget. The `scripts/` directory (vendoring tooling) and `corpora/` (the in-tree corpus) were added against this budget and are each load-bearing: the script keeps re-pinning one command, and the corpus is what makes conformance reproducible.

## GitHub project-settings checklist (applied outside files)

Settings that cannot be expressed in-repo; apply them on the repository:

1. **Protected branches** — protect `main`: no direct pushes, PRs only from `dev`; require the `pre-commit` and `sast` checks to pass.
2. **Merge method** — squash merge only; linear history.
3. **Branch protection on `dev`** — PR-only push policy.
4. **Renovate** — enable the Renovate GitHub app; the single `renovate.json` needs no changes.
5. **Secrets** — `OPENROUTER_API_KEY` (or the ocr endpoint key) as a repository secret; nothing else.
6. **Private vulnerability reporting** — enable the GitHub security tab and private vulnerability reporting (`SECURITY.md` reporting path).
7. **Actions permissions** — default token `contents: read`; workflows declare their own least-privilege permission blocks.

## Rejected alternatives

- **GPL-family license** — rejected: link-time infection is the wrong default for a library meant to be embedded in third-party tools (§18).
- **Validator that parses RDF itself** — rejected: I/O and filesystem coupling make the core unprovable and impossible to embed; parsing belongs at the edge (`flyology_rdf`).
- **Core + SHACL-AF from day one** — rejected: AF doubles the surface before Core semantics are proven.
- **Separate CI-only Gitleaks/codespell steps** — rejected (drift, §9).
- **Codespell kept alongside cspell** — rejected; two spell-checkers is one too many.
- **Bundling the full preferences skill** — rejected (drift risk; see pointer-skill section).

## Open questions

- Which SPARK profile the report serializer takes (the report layer touches string building; whether it stays inside the proved core or sits beside it as a proven-input consumer is open until the report vocabulary lands).
- The Alire index submission path (community index vs. a maintained local index) — decided at the `alire-index` milestone, not before.
