-- INTERVAL COSMOS v2.0.5
-- Phase 6 permission correction
-- IMPORTANT: staff accounts are normal players. Only is_admin = true may manage assignments.
-- Run after sql/assignments-v2.0.5.sql if that file has already been applied.

begin;

-- Legacy helper name kept temporarily for compatibility with the Phase 6 RPCs.
-- Despite the function name, this now means "internal administrator only".
create or replace function public.is_current_teacher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.is_admin and not p.is_suspended
    from public.players p
    where p.id = public.current_player_id()
    limit 1
  ), false);
$$;

comment on function public.is_current_teacher() is
  'Legacy Phase 6 helper. Returns true only for the internal administrator (players.is_admin = true); ordinary staff accounts are normal players.';

-- Browser clients do not need to call the helper directly.
revoke execute on function public.is_current_teacher() from public, anon, authenticated;

commit;
