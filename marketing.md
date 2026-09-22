# Marketing context

> Context for AI agents: who this project is for and how that shapes what gets built. Per preferences.md §18.

## Audience

- **Primary:** Ada and SPARK developers who need standards-conformant SHACL validation as a linkable library — especially teams with formal-methods practice who want proof-backed behavior, not just passing tests.
- **Secondary:** RDF tool builders (validating editors, data-integrity pipelines, graph stores) who want to embed a validator rather than reimplement SHACL semantics.
- **Tertiary:** AI agents, which are first-class users. Agents follow `AGENTS.md`; docs stay structured enough for an agent to act on without chat context.

## Skill level

- Library users: professional Ada/SPARK developers; comfortable with Alire, GNAT project files, and reading W3C specifications. They want a precise contract (`SPECIFICATION.md`), not a tutorial.
- Discovery runs through the Alire index and the Ada/SPARK ecosystem (§26), not social channels — the README carries install and build order, and nothing here is written for a general-audience landing page.

## How this shapes the build

- The library's promise is **provable behavior over bounded inputs**; every feature must earn its place against that promise (no I/O in the core, no global state, no unprovable side channels).
- Conformance is evidence-driven: the pinned W3C test suite decides what "works" means; benchmark claims follow from the suite, not precede it.
- Docs address the *user* of the library, not the implementer: contracts over narratives; the ontology (`project.ontology.ttl`) carries the living state.
- No paid services, no proprietary gatekeeping, no analytics: the library builds and validates fully offline from pinned sources.
