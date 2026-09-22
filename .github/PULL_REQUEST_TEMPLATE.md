## What

<!-- One paragraph: what does this PR change and why? Reference the issue it closes (Closes #N) if any. -->

## How

<!-- Key changes, file by file or concern by concern. Include what was intentionally NOT changed. -->

## Type of change

- [ ] New capability
- [ ] Fix to existing behavior
- [ ] Documentation only
- [ ] CI/CD or tooling only

## AI assistance disclosure

<!-- Per §18/§28: disclose AI use and name the models. Delete this section if no AI assistance was used. -->

- AI used: yes / no
- Models:

## Checklist

- [ ] Pre-commit suite passes locally (`pre-commit run --all-files`)
- [ ] `CHANGELOG.md` row added as part of the change (not retroactively)
- [ ] `ROADMAP.md` updated if this shifts direction
- [ ] `project.ontology.ttl` updated (Decisions / Milestones / LessonLearned / Workflow state) if applicable
- [ ] Docs updated when the project's surface area changes
- [ ] Full diff self-reviewed; no secrets, no dead code, no leftover debug output
- [ ] Branch is rebased on `dev` (no merge commits); merge lands as a squashed unit on `main` via `dev`
