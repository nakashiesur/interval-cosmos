#!/bin/bash
cd "$(dirname "$0")"
PORT=8765
printf '\nINTERVAL COSMOS を起動します…\n終了する時は、このウインドウで Control + C を押してください。\n\n'
python3 -m http.server "$PORT" >/tmp/interval-cosmos-server.log 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null' EXIT INT TERM
sleep 1
open "http://localhost:$PORT"
wait "$SERVER_PID"
