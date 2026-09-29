-- Additive beta upgrade. Preserve existing earned rewards and accounts.
begin;
-- Admin self-management: admin authentication remains mandatory.
create or replace function public.get_admin_student_dashboard(p_player_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_student jsonb;
  v_summary jsonb;
  v_modes jsonb;
  v_recent jsonb;
  v_daily jsonb;
  v_hours jsonb;
  v_assignments jsonb;
  v_interval_snapshot jsonb;
begin
  if not public.is_current_admin() then
    raise exception 'Admin account required';
  end if;

  select jsonb_build_object(
    'player_id', p.id,
    'student_number', p.student_number,
    'player_name', p.player_name,
    'course_code', p.course_code,
    'course_name', c.display_name,
    'avatar_id', p.avatar_id,
    'created_at', p.created_at
  )
  into v_student
  from public.players p
  left join public.courses c on c.code = p.course_code
  where p.id = p_player_id
    and (p.account_type = 'student' or p.id = public.current_player_id());

  if v_student is null then
    raise exception 'Student not found';
  end if;

  select jsonb_build_object(
    'sessions_all', count(*)::integer,
    'sessions_30d', count(*) filter (where ps.played_at >= now() - interval '30 days')::integer,
    'answers_all', coalesce(sum(ps.total_answers),0),
    'correct_all', coalesce(sum(ps.correct_answers),0),
    'answers_30d', coalesce(sum(ps.total_answers) filter (where ps.played_at >= now() - interval '30 days'),0),
    'correct_30d', coalesce(sum(ps.correct_answers) filter (where ps.played_at >= now() - interval '30 days'),0),
    'best_score', coalesce(max(ps.score),0),
    'max_combo', coalesce(max(ps.max_combo),0),
    'last_play_at', max(ps.played_at),
    'ranked_sessions', count(*) filter (where ps.source = 'ranked')::integer,
    'practice_sessions', count(*) filter (where ps.source = 'practice')::integer,
    'assignment_sessions', count(*) filter (where ps.source = 'assignment')::integer
  )
  into v_summary
  from public.play_sessions ps
  where ps.player_id = p_player_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'mode', m.mode,
    'sessions_all', m.sessions_all,
    'sessions_30d', m.sessions_30d,
    'answers_all', m.answers_all,
    'correct_all', m.correct_all,
    'answers_30d', m.answers_30d,
    'correct_30d', m.correct_30d,
    'best_score', m.best_score,
    'max_combo', m.max_combo,
    'last_play_at', m.last_play_at
  ) order by m.mode), '[]'::jsonb)
  into v_modes
  from (
    select
      ps.mode,
      count(*)::integer as sessions_all,
      count(*) filter (where ps.played_at >= now() - interval '30 days')::integer as sessions_30d,
      coalesce(sum(ps.total_answers),0)::bigint as answers_all,
      coalesce(sum(ps.correct_answers),0)::bigint as correct_all,
      coalesce(sum(ps.total_answers) filter (where ps.played_at >= now() - interval '30 days'),0)::bigint as answers_30d,
      coalesce(sum(ps.correct_answers) filter (where ps.played_at >= now() - interval '30 days'),0)::bigint as correct_30d,
      coalesce(max(ps.score),0)::integer as best_score,
      coalesce(max(ps.max_combo),0)::integer as max_combo,
      max(ps.played_at) as last_play_at
    from public.play_sessions ps
    where ps.player_id = p_player_id
    group by ps.mode
  ) m;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', r.id,
    'source', r.source,
    'mode', r.mode,
    'score', r.score,
    'total_answers', r.total_answers,
    'correct_answers', r.correct_answers,
    'max_combo', r.max_combo,
    'avg_response', r.avg_response,
    'assignment_id', r.assignment_id,
    'played_at', r.played_at
  ) order by r.played_at desc), '[]'::jsonb)
  into v_recent
  from (
    select ps.*
    from public.play_sessions ps
    where ps.player_id = p_player_id
    order by ps.played_at desc
    limit 20
  ) r;

  with days as (
    select generate_series(
      (timezone('Asia/Tokyo', now())::date - 29),
      timezone('Asia/Tokyo', now())::date,
      interval '1 day'
    )::date as day
  ), activity as (
    select
      timezone('Asia/Tokyo', ps.played_at)::date as day,
      count(*)::integer as sessions,
      coalesce(sum(ps.total_answers),0)::bigint as answers,
      coalesce(sum(ps.correct_answers),0)::bigint as correct
    from public.play_sessions ps
    where ps.player_id = p_player_id
      and ps.played_at >= now() - interval '31 days'
    group by timezone('Asia/Tokyo', ps.played_at)::date
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'day', d.day,
    'sessions', coalesce(a.sessions,0),
    'answers', coalesce(a.answers,0),
    'correct', coalesce(a.correct,0)
  ) order by d.day), '[]'::jsonb)
  into v_daily
  from days d
  left join activity a on a.day = d.day;

  with hours as (
    select generate_series(0,23) as hour
  ), activity as (
    select
      extract(hour from timezone('Asia/Tokyo', ps.played_at))::integer as hour,
      count(*)::integer as sessions
    from public.play_sessions ps
    where ps.player_id = p_player_id
      and ps.played_at >= now() - interval '30 days'
    group by 1
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'hour', h.hour,
    'sessions', coalesce(a.sessions,0)
  ) order by h.hour), '[]'::jsonb)
  into v_hours
  from hours h
  left join activity a on a.hour = h.hour;

  select coalesce(jsonb_agg(jsonb_build_object(
    'assignment_id', a.id,
    'title', a.title,
    'allowed_modes', coalesce(a.allowed_modes, array[a.mode]),
    'start_at', a.start_at,
    'deadline_at', a.deadline_at,
    'is_published', a.is_published,
    'attempts', coalesce(ab.attempts,0),
    'best_score', ab.best_score,
    'best_accuracy', ab.best_accuracy,
    'achieved', coalesce(ab.achieved,false),
    'last_attempt_at', ab.last_attempt_at,
    'mode_bests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'mode', amb.mode,
        'best_score', amb.best_score,
        'best_accuracy', amb.best_accuracy,
        'attempts', amb.attempts,
        'achieved', amb.achieved,
        'last_attempt_at', amb.last_attempt_at
      ) order by amb.mode)
      from public.assignment_mode_bests amb
      where amb.assignment_id = a.id
        and amb.player_id = p_player_id
    ), '[]'::jsonb)
  ) order by a.deadline_at desc), '[]'::jsonb)
  into v_assignments
  from public.assignments a
  left join public.assignment_bests ab
    on ab.assignment_id = a.id
   and ab.player_id = p_player_id
  where a.is_published
     or ab.player_id is not null;

  select ps.interval_stats
  into v_interval_snapshot
  from public.play_sessions ps
  where ps.player_id = p_player_id
    and ps.interval_stats ? 'intervals'
    and jsonb_typeof(ps.interval_stats->'intervals') = 'object'
  order by ps.played_at desc
  limit 1;

  return jsonb_build_object(
    'generated_at', now(),
    'student', v_student,
    'summary', coalesce(v_summary, '{}'::jsonb),
    'modes', coalesce(v_modes, '[]'::jsonb),
    'daily_30d', coalesce(v_daily, '[]'::jsonb),
    'hours_30d', coalesce(v_hours, '[]'::jsonb),
    'recent_sessions', coalesce(v_recent, '[]'::jsonb),
    'assignments', coalesce(v_assignments, '[]'::jsonb),
    'interval_snapshot', coalesce(v_interval_snapshot, '{}'::jsonb)
  );
