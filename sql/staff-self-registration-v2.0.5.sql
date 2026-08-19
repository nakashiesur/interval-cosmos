-- INTERVAL COSMOS v2.0.5
-- Staff self-registration + private real-name identity
--
-- Policy:
-- - Staff may self-register from the client.
-- - Staff are ordinary players by default (is_admin = false).
-- - real_name is private and never copied to public_profiles.
-- - Teacher avatar is fixed; no student number/course is used.

alter table public.players
  add column if not exists real_name text;

comment on column public.players.real_name is
  'Private real name. Used for staff identity/administration only; never copied to public_profiles.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.players'::regclass
      and conname = 'players_real_name_length_check'
  ) then
    alter table public.players
      add constraint players_real_name_length_check
      check (
        real_name is null
        or char_length(btrim(real_name)) between 2 and 40
      );
  end if;
end;
$$;

create or replace function public.create_staff_account(
  p_real_name text,
  p_player_name text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := (select auth.uid());
  v_player_id uuid;
begin
  if v_auth_uid is null then
    raise exception 'Authentication required';
  end if;

  if exists (
    select 1
    from public.player_devices pd
    where pd.auth_user_id = v_auth_uid
  ) then
    raise exception 'This device is already linked to a player';
  end if;

  if char_length(btrim(coalesce(p_real_name, ''))) not between 2 and 40 then
    raise exception 'Real name must be 2-40 characters';
  end if;

  if char_length(btrim(coalesce(p_player_name, ''))) not between 2 and 16 then
    raise exception 'Player name must be 2-16 characters';
  end if;

  if not exists (
    select 1
    from public.avatar_catalog a
    where a.id = 'teacher'
      and a.is_active
      and a.staff_only
  ) then
    raise exception 'Teacher avatar is unavailable';
  end if;

  insert into public.players (
    account_type,
    student_number,
    real_name,
    player_name,
    course_code,
    avatar_id,
    is_admin
  ) values (
    'staff',
    null,
    btrim(p_real_name),
    btrim(p_player_name),
    null,
    'teacher',
    false
  )
  returning id into v_player_id;

  insert into public.player_devices (
    auth_user_id,
    player_id,
    device_label
  ) values (
    v_auth_uid,
    v_player_id,
    'Staff primary device'
  );

  insert into public.player_frames (player_id, frame_id)
  values (v_player_id, 'normal')
  on conflict do nothing;

  return v_player_id;
end;
$$;

create or replace function public.get_my_private_identity()
returns table (
  account_type text,
  real_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.account_type, p.real_name
  from public.players p
  where p.id = public.current_player_id();
$$;

create or replace function public.update_my_staff_identity(
  p_real_name text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player_id uuid := public.current_player_id();
  v_type text;
begin
  if v_player_id is null then
    raise exception 'Player account required';
  end if;

  select p.account_type
  into v_type
  from public.players p
  where p.id = v_player_id;

  if v_type <> 'staff' then
    raise exception 'Staff account required';
  end if;

  if char_length(btrim(coalesce(p_real_name, ''))) not between 2 and 40 then
    raise exception 'Real name must be 2-40 characters';
  end if;

  update public.players p
  set real_name = btrim(p_real_name)
  where p.id = v_player_id;
end;
$$;

revoke all on function public.create_staff_account(text, text) from public, anon;
revoke all on function public.get_my_private_identity() from public, anon;
revoke all on function public.update_my_staff_identity(text) from public, anon;

grant execute on function public.create_staff_account(text, text) to authenticated;
grant execute on function public.get_my_private_identity() to authenticated;
grant execute on function public.update_my_staff_identity(text) to authenticated;
