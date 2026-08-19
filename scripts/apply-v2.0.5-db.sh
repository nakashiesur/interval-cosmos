#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql is required." >&2
  exit 1
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: DATABASE_URL is not set." >&2
  echo "Example: DATABASE_URL='postgresql://...' bash scripts/apply-v2.0.5-db.sh" >&2
  exit 1
fi

FILES=(
  "supabase_setup.sql"
  "sql/avatar-catalog-v2.0.5.sql"
  "sql/device-link-v2.0.5.sql"
  "sql/account-recovery-v2.0.5.sql"
  "sql/progression-v2.0.5.sql"
  "sql/assignments-v2.0.5.sql"
  "sql/assignments-admin-only-v2.0.5.sql"
  "sql/assignments-multimode-v2.0.5.sql"
  "sql/admin-dashboard-v2.0.5.sql"
  "sql/staff-self-registration-v2.0.5.sql"
  "sql/admin-player-management-v2.0.5.sql"
)

if grep -q '__TOO_LARGE_PLACEHOLDER__' "$ROOT_DIR/supabase_setup.sql"; then
  echo "ERROR: root supabase_setup.sql is still the known placeholder (Issue #6)." >&2
  echo "Restore the Phase 1 base before running this migration chain." >&2
  exit 1
fi

for relative in "${FILES[@]}"; do
  file="$ROOT_DIR/$relative"
  if [[ ! -f "$file" ]]; then
    echo "ERROR: missing migration: $relative" >&2
    exit 1
  fi
  echo "==> Applying $relative"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file"
done

echo "==> INTERVAL COSMOS v2.0.5 database migration chain completed successfully."
