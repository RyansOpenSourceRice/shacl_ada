# ROADMAP.md

What is planned, what is explicitly not being built, and the direction of the project. Updated **as part of the change** that shifts direction; stale entries are pruned, not left to accumulate. The canonical state is `project.ontology.ttl` (Milestone nodes); this file is the human-readable view.

## Direction

shacl_ada becomes the dependable Ada/SPARK building block for SHACL validation: a conformant W3C SHACL 1.0 Core validator whose core is pure SPARK (bounded memory, no I/O, OS-free) with proof-level assurance on the semantic core. It grows narrow and deep — Core only, proven — not wide.

## Planned

- **Vendor the pinned W3C SHACL test suite** — land the corpus in `corpora/` at the recorded pin (`corpora/README.md`), wired to the first conformance test run.
- **Shapes-graph parsing** — node shapes, property shapes, targets, and Core constraint parameters parsed from the graph provided by the RDF syntax layer.
- **Constraint evaluation engine** — the Core constraint components evaluated per the Recommendation's semantics, producing violations.
- **Validation-report vocabulary** — `sh:ValidationReport`/`sh:ValidationResult` output with severity, focus/value nodes, paths, and messages.
- **SPARK Silver proofs** — gnatprove over the validator core: absence of runtime errors on the proved units.
- **Ada toolchain CI job** — `alr build` + `gnatprove` job joins the pipeline with the first implementation commit.
- **Alire index publication** — submit the crate to the community index once Core is usable from a linkable build.
- **Preference-drift follow-up** — the switch from Codespell to cspell+Vale is a deviation from preferences.md §9 (which names Codespell). When §9 is updated upstream (operator-driven, §34), the DESIGN.md note is removed.
- **Ontology serializer tooling** — `tools/serializer` setup for the EDM Council `rdf-toolkit.jar` (OpenJDK 21+) so ontology commits ship standardized Turtle formatting, when the toolchain is available.

## Explicitly not building

- **No SHACL-AF.** Rules, recursion control, annotations, and node expressions are out of scope until Core is conformant and proven.
- **No RDF parsing inside the validator.** RDF syntax stays in the syntax layer (`flyology_rdf`); the core consumes built graphs.
- **No binary, server, CLI, or GUI.** shacl_ada is a library; applications embed it.
- **No container image.** An OS-free library has no runtime to containerize.
- **No scheduled CI on the shared forge.** Event-driven pipelines only; heavy or scheduled work belongs on owned hardware (§9 capacity awareness).
- **No documentation site.** README + the standards files are the documentation surface (§9).
- **No full copy of the preferences skill.** The pointer skill keeps agents on the global ontology; byte-identical preference copies would drift.

## Recently completed

- **2026.09.22** — bootstrap: standards files, pre-commit gate, GitHub Actions pipeline, issue/PR templates, Alire crate scaffold, project ontology with SHACL shapes, corpus pin policy, pointer skill. See `CHANGELOG.md` [2026.09.22.1].
