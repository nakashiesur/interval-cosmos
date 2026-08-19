-- INTERVAL COSMOS v2.0.5
-- Canonical avatar catalog used by the v2.0.5 account UI.
--
-- The Phase 1 base schema originally contained only `default + teacher` as
-- placeholders. The v2.0.5 client registration UI uses the 12 student avatar
-- IDs below, in this exact display order. Keep this migration idempotent so it
-- can safely normalize an already-running development database.

begin;

insert into public.avatar_catalog
  (id, display_name, asset_path, staff_only, is_active, sort_order)
values
  ('nova',    'NOVA',    null, false, true,   10),
  ('orbit',   'ORBIT',   null, false, true,   20),
  ('pulse',   'PULSE',   null, false, true,   30),
  ('prism',   'PRISM',   null, false, true,   40),
  ('comet',   'COMET',   null, false, true,   50),
  ('nebula',  'NEBULA',  null, false, true,   60),
  ('vector',  'VECTOR',  null, false, true,   70),
  ('echo',    'ECHO',    null, false, true,   80),
  ('quasar',  'QUASAR',  null, false, true,   90),
  ('lumen',   'LUMEN',   null, false, true,  100),
  ('wave',    'WAVE',    null, false, true,  110),
  ('aster',   'ASTER',   null, false, true,  120),
  ('teacher', 'TEACHER', null, true,  true,  1000)
on conflict (id) do update
set display_name = excluded.display_name,
    asset_path   = excluded.asset_path,
    staff_only   = excluded.staff_only,
    is_active    = excluded.is_active,
    sort_order   = excluded.sort_order;

-- `default` was only a Phase 1 placeholder. Keep the row for FK compatibility
-- with any early test data, but remove it from the active selectable catalog.
update public.avatar_catalog
set is_active = false,
    sort_order = 0
where id = 'default';

-- New rows should fall back to the real first student avatar rather than the
-- inactive Phase 1 placeholder. Client registration already supplies an avatar
-- explicitly, but the DB default should be internally valid as well.
alter table public.players
  alter column avatar_id set default 'nova';

commit;
