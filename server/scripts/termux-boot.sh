#!/data/data/com.termux/files/usr/bin/bash

sleep 10

# SQLite is embedded, so there is no pg_ctl step in the current stack.

~/llama.cpp/build/bin/llama-server \
  -m ~/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
  --host 127.0.0.1 \
  --port 8080 \
  --ctx-size 2048 \
  --threads 4 \
  -n 150 &

sleep 15

cloudflared tunnel run --url http://localhost:3000 petling &

sleep 3

pm2 resurrect
