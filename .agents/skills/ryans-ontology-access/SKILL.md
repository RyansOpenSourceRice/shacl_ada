---
name: ryans-ontology-access
description: Pointer/routing skill for accessing Ryan's preferences as an RDF/OWL ontology. Use when the user asks about Ryan's preferences or defaults ("how should I build this", "what stack", "my default for X", "what are my preferences"), references an ontology, RDF, SPARQL, Apache Jena Fuseki, the Jena MCP server, or asks how to reach the preferences ontology. Directs the agent to query the ontology read-only via the Apache Jena MCP server instead of reading the raw .ttl.
---

# Ryan's Preferences — Ontology Access

Ryan's preferences are expressed as an RDF/OWL ontology. This skill tells you
how to read it.

## Primary document

- **Ontology (primary, machine-readable):** `preferences.ontology.ttl` at the
  repository root of `RyansOpenSourceRice/ryans-agentic-coding-preferences`
  (GitLab).
- **Dataset:** the ontology is loaded into Apache Jena Fuseki dataset
  `ryans-preferences`.
- **Viewable companion (human-readable):** `preferences.md` (and its mirror
  `.agents/skills/ryans-preferences/SKILL.md`). Use this if the ontology is
  unavailable.

## How to read it (via MCP, not raw SPARQL)

Use the **Apache Jena MCP server** tools — never load the raw `.ttl` into
context and do not hand-write SPARQL:

1. `list_graphs` — see what graphs are present in the dataset.
2. `sparql_query_templates` — get a starting template for the kind of question.
3. `execute_sparql_query` — run a SPARQL SELECT over `pref:Section` /
   `pref:Rule` (namespace
   `https://gitlab.com/RyansOpenSourceRice/ryans-agentic-coding-preferences/onto#`)
   to find matching `pref:title` / `pref:text`.

Example intent → query pattern: to find a preference, query for the `pref:Rule`
or `pref:Section` whose `pref:text` or `pref:title` matches the topic, and read
the verbatim `pref:text`.

## Read-only

- **You read the ontology read-only.** Chats never write to the ontology.
- If a preference needs to change, **surface the proposed change to Ryan** — do
  not edit the ontology or write SPARQL updates. Updates flow only through the
  operator-driven regeneration workflow (see §34 of the skill).

## Fallback

- If the Jena MCP server is not available, read `preferences.md` (the viewable
  companion) directly instead of the `.ttl`.
