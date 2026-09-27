-- INTERVAL COSMOS v2.0.5
-- Phase 1 database bootstrap manifest.
--
-- The original 1,571-line Phase 1 fresh-build SQL was accidentally replaced
-- in the repository by a placeholder during v2.0.5 development. The canonical
-- source has now been restored verbatim into eight ordered files under:
--
--   sql/base-v2.0.5/part-01.sql
--   sql/base-v2.0.5/part-02.sql
--   sql/base-v2.0.5/part-03.sql
--   sql/base-v2.0.5/part-04.sql
--   sql/base-v2.0.5/part-05.sql
--   sql/base-v2.0.5/part-06.sql
--   sql/base-v2.0.5/part-07.sql
--   sql/base-v2.0.5/part-08.sql
--
-- This root file is intentionally a psql include manifest rather than another
-- duplicated 60 KB copy. `\ir` resolves paths relative to this script, so the
-- Phase 1 base can be executed deterministically from the repository root.
--
-- IMPORTANT:
--   * This Phase 1 base intentionally drops the pre-v2.0.5 application tables.
--   * Do NOT run it against a production database containing data you need.
--   * auth.users is not dropped by the base script.
--   * This file alone creates the canonical Phase 1 base only.
--
-- For the COMPLETE current v2.0.5 database, do not manually guess migration
-- order. Use:
--
--   DATABASE_URL='postgresql://...' bash scripts/apply-v2.0.5-db.sh
--
-- That runner applies this base first, then the avatar catalog, device linking,
-- recovery, progression, assignment, admin-dashboard, and staff-registration
-- migrations in the reviewed order recorded in sql/V2.0.5_MIGRATION_ORDER.md.
-- It runs psql with ON_ERROR_STOP so the build stops at the first SQL error.
--
-- If you need a single pasteable SQL document for Supabase SQL Editor, build
-- and verify one from this ordered source set before release rather than editing
-- the generated database schema by hand.

\set ON_ERROR_STOP on

\ir sql/base-v2.0.5/part-01.sql
\ir sql/base-v2.0.5/part-02.sql
\ir sql/base-v2.0.5/part-03.sql
\ir sql/base-v2.0.5/part-04.sql
\ir sql/base-v2.0.5/part-05.sql
\ir sql/base-v2.0.5/part-06.sql
\ir sql/base-v2.0.5/part-07.sql
\ir sql/base-v2.0.5/part-08.sql
