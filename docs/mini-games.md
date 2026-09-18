# Mochi Mini-Games — Phasing & Tracking

> Tagline: **"Play with Mochi, not just chat."** — three offline mini-games (Snack Catch, Tickle Pop, Mood Match) that feed the existing XP / mood / satiety loop, all on-device with no new native deps.

**Legends:** `[x]` done · `[ ]` todo · `[~]` in-progress
**Scope:** Fully local (`sqlite3` + `llama_cpp_dart` already present). No new packages for v1. No LLM/TTS inside game loops. Entry point: Home Play panel under the hero panel.

**Cozy reward rule:** games are a side dish. Chat (`xpPerChat = 10`, `lib/config/game_config.dart:5`) must stay the best XP source; games cap at **8 XP** per run and **5 scored runs/day**.

---

## Design Summary

| Game | Fantasy | Loop | Core skill | Side-effect |
| --- | --- | --- | --- | --- |
| **Snack Catch** | Feed Mochi | 60s, drag Mochi left/right, catch falling `Food.emoji`, dodge trash (`🧦`/`🗑️`). 3 misses ends early. | Hand-eye, speed ramp | Satiety `+min(12, score~/12)`, mood_score +4 |
| **Tickle Pop** | Pet/affection | 30s, pop bubbles around Mochi, combo chained when pops <1.1s apart. No fail state. | Reflex, combos | Mood nudge toward `happy`/`laughing`, mood_score +6 |
| **Mood Match** | Calm company | 4×3 grid of mood icons (6 pairs), flip pairs, par = 10 moves. Soft 90s ceiling. | Memory | No satiety change; flavor only |

All three: big touch targets, quit button, pause-on-background overlay, consolation prize on loss, haptics, no shame states.

### XP curve (pure function, mood modifier still applies via `awardXp`)

| Game | Raw XP | Cap | Notes |
| --- | --- | --- | --- |
| Snack Catch | `2 + score ~/ 25` | 8 | win bonus satiety/mood |
| Tickle Pop | `2 + bestCombo ~/ 2` | 8 | counts like a pet tap |
| Mood Match | `max(3, 8 - (moves - par) ~/ 2)`, unfinished = 1 | 8 | calm, no farming upside |

### Anti-farming

- **Daily cap:** 5 scored plays/day total across all games.
- **Cooldown:** 90s between scored plays.
- Over-cap / cooldown runs are still playable but award **0 XP** and only a tiny mood effect.
- All awards route through `MochiRepository.awardXp` (`lib/db/mochi_repository.dart:262`), so `pet.mood.xpModifier` (`lib/models/mood.dart:86`), affection gain, `last_interaction_at`, and `checkStagePromotion()` stay single-sourced.

---

## Phase 1 — Scoring & Config Foundation

*Goal: reward math and constants exist, pure and tested, before any UI.*

- [x] **Config** `lib/config/game_config.dart` — `xpPerMiniGameMax = 8`, `miniGameDailyCap = 5`, `miniGameCooldownSeconds = 90`, `snackCatchDurationSeconds = 60`, `snackCatchLives = 3`, `ticklePopDurationSeconds = 30`, `moodMatchParMoves = 10`, `moodMatchSeconds = 90`
- [x] **Model** `lib/games/mini_game.dart` (new) — `enum MiniGame { snackCatch, ticklePop, moodMatch }` + `label` / `blurb` / `emoji` / `icon` extensions, `miniGameFromString`, `MiniGameOutcome`, `MiniGameResult`
- [x] **Scoring** `lib/games/mini_game_scoring.dart` (new) — `int miniGameXpForScore(MiniGame game, {int score = 0, int bestCombo = 0, int moves = 0, bool finished = true})`; clamps to cap and floor
- [x] **Tests** `test/mini_game_scoring_test.dart` (new) — boundary scores, cap clamp, unfinished loss floor = 1, combo scaling

**Exit:** `flutter analyze` + `flutter test` green; scoring verified independent of DB/UI. ✅

---

## Phase 2 — Persistence & Repository

*Goal: a scored run can be recorded, capped, and promoted without UI.*

- [x] **Schema** `lib/db/mochi_db.dart` — `mini_game_plays (id, member_id, game, score, xp_awarded, created_at)` in `_runSchema`; index `mini_game_plays_created_idx`; `CREATE TABLE IF NOT EXISTS` keeps existing installs working
- [x] **Repo** `lib/db/mochi_repository.dart` — `recordMiniGamePlay({required int memberId, required MiniGame game, int score = 0, int bestCombo = 0, int moves = 0, bool finished = true})`:
  - daily count check via `_dayStartUtc` (reuse mood-check pattern)
  - cooldown check against last scored `mini_game_plays.created_at`
  - compute XP via `miniGameXpForScore`, then `awardXp`
  - apply per-game side-effects (satiety clamp, mood_score bump), then `checkStagePromotion()`
  - returns `MiniGameResult {outcome, xpAwarded, satietyAfter, playsRemaining}`
