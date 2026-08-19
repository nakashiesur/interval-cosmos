    account_type, student_number, player_name, course_code, avatar_id
  )
  values (
    p_account_type, v_student_number, btrim(p_player_name), p_course_code, v_avatar_id
  )
  returning id into v_player_id;

  insert into public.player_devices (auth_user_id, player_id, device_label)
  values (v_auth_uid, v_player_id, 'Primary device');

  insert into public.player_frames (player_id, frame_id)
  values (v_player_id, 'normal')
  on conflict do nothing;

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

create or replace function public.get_my_player()
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
  is_suspended boolean,
  is_admin boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.account_type, p.student_number, p.player_name, p.course_code,
         p.avatar_id, p.ranking_visibility, p.main_title_id,
         p.equipped_frame_id, p.achievement_points, p.is_suspended,
         p.is_admin, p.created_at, p.updated_at
  from public.players p
  where p.id = public.current_player_id();
$$;


create or replace function public.update_my_profile(
  p_player_name text default null,
  p_avatar_id text default null,
  p_ranking_visibility text default null,
  p_main_title_id text default null,
  p_equipped_frame_id text default null
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

  if p_player_name is not null
     and char_length(btrim(p_player_name)) not between 2 and 16 then
    raise exception 'Player name must be 2-16 characters';
  end if;

  if p_ranking_visibility is not null
     and p_ranking_visibility not in ('ask','always_public','always_private') then
    raise exception 'Invalid ranking visibility';
  end if;

  if p_avatar_id is not null then
    if v_type = 'staff' and p_avatar_id <> 'teacher' then
      raise exception 'Staff avatar is fixed';
    end if;
    if v_type = 'student' and not exists (
      select 1 from public.avatar_catalog a
      where a.id = p_avatar_id and a.is_active and not a.staff_only
    ) then
      raise exception 'Invalid avatar';
    end if;
  end if;

  if p_main_title_id is not null and not exists (
    select 1 from public.player_titles pt
    where pt.player_id = v_player_id and pt.title_id = p_main_title_id
  ) then
    raise exception 'Title is not unlocked';
  end if;

  if p_equipped_frame_id is not null and not exists (
    select 1 from public.player_frames pf
    where pf.player_id = v_player_id and pf.frame_id = p_equipped_frame_id
  ) then
    raise exception 'Frame is not unlocked';
  end if;

  update public.players p
  set player_name = coalesce(btrim(p_player_name), p.player_name),
      avatar_id = case
        when v_type = 'staff' then 'teacher'
        else coalesce(p_avatar_id, p.avatar_id)
      end,
      ranking_visibility = coalesce(p_ranking_visibility, p.ranking_visibility),
      main_title_id = coalesce(p_main_title_id, p.main_title_id),
      equipped_frame_id = coalesce(p_equipped_frame_id, p.equipped_frame_id)
  where p.id = v_player_id;
end;
$$;

-- =========================================================
-- 8. Ranked play submission / publication
-- =========================================================

create or replace function public.submit_play_session(
  p_client_event_id uuid,
  p_source text,
  p_mode text,
  p_score integer,
  p_total_answers integer,
  p_correct_answers integer,
  p_max_combo integer,
  p_avg_response double precision,
  p_interval_stats jsonb default '{}'::jsonb,
  p_played_at timestamptz default now(),
  p_assignment_id uuid default null
)
returns table (
  session_id uuid,
  duplicate boolean,
  publication_required boolean,
  monthly_rank bigint,
  hall_rank bigint,
  monthly_best_score integer,
  hall_best_score integer,
  monthly_best_improved boolean,
  hall_best_improved boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player_id uuid := public.current_player_id();
  v_visibility text;
  v_suspended boolean;
  v_session_id uuid;
  v_month text;
  v_is_public boolean := false;
  v_existing_session uuid;
  v_month_old integer;
  v_hall_old integer;
  v_month_best integer;
  v_hall_best integer;
  v_accuracy numeric(5,2);
  v_assignment public.assignments%rowtype;
  v_played_at timestamptz;
begin
  if v_player_id is null then
    raise exception 'Player account required';
  end if;

  select p.ranking_visibility, p.is_suspended
  into v_visibility, v_suspended
  from public.players p
  where p.id = v_player_id;

  if v_suspended then
    raise exception 'Account suspended';
  end if;

  if p_client_event_id is null then
    raise exception 'client_event_id is required';
  end if;
  if p_source not in ('ranked','practice','assignment') then
    raise exception 'Invalid source';
  end if;
  if p_mode not in ('TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK') then
    raise exception 'Invalid mode';
