# Mochi — development phasing

This document ties together:

1. **Development life-cycle (SDLC) stages** — where the project sits in a classic software lifecycle.
2. **Product roadmap phases (1–3)** — MVP themes from the root [README.md](../README.md), with **checkbox checkpoints** grounded in the real Flutter + `server/` tree.

**Checkbox legend**

- `[x]` — implemented in repo (usable end-to-end where applicable).
- `[ ]` — not implemented, stubbed, or intentionally deferred.
- Items marked *(partial)* still use `[ ]` on the parent line; sub-bullets use `[x]` / `[ ]` to show what is already there.

---

## 1. Development life cycle (SDLC)

Where **Mochi** is today: past early **requirements** and **architecture**, deep in **implementation** for core MVP, with **QA**, **release**, and **operations** still lightweight.

| Life-cycle stage | Meaning | Mochi status |
| --- | --- | --- |
| **1. Requirements & discovery** | Problem, audience, MVP scope | Largely settled; README + `docs/mochi.pdf` carry product intent. |
| **2. Architecture & design** | Stack, data model, flows | **In progress** — core client/server split is stable; auth/household TBD. |
| **3. Implementation** | Build features against design | **Active** — Phase 1 mostly built; Phase 2–3 partial or missing. |
| **4. Quality assurance** | Automated tests, manual passes, contracts | **Early** — placeholder widget test only; no API/server test suite in repo. |
| **5. Release & distribution** | Store builds, versioning, update story | **Early** — local/dev + documented server deploy; no release checklist in repo. |
| **6. Operate & evolve** | Monitoring, incidents, backlog | **Partial** — `docs/server_setup.md`, PM2, logs; no formal SLOs in code. |

### 1.1 SDLC checkpoints (checkboxes)

**Requirements & discovery**

- [x] MVP scope documented (README, PDF, diagrams).
- [x] Core user stories identifiable: shared pet, family members, chat, moods, growth.
- [ ] Formal non-goals / Phase 3+ scope locked with stakeholders *(informal only).*

**Architecture & design**

- [x] Client–server boundaries (REST + WebSocket).
- [x] SQLite schema for pet, members, interactions, memories, affection, moods, feed-related data.
- [x] AI path: local llama + Gemini fallback.
- [x] Optional shared-secret API auth: when `MOCHI_API_KEY` is set, HTTP (except `GET /health`) and WebSocket require `Authorization: Bearer …` *(see [server_setup.md](server_setup.md)).*
- [ ] Household identity, accounts, invites, and multi-home isolation *(beyond shared API key; not implemented).*

**Implementation**

- [x] Flutter shell: bootstrap, errors, first-member gate, main tabs.
- [x] Backend: chat, mood check-in, tap, XP, stage events, mood decay, feed, health.
- [ ] Memory **authoring** on server *(read path exists; no insert/update pipeline).*
- [ ] Voice output (TTS) and voice **input** end-to-end.
- [ ] Push / local notifications wired to settings toggles.

**Quality assurance**

- [ ] Provider and widget tests for chat, home, settings.
- [ ] HTTP contract tests (client ↔ server).
- [ ] Server unit/integration tests for routes and XP/mood logic.

**Release & distribution**

- [ ] CI pipeline (analyze, test, build) documented or configured in repo.
- [ ] Store listing assets and privacy posture captured for public release.

**Operate & evolve**

- [x] Server runbook: [docs/server_setup.md](server_setup.md) (PM2, Termux, tunnels).
- [ ] Centralized error reporting / analytics *(not in repo).*

---

## 2. Product Phase 1 — Core companion loop

*README: profiles, chat, pet display, growth, basic moods.*  
*SDLC: primarily **implementation**; aligns with **alpha** behavior (works on dev stack).*

- [x] Family member profiles: create, list, select; colors, XP, affection from API.
- [x] Shared pet state: single pet, stage, XP, server-driven mood.
- [x] Chat with AI: send, history, optimistic UI, WebSocket-driven refresh.
- [x] Pet display: stage/mood assets + basic idle motion (`PetSprite`).
- [x] Mood check-in on Home; server enforces one check-in per member per day.
- [x] Growth: XP from chat, check-in, taps; stage promotion on server.
- [x] Boot UX: syncing card, retry, “add first member” empty state.
- [ ] **Core polish**
  - [ ] Wire or remove placeholder screens: `splash_screen`, `member_select_screen`, `mood_checkin_screen`, `activity_feed_screen`, `pet_profile_screen` *(currently not routed from `main.dart`).*
  - [ ] Expand automated tests beyond default `widget_test.dart`.

---

## 3. Product Phase 2 — Personality & presence

*README: voice, memory system, animations, daily engagement.*  
*SDLC: **implementation** continuing; needs **QA** as TTS/notifications land.*

- [ ] **Memory system**
  - [x] Memories loaded into prompts (top weighted per member).
  - [x] Memories listed in UI (Home profile / API).
  - [ ] Server workflow to create, update, or prune memories after chat or on a schedule.
- [ ] **Voice**
  - [x] Chat UI toggle for “voice” state (`ttsEnabled`) *(state only).*
  - [ ] `TtsService` implementation (e.g. device TTS for pet replies).
- [ ] **Animations**
  - [x] Mood-based bob, tilt, asset selection.
  - [ ] Richer motion (transitions, optional frame sequences, effects).
- [ ] **Daily engagement**
  - [x] Mood decay job + check-in flow.
  - [ ] Push or local notifications; scheduled nudges; “milestone notifications” backed by real notifications *(toggle is in-memory today).*

---

## 4. Product Phase 3 — Family depth & scale

*README: affection, activity feed, shared family features, notifications.*  
*SDLC: **architecture** extensions (identity) plus **implementation**; **release** concerns for multi-tenant safety.*

- [x] Affection: persisted and updated with XP path; shown on members.
- [x] Activity feed: `feed` API + Home feed panel *(standalone `ActivityFeedScreen` unused).*
- [x] Shared realtime: WebSocket pet updates.
- [ ] Multi-device **identity** (accounts, invites, household pairing) *(shared `MOCHI_API_KEY` gate exists; user accounts do not).*
- [ ] Voice **input**: client capture + `input_type: 'voice'` usage *(schema allows it).*
- [x] Ops documentation for home/server deploy *(see [server_setup.md](server_setup.md), including Linux PC + llama.cpp + Fish workflow).*
- [ ] Production hardening: secrets rotation, rate limits, backup story *(evaluate per deployment).*

---

## 5. One-page summary

| Product phase | Theme | SDLC emphasis now | Completion (rough) |
| --- | --- | --- | --- |
| **1** | Core loop | Implementation → QA polish | **~85%** (tests & routed screens gaps) |
| **2** | Personality | Implementation | **~25%** (motion baseline only) |
| **3** | Family & scale | Architecture + implementation | **~35%** (feed + affection + realtime; not auth) |

| SDLC stage | Rough completion for Mochi |
| --- | --- |
| Requirements | **High** |
| Architecture | **Medium–high** (gaps: auth, memory writes) |
| Implementation | **Medium** (core strong; voice/memory/notifications weak) |
| QA | **Low** |
| Release | **Low** |
| Operations | **Medium** (documented server path) |

Use this file for backlog grooming so **life-cycle stage**, **product phase**, and **checkbox** line items stay aligned.
