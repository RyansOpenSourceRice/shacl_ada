# shacl_ada

[![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/version-2026.09.22.1-blue?style=flat-square)](CHANGELOG.md)
[![Status](https://img.shields.io/badge/status-bootstrap%20--%20no%20implementation%20yet-orange?style=flat-square)](ROADMAP.md)
[![Pre-commit](https://img.shields.io/badge/pre--commit-gitleaks%20%7C%20cspell%20%7C%20Vale%20%7C%20OpenGrep%20%7C%20ocr-purple?style=flat-square)](.pre-commit-config.yaml)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions%20%7C%20pre--commit%20gate%20%7C%20SAST-orange?style=flat-square)](.github/workflows/pre-commit.yml)
[![Renovate](https://img.shields.io/badge/Renovate-one%20config%20%7C%20pinned%20digests-green?style=flat-square)](renovate.json)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/badge/github/RyansOpenSourceRice/shacl_ada?style=flat-square)](https://github.com/ossf/scorecard)
[![Ontology](https://img.shields.io/badge/ontology-project.ontology.ttl%20%7C%20SHACL-yellow?style=flat-square)](project.ontology.ttl)
[![Standards](https://img.shields.io/badge/standards-CHANGELOG%20%7C%20MAINTAINERS%20%7C%20DESIGN%20vs%20SPECIFICATION%20%7C%20ROADMAP-orange?style=flat-square)](MAINTAINERS.md)

W3C SHACL 1.0 Core validator in SPARK for Ada: shapes-graph parsing, constraint evaluation, and validation-report vocabulary. Bounded memory, no I/O, OS-free.

## Status

Bootstrap. The repository carries its standards, quality gates, crate scaffold, tracked plan, and the vendored conformance corpus; the validator itself is not implemented yet. The build order lives in `ROADMAP.md` (shapes-graph parsing → constraint evaluation → report vocabulary → SPARK proofs → Alire index publication).

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
