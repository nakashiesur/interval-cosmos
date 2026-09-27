#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
PORT=8876
SERVER_PID=""
stop() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
}
trap stop EXIT INT TERM
printf '\nINTERVAL COSMOS v2.0.5 — FRESH BUILD TEST\n'
printf 'Fresh Build Test DB専用の localhost:8876 で起動します。\n'
printf '通常の cloud-config.js と開発サーバー(8875)は変更しません。\n'
printf '終了: Control + C\n\n'
python3 scripts/serve-fresh-test.py --port "$PORT" &
SERVER_PID=$!
sleep 1
kill -0 "$SERVER_PID"
open "http://127.0.0.1:$PORT/?fresh-build-test=1"
wait "$SERVER_PID"
