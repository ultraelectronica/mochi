# AGENTS.md

Mochi is an on-device AI companion pet: one tiny creature living on your phone, with chat, moods, memories, and growth. Flutter app at the root. No server — the Node backend (`server/`) was retired in Aug 2026.

## Graph protocol (read this first)

This repo has a graphify knowledge graph in `graphify-out/` (gitignored, rebuilt locally).

- **Before answering codebase questions** ("how does X work?", "what calls Y?", "trace data flow"), run `graphify query "<question>"` from the repo root. Use the graph instead of grepping blind.
- `graphify path "A" "B"` — shortest path between two concepts. `graphify explain "<node>"` — plain-language node explanation.
- **After changing code**, the post-commit hook re-extracts changed files automatically. After doc/image changes, run `graphify --update` manually.
- `graphify-out/GRAPH_REPORT.md` — god nodes, communities, import cycles. `graphify-out/graph.html` — interactive map. `graphify-out/graph.json` — raw data.
- If `graphify-out/graph.json` is missing or badly stale, run a full rebuild via the graphify skill before relying on it.
- Edge honesty: EXTRACTED edges are source-verified; INFERRED edges are model-reasoned; AMBIGUOUS edges need verification. Cite `source_location` when quoting the graph.

## Commands

```
flutter analyze          # lint/typecheck — run before finishing any Dart change
flutter test             # tests (test/) — mood engine + prompt/sanitizer units
flutter run              # needs an Android device/emulator (arm64)
flutter build apk --debug
```

Verify everything before declaring done: `flutter analyze` + `flutter test`. To sanity-check the native stack, inspect the APK's `lib/arm64-v8a/` for `libllama.so`, `libggml*.so`, `libsqlite3.so`.

## Repo layout

```
lib/
  config/      game_config.dart (XP/mood/ctx constants), app_config.dart (theme)
  db/          mochi_db.dart (sqlite3 open + schema), mochi_repository.dart
               (ALL game logic: mood engine, XP, memories, feeds, tap/check-in)
  models/      pet, member, mood, chat_session
  providers/   pet_provider, member_provider — manual ChangeNotifier
  services/    local_llm/ (llm_service, model_manager, local_models,
               prompt_builder, reply_sanitizer), tts/stt, floating_mochi_service
  screens/     onboarding, home, chat, mood_checkin, settings
  widgets/     pet_sprite, chat_bubble, xp_bar, mood_tile, model_setup_panel,
               bottom nav, toast, ...
```

## Architecture

- **Fully local**: on-device LFM2.5 GGUF via `llama_cpp_dart` (worker isolate; native libs auto-bundled into the APK through its native-assets hook). Local SQLite (`package:sqlite3`, also via build hooks) at `<app support>/mochi.db`, WAL mode.
- **Model delivery**: first-launch download from Hugging Face (`LiquidAI/LFM2.5-1.2B-Instruct-GGUF` Q4_K_M default, 2.6B optional), resumable `.part` + Range headers, managed by `model_manager.dart` (`ModelManager` singleton).
- **Chat flow**: `PetProvider.sendMessage` → repo session/interaction writes → `LlmService.reply` (chat template from GGUF, ChatML fallback) → sanitizer → XP/memory/mood/stage updates → local reload.
- **Mood engine**: port of the old server logic (`mood-engine.ts`) — threshold + recent-logs scoring, recomputed on chat/tap/check-in/resume.
- **Single user**: one local profile + one pet. No auth, no households, no accounts.

## Conventions

**Dart**: files `snake_case.dart`, classes `PascalCase`. Screens end `_screen.dart`, services `_service.dart`. Providers expose private fields + getters, notify manually. No DI framework — singletons (`ModelManager.instance`, `LlmService.instance`, `MochiDb.instance()`).

## Gotchas

- Never write bare `Row` for sqlite rows in `mochi_repository.dart` — import sqlite3 aliased and use `sqlite3.Row` (Flutter's `Row` collides).
- Model file bytes (730895168 / 1674455040) are exact `Content-Length` values from the official repos — update them only after re-checking with `curl -sIL <resolve-url> | grep -i content-length`.
- Do NOT add `sqlite3_flutter_libs` — `sqlite3 >= 3.0` bundles SQLite via its own build hook.
- llama_cpp_dart is on the 0.9-dev track; its API is mid-rewrite — read `lib/src/isolate/engine.dart` in the pub cache before touching `llm_service.dart`.
- iOS needs the `llama.xcframework` step from `llama_cpp_dart` README (Android-first for now).
- `accounts.txt` at repo root is obsolete plaintext credentials from the server era — confirm with the owner before relying on/removing it.
