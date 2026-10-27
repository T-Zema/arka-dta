# Source: Andrej Karpathy — "LLM wiki" idea file

URL: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
Ingested: 2026-10-24 (summary of the gist body; comments under the gist were ignored).

This file is a raw source: do not edit it.

## Summary

- Rather than RAG over raw documents on every question, the LLM **incrementally builds and maintains a
  persistent, interlinked wiki of markdown files**: knowledge is "compiled once and kept current",
  a "persistent, compounding artifact". Analogy: *Obsidian is the IDE; the LLM is the programmer;
  the wiki is the codebase.* The human curates sources and asks questions; the LLM does the bookkeeping.
- **Three layers:** raw sources (immutable, LLM reads but never modifies) → the wiki (LLM-owned:
  summaries, entity/concept pages, comparisons, overview) → the schema (e.g. CLAUDE.md / AGENTS.md:
  structure, conventions, workflows; co-evolved).
- **Operations:**
  - *Ingest* — read a new source, discuss takeaways, write a summary page, update the index and related
    pages (often 10–15 files), append to the log.
  - *Query* — search the wiki, synthesize an answer with citations, optionally file good answers back
    as new pages.
  - *Lint* — periodic health check: contradictions, stale claims, orphan pages, missing concept pages,
    missing cross-references, data gaps.
- **Special files:** `index.md` (content catalog: link + one-line summary per page, by category; read
  first on every query — works without embeddings at moderate scale) and `log.md` (append-only,
  chronological, consistent line prefixes so it greps well).
- No fixed directory layout — it is worked out between the user and the agent.
- Optional tooling: local markdown search (qmd), Obsidian Web Clipper, Obsidian graph view, Marp,
  Dataview over frontmatter, git for history.
- Rationale: personal wikis die from maintenance cost, which an LLM makes near-zero.
