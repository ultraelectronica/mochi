# Mochi

*One shared AI pet for your family—chat, moods, memories, and growth. A companion, not an assistant.*

**Mochi** is a family-shared AI companion pet app. One creature lives on a shared server and grows wiser, more expressive, and more emotionally nuanced the more your family interacts with it. Each family member has their own identity and affection score with the pet, but the pet itself is singular—a shared family bond. It speaks in short, warm sentences, remembers moments, reacts to moods, and visibly evolves through life stages. It is not a smart assistant; it is a companion.

## Documentation

- **[docs/mochi.pdf](docs/mochi.pdf)** — Full product and architecture write-up (tech stack, device setup, database, screens, Flutter layout).
- **[docs/mochi_diagram_explanations.txt](docs/mochi_diagram_explanations.txt)** — Text descriptions of the diagrams (stack, MVP phases, schema, architecture, navigation, moods, file structure).
- **[docs/server_setup.md](docs/server_setup.md)** — Practical backend setup for `server/`, PM2, Termux:Boot, logs, and day-to-day server commands.

## Tech stack (system)

| Layer | Technology |
| --- | --- |
| **Client** | Flutter (UI, animations, I/O including voice) |
| **Backend** | Node.js + Express (API, mood processing, scheduled tasks) |
| **AI** | TinyLlama via **llama.cpp** (local); **Gemini API** when local inference is unavailable |
| **Data** | SQLite (pet state, interactions, memories, etc.) |
| **Infra (reference setup)** | Termux, Cloudflare Tunnel, Termux:Boot—e.g. a Samsung Galaxy Note 8 as an always-on home server |

This repository now contains both the **Flutter application** and the **Node/SQLite backend** in `server/`. The deeper product and architecture write-up is still in `docs/mochi.pdf`, and the practical PM2 + Termux server workflow is in `docs/server_setup.md`.

## Architecture (high level)

Family members’ Flutter apps talk to the backend over **HTTPS** (often through a **Cloudflare Tunnel** to a home device). **Node.js** reads and writes **SQLite**, builds prompts (pet state + memory snippets), calls **TinyLlama** through **llama.cpp**, persists results, and pushes live updates over **WebSocket**. If the local server is unreachable, the app can fall back to **Gemini** so the pet stays available.

## MVP roadmap

1. **Phase 1 — Core:** User profiles, chat, pet display, growth system, basic mood system.
2. **Phase 2 — Personality:** Voice, memory system, animations, daily engagement.
3. **Phase 3 — Family:** Affection tracking, activity feed, shared family features (and notifications in the PDF).

## Data model (backend)

| Entity | Role |
| --- | --- |
| `pet` | Single shared companion (stage, mood, XP, etc.) |
| `members` | Per-person profiles and XP |
| `interactions` | Conversation turns, responses, XP awarded |
| `memories` | Short summaries injected into prompts for long-term recall |
| `affection` | Closeness between each member and the pet |
| `mood_log` | Daily mood check-ins |

## App navigation

Flow: **Splash / onboarding → member select or create → Home.**

From **Home:** Chat, mood check-in, activity feed. Paths converge on **Pet profile** (growth, memories, progress) and **Settings**. Navigation is centered on the pet for a simple, consistent loop.

## Pet moods

Each mood maps to **color**, **animation style**, and **response tone** (e.g. happy: bright and energetic; sad: soft and slower; angry: short and tense). Mood reacts to interaction patterns and input, forming a feedback loop between behavior and personality.

## Flutter project layout

```
lib/
├── main.dart
├── config/          # e.g. app_config.dart — server URL, constants
├── models/          # pet, member, mood
├── services/        # API, WebSocket, TTS
├── screens/         # splash, member select, home, chat, mood, feed, pet profile, settings
├── widgets/         # reusable UI (pet sprite, mood tiles, chat, XP bar, avatars, nav)
└── providers/       # Riverpod — pet and member state
```

## Getting started

### Backend (`server/`)

On a PC, from the repo root:

```bash
cd server
pnpm install
cp .env.example .env
pnpm dev
```

Optional: set `MOCHI_API_KEY` in `server/.env` so HTTP (except `GET /health`) and WebSocket require `Authorization: Bearer …`. Match the client with `--dart-define=MOCHI_API_KEY=…`.

Full commands, LAN notes, Flutter flags, **llama.cpp + TinyLlama on a Linux PC**, Fish helpers, and the Termux / PM2 flow are in **[docs/server_setup.md](docs/server_setup.md)**. Deeper product context: **[docs/mochi.pdf](docs/mochi.pdf)**.

### Flutter app

```bash
flutter pub get
flutter run
```

With API auth and a custom server URL:

```bash
flutter run \
  --dart-define=MOCHI_SERVER_URL=http://127.0.0.1:3000 \
  --dart-define=MOCHI_API_KEY=your_shared_secret
```

See the [Flutter documentation](https://docs.flutter.dev/) for environment setup and tooling.

## License

This project is licensed under the [MIT License](LICENSE).
