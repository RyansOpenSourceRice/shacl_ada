# shacl_ada

[![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/version-2026.10.06.2-blue?style=flat-square)](CHANGELOG.md)
[![Status](https://img.shields.io/badge/status-path%20expressions%20landed-yellow?style=flat-square)](ROADMAP.md)
[![Pre-commit](https://img.shields.io/badge/pre--commit-gitleaks%20%7C%20cspell%20%7C%20Vale%20%7C%20OpenGrep%20%7C%20ocr-purple?style=flat-square)](.pre-commit-config.yaml)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions%20%7C%20pre--commit%20gate%20%7C%20SAST-orange?style=flat-square)](.github/workflows/pre-commit.yml)
[![Renovate](https://img.shields.io/badge/Renovate-one%20config%20%7C%20pinned%20digests-green?style=flat-square)](renovate.json)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/RyansOpenSourceRice/shacl_ada/badge)](https://scorecard.dev/viewer/?uri=github.com/RyansOpenSourceRice/shacl_ada)
[![Ontology](https://img.shields.io/badge/ontology-project.ontology.ttl%20%7C%20SHACL-yellow?style=flat-square)](project.ontology.ttl)
[![Standards](https://img.shields.io/badge/standards-CHANGELOG%20%7C%20MAINTAINERS%20%7C%20DESIGN%20vs%20SPECIFICATION%20%7C%20ROADMAP-orange?style=flat-square)](MAINTAINERS.md)

W3C SHACL 1.0 Core validator in SPARK for Ada: shapes-graph parsing, constraint evaluation, and validation-report vocabulary. Bounded memory, no I/O, OS-free.

## Status

Constraint evaluation is implemented: the engine (`SHACL_Ada.Eval`) evaluates node and property shapes over the full Core path grammar (§6: predicate, inverse, sequence, alternative, and the three cardinality forms) and records violations into a caller-sized table, with shape-link recursion bounded by `Max_Depth` and path walking bounded by a step fuel. The whole `src/` core (`SHACL_Ada.Terms`, `SHACL_Ada.Shapes`, `SHACL_Ada.Eval`) is proved by gnatprove at level 3 through `proof/spark_core.gpr` (two-phase: the full run plus `--limit-subp` re-proof of two context-explosive postconditions); `scripts/verify.sh` runs the same gate locally before every push. The `boundary/` adapter loads Turtle via [`flyology_rdf`](https://github.com/flyology-ada/flyology-rdf) and extracts shapes, targets, path expressions, and Core constraint parameters; the test crate runs extraction assertions and a corpus runner over 86 vendored suite cases. Next — the build order lives in `ROADMAP.md` (report vocabulary → SPARK Silver → Alire index publication).

## What it will do

- **Shapes-graph parsing** — node shapes, property shapes, targets, and Core constraint parameters parsed from a graph built by the RDF syntax layer (`flyology_rdf`, see `DESIGN.md`).
- **Constraint evaluation** — the W3C SHACL 1.0 Core constraint components evaluated per the Recommendation's semantics; SHACL-AF is out of scope (see `MAINTAINERS.md`).
- **Validation-report vocabulary** — `sh:ValidationReport` and `sh:ValidationResult` output with severity, focus/value nodes, result paths, and messages.
- **SPARK guarantees** — the validator core is pure SPARK: bounded memory, no I/O, no OS calls; gnatprove targets Silver-level assurance (absence of runtime errors) on the proved units.

## Using the repository

- Conformance testing runs against the W3C SHACL test suite, vendored in `corpora/` at a recorded pin (`corpora/PIN.md`); integrity is verified by `scripts/vendor-corpus.sh --verify` and CI.
- The crate is built and consumed through [Alire](https://alire.ada.dev/); the descriptor is `alire.toml`.
- Contributions follow `CONTRIBUTING.md`; AI agents follow `AGENTS.md`.

## File map

| Path | Purpose |
|---|---|
| `.pre-commit-config.yaml` | The single quality gate (§29) |
| `.github/workflows/` | Host-native CI: pre-commit gate, SAST, AI review, corpus integrity, Scorecard |
| `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE.md` | Issue and PR templates |
| `alire.toml`, `shacl_ada.gpr`, `src/` | Alire crate descriptor, GNAT project, package stub |
| `project.ontology.ttl` | The project ontology (§36) |
| `validation/shapes.ttl` | SHACL shapes for the ontology |
| `corpora/` | Vendored W3C SHACL suite at a recorded pin (`PIN.md`, `SHA256SUMS`) |
| `scripts/` | Maintainer tooling (`vendor-corpus.sh`) |
| `CHANGELOG.md`, `CONTRIBUTING.md`, `MAINTAINERS.md`, `ROADMAP.md` | Repo standards |
| `DESIGN.md`, `SPECIFICATION.md` | The why and the what |
| `SECURITY.md`, `AGENTS.md`, `marketing.md` | Disclosure, AI guidance, audience context |
| `THIRD_PARTY_NOTICES.md` | Open-source license disclosure (§29) |
| `renovate.json` | Dependency updates (single config, runs anywhere) |

## License

Apache-2.0 (see `LICENSE`). shacl_ada is a linkable library, so the Apache family applies (preferences.md §18); the reasoning is recorded in `DESIGN.md`.
