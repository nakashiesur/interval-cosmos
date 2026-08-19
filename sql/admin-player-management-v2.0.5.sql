-- INTERVAL COSMOS v2.0.5
-- Phase 8 completion: admin player/ranking/account management RPCs
-- Run AFTER sql/staff-self-registration-v2.0.5.sql.
--
-- Destructive Auth-user deletion is intentionally NOT performed here.
-- Complete deletion is handled by the server-side Edge Function
-- supabase/functions/admin-delete-player/index.ts so the service_role key never
-- appears in browser JavaScript.

begin;

create or replace function public.admin_update_player_profile(
  p_player_id uuid,
  p_player_name text,
  p_course_code text,
  p_avatar_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.players%rowtype;
begin
  if not public.is_current_admin() then
    raise exception 'Admin account required';
  end if;

  select * into v_target
  from public.players
  where id = p_player_id
  for update;

  if not found then
    raise exception 'Player not found';
  end if;

  if v_target.account_type <> 'student' then
    raise exception 'This editor currently supports student profiles only';
  end if;

  if char_length(btrim(coalesce(p_player_name,''))) not between 2 and 16 then
    raise exception 'Player name must be 2-16 characters';
  end if;

  if p_course_code is null or not exists (
    select 1 from public.courses c where c.code = p_course_code
  ) then
    raise exception 'Invalid course';
  end if;

  if p_avatar_id is null or not exists (
    select 1
    from public.avatar_catalog a
    where a.id = p_avatar_id
      and a.is_active
      and not a.staff_only
  ) then
    raise exception 'Invalid avatar';
  end if;

  update public.players p
  set player_name = btrim(p_player_name),
      course_code = p_course_code,
      avatar_id = p_avatar_id
  where p.id = p_player_id;

  return jsonb_build_object(
    'ok', true,
    'player_id', p_player_id,
    'player_name', btrim(p_player_name),
    'course_code', p_course_code,
    'avatar_id', p_avatar_id
  );
end;
$$;

create or replace function public.admin_set_player_suspended(
  p_player_id uuid,
  p_suspended boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_current_admin() then
    raise exception 'Admin account required';
  end if;

  if p_player_id = public.current_player_id() then
    raise exception 'You cannot suspend your own admin account';
  end if;

  update public.players p
  set is_suspended = coalesce(p_suspended,false)
  where p.id = p_player_id;

  if not found then
    raise exception 'Player not found';
  end if;

  return jsonb_build_object(
    'ok', true,
    'player_id', p_player_id,
    'is_suspended', coalesce(p_suspended,false)
  );
end;
$$;

-- Remove the player's currently published leaderboard records without deleting
-- play history or their private bests. This is the safe "make rankings private"
-- operation.
create or replace function public.admin_unpublish_player_rankings(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rows integer;
begin
  if not public.is_current_admin() then
    raise exception 'Admin account required';
  end if;

  if not exists (select 1 from public.players p where p.id = p_player_id) then
    raise exception 'Player not found';
  end if;

  update public.play_sessions
  set is_public = false
  where player_id = p_player_id
    and source = 'ranked'
    and is_public;

  update public.ranking_bests
  set public_session_id = null,
      public_score = null,
      public_total_answers = null,
      public_correct_answers = null,
      public_max_combo = null,
      public_avg_response = null,
      public_updated_at = null
  where player_id = p_player_id;

  get diagnostics v_rows = row_count;

  return jsonb_build_object('ok', true, 'player_id', p_player_id, 'ranking_rows_unpublished', v_rows);
end;
$$;

-- Delete the player's ranking-best cache while preserving durable play history.
-- This is stronger than unpublish and intentionally requires an explicit UI
-- confirmation. A future ranked submission can create new best rows again.
create or replace function public.admin_delete_player_rankings(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rows integer;
begin
  if not public.is_current_admin() then
    raise exception 'Admin account required';
  end if;

  if not exists (select 1 from public.players p where p.id = p_player_id) then
    raise exception 'Player not found';
  end if;

  update public.play_sessions
  set is_public = false
  where player_id = p_player_id
    and source = 'ranked'
    and is_public;

  delete from public.ranking_bests
  where player_id = p_player_id;

  get diagnostics v_rows = row_count;

  return jsonb_build_object('ok', true, 'player_id', p_player_id, 'ranking_rows_deleted', v_rows);
end;
$$;

-- Server-side Edge Function uses this to perform the final application-row
-- deletion only after it has verified the caller and deleted linked auth.users
-- with the service-role admin API.
create or replace function public.admin_delete_player_application_row(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_current_admin() then
    raise exception 'Admin account required';
  end if;

  if p_player_id = public.current_player_id() then
    raise exception 'You cannot delete your own admin account';
  end if;

  delete from public.players p where p.id = p_player_id;
  if not found then
    raise exception 'Player not found';
  end if;
end;
$$;

revoke all on function public.admin_update_player_profile(uuid,text,text,text) from public, anon;
revoke all on function public.admin_set_player_suspended(uuid,boolean) from public, anon;
revoke all on function public.admin_unpublish_player_rankings(uuid) from public, anon;
revoke all on function public.admin_delete_player_rankings(uuid) from public, anon;
revoke all on function public.admin_delete_player_application_row(uuid) from public, anon;

grant execute on function public.admin_update_player_profile(uuid,text,text,text) to authenticated;
grant execute on function public.admin_set_player_suspended(uuid,boolean) to authenticated;
grant execute on function public.admin_unpublish_player_rankings(uuid) to authenticated;
grant execute on function public.admin_delete_player_rankings(uuid) to authenticated;
-- Deliberately NOT granted to authenticated. The Edge Function invokes this as
-- service_role after independently verifying the requester's admin status.
revoke execute on function public.admin_delete_player_application_row(uuid) from authenticated;

grant execute on function public.admin_delete_player_application_row(uuid) to service_role;

notify pgrst, 'reload schema';
commit;
