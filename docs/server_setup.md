# Server Setup

This repo now includes the backend in `server/` and shared backend data in `shared/`.

## What Runs On The Note 8

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

Create `server/.env` on the phone:

```bash
PORT=3000
LLAMA_URL=http://127.0.0.1:8080
GEMINI_API_KEY=your_key_here
MOOD_DECAY_HOURS=12
XP_PER_CHAT=10
XP_PER_CHECKIN=5
XP_PER_TAP=2
```

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
