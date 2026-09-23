# Changelog

All notable changes to this project are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/) conventions (`Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`). Versions use CalVer `YYYY.MM.DD.N` (release date, daily counter), the same scheme across all owned projects (preferences.md §9). Every shipped change gets its row **as part of the change**, not retroactively before release.

## [Unreleased]

## [2026.09.22.4] — 2026-09-22

OpenSSF Scorecard wired into CI, and repository settings brought to the applied state: the failing Copilot-license check is gone, both branch rulesets are live, and the README loses its internal meta-section.

### Added

- `.github/workflows/scorecard.yml` — OpenSSF Scorecard analysis on every push to `main`/`dev`, PRs, and on demand; SARIF uploaded to code scanning, results published for the public badge. Event-driven only — no scheduled cron (§9). Actions are tag-pinned (Renovate converts to digest pins).
- README — OpenSSF Scorecard badge in the badge row.

### Changed

- `README.md` — the "Why DESIGN.md and SPECIFICATION.md are separate" section removed: a README targets developers evaluating the library; internal doc-explainer content stays in the docs themselves. The `.github/workflows/` file-map row now lists Scorecard.
- `SPECIFICATION.md` — file inventory and CI contract rows for the `scorecard` workflow.
- Fix during review: `scorecard-action` pinned to the `v2.4.4` commit digest `2d114668` (the rolling `@v2` tag does not exist upstream), and the `pull_request` trigger dropped — the action publishes results only on push events.
- `DESIGN.md` — why the Scorecard is event-driven only (§9); the project-settings section rewritten to the applied state: rulesets `Protect Main` (PR + required checks + linear history + squash-only + no force-push/deletion) and `dev` (no force-push/deletion; operator pushes `dev` directly), and the code-scanning default setup disabled.
- `project.ontology.ttl` — CI workflow description includes Scorecard; new decision `decision-scorecard` (benchmark per §9, event-driven per operator decision).
- `cspell.json` — `scorecard`, `ossf`, `sarif` added to the word list.

### Removed

- Code-scanning default setup (repository setting, outside files) — GitHub's bundled AI code review requires a Copilot license and failed 403 on every PR; its CodeQL component only analyzed Actions files. Static analysis remains the `sast`/OpenGrep job; Scorecard SARIF has its own upload step.

## [2026.09.22.3] — 2026-09-22

Pointer skill removed from the repository. `.agents/skills/ryans-ontology-access/` was copied in at bootstrap from the template's file set, but the skill is a global asset whose only home is `ryans-agentic-coding-preferences`; bundling it per-repo multiplies a drift-prone file. Agent orientation for this repository is carried entirely by `AGENTS.md`.

### Removed

- `.agents/skills/ryans-ontology-access/` — the pointer skill routing agents to the global ontologies. It stays in its single home (`ryans-agentic-coding-preferences`); project repos must not carry copies.

### Changed

- `.pre-commit-config.yaml` — Vale exclude reduced to the vendored-corpus pattern; the `.agents/` clause is gone with the directory.
- `cspell.json` — `.agents/**` removed from ignore paths.
- `DESIGN.md` — the pointer-skill section rewritten as the no-bundled-skills rationale (drift for `preferences.md`, global-asset ownership for the skill); rejected-alternatives bullet reworded.
- `SPECIFICATION.md`, `README.md` — file-inventory rows for the skill removed.
- `MAINTAINERS.md`, `ROADMAP.md` — non-goal statements now cover both the preferences skill and the pointer skill; both are global assets, `AGENTS.md` carries orientation.
- `project.ontology.ttl` — `component-pointer-skill` removed; the decision rewritten as `decision-no-bundled-skills` ("No preferences or pointer skill bundled in project repos"), documenting the removal as the alternative now adopted.

## [2026.09.22.2] — 2026-09-22

Corpus vendored in-tree. This release lands the `corpus-vendor` milestone: the W3C SHACL test suite is now pinned, vendored, integrity-checked, and refreshable by script — before any validator code exists, so the shapes-parsing work that follows is test-driven from day one.

### Added

- `corpora/data-shapes-test-suite/tests/` — the W3C SHACL suite data, vendored verbatim from `w3c/data-shapes` (150 files: `core/` cases, the `sparql/` SHACL-AF cases, `manifest.ttl`). Whole-suite scope; Core selection is a runner concern, not a data edit.
- `corpora/PIN.md` — recorded pin: upstream URL, ref (`gh-pages`), commit `c0b949e`, vendoring date, vendored-path scope, semantic anchor (W3C SHACL 1.0 Recommendation, 20 July 2017), and the verbatim rule.
- `corpora/SHA256SUMS` — integrity manifest over the vendored tree.
- `scripts/vendor-corpus.sh` — vendoring/refresh script: `--ref <sha|tag>` to re-pin, `--verify` to check integrity. Uses a blobless partial clone and records the commit SHA from a real clone (never from memory).
- `.github/workflows/corpus.yml` — CI integrity verification on changes touching `corpora/` or the vendor script, plus an on-demand (`workflow_dispatch`) upstream-drift check. No scheduled jobs (§9).

### Changed

