# SECURITY.md

## Reporting a vulnerability

Do **not** open a public issue for security reports. Report privately through GitHub's private vulnerability reporting for this repository (Security tab → *Report a vulnerability*), or contact the maintainer directly through the channels listed on the maintainer's GitHub profile.

Include: what the issue is, how it was found, a reproduction (synthetic data only — never real credentials), and any suggested fix. Do not include secrets, personal data, or working exploits against third-party systems in the report.

## Response commitments

- **100-day fix SLA framing** — the goal is a fix within 100 days of a validated report; the realistic target is one month for high-severity findings.
- The reporter is acknowledged on first triage, kept informed of status, and credited at disclosure if they want credit.

## Scope

- This repository's files, CI configuration, and tooling.
- The library's own defects (e.g. a validation bypass, unsound constraint handling, memory unsafety in the core).

## Out of scope

- Vulnerabilities in applications that merely embed the library.
- Vulnerabilities in the pinned tools themselves (gitleaks, cspell, Vale, OpenGrep, open-code-review) and in the Ada toolchain — report those upstream; a pin bump is handled through Renovate.
- Scanning or probing systems the project does not own. Scanners in this repository fix problems they encounter while working; they do not hunt (preferences.md §7, §28).

## AI use disclosure

Issues and PRs in this repository are triaged and worked with AI assistance. The models in use are routed through [OpenRouter](https://openrouter.ai/) with Zero Data Retention enabled by default; model names are disclosed in the PR that ships a change. No AI system receives real credentials: repository secrets carrying LLM keys are scoped and masked, and validation uses synthetic fixtures only.