end;
$$;

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

  if v_target.account_type <> 'student' and v_target.id <> public.current_player_id() then
    raise exception 'This editor currently supports student profiles only';
  end if;

  if char_length(btrim(coalesce(p_player_name,''))) not between 2 and 16 then
    raise exception 'Player name must be 2-16 characters';
  end if;

  if (p_course_code is null and v_target.account_type <> 'staff')
    or (p_course_code is not null and not exists (
      select 1 from public.courses c where c.code = p_course_code
    )) then
    raise exception 'Invalid course';
  end if;

  if p_avatar_id is null or not exists (
    select 1
    from public.avatar_catalog a
    where a.id = p_avatar_id
      and a.is_active
      and (not a.staff_only or v_target.account_type = 'staff')
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



-- Additive rewards only: existing unlocks, points, accounts and history are preserved.
insert into public.achievement_catalog (id,display_name,description,category,points,hidden,requirement,sort_order,is_active) values
('sessions_250','DEEP SPACE VOYAGER','累計250回プレイする。','basic',150,false,'{"type": "sessions", "count": 250}'::jsonb,1100,true),
('sessions_1000','THOUSAND ORBITS','累計1,000回プレイする。','basic',300,false,'{"type": "sessions", "count": 1000}'::jsonb,1101,true),
('perfect_40','PRECISION ACE','40問以上のセッションを正答率100%で完了する。','accuracy',180,false,'{"type": "perfect_session", "min_answers": 40}'::jsonb,1102,true),
('combo_100','CENTURY CHAIN','100コンボに到達する。','combo',200,false,'{"type": "combo", "value": 100}'::jsonb,1103,true),
('streak_30','MONTHLY ORBIT','30日連続でプレイする。','streak',200,false,'{"type": "streak_days", "days": 30}'::jsonb,1104,true),
('streak_60','ENDURING STAR','60日連続でプレイする。','streak',300,false,'{"type": "streak_days", "days": 60}'::jsonb,1105,true),
('all_modes_perfect_30','FIVE STAR PRECISION','主要5モードそれぞれで30問以上・正答率100%を達成する。','mode',300,false,'{"type": "all_modes_perfect", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_answers": 30}'::jsonb,1106,true),
('ear_perfect_40','DEEP LISTENER','EAR LINKで40問以上・正答率100%を達成する。','accuracy',250,false,'{"type": "perfect_session", "mode": "EAR_LINK", "min_answers": 40}'::jsonb,1107,true)
on conflict (id) do nothing;
insert into public.frame_catalog (id,display_name,tier,points_required,animated,hidden,unlock_rule,sort_order,is_active) values
('pulsar','PULSAR',9,0,true,false,'{"type": "achievement_combo", "ids": ["sessions_250", "perfect_40", "streak_30"]}'::jsonb,90,true),
('omega','OMEGA',10,0,true,false,'{"type": "achievement_combo", "ids": ["first_signal", "sessions_5", "sessions_20", "sessions_50", "sessions_100", "perfect_5", "perfect_10", "perfect_20", "combo_5", "combo_10", "combo_20", "combo_30", "text_10", "keys_10", "hyper_first", "ear_first", "all_modes", "interval_all_seen", "interval_80", "interval_90", "streak_3", "streak_7", "streak_14", "public_record", "rank_top10", "rank_podium", "rank_first", "hidden_ear_perfect", "hidden_all_mode_perfect", "hidden_combo_50", "hidden_singularity", "sessions_250", "sessions_1000", "perfect_40", "combo_100", "streak_30", "streak_60", "all_modes_perfect_30", "ear_perfect_40"]}'::jsonb,100,true)
on conflict (id) do nothing;

commit;
