# Mochi Remembers — Phasing & Tracking

> Tagline: **"Mochi remembers who you are."** — durable identity (bio / birthdate / age) + conversational memory (history window) + long-term recall (RAG-lite, on-device, no server).

**Legends:** `[x]` done · `[ ]` todo · `[~]` in-progress  
**Scope:** Fully local (`sqlite3` + `llama_cpp_dart`). No new native deps for v1. Context budget `2048` tokens (`lib/config/game_config.dart:14`).

---

## Phase 1 — Identity Foundation

*Goal: user can tell Mochi who they are; prompt knows it.*

- [x] **DB migration** `lib/db/mochi_db.dart:34` — `ALTER TABLE members ADD bio TEXT`, `birthdate TEXT (YYYY-MM-DD)`, index `members_birthdate_idx`; idempotent `PRAGMA table_info` guard
- [x] **Model** `lib/models/member.dart:3` — `String? bio`, `DateTime? birthdate`, `int? get age` (derived), update `copyWith`/`fromJson`
- [x] **Repo** `lib/db/mochi_repository.dart:40,664` — `updateProfile({bio, birthdate})` + validation (bio ≤500, birthdate ≤ today), map in `_memberFromRow`
- [x] **Prompt** `lib/services/local_llm/prompt_builder.dart:14` — inject `About $name: $bio` + `Birthday: $birthdate (age $age)` block (omit if empty) before mood/memories
- [x] **World setup** `lib/services/world_setup.dart:10` — pass optional `bio`/`birthdate` through `createWorld`
- [x] **Onboarding** `lib/screens/onboarding_screen.dart:21,171` — optional expandable "Tell Mochi about you" (bio multiline + date picker, not blocking)
- [x] **Settings** `lib/screens/settings_screen.dart:306` — `About you` card (editable bio/birthdate, computed Age, privacy note "Stored only on this phone")
- [x] **Config** `lib/config/game_config.dart:1` — `maxBioLength = 500`
- [x] **Tests** `test/ai_services_test.dart:7` — system prompt contains bio/birthdate when present

---

## Phase 2 — Conversational Memory (Short-term)

*Goal: Mochi references recent chats in this session; no extra deps.*

- [x] **Repo wiring** `lib/db/mochi_repository.dart:188` — reuse `chatHistory(sessionId, limit: 8)` (already exists)
- [x] **Prompt** `lib/services/local_llm/prompt_builder.dart:26` — new param `List<LlmChatMessage> history`; serialize as `user`/`assistant` roles before final `user`; truncate oldest if >900 tokens (~4c/token estimate)
- [x] **Provider** `lib/providers/pet_provider.dart:214` — fetch `history` before `buildMessages`; pass to `LlmService.reply:97` (already loops `system/user/assistant` via `engine.createChat`)
- [x] **Heuristic** — skip empty / `hi`-only history entries (drop turn + paired reply); keep `sessionId` scoping via `_activeSessionId`
- [x] **Tests** `test/ai_services_test.dart` — `history` injected in correct role order; overflow truncates gracefully

---

## Phase 3 — Long-term Recall (RAG-lite, FTS5)

*Goal: cross-session recall without embeddings; keyword search on-device.*

- [x] **FTS schema** `lib/db/mochi_db.dart:34` — `memories_fts(fts5, content, content='memories')` + `interactions_fts(fts5, input_text, response_text)` + triggers `memories_ai/ad/au`; guard with `SELECT sqlite_compileoption_used('ENABLE_FTS5')` → fallback `LIKE`
- [x] **Retrieval** `lib/db/mochi_repository.dart:558` — `retrieveRelevantMemories(String query, {k=3})` → `SELECT m.content, rank FROM memories_fts JOIN memories ... WHERE MATCH ? ORDER BY rank, weight DESC LIMIT k` + one interaction hit; recency/weight boost
- [x] **Prompt merge** `lib/services/local_llm/prompt_builder.dart:14` — new block `Relevant past moments (use only if helpful):` merged with `memoriesForPrompt:558` (dedup, prefer retrieved)
- [x] **Provider** `lib/providers/pet_provider.dart:210,262` — `relevant = retrieveRelevantMemories(text)` before `buildMessages`; keep `upsertMemory:487` but guard `text.length>12` + personal-signal filter to reduce noise
- [x] **Heuristic fallback** — if FTS missing: token-overlap scorer `weight*10 + recencyBonus`
- [x] **Pruning** — keep `pruneStaleMemories:530` (weight≤2 after 30d)
- [x] **Tests** `test/memory_retrieval_test.dart` (new) — in-memory `sqlite3.openInMemory()` verifies FTS + fallback

> **v2 optional (deferred):** embedding model (MiniLM ~25MB + `sqlite-vec`) for semantic paraphrase + LLM fact extractor post-reply. Not required to ship tagline.

---

## Verification

- [x] `flutter analyze` + `flutter test` (incl. updated `ai_services_test.dart` + new retrieval test)
- [ ] Manual: set bio/birthdate → send "Who am I?" → reply references name/bio
- [ ] Manual: chat 3 turns → new turn references prior turn (Phase 2); old session fact retrieved via keyword (Phase 3)
- [ ] Build: `flutter build apk --debug` → check `lib/arm64-v8a/libllama.so` present

---

## Open Decisions

- [ ] Store `birthdate` only (derive `age`) vs explicit `age` field — **proposed: birthdate only + `age` getter**
- [ ] Auto-memory threshold — every chat vs personal-signal only — **proposed: signal filter**
- [ ] Birthday nudge — Mochi wishes happy birthday via `petProvider` notifications?

---

## Progress

| Phase | Theme | Status |
|-------|-------|--------|
| 1 | Identity | `9/9` |
| 2 | Conversational window | `5/5` |
| 3 | RAG-lite FTS | `7/7` |

Update this file as checkboxes land; keep single source of truth for "Mochi remembers" work.
