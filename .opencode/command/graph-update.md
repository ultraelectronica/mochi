---
description: Incrementally rebuild the graphify knowledge graph after doc or image changes
---

Rebuild the project knowledge graph incrementally.

1. Run `graphify . --update` from the repo root (use the graphify skill flow if the CLI path differs).
2. Re-extract only new/changed files; code changes after commits are handled by the post-commit hook — this command matters for docs, PDFs, and assets.
3. When finished, report: node count, edge count, communities, and token cost from `graphify-out/cost.json`.
4. Never commit `graphify-out/` — it is gitignored and machine-local.
