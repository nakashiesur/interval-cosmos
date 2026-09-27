  completed_at timestamptz,
  primary key (player_id, mission_date, slot),
  unique (player_id, mission_date, mission_id)
);

-- =========================================================
-- 6. Shared helpers
-- =========================================================

create or replace function public.normalize_student_number(p_input text)
returns text
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(
    translate(coalesce(p_input, ''), '０１２３４５６７８９', '0123456789'),
    '[^0-9]',
    '',
    'g'
  );
$$;

create or replace function public.current_player_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select pd.player_id
  from public.player_devices pd
  where pd.auth_user_id = (select auth.uid())
  limit 1;
$$;

create or replace function public.is_current_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.is_admin
    from public.players p
    join public.player_devices pd on pd.player_id = p.id
    where pd.auth_user_id = (select auth.uid())
    limit 1
  ), false);
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;


create or replace function public.normalize_player_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.player_name := btrim(new.player_name);
  if new.account_type = 'student' then
    new.student_number := public.normalize_student_number(new.student_number);
  else
    new.student_number := null;
    new.course_code := null;
    new.avatar_id := 'teacher';
  end if;
  return new;
end;
$$;

create trigger players_normalize_fields
before insert or update of account_type, student_number, player_name, course_code, avatar_id
on public.players
for each row execute function public.normalize_player_fields();

create or replace function public.sync_public_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.public_profiles (
    player_id, account_type, player_name, course_code, avatar_id,
    main_title_id, equipped_frame_id, achievement_points, updated_at
  )
  values (
    new.id, new.account_type, new.player_name, new.course_code, new.avatar_id,
    new.main_title_id, new.equipped_frame_id, new.achievement_points, now()
  )
  on conflict (player_id) do update
  set account_type = excluded.account_type,
      player_name = excluded.player_name,
      course_code = excluded.course_code,
      avatar_id = excluded.avatar_id,
      main_title_id = excluded.main_title_id,
      equipped_frame_id = excluded.equipped_frame_id,
      achievement_points = excluded.achievement_points,
      updated_at = now();
  return new;
end;
$$;

create trigger players_touch_updated_at
before update on public.players
for each row execute function public.touch_updated_at();

create trigger assignments_touch_updated_at
before update on public.assignments
for each row execute function public.touch_updated_at();

create trigger players_sync_public_profile
after insert or update of account_type, player_name, course_code, avatar_id,
  main_title_id, equipped_frame_id, achievement_points
on public.players
for each row execute function public.sync_public_profile();

-- =========================================================
-- 7. Player account RPCs
-- =========================================================

create or replace function public.create_player_account(
  p_account_type text,
  p_student_number text,
  p_player_name text,
  p_course_code text,
  p_avatar_id text default 'default'
)
returns table (
  player_id uuid,
  account_type text,
  student_number text,
  player_name text,
  course_code text,
  avatar_id text,
  ranking_visibility text,
  main_title_id text,
  equipped_frame_id text,
  achievement_points integer,
  is_suspended boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := (select auth.uid());
  v_player_id uuid;
  v_student_number text;
  v_avatar_id text;
begin
  if v_auth_uid is null then
    raise exception 'Authentication required';
  end if;

  if exists (select 1 from public.player_devices pd where pd.auth_user_id = v_auth_uid) then
    raise exception 'This device is already linked to a player';
  end if;

  if p_account_type <> 'student' then
    raise exception 'Staff accounts require administrator setup';
  end if;

  if char_length(btrim(coalesce(p_player_name,''))) not between 2 and 16 then
    raise exception 'Player name must be 2-16 characters';
  end if;

  v_student_number := public.normalize_student_number(p_student_number);
  if char_length(v_student_number) not between 3 and 20 then
    raise exception 'Invalid student number';
  end if;
  if p_course_code is null or not exists (
    select 1 from public.courses c where c.code = p_course_code
  ) then
    raise exception 'Invalid course';
  end if;
  v_avatar_id := coalesce(nullif(p_avatar_id,''), 'default');
  if v_avatar_id = 'teacher' then
    raise exception 'Teacher avatar is staff-only';
  end if;
  if not exists (
    select 1 from public.avatar_catalog a
    where a.id = v_avatar_id and a.is_active and not a.staff_only
  ) then
    raise exception 'Invalid avatar';
  end if;

  insert into public.players (
