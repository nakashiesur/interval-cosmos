#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
PORT=8876
CONFIG="cloud-config.js"
BACKUP="$(mktemp /tmp/interval-cosmos-cloud-config.XXXXXX)"
SERVER_PID=""

restore() {
  if [[ -f "$BACKUP" ]]; then
    cp "$BACKUP" "$CONFIG" 2>/dev/null || true
    rm -f "$BACKUP" 2>/dev/null || true
  fi
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
}
trap restore EXIT INT TERM

cp "$CONFIG" "$BACKUP"
cat > "$CONFIG" <<'EOF'
window.INTERVAL_COSMOS_CLOUD = {
  supabaseUrl: 'https://yaqeeyhajnpwqvdjondk.supabase.co',
  supabaseAnonKey: 'sb_publishable_fVjvKHTikP_GEMiukEXqFw_oziY4vET',
  rankingsTable: 'rankings',
  profilesTable: 'profiles'
};
EOF

printf '\nINTERVAL COSMOS v2.0.5 — FRESH BUILD TEST\n'
printf '通常の開発DBではなく、使い捨てFresh Build Test DBへ接続します。\n'
printf '通常開発サーバー(8875)とは別の 8876 ポートを使用します。\n'
printf '終了する時は、このウインドウで Control + C を押してください。\n'
printf '終了時に cloud-config.js は自動的に元へ戻ります。\n\n'

python3 -m http.server "$PORT" >/tmp/interval-cosmos-v205-fresh-server.log 2>&1 &
SERVER_PID=$!
sleep 1
open "http://localhost:$PORT/?fresh-build-test=1"
wait "$SERVER_PID"
