---
description: Query the mochi knowledge graph with a natural-language question
---

Answer this question about the codebase using the graphify knowledge graph: $ARGUMENTS

Protocol:

1. Run `graphify query "$ARGUMENTS"` from the repo root.
2. If the CLI is unavailable, traverse `graphify-out/graph.json` directly (networkx or plain JSON walk) instead of grepping the codebase.
3. Answer only from what the graph returns. Cite `source_location` for every specific claim.
4. Mark claims backed by INFERRED or AMBIGUOUS edges as unverified in the answer.
5. If `graphify-out/graph.json` is missing, tell the user to rebuild it (full graphify pipeline) rather than guessing from source.
