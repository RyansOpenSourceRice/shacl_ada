# SPECIFICATION.md

> **Audience:** a reviewer, tester, or downstream user who needs to know exactly what this repository provides without reading every file. Answers "what is the contract?" — not "why is it shaped this way?" (that is `DESIGN.md`).

## File inventory

| Path | Purpose |
|---|---|
| `.pre-commit-config.yaml` | The single quality gate (hooks specified below) |
| `cspell.json` | cspell word list, file globs, ignore paths |
| `.vale.ini` + `styles/Template/` | Vale prose style (self-contained) |
| `.github/workflows/pre-commit.yml` | CI gate — same hooks as local |
| `.github/workflows/sast.yml` | OpenGrep static analysis, fail-closed |
| `.github/workflows/review.yml` | AI diff review on PRs, non-blocking |
| `.github/workflows/corpus.yml` | Corpus integrity verify + on-demand upstream-drift check |
| `.github/workflows/scorecard.yml` | OpenSSF Scorecard supply-chain analysis, SARIF + public badge |
| `.github/workflows/ada.yml` | Ada toolchain job: `alr build`, gnatprove over the SPARK core, tests + conformance smoke |
| `.github/ISSUE_TEMPLATE/` | `bug_report.yml`, `feature_proposal.yml`, `config.yml` |
| `.github/PULL_REQUEST_TEMPLATE.md` | Default PR description template |
| `alire.toml` | Alire crate descriptor |
| `shacl_ada.gpr` | GNAT library project |
| `src/` | Pure SPARK core: root package, bounded term model (`SHACL_Ada.Terms`), shapes-graph model (`SHACL_Ada.Shapes`), constraint-evaluation engine (`SHACL_Ada.Eval`) |
| `boundary/` | `SHACL_Ada.Rdf` — flyology_rdf adapter: Turtle loading and shapes-graph extraction (`SPARK_Mode (Off)`) |
| `proof/spark_core.gpr` | SPARK-only proof project: gnatprove sees `src/` only, never the boundary or dependencies |
| `tests/` | Test crate (pinned path dependency): `shapes_tests` extraction assertions, `conformance` corpus smoke runner |
| `project.ontology.ttl` | Project ontology (§36 scaffold + working instance layer) |
| `validation/shapes.ttl` | SHACL shapes for the ontology |
| `corpora/README.md` | Test-corpus policy: source, pin, layout, verbatim rule |
| `corpora/PIN.md` | Recorded pin: upstream URL, ref, commit, date, scope (generated) |
| `corpora/SHA256SUMS` | Integrity manifest over the vendored tree (generated) |
| `corpora/data-shapes-test-suite/tests/` | Vendored W3C suite data — verbatim upstream |
| `scripts/vendor-corpus.sh` | Vendoring/refresh script: `--ref <sha|tag>` to re-pin, `--verify` for integrity |
| `scripts/verify.sh` | Local-first gate: build, two-phase proof, tests, conformance smoke, corpus suite |
| `CHANGELOG.md` | Keep a Changelog, CalVer `YYYY.MM.DD.N` |
| `CONTRIBUTING.md` | Workflow, gate, AI-contribution rules |
| `MAINTAINERS.md` | Scope, ownership, non-goals |
| `ROADMAP.md` | Planned / not-building / direction |
| `DESIGN.md` | The why |
| `SPECIFICATION.md` | This file |
| `SECURITY.md` | Reporting path, 100-day SLA, AI disclosure |
| `AGENTS.md` | AI behavior guidance |
| `marketing.md` | Audience and skill-level context |
| `THIRD_PARTY_NOTICES.md` | Open-source license disclosure |
| `.gitignore` | Non-empty; caches and build artifacts |
| `renovate.json` | Single Renovate config |
| `README.md` | Badges, status, file map |
| `LICENSE` | Apache-2.0 |

## Repository contract (bootstrap state)

