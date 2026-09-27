-- INTERVAL COSMOS v2.0.5
-- Admin-only learning dashboard RPCs
-- Run after the Phase 1 schema and Phase 6 assignment patches.

begin;

create or replace function public.get_admin_dashboard_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not public.is_current_admin() then
    raise exception 'Admin account required';
  end if;

  with active_assignment_count as (
    select count(*)::integer as total
    from public.assignments a
    where a.is_published
      and now() between a.start_at and a.deadline_at
  ),
  student_base as (
    select
      p.id,
      p.student_number,
      p.player_name,
      p.course_code,
      c.display_name as course_name,
      p.avatar_id,
      p.created_at
    from public.players p
    left join public.courses c on c.code = p.course_code
    where p.account_type = 'student'
      and not p.is_suspended
  ),
  session_rollup as (
    select
      ps.player_id,
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
    group by ps.player_id
  ),
  assignment_rollup as (
    select
      ab.player_id,
      count(distinct ab.assignment_id)::integer as assignments_attempted,
      count(distinct ab.assignment_id) filter (where ab.achieved)::integer as assignments_achieved,
      count(distinct ab.assignment_id) filter (
        where ab.achieved
          and a.is_published
          and now() between a.start_at and a.deadline_at
      )::integer as active_assignments_achieved
    from public.assignment_bests ab
    join public.assignments a on a.id = ab.assignment_id
    group by ab.player_id
  ),
  rows as (
    select
      sb.*,
      coalesce(sr.sessions_all,0) as sessions_all,
      coalesce(sr.sessions_30d,0) as sessions_30d,
      coalesce(sr.answers_all,0) as answers_all,
      coalesce(sr.correct_all,0) as correct_all,
      coalesce(sr.answers_30d,0) as answers_30d,
      coalesce(sr.correct_30d,0) as correct_30d,
      coalesce(sr.best_score,0) as best_score,
      coalesce(sr.max_combo,0) as max_combo,
      sr.last_play_at,
      coalesce(ar.assignments_attempted,0) as assignments_attempted,
      coalesce(ar.assignments_achieved,0) as assignments_achieved,
      coalesce(ar.active_assignments_achieved,0) as active_assignments_achieved,
      (select total from active_assignment_count) as active_assignments
    from student_base sb
    left join session_rollup sr on sr.player_id = sb.id
    left join assignment_rollup ar on ar.player_id = sb.id
  )
  select jsonb_build_object(
    'generated_at', now(),
    'summary', jsonb_build_object(
      'students', (select count(*) from rows),
      'active_30d', (select count(*) from rows where sessions_30d > 0),
      'sessions_all', (select coalesce(sum(sessions_all),0) from rows),
      'sessions_30d', (select coalesce(sum(sessions_30d),0) from rows),
      'answers_all', (select coalesce(sum(answers_all),0) from rows),
      'correct_all', (select coalesce(sum(correct_all),0) from rows),
      'answers_30d', (select coalesce(sum(answers_30d),0) from rows),
      'correct_30d', (select coalesce(sum(correct_30d),0) from rows),
      'active_assignments', (select total from active_assignment_count)
    ),
    'students', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'player_id', r.id,
          'student_number', r.student_number,
          'player_name', r.player_name,
          'course_code', r.course_code,
          'course_name', r.course_name,
          'avatar_id', r.avatar_id,
          'created_at', r.created_at,
          'sessions_all', r.sessions_all,
          'sessions_30d', r.sessions_30d,
          'answers_all', r.answers_all,
          'correct_all', r.correct_all,
          'answers_30d', r.answers_30d,
          'correct_30d', r.correct_30d,
          'best_score', r.best_score,
          'max_combo', r.max_combo,
          'last_play_at', r.last_play_at,
          'assignments_attempted', r.assignments_attempted,
          'assignments_achieved', r.assignments_achieved,
          'active_assignments_achieved', r.active_assignments_achieved,
          'active_assignments', r.active_assignments
        )
        order by r.student_number, r.player_name
      )
      from rows r
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

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
    and p.account_type = 'student';

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

revoke execute on function public.get_admin_dashboard_overview() from public, anon, authenticated;
revoke execute on function public.get_admin_student_dashboard(uuid) from public, anon, authenticated;
grant execute on function public.get_admin_dashboard_overview() to authenticated;
grant execute on function public.get_admin_student_dashboard(uuid) to authenticated;

commit;
