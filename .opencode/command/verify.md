---
description: Run the full mochi verification suite (flutter analyze + flutter test + server tests)
---

Verify the whole monorepo before declaring work done. Run all three, in order, and report pass/fail for each:

1. `flutter analyze` (repo root) — must be clean.
2. `flutter test` (repo root) — widget tests.
3. `pnpm test` in `server/` — node --experimental-strip-types --test.

If anything fails, fix the root cause and re-run. Do not skip a failing suite; report it honestly if it cannot be fixed.
