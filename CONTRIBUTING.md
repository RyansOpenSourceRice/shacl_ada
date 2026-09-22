# CONTRIBUTING.md

Thanks for considering a contribution. Read this file, then `MAINTAINERS.md` (scope), `SECURITY.md` (vulnerability reporting), and `AGENTS.md` (AI behavior guidance) before opening anything. Issues use the forms in `.github/ISSUE_TEMPLATE/`; pull requests use `.github/PULL_REQUEST_TEMPLATE.md`.

Contribution posture: third-party contributions are welcome through the workflow below.

## Branching and merge flow

- `main` is the protected default branch; `dev` is the integration branch. New work lands in `dev` first (preferences.md §18).
- Direct pushes to `main` are blocked. Merges to `main` happen only via reviewed pull requests from `dev`.
- **Rebase before merge.** Linear history on `main` is required; no merge commits in pull requests.
- **Squash on merge.** A multi-commit PR lands as a single commit on `main`, keeping history legible; each landed change is one reviewable unit.

## The pre-commit gate

The checked-in `.pre-commit-config.yaml` is the only configuration for Gitleaks, spellcheck, and linting — locally and in CI (preferences.md §9). Run it before pushing:

```bash
pipx install pre-commit     # or: uv tool install pre-commit
pre-commit install
pre-commit run --all-files
```

Tool setup notes:

- **Node.js ≥ 22.18** is required for the cspell hook (cspell v10 checks and refuses older versions).
- **OpenGrep** ships as a standalone binary:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/opengrep/opengrep/main/install.sh | bash
  ```
- **open-code-review** (`ocr`) runs only on explicit request (`pre-commit run open-code-review --hook-stage manual`). It needs an LLM endpoint: an `OPENROUTER_API_KEY` provided securely, or an OpenAI/Anthropic-compatible endpoint. If you do not have a key, skip the hook — CI surfaces the `review` workflow on pull requests.
- **Vale** and **cspell** are installed by pre-commit; the Vale style lives in `styles/Template/`.

The CI pipeline runs the same suite (`pre-commit run --all-files`) as its gate. If a hook fails in CI but passed locally, the environments differ — fix the config, not the gate.

## Ada toolchain (contributors)

The crate builds and tests through [Alire](https://alire.ada.dev/):

```bash
alr build
alr run        # when targets exist
gnatprove      # when proofs land, per ROADMAP.md
```

The CI pipeline runs the pre-commit and SAST gates on every push; the Ada toolchain job (`alr build` + `gnatprove`) joins the pipeline with the first implementation commit. Until then, build verification is local and on-demand.

## What changes require what

- **Every change** ships with a `CHANGELOG.md` row, added as part of the change (Keep a Changelog categories; CalVer versioning).
- **Direction changes** ship with a `ROADMAP.md` update in the same change.
- **Design decisions** get a `Decision` node in `project.ontology.ttl` and a `DESIGN.md` paragraph — decisions, trade-offs, and rejected alternatives with reasons.
- **Surface-area changes** (new files, changed contracts) update `README.md` and `SPECIFICATION.md`.
- **Ontology changes** follow preferences.md §36: propose the change, get maintainer approval, then update classes/nodes. The AI updates the ontology as working state; it does not invent new domain terms without approval.

## AI contributions

- Disclose AI assistance in the PR description and name the models (the PR template has a section for this).
- AI-assisted commits authored on the maintainer's behalf use the git identity `RyansOpenSourceRice` with the GitHub noreply email; AI assistance is disclosed in the commit body, not by adding a separate AI author line.
- AI contributors review their full diff before declaring work done: no secrets, no dead code, no leftover debug output, no AI-fingerprint comments.
- Shipped text uses a neutral, factual voice — no promotional register, no personhood-implying phrasing (the output reads as the project's voice).
- Never commit secrets. Gitleaks is the gate, but the gate is the floor, not an excuse.
- AI agents working on this repo follow `AGENTS.md` and the cold-start routine it describes.

## Commit and PR discipline

- One PR, one concern. Twelve unrelated fixes are twelve PRs.
- Resolve review conversations before merging; unresolved discussions block the merge.
- CI must be green (the `pre-commit` and `sast` workflows) — a hard gate, not a guideline.
- Dependency updates come through Renovate (`renovate.json`); do not hand-edit lockfiles or bump pinned hook revisions outside a Renovate PR.

## Licensing and conduct

- Contributions to this library are licensed under **Apache-2.0** (see `LICENSE`).
- The project follows the [Citizen Code of Conduct](https://github.com/stumpsyn/policies/blob/master/citizen_code_of_conduct.md). Discriminatory or harassing contributions are out of scope.
- By contributing, you agree your contribution may be AI-reviewed; human review of the diff is not required before merge, but the gates are.
