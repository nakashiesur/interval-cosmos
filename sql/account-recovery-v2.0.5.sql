-- INTERVAL COSMOS v2.0.5
-- Phase 2.5: self-service recovery after cookie/site-data loss
-- Run AFTER the v2.0.5 base schema.

begin;

-- Supabase installs most extensions under `extensions`.
-- Keep pgcrypto in that schema so SECURITY DEFINER functions can qualify it safely.
create schema if not exists extensions;
do $$
declare
  v_schema text;
begin
  select n.nspname
    into v_schema
  from pg_extension e
  join pg_namespace n on n.oid = e.extnamespace
  where e.extname = 'pgcrypto';

  if v_schema is null then
    execute 'create extension pgcrypto with schema extensions';
  elsif v_schema <> 'extensions' then
    execute 'alter extension pgcrypto set schema extensions';
  end if;
end;
$$;

-- Recovery credentials are deliberately separate from `players` and have no
-- client-readable policy. Only SECURITY DEFINER RPCs below may inspect hashes.
create table if not exists public.player_recovery_credentials (
  player_id uuid primary key references public.players(id) on delete cascade,
  recovery_code_hash text not null,
  failed_attempts smallint not null default 0 check (failed_attempts >= 0),
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.player_recovery_credentials enable row level security;
revoke all on table public.player_recovery_credentials from public, anon, authenticated;

create or replace function public.normalize_recovery_code(p_input text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(btrim(coalesce(p_input, '')));
$$;

create or replace function public.is_valid_recovery_code(p_input text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    public.normalize_recovery_code(p_input) ~ '^[A-Z0-9]{8,20}$'
    and public.normalize_recovery_code(p_input) ~ '[A-Z]'
    and public.normalize_recovery_code(p_input) ~ '[0-9]';
$$;

create or replace function public.set_my_recovery_code(p_recovery_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player_id uuid := public.current_player_id();
  v_type text;
  v_student_number text;
  v_code text := public.normalize_recovery_code(p_recovery_code);
begin
  if v_player_id is null then
    raise exception 'Player account required';
  end if;

  select p.account_type, p.student_number
    into v_type, v_student_number
  from public.players p
  where p.id = v_player_id;

  if v_type <> 'student' then
    raise exception 'Student account required';
  end if;

  if not public.is_valid_recovery_code(v_code) then
    raise exception 'Recovery code must be 8-20 letters/numbers and include both';
  end if;

  if v_student_number is not null and v_code = upper(v_student_number) then
    raise exception 'Recovery code cannot be the student number';
  end if;

  insert into public.player_recovery_credentials (
    player_id, recovery_code_hash, failed_attempts, locked_until, updated_at
  ) values (
    v_player_id,
    extensions.crypt(v_code, extensions.gen_salt('bf', 10)),
    0,
    null,
    now()
  )
  on conflict (player_id) do update
  set recovery_code_hash = excluded.recovery_code_hash,
      failed_attempts = 0,
      locked_until = null,
      updated_at = now();

  return jsonb_build_object('ok', true, 'configured', true);
end;
$$;

create or replace function public.get_my_recovery_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_player_id uuid := public.current_player_id();
begin
  if v_player_id is null then
    return jsonb_build_object('configured', false);
  end if;

  return jsonb_build_object(
    'configured', exists (
      select 1
      from public.player_recovery_credentials r
      where r.player_id = v_player_id
    )
  );
end;
$$;

-- Wrong-code attempts return a result rather than throwing so the failure count
-- commits. Five consecutive failures lock recovery for 15 minutes.
create or replace function public.recover_student_account(
  p_student_number text,
  p_recovery_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := (select auth.uid());
  v_student_number text := public.normalize_student_number(p_student_number);
  v_code text := public.normalize_recovery_code(p_recovery_code);
  v_player_id uuid;
  v_hash text;
  v_failed smallint;
  v_locked_until timestamptz;
  v_new_failed smallint;
begin
  if v_auth_uid is null then
    raise exception 'Authentication required';
  end if;

  if exists (
    select 1 from public.player_devices pd where pd.auth_user_id = v_auth_uid
  ) then
    return jsonb_build_object(
      'ok', false,
      'code', 'already_linked',
      'message', 'この端末はすでにアカウントへ接続されています。'
    );
  end if;

  if char_length(v_student_number) not between 3 and 20
     or not public.is_valid_recovery_code(v_code) then
    return jsonb_build_object(
      'ok', false,
      'code', 'invalid_credentials',
      'message', '学籍番号または復旧コードを確認してください。'
    );
  end if;

  select p.id
    into v_player_id
  from public.players p
  where p.account_type = 'student'
    and p.student_number = v_student_number
    and not p.is_suspended
  limit 1;

  if v_player_id is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'invalid_credentials',
      'message', '学籍番号または復旧コードを確認してください。'
    );
  end if;

  select r.recovery_code_hash, r.failed_attempts, r.locked_until
    into v_hash, v_failed, v_locked_until
  from public.player_recovery_credentials r
  where r.player_id = v_player_id
  for update;

  if v_hash is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'not_configured',
      'message', 'このアカウントには復旧コードがまだ設定されていません。管理者へ連絡してください。'
    );
  end if;

  if v_locked_until is not null and v_locked_until > now() then
    return jsonb_build_object(
      'ok', false,
      'code', 'locked',
      'message', '入力回数が上限に達しました。15分ほど待ってから再度お試しください。',
      'locked_until', v_locked_until
    );
  end if;

  if v_hash <> extensions.crypt(v_code, v_hash) then
    v_new_failed := coalesce(v_failed, 0) + 1;

    update public.player_recovery_credentials r
    set failed_attempts = case when v_new_failed >= 5 then 0 else v_new_failed end,
        locked_until = case when v_new_failed >= 5 then now() + interval '15 minutes' else null end,
        updated_at = now()
    where r.player_id = v_player_id;

    return jsonb_build_object(
      'ok', false,
      'code', case when v_new_failed >= 5 then 'locked' else 'invalid_credentials' end,
      'message', case
        when v_new_failed >= 5 then '入力回数が上限に達しました。15分ほど待ってから再度お試しください。'
        else '学籍番号または復旧コードを確認してください。'
      end,
      'remaining_attempts', greatest(0, 5 - v_new_failed)
    );
  end if;

  update public.player_recovery_credentials r
  set failed_attempts = 0,
      locked_until = null,
      updated_at = now()
  where r.player_id = v_player_id;

  insert into public.player_devices (
    auth_user_id, player_id, device_label, linked_at, last_seen_at
  ) values (
    v_auth_uid, v_player_id, 'Recovered device', now(), now()
  )
  on conflict (auth_user_id) do update
  set player_id = excluded.player_id,
      device_label = excluded.device_label,
      last_seen_at = now();

  return jsonb_build_object(
    'ok', true,
    'code', 'recovered',
    'player', (
      select to_jsonb(x)
      from public.get_my_player() x
    )
  );
end;
$$;

-- New registrations must set a recovery code from day one.
drop function if exists public.create_player_account(text,text,text,text,text);

create or replace function public.create_player_account(
  p_account_type text,
  p_student_number text,
  p_player_name text,
  p_course_code text,
  p_recovery_code text,
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
  v_code text := public.normalize_recovery_code(p_recovery_code);
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

  if not public.is_valid_recovery_code(v_code) then
    raise exception 'Recovery code must be 8-20 letters/numbers and include both';
  end if;

  if v_code = upper(v_student_number) then
    raise exception 'Recovery code cannot be the student number';
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
    account_type, student_number, player_name, course_code, avatar_id
  ) values (
    p_account_type, v_student_number, btrim(p_player_name), p_course_code, v_avatar_id
  )
  returning id into v_player_id;

  insert into public.player_devices (auth_user_id, player_id, device_label)
  values (v_auth_uid, v_player_id, 'Primary device');

  insert into public.player_frames (player_id, frame_id)
  values (v_player_id, 'normal')
  on conflict do nothing;

  insert into public.player_recovery_credentials (
    player_id, recovery_code_hash
  ) values (
    v_player_id,
    extensions.crypt(v_code, extensions.gen_salt('bf', 10))
  );

  return query
  select p.id, p.account_type, p.student_number, p.player_name, p.course_code,
         p.avatar_id, p.ranking_visibility, p.main_title_id,
         p.equipped_frame_id, p.achievement_points, p.is_suspended
  from public.players p
  where p.id = v_player_id;
exception
  when unique_violation then
    raise exception 'This student number is already registered';
end;
$$;

revoke execute on function public.normalize_recovery_code(text) from public, anon, authenticated;
revoke execute on function public.is_valid_recovery_code(text) from public, anon, authenticated;
revoke execute on function public.set_my_recovery_code(text) from public, anon;
revoke execute on function public.get_my_recovery_status() from public, anon;
revoke execute on function public.recover_student_account(text,text) from public, anon;
revoke execute on function public.create_player_account(text,text,text,text,text,text) from public, anon;

grant execute on function public.set_my_recovery_code(text) to authenticated;
grant execute on function public.get_my_recovery_status() to authenticated;
grant execute on function public.recover_student_account(text,text) to authenticated;
grant execute on function public.create_player_account(text,text,text,text,text,text) to authenticated;

commit;
