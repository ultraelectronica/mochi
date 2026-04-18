# Server Setup

This repo now includes the backend in `server/` and shared backend data in `shared/`.

## Running on a PC (Linux, macOS, Windows)

Use this for day-to-day development when the Flutter app should talk to a backend on the same machine or LAN.

### Prerequisites

- **Node.js 20+** (the `pnpm start` / `pnpm dev` scripts rely on `node --env-file=.env`).
- **pnpm** (`npm install -g pnpm` or [corepack](https://pnpm.io/installation)).
- A normal native toolchain so **`better-sqlite3`** can compile (on Windows, install the “Desktop development with C++” workload in Visual Studio Build Tools if `pnpm install` fails).

### First-time setup

From the repository root:

```bash
cd server
pnpm install
cp .env.example .env
```

Edit `server/.env`:

| Variable | Purpose |
| --- | --- |
| `PORT` | HTTP listen port (default `3000`). |
| `MOCHI_API_KEY` | Optional. If set to a non-empty value, every HTTP route **except** `GET /health` and every **WebSocket** connection requires header `Authorization: Bearer <same value>`. Leave empty for fully open local dev. |
| `LLAMA_URL` | Base URL for local llama.cpp HTTP API (default `http://127.0.0.1:8080`). |
| `GEMINI_API_KEY` | Used when the local model is unavailable. |

### Start the server (foreground)

```bash
cd server
pnpm dev
```

Or without auto-reload:

```bash
cd server
pnpm start
```

You should see a line such as `Mochi server listening on port 3000`. If `MOCHI_API_KEY` is unset, the process logs a warning that the API is open; if it is set, it logs that Bearer auth is required.

### Quick checks

```bash
curl -sS http://127.0.0.1:3000/health
```

When `MOCHI_API_KEY` is set, authenticated calls look like:

```bash
curl -sS -H "Authorization: Bearer YOUR_KEY" http://127.0.0.1:3000/pet
```

### Flutter app on the same PC

Point the client at the server (defaults already match `http://127.0.0.1:3000`):

```bash
cd /path/to/mochi
flutter run --dart-define=MOCHI_SERVER_URL=http://127.0.0.1:3000
```

If the server uses a shared secret, pass the **same** value as in `server/.env`:

```bash
flutter run \
  --dart-define=MOCHI_SERVER_URL=http://127.0.0.1:3000 \
  --dart-define=MOCHI_API_KEY=YOUR_KEY
```

On **Flutter web**, the WebSocket client cannot attach `Authorization` headers; use a VM/desktop/mobile target for full auth, or leave `MOCHI_API_KEY` empty on the server during web-only experiments.

Broader product and architecture context lives in **[mochi.pdf](mochi.pdf)**.

---

## Linux PC full stack (llama.cpp, TinyLlama, Mochi)

Use this when you want the **complete** dev stack on a desktop Linux machine (e.g. **CachyOS**): local inference via **llama.cpp**, then the **Node** API. Snippets below use **`bash`** by default; see **Fish shell** for `(nproc)` vs `$(nproc)`.

### Database (SQLite)

The server stores data in a single SQLite file next to the backend code:

| Item | Detail |
| --- | --- |
| **File** | `server/mochi.db` (created automatically on first run) |
| **Migrations** | Applied at process startup via `runMigrations()` in `server/src/index.ts` — there is **no** separate migrate CLI and **no** `DATABASE_URL` env var in this repo. |

You do not need to run SQL manually for a normal first-time setup.

### 1. Build llama.cpp

```bash
cd ~
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"
```

On a phone (e.g. Note 8) you might use `-j2` to limit heat; **on a PC** you can use all cores as above. Expect roughly **2–5 minutes** depending on CPU.

Verify the CLI:

```bash
./bin/llama-cli --version
```

### 2. Download TinyLlama (GGUF)

```bash
mkdir -p ~/models
cd ~/models
wget "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
```

(~700 MB.) Quick sanity check (CLI inference):

```bash
~/llama.cpp/build/bin/llama-cli \
  -m ~/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
  -p "You are Mochi, a friendly pet. Say hello in one sentence." \
  -n 50 --temp 0.7
```

You should see a short reply within a few seconds on typical PC hardware.

### 3. Run llama-server (HTTP API)

Leave this process running in a dedicated terminal.

**Bash:**

```bash
~/llama.cpp/build/bin/llama-server \
  -m ~/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
  --host 127.0.0.1 \
  --port 8080 \
  --ctx-size 2048 \
  -t "$(nproc)" \
  -n 150
```

**Fish** uses `(nproc)` for command substitution instead of `"$(nproc)"`:

```fish
~/llama.cpp/build/bin/llama-server \
  -m ~/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
  --host 127.0.0.1 \
  --port 8080 \
  --ctx-size 2048 \
  -t (nproc) \
  -n 150
```

If your installed `llama-server` uses different thread flags for your build, adjust to match `llama-server --help`.

Check health from another terminal:

```bash
curl -sS http://127.0.0.1:8080/health
```

Expected: JSON including `"status":"ok"` (exact shape may vary slightly by llama.cpp version).

### 4. Clone Mochi and install the Node server

```bash
cd ~
git clone https://github.com/<your-username>/mochi.git
cd mochi/server
pnpm install
cp .env.example .env
```

Edit `server/.env` for local PC development, for example:

```bash
PORT=3000
MOCHI_API_KEY=
LLAMA_URL=http://127.0.0.1:8080
GEMINI_API_KEY=your_key_here
MOOD_DECAY_HOURS=12
XP_PER_CHAT=10
XP_PER_CHECKIN=5
XP_PER_TAP=2
```

- Set **`GEMINI_API_KEY`** so the backend can fall back when the local model is down or unreachable.
- Set **`MOCHI_API_KEY`** when you want Bearer auth; then add `-H "Authorization: Bearer <key>"` to `curl` examples below and pass `--dart-define=MOCHI_API_KEY=...` to Flutter (see **Running on a PC**).

Do **not** rely on a `DATABASE_URL` variable — this project does not read it; SQLite lives at **`server/mochi.db`**.

### 5. First run and PM2

From `server/`:

```bash
pnpm start
```

You should see **`Mochi server listening on port <PORT>`** (and either the API-key info line or the open-API warning). The SQLite file and tables are created during this startup.

Stop with **Ctrl+C**, then use PM2 for a durable dev process:

```bash
mkdir -p logs
pnpm pm2:start
pnpm pm2:save
pnpm pm2:logs
```

(`pnpm pm2:start` runs `pm2 start ecosystem.config.cjs` from `server/ecosystem.config.cjs`.)

### 6. Smoke-test HTTP routes

With **`MOCHI_API_KEY` empty** (simplest for local testing):

```bash
# Health (always unauthenticated)
curl -sS http://127.0.0.1:3000/health

# Pet state
curl -sS http://127.0.0.1:3000/pet

# Create a family member
curl -sS -X POST http://127.0.0.1:3000/members \
  -H "Content-Type: application/json" \
  -d '{"name": "Dad", "avatar_color": "#1D9E75"}'

# Chat (use member id from the response above)
curl -sS -X POST http://127.0.0.1:3000/chat \
  -H "Content-Type: application/json" \
  -d '{"member_id": 1, "text": "Hello Mochi!"}'

# Mood check-in
curl -sS -X POST http://127.0.0.1:3000/mood/checkin \
  -H "Content-Type: application/json" \
  -d '{"member_id": 1, "mood": "happy"}'

curl -sS http://127.0.0.1:3000/feed
curl -sS http://127.0.0.1:3000/members
```

If **`MOCHI_API_KEY` is set**, prefix protected calls with:

`-H "Authorization: Bearer YOUR_KEY"` (not needed for `GET /health`).

### 7. Fish helper functions (optional)

Add to `~/.config/fish/config.fish` (adjust paths if your home layout differs):

```fish
# Mochi dev helpers
function mochi-llama
  ~/llama.cpp/build/bin/llama-server \
    -m ~/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
    --host 127.0.0.1 --port 8080 \
    --ctx-size 2048 -t (nproc) -n 150
end

function mochi-start
  cd ~/mochi/server
  pm2 start ecosystem.config.cjs
end

function mochi-logs
  pm2 logs mochi-server
end

function mochi-status
  pm2 status
end

function mochi-restart
  pm2 restart mochi-server
end
```

Reload:

```fish
source ~/.config/fish/config.fish
```

Then **terminal 1:** `mochi-llama` · **terminal 2:** `mochi-start` and `mochi-logs`.

### 8. Typical dev workflow (e.g. CachyOS)

1. Start **`mochi-llama`** (or the long `llama-server` command) and keep it running.
2. Start / resurrect the Node app: **`mochi-start`** or `cd ~/mochi/server && pnpm pm2:start`.
3. After editing server code: **`pm2 reload mochi-server`** (graceful) or **`pm2 restart mochi-server`** if something is stuck.

---

### What Runs On The Note 8

- `llama-server` for local TinyLlama inference
- `pm2` to keep the Node server alive, restart it on crashes, and keep logs
- `cloudflared` to expose the local server if you are using a tunnel
- `termux-boot` to restore everything after a reboot

The current backend uses SQLite, so there is no `pg_ctl` step.

## Install PM2

```bash
pnpm add -g pm2
```

## Server Layout

```text
server/
├── ecosystem.config.cjs
├── logs/
├── package.json
├── scripts/
│   └── termux-boot.sh
└── src/
```

`server/logs/` is ignored by git and is where PM2 writes `out.log` and `error.log`.

## Environment

Create `server/.env` on the phone (or copy from `.env.example` on PC — see **Running on a PC** above):

```bash
PORT=3000
MOCHI_API_KEY=
LLAMA_URL=http://127.0.0.1:8080
GEMINI_API_KEY=your_key_here
MOOD_DECAY_HOURS=12
XP_PER_CHAT=10
XP_PER_CHECKIN=5
XP_PER_TAP=2
```

Set `MOCHI_API_KEY` to a long random string when the API should reject anonymous clients (recommended if the port is reachable on a LAN). The Flutter app must pass the same value via `--dart-define=MOCHI_API_KEY=...`.

## Package Scripts

From `server/`:

```bash
pnpm start
pnpm dev
pnpm pm2:start
pnpm pm2:status
pnpm pm2:logs
pnpm pm2:restart
pnpm pm2:reload
pnpm pm2:stop
pnpm pm2:save
```

## Ecosystem Config

The PM2 config lives at `server/ecosystem.config.cjs`.

Important behavior:

- `max_memory_restart: '300M'` restarts the server before it starts fighting TinyLlama for RAM
- `restart_delay: 3000` avoids a hot crash loop
- `max_restarts: 10` stops endless restart churn if the app is fundamentally broken
- `cwd: __dirname` resolves to the `server/` directory automatically, including on Termux

## First-Time Setup On The Note 8

```bash
cd ~/mochi/server
pnpm install
mkdir -p logs
pm2 start ecosystem.config.cjs
pm2 status
pm2 save
```

If your repo is cloned at `~/mochi`, `cwd: __dirname` resolves to:

```text
/data/data/com.termux/files/home/mochi/server
```

## Daily PM2 Commands

```bash
cd ~/mochi/server

pm2 start ecosystem.config.cjs
pm2 status
pm2 logs mochi-server
pm2 logs mochi-server --err
pm2 restart mochi-server
pm2 stop mochi-server
pm2 reload mochi-server
pm2 save
```

## Termux:Boot

The example boot script is in `server/scripts/termux-boot.sh`.

Copy it into your Termux boot directory and make it executable:

```bash
mkdir -p ~/.termux/boot
cp ~/mochi/server/scripts/termux-boot.sh ~/.termux/boot/mochi.sh
chmod +x ~/.termux/boot/mochi.sh
```

What it does:

- waits for the phone to finish booting
- starts `llama-server`
- starts `cloudflared`
- runs `pm2 resurrect` so the saved `mochi-server` process comes back with the same restart rules and logs

## Updating The Server

After pulling code changes:

```bash
cd ~/mochi/server
pnpm install
pm2 reload mochi-server
pm2 save
```

## Log Paths

```text
server/logs/out.log
server/logs/error.log
```

Live log tail:

```bash
cd ~/mochi/server
pm2 logs mochi-server
```

Errors only:

```bash
cd ~/mochi/server
pm2 logs mochi-server --err
```

## Troubleshooting

If `POST /chat` fails, the server is usually fine and the missing piece is one of these:

- `llama-server` is not reachable at `LLAMA_URL`
- `GEMINI_API_KEY` is missing, so fallback cannot run

Quick checks:

```bash
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:8080/health
pm2 status
pm2 logs mochi-server --err
```

If `MOCHI_API_KEY` is set, protected routes return `401` without a matching `Authorization: Bearer …` header (see **Running on a PC**).