- [x] **Queries** — `dailyMiniGamePlays()`, `miniGameCooldownRemainingSeconds()`, `miniGameBestScores()`
- [x] **Feed** `lib/models/pet.dart` — `mini_game` case in `ActivityEntry.fromJson` (title/detail/accent/icon) and emitted from `feed()`
- [x] **Tests** `test/mini_game_test.dart` (new) — `MochiDb.openInMemory()`: XP recorded, daily cap blocks 6th play, cooldown blocks early re-play, best score updates, side-effects, feed entry

**Exit:** DB + repo behavior fully covered by unit tests. ✅

---

## Phase 3 — Provider & Home Entry

*Goal: Home has a Play panel; provider exposes game state.*

- [x] **Provider** `lib/providers/pet_provider.dart` — `playMiniGame({required MiniGame game, int score, int bestCombo, int moves, bool finished})` → repo → `_reloadLocal(includeChat: false)`; exposes `miniGameCooldownRemaining()`, `dailyMiniGamePlays()`, `miniGameBestScores()`
- [x] **Play panel** `lib/screens/play_panel.dart` (new) — card with three game rows (emoji, blurb, best score), big Play buttons; styled with `pixelCardDecoration` + `MochiPalette`
- [x] **Wiring** `lib/screens/home_screen.dart` — `PlayPanel` under the hero panel (shared by wide + compact branches), above `_MoodSummaryPanel`
- [x] **Reuse** — reward feedback shown in the game-over card (XP / satiety / cooldown), consistent with `_FloatingXp` and `MochiToast` patterns

**Exit:** Play panel renders, reflects caps/cooldowns, and routes into the games. `flutter analyze` green. ✅

---

## Phase 4 — Game Screens

*Goal: all three games playable end-to-end with rewards.*

- [x] **Shell** `lib/games/game_shell.dart` (new) — `GameScaffold`, `GameHudPill`, `GameResultCard`, `MochiGameBlob`, `GameLifecycle` mixin + `GamePausedOverlay`; no LLM/TTS
- [x] **Snack Catch** `lib/games/snack_catch_game.dart` (new) — drag/tap control, falling foods from `Food.emoji`, trash items, 3 lives, speed ramp, 60s
- [x] **Tickle Pop** `lib/games/tickle_pop_game.dart` (new) — mood bubbles around Mochi, combo window, tap squash, 30s
- [x] **Mood Match** `lib/games/mood_match_game.dart` (new) — 3/4-column grid of `MochiMood` icon cards, flip/reveal, move counter, par logic, 90s ceiling
- [x] **Navigation** — Play buttons push each screen; finish calls `petProvider.playMiniGame(...)`
- [x] **Tests** — reward/cap/cooldown/feed path covered by `test/mini_game_test.dart`; `test/mini_game_widget_test.dart` guards falling items, bubble spawning, and full-board card sizing (game-over animation still covered indirectly)

**Exit:** `flutter analyze` + `flutter test` green; games award XP and update satiety/mood/feed. ✅ (manual device pass pending)

---

## Phase 5 — Polish & Verification

*Goal: cozy, accessible, shippable.*

- [x] Haptics on catch/pop/end, win/lose feedback copy in Mochi's voice, pause-on-background (`GameLifecycle` + `GamePausedOverlay`)
- [x] Accessibility: large touch targets, mood cards distinguished by icon (not color alone), `Mood Match` has no reflex requirement
- [x] Field fixes after first device pass: spawn eviction bug in `_tick` (falling items/bubbles were cleared the same tick they spawned), Mood Match grid now stretches cards to fill the board, game header title scales down instead of overflowing, Snack Catch paddle no longer re-centers when dragged to the far left
- [ ] Manual: 5 plays cap, 90s cooldown, feed entry, stage promotion mid-game, mood modifier applied
- [x] Build: `flutter build apk --debug` succeeds; `lib/arm64-v8a/` still has `libllama.so`, `libggml*.so`, `libsqlite3.so` — **no new native libs** added by mini-games
- [x] Update `docs/development_phasing.md` Phase 2/3 checklist to reference this file

---

## Verification Checklist (global)

- [x] `flutter analyze`
- [x] `flutter test`
- [ ] Manual: play each game to win and to lose; confirm consolation + no XP over cap
- [ ] Manual: chat still yields 10 XP base and remains the primary growth path
- [ ] Manual: affect detection — Snack Catch moves satiety, Tickle Pop moves mood, best scores persist across app restart

---

## Open Decisions

- [x] Daily cap **5 total** (chosen) vs 3 per game — single counter, simpler
- [x] Snack Catch trash penalty — **lose a life** (chosen), start with 3
- [x] Sound — **silent + haptics** (chosen), keeps APK lean
- [x] Mood Match timer — **soft 90s ceiling** (chosen), no fail pressure
- [x] Golden/perfect run flavor — **cosmetic headline** (chosen) for v1

---

## Progress

| Phase | Theme | Status |
| --- | --- | --- |
| 1 | Scoring & config | `4/4` |
| 2 | Persistence & repo | `5/5` |
| 3 | Provider & Home entry | `4/4` |
| 4 | Game screens | `6/6` |
| 5 | Polish & verification | `5/6` (manual device pass pending) |

Update this file as checkboxes land; keep it the single source of truth for mini-game work.
