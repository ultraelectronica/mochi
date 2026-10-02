# Generous pantry — development phasing

**Date:** 2026-10-02  
**Goal:** Make feeding Mochi easy to sustain through casual chat, check-ins,
and play. Food rewards acknowledge participation, including low scores and losses.

Legend: `[x]` complete · `[ ]` pending. Complete implementation checkpoints only
after their behavior has been verified.

## Agreed balance

| Rule | Previous | Target |
| --- | --- | --- |
| Chat food | 1 every 4 rewarded messages, 3/day | 1 every 2 rewarded messages, 6/day |
| Check-in food | 1 random item/day | 1 Mochi bite + 1 onigiri on the first check-in/day |
| Game food | 1 per XP-eligible run, 5/day | 1 per naturally ended run, 10/day, independent of XP eligibility |
| Stock capacity | 9 per food type | 20 per food type |
| One-time starter pack | 5 bites + 2 onigiri | 8 bites + 4 onigiri |

Daily boundaries use the existing UTC day. Game XP remains capped at 8 per run,
5 scored runs/day, with a 90-second cooldown. Food source limits are independent.
Chat progress continues across days, using rewarded interactions since the last
chat grant. Deflected, unrewarded chats do not advance it.

## Phase 1 — Document the contract

- [x] Record target values, rollout order, and acceptance criteria before coding.
- [x] Define edge cases and existing-save behavior below.
- [x] Link this rollout from the development roadmap and mini-game documentation.

### Edge cases and persistence

- Natural game endings include timer expiry, Snack Catch losing all lives, and
  Mood Match timing out without matching every pair. `finished` continues to
  describe Mood Match scoring success; it must not block participation food.
  Quitting/back navigation does not submit a result and earns no food.
- Food granted during XP cooldown or after the XP daily cap is recorded normally
  in `food_grants` and inventory. It does not consume another scored XP play.
- Food drops respect stage unlocks and per-type capacity. A full pantry grants
  nothing and consumes no food allowance. Eggs receive no feedable drops.
- The check-in prefers a bite and onigiri. If a preferred type is capped, roll an
  unlocked food with space instead. Grant up to two items if space permits;
  a duplicate check-in must never retry or grant extra food that day.
- Store one grant row per awarded item so daily counting and activity history
  remain accurate. Existing tables already support this; no schema migration.
- Existing inventories and grant history stay valid. The larger starter pack
  applies only to saves that have never received a starter pack.

## Phase 2 — Reward logic and persistence

- [x] Apply the target constants and retain stock/stage checks for all drops.
- [x] Return a list of check-in rewards, with per-item grant history and a
  repository-level first-check-in guard.
- [x] Award game food independently of XP cooldown and scored-play limits.
- [x] Expose the remaining daily game-food allowance for feedback.

**Exit:** Two rewarded chats grant food; the check-in grants both staples;
cooldown/XP-capped game runs can still grant food up to ten items/day.

## Phase 3 — Provider and reward feedback

- [x] Carry multiple pending check-in foods through the provider and toast.
- [x] Show food earned on game result cards even when XP is resting.
- [x] Label the Play panel's XP allowance/cooldown separately from food allowance.

**Exit:** Feedback reports the actual awarded items and never implies that an XP
cooldown prevents food. Pending rewards are consumed once.

## Phase 4 — Regression checks and documentation

- [x] Test chat thresholds/caps and unrewarded-message exclusion.
- [x] Test two-item check-ins, duplicates, capped staples, full pantry, and eggs.
- [x] Test game food during cooldown, after the XP cap, on low-score/lost runs,
  its independent cap/day reset, and a full pantry without spent allowance.
- [x] Test starter idempotency, new capacity, and reward feedback.
- [x] Run `flutter analyze` and `flutter test` (120 tests passed).
- [x] Update the current mini-game reward rules.
- [x] Refresh the code and documentation knowledge graph (`graphify --update`
  skill flow; this installation's `graphify update` CLI handles code only).

**Exit:** Automated checks pass and current docs match the shipped behavior.

## Device follow-up

- [ ] Check in once and confirm both items in the toast, pantry, and history.
- [ ] Replay each game during XP cooldown and confirm food-only feedback.
- [ ] Lose Snack Catch and time out Mood Match; confirm participation food.
- [ ] Quit a game early; confirm no award. Restart with an existing save and
  confirm pantry counts persist without a second starter pack.