This repository ships its standards, gates, crate scaffold, and tracked plan. It does **not** yet ship a validator: `src/shacl_ada.ads` is a `pragma Pure` package stub establishing the crate boundary. The implementation contract below is the target the roadmap builds toward; each milestone lands with its specification rows in this file as part of the change that implements it.

## Pre-commit contract

Running `pre-commit run --all-files` enforces, in one invocation:

| Hook | Enforces |
|---|---|
| `gitleaks` v8.30.1 | No secrets in any commit |
| `cspell` v10.2.0 | No unrecognized words (per `cspell.json`) |
| `vale` v3.20.0 | Prose style on `*.md`: banned promotional/AI-slop phrasing (error), sentence-case headings (suggestion), repeated words (warning) |
| `trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-added-large-files` (pre-commit-hooks v6.0.0) | Standard hygiene |
| `opengrep` (system binary) | Static analysis with the pinned `p/security-audit` ruleset; fails on findings (`--error`) |
| `open-code-review` | AI diff review; **manual stage only**, run with `pre-commit run open-code-review --hook-stage manual`; requires a configured LLM endpoint or the OpenCode extension |

Contract rules: this file is the only configuration for gitleaks/spellcheck/lint (no parallel CI-only steps); opengrep fails closed when the binary is missing; the ocr hook never blocks a local commit.

## CI contract (GitHub Actions)

Workflows run in parallel, all `contents: read`, concurrency-cancelled per ref:

| Workflow | Trigger | Behavior |
|---|---|---|
| `pre-commit` | push to `main`/`dev`, PRs | The gate — same hooks as local |
| `sast` | push to `main`/`dev`, PRs | OpenGrep over the repo, fails on findings |
| `review` | PRs only | `ocr review` against the PR base; skips itself without `OPENROUTER_API_KEY`; `continue-on-error: true` |
| `corpus` | push/PR touching `corpora/**` or the vendor script; `workflow_dispatch` | PRs/pushes: run `vendor-corpus.sh --verify` (integrity). Dispatch: compare pinned commit with the upstream tip and report drift — no scheduled jobs (§9) |
| `scorecard` | push to `main`, `workflow_dispatch` | OpenSSF Scorecard analysis; SARIF to code scanning and results published for the public badge. Event-driven only — no scheduled jobs (§9). No PR runs: the action publishes results only on push events |
| `ada` | push to `main`/`dev`, PRs | `alr build` over the crate, the two-phase `gnatprove -U --level=3 --timeout=300` proof over `proof/spark_core.gpr` (full run plus `--limit-region` re-proof of two context-explosive postconditions; phase 1 tolerates unproved checks only inside those two instantiated units, phase 2 proves clean), `shapes_tests`, the `conformance` smoke run, and the `eval_tests` corpus suite over the vendored corpus |

Skipped-by-design jobs (documented per §29, added when they apply): `container` (no container ships — OS-free library) and `dynamic` (no runtime to probe).

## Alire crate contract

- `alire.toml`: crate `shacl_ada`, version `0.1.0-dev` (SemVer for libraries, §9/§26), license `Apache-2.0`, description matching the repo's published description.
- `shacl_ada.gpr`: static library project over `src/` (proved core) and `boundary/` (RDF adapter); library interface `SHACL_Ada`, `SHACL_Ada.Terms`, `SHACL_Ada.Shapes`, `SHACL_Ada.Rdf`.
- Runtime dependency: `flyology_rdf` (and transitively `flyology_iri`) from the flyology-ada Alire index; licenses disclosed in `THIRD_PARTY_NOTICES.md`. Proof scope excludes it: `gnatprove` runs over `proof/spark_core.gpr` only.
- `src/shacl_ada.ads`: root package, `pragma Pure` — the OS-free, stateless library boundary.
- Build verification via `alr build` is deferred to the first implementation commit (no Ada toolchain in the pipeline yet; documented skip in `DESIGN.md`).

