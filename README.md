# Mochi

*One tiny AI pet for your phone — chat, moods, memories, and growth. A companion, not an assistant.*

**Mochi** is an on-device AI companion pet. A small language model lives on your phone — no server, no accounts, no API keys — and grows more expressive the more you talk to it. It speaks in short, warm sentences, remembers moments, reacts to moods, and visibly evolves through life stages. It is not a smart assistant; it is a companion.

## Documentation

- **[docs/mochi.pdf](docs/mochi.pdf)** — Full product and architecture write-up.
- **[docs/mochi_diagram_explanations.txt](docs/mochi_diagram_explanations.txt)** — Text descriptions of the diagrams (stack, MVP phases, schema, architecture, moods, file structure).
- **[docs/development_phasing.md](docs/development_phasing.md)** — MVP phase checklists.

## Tech stack

| Layer | Technology |
| --- | --- |
| **Client** | Flutter (UI, animations, voice via TTS + STT) |
| **AI** | [LFM2.5](https://huggingface.co/LiquidAI) (1.2B / 2.6B) GGUF via **llama.cpp** — fully on-device, offline after download |
| **Data** | SQLite on-device (pet state, chats, memories, moods) via `package:sqlite3` |

## Architecture (high level)

Mochi is a single Flutter app. The **llama.cpp** engine runs in a background isolate through `llama_cpp_dart` (arm64 native libraries are bundled into the APK). All game logic — mood engine, XP, stage growth, memories — mirrors the previous server code as pure Dart operating on a local SQLite database. The application needs internet only once: to download the GGUF model from Hugging Face on first launch.

## Models

| Model | Download | RAM-ish | Notes |
| --- | --- | --- | --- |
| **LFM2.5-1.2B-Instruct Q4_K_M** (default) | 731 MB | ~1.3 GB | Fast, plenty for cozy one-liners |
| **LFM2.5-2.6B Q4_K_M** | 1.67 GB | ~2.6 GB | Richer personality, needs a beefier phone |

Both can be downloaded, deleted, or switched from **Settings → On-device AI**. Downloads resume if interrupted.

## Pet moods

Each mood maps to **color**, **animation style**, and **response tone** (e.g. happy: bright and energetic; sad: soft and slower; angry: short and tense). Mood reacts to interaction patterns and inactivity, forming a feedback loop between behavior and personality.

## Flutter project layout

```
lib/
├── main.dart
├── config/          # app_config.dart — theme, game constants
├── db/              # mochi_db.dart (SQLite schema), mochi_repository.dart (all game logic)
├── models/          # pet, member, mood, chat session
├── services/
│   ├── local_llm/   # model download manager, llama.cpp engine, prompt builder, reply sanitizer
│   ├── floating_mochi_service.dart
│   └── tts_service.dart / stt_service.dart
├── screens/         # onboarding, home, chat, mood check-in, settings
├── widgets/         # reusable UI (pet sprite, mood tiles, chat, XP bar, avatars, nav)
└── providers/       # ChangeNotifier state — pet and member
```

## Getting started

```bash
flutter pub get
flutter run
```

First run asks for your name, names your Mochi, then downloads the default model (731 MB) with a progress screen. Everything else works offline.

## License

This project is licensed under the [MIT License](LICENSE).
