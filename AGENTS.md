# AGENTS.md

> Validated AI-behavior guidance for this repository (preferences.md §28: a validated subset of the global skill). Validation date 2026-09-22, four-lens review (HR, Lawyer, open-source peer, job recruiter); no API keys, no personal data, no disparagement, no comparison claims found. Re-validate when the global preferences skill changes — drift between it and this file is a bug.

## Cold start — self-orient before working

1. Query the global preferences ontology: `jena` MCP server, Fuseki dataset `ryans-preferences` (SPARQL via `execute_sparql_query`, not raw hand-typed queries).
2. Query the global skill registry: `jena-conglomerate` MCP server, dataset `skill-conglomerate`.
3. Read `project.ontology.ttl` from this repo's root with the file read tool — extract project status, component states, decisions, lessons, milestones, blockers.

Do all three before doing work. Do not rely on memory from prior sessions.

## Rules of engagement

- **Identity.** Commits authorized by the operator use git author `RyansOpenSourceRice` with the GitHub noreply email (`RyansOpenSourceRice@users.noreply.github.com`). Anything written into shared artifacts refers to the operator by first name only ("Ryan"), never a last name. Shipped text uses a neutral, factual voice — no promotional register, no personhood-implying phrasing.
- **AI as a tool, not a person.** The output reads as the project's voice. Reversible low-stakes calls (format, naming, file location) are yours to make and get recorded in the end-of-response summary; consequential calls (scope, legal or public posture) are surfaced and awaited.
- **The gate.** `.pre-commit-config.yaml` is the single configuration for secrets (gitleaks), spelling (cspell), prose style (Vale), hygiene, and static analysis (OpenGrep). Run `pre-commit run --all-files` before declaring any change done. Never add a parallel CI-only config for these tools.
- **Forge etiquette.** This repository is inspected via a local clone, not via repeated GitHub API calls: clone once (shallow where sensible), work from the local copy, batch what must be batched (preferences.md §27, "clone, don't hammer").
- **Changelog with the change.** Every shipped change gets a `CHANGELOG.md` row as part of the same change. Direction shifts also update `ROADMAP.md`. Architecture changes update the docs (`DESIGN.md`, `SPECIFICATION.md`) in the same change.
- **Workflow.** Work lands on `dev`; `main` merges only via reviewed PR from `dev`. Rebase before merge (no merge commits); multi-commit PRs land squashed. Use the PR template in `.github/PULL_REQUEST_TEMPLATE.md`.
- **Ontology discipline.** `project.ontology.ttl` is working state: update components, decisions, lessons, milestones, and workflows as work progresses, committed alongside the change. Never store file contents, diffs, findings, vulnerabilities, or negative reviews in it (§36 guardrails). Do not invent domain classes without maintainer approval. The global ontologies are read-only to you — proposed preference changes go to the maintainer (§34).
- **Build and prove before claiming done.** `alr build` (and, once proofs land, `gnatprove`) must pass before an implementation change is declared complete. Until the Ada toolchain job exists in CI, this verification is local and on-demand — do not skip it silently; report what was and was not verified.
- **Self-review the full diff** before declaring done: no secrets, no dead code, no leftover debug output, no AI-fingerprint comments. Human review of the diff is not required; the gates (CI, lint, tests) are.
- **Anti-slop definition of done:** (A) builds/runs without errors, (B) linting passes, (C) tests pass, (D) the change is describable in plain language. A hallucination scan is optional but the first four are not.
- **Destructive operations.** Never delete repositories. No database or container deletion without explicit per-operation approval. Stay inside the designated development environment.
- **Secrets.** Never commit, echo, or log secrets. A key counts as leaked only when it enters committed repository history. LLM keys (`OPENROUTER_API_KEY`) belong in repository secrets or a secure local environment — never in files.
- **Scope guardrail.** These rules apply to projects the operator owns; on third-party repositories, that repository's norms take priority.