## Ontology contract

- File: `project.ontology.ttl` at the repo root; namespace `https://github.com/RyansOpenSourceRice/shacl_ada/onto#`.
- Defines the 10 §36 core classes (`Project`, `Component`, `Milestone`, `Decision`, `LessonLearned`, `Workflow`, `Person`, `Locale`, `TestSuite`, `Blocker`) as `owl:Class` with `skos:prefLabel` + `skos:definition`; relationships as typed object/data properties.
- Status vocabularies follow §36 (e.g. Project: `planning → in-development → beta → stable → maintenance → archived`).
- Semantic version `1.0.0` recorded on the ontology node; independent of the repo's CalVer release version.
- `validation/shapes.ttl` requires: SKOS annotations on classes and properties, required properties per class (names, status, rationale, dates).
- The instance layer is working state: components, milestones, decisions, lessons, and workflows update alongside the changes they describe.

## Test-corpus contract

- `corpora/data-shapes-test-suite/tests/` holds the vendored W3C SHACL suite data, verbatim from `w3c/data-shapes` (whole `tests/` scope — the `sparql/` SHACL-AF cases ride along unexecuted; Core selection is a runner concern).
- `corpora/PIN.md` records upstream URL, vendored ref, commit SHA (from a real clone, never from memory), date, scope, and the verbatim rule. `corpora/SHA256SUMS` covers every vendored file.
- Vendoring/re-pinning goes through `scripts/vendor-corpus.sh`; integrity is checked by `scripts/vendor-corpus.sh --verify` locally and by the `corpus` CI workflow on changes. Upstream-drift checking is on-demand (`workflow_dispatch`).
- The corpus is excluded from mutating pre-commit hooks and local linting — it is upstream data (§29 documented skip for the vendored paths).
- The `conformance` smoke runner parses a corpus shapes graph (with a `file://` base IRI — the corpus uses relative IRIs) and reports quad/shape/target counts; full per-test conformance runs land with the constraint-engine milestone.

## Conformance target

W3C SHACL 1.0 Recommendation — shapes graph semantics, constraint components, and validation-report vocabulary as published 20 July 2017. Deviations, if any, are recorded in this file at implementation time, not silently absorbed.

## Conformance deviations

Recorded deviations, each also documented where the code carries it:

- **`sh:inversePath` accepts a single predicate argument.** The Recommendation permits any path as the argument; a compound argument evaluates as yielding no values. The bounded path walker does not carry the candidate enumeration a general inversion needs, and no suite case exercises one.
- **Path evaluation runs under a step fuel.** Each path computation processes at most `Max_Path_Work` (512) work items; a path expanding past the fuel evaluates over the visited prefix, and the computation's `Overflow` flag reports exhaustion. Cyclic data terminates on the fuel, not on cycle detection.
- **An ill-formed path validates nothing.** A property shape whose `sh:path` does not resolve into a path expression is treated as validating nothing rather than as a shapes-graph failure; extraction does not raise for it.
- **`sh:pattern` implements a bounded regex subset** — literals, `.`, character classes with ranges and negation, backslash escapes, the `*`/`+`/`?` quantifiers, `^`/`$` anchors, and the case-insensitivity flag — not the full XSD regular-expression surface.
- **XSD numeric comparison approximates** beyond 18 significant mantissa digits and caps exponents at `2**20`; the corpus and ordinary datasets compare exactly.

## Versioning

- Repo releases: CalVer `YYYY.MM.DD.N` (preferences.md §9); the `CHANGELOG.md` carries the versions.
- The crate carries SemVer (`0.1.0-dev`), independent of repo releases (§26).
- The ontology carries its own SemVer (`1.0.0`), independent of both (§33).
- The README version badge tracks the current repo release.

## License

Apache-2.0 (see `LICENSE`), documented as a design decision in `DESIGN.md` per §18 (libraries take the Apache family).
