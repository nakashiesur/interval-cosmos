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
  "sql/account-avatar-default-v2.0.5.sql"
  "sql/progression-v2.0.5.sql"
  "sql/assignments-v2.0.5.sql"
  "sql/assignments-admin-only-v2.0.5.sql"
  "sql/assignments-multimode-v2.0.5.sql"
  "sql/admin-dashboard-v2.0.5.sql"
  "sql/staff-self-registration-v2.0.5.sql"
  "sql/admin-player-management-v2.0.5.sql"
  "sql/security-hardening-v2.0.5.sql"
  "supabase/migrations/20260915032833_offline_submission_guard.sql"
  "supabase/migrations/20260924145138_shared_learning_answers.sql"
  "supabase/migrations/20260927094923_ranking_private_bests_rls.sql"
  "supabase/migrations/20260927095714_suspended_admin_guard.sql"
  "supabase/migrations/20260927103943_suspended_account_actions.sql"
  "supabase/migrations/20260929105007_additive_mastery_and_admin_self_management.sql"
  "supabase/migrations/20260929111219_prospective_reward_balance.sql"
  "supabase/migrations/20260929113538_attainable_progression_and_frame_order.sql"
  "supabase/migrations/20260929115249_balanced_practice_rewards.sql"
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