- `corpora/README.md` — rewritten for the real layout: upstream path (`data-shapes-test-suite/tests/`), generated artifacts, vendoring workflow, and the verbatim rule.
- `.pre-commit-config.yaml` — the vendored corpus is excluded from the mutating hygiene hooks (trailing-whitespace, end-of-file-fixer) and from Vale: upstream data is verbatim, and rewriting it would break the manifest.
- `cspell.json` — ignore paths extended for the vendored tree.
- `THIRD_PARTY_NOTICES.md` — the W3C Software and Document License entry for the vendored suite (replaces the anticipated-entry placeholder).
- `SPECIFICATION.md` — file inventory, CI contract (`corpus` workflow), and test-corpus contract updated for the vendored state.
- `ROADMAP.md` — `corpus-vendor` moved to Recently completed; shapes-graph parsing is next and is annotated as the first implementation commit (Ada toolchain job + conformance runner wiring).
- `DESIGN.md` — corpus vendoring rationale (in-tree snapshot + manifest, rejected alternatives: submodule, fetch-on-demand, auto re-pinning); root-budget note for `scripts/` and `corpora/`.
- `project.ontology.ttl` — `corpus-vendor` milestone complete; test-corpus component description updated; CI workflow description includes the corpus job.

## [2026.09.22.1] — 2026-09-22

Bootstrap. This release establishes the repository's standards, quality gates, crate scaffold, and tracked plan. The validator itself is not implemented yet; the build order lives in `ROADMAP.md`.

### Added

- `CHANGELOG.md` (this file) — Keep a Changelog format, CalVer versions.
- `CONTRIBUTING.md` — dev→main workflow, pre-commit gate, AI-contribution rules, changelog/roadmap-with-change rules.
- `.pre-commit-config.yaml` — the single gate: Gitleaks, cspell (spelling), Vale (prose style), standard hygiene hooks, OpenGrep (static analysis), open-code-review (AI diff review, manual stage).
- `cspell.json` — project word list (SHACL, Ada/SPARK/Alire/GNAT vocabulary) and ignore paths for the spelling gate.
- `.vale.ini` + `styles/Template/` — self-contained prose style: banned promotional/AI-slop phrasing, sentence-case headings, repeated-word detection.
- `.github/workflows/pre-commit.yml` — the gate: `pre-commit run --all-files` on push to `main`/`dev` and on PRs.
- `.github/workflows/sast.yml` — OpenGrep static analysis, fail-closed.
- `.github/workflows/review.yml` — AI diff review on PRs (open-code-review), skips without `OPENROUTER_API_KEY`, non-blocking.
- `.github/ISSUE_TEMPLATE/` — bug report and feature proposal issue forms; `config.yml` routes security reports to private vulnerability reporting.
- `.github/PULL_REQUEST_TEMPLATE.md` — default PR template; enforces the changelog/roadmap/ontology-update checklist and AI-assistance disclosure.
- `alire.toml` — Alire crate descriptor: `shacl_ada`, `0.1.0-dev`, Apache-2.0, published description.
- `shacl_ada.gpr` — GNAT static library project over `src/`.
- `src/shacl_ada.ads` — root package stub (`pragma Pure`) establishing the crate boundary.
- `project.ontology.ttl` — per-repo project ontology (preferences.md §36): the 10 core classes as OWL 2 DL with SKOS annotations, and this project's working instance layer.
- `validation/shapes.ttl` — SHACL shapes validating the ontology's structural constraints.
- `corpora/README.md` — test-corpus pin policy: source suite, semantic anchor (W3C SHACL 1.0 Recommendation, 20 July 2017), pin-first rule, verbatim vendoring.
- `README.md` — rewritten for the library's audience with shields.io badges, status, build order, and file map.
- `MAINTAINERS.md` — scope, ownership, non-goals, co-maintainer path.
- `ROADMAP.md` — planned, explicitly not building, and direction.
- `DESIGN.md` — the why: OS-free SPARK core, Core-first scope, Apache-2.0 per §18, GitHub as hosting forge, `flyology_rdf` as the RDF syntax layer, pre-commit-as-gate, cspell+Vale over codespell, OpenGrep via system binary, root-budget overflow note, GitHub project-settings checklist, and skip reasons for jobs that do not apply.
- `SPECIFICATION.md` — the what: file inventory, pre-commit contract, CI contract, crate contract, ontology contract, corpus contract, conformance target, versioning.
- `SECURITY.md` — vulnerability reporting, 100-day fix SLA framing, AI-use and model disclosure.
- `AGENTS.md` — validated AI behavior guidance for this repo: cold-start self-orientation, gate rules, and update discipline.
- `marketing.md` — audience and skill-level context for AI agents.
- `THIRD_PARTY_NOTICES.md` — open-source license disclosure (§29): Apache-2.0 project, no third-party code yet, anticipated corpus entry.
- `.gitignore` — tool caches, editor state, Ada/Alire build artifacts.
- `renovate.json` — single Renovate config (one file, runs anywhere): Dependency Dashboard, pinned digests, OSV vulnerability alerts, grouped non-breaking updates, automerge for patch and dev-dependency updates.
- `.agents/skills/ryans-ontology-access/SKILL.md` — pointer skill routing agents to the global ontologies (Apache Jena MCP servers) and the project ontology file, instead of a drift-prone preferences copy.

### Security

- Gitleaks scans every commit for secrets through the pre-commit gate, locally and in CI.
- OpenGrep static analysis runs in CI on every push.
- Actions workflows declare least-privilege `permissions: contents: read`.
- Repository secrets that carry LLM keys (`OPENROUTER_API_KEY`) stay masked and scoped to the `review` workflow, which skips itself when the key is absent.
