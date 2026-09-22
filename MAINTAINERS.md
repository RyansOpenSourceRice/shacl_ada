# MAINTAINERS.md

> **Scope:** boundaries, ownership, and "what this project does not do" for `shacl_ada`.

## Maintainer

- **Ryan** (`RyansOpenSourceRice` on GitHub) — sole maintainer.

## Scope

This project is a **linkable W3C SHACL 1.0 Core validator in SPARK for Ada**: shapes-graph parsing, constraint evaluation, and the validation-report vocabulary. Pure SPARK core — bounded memory, no I/O, OS-free.

## What this project does

- Validates data graphs against SHACL shapes graphs per the W3C SHACL 1.0 Recommendation (Core).
- Conforms against the pinned W3C SHACL test suite (`corpora/`).
- Provides an Alire-installable static library with a `pragma Pure` root package.
- Targets SPARK proof (gnatprove, Silver-level assurance on the proved units) for the validator core.

## What this project does not do

- **Does not implement SHACL-AF.** Advanced Features (rules, recursion control, annotations, node expressions) are out of scope until Core is conformant and proven; reopening them is a design decision, not a feature request.
- **Does not parse RDF itself.** RDF syntax handling comes from the RDF syntax layer (`flyology_rdf`, see `DESIGN.md`); the validator consumes an already-built graph. There is no file, socket, or database access in the core.
- **Does not ship a validator binary, server, CLI, or GUI.** It is a library; applications embed it and own their interfaces.
- **Does not carry side effects or global state.** The root package is `pragma Pure`; the core is reentrant and OS-free.
- **Does not enforce the maintainer's preferences on third-party repositories.** Scope guardrail from preferences.md §1.
- **Does not bundle the preferences or pointer skill.** Both are global assets with their home in `ryans-agentic-coding-preferences`; `AGENTS.md` carries agent orientation for this repository.

## Path to becoming a co-maintainer

Third-party contributions are welcome (see `CONTRIBUTING.md`). A co-maintainer gets write access after sustained, high-quality contributions to the validator core or conformance tooling plus agreement with the scope boundaries above. Changes to *what the project is* (scope, license, proof targets) stay with the maintainer; preference-level changes are mirrored upstream into `ryans-agentic-coding-preferences` first.

## Reporting issues

Use the issue forms in `.github/ISSUE_TEMPLATE/`. Issues are read and triaged; the maintainer reserves the right not to act on issues that conflict with the project's scope.

## Vulnerability disclosure

Follows `SECURITY.md` (100-day fix SLA framing, AI-use and model disclosure).

## Licensing

Apache-2.0. shacl_ada is a linkable library, so the Apache family applies (preferences.md §18); the reasoning is recorded in `DESIGN.md`.
