-- INTERVAL COSMOS v2.0.5
-- Phase 6: assignments / teacher assignment management
-- Run after the Phase 1 schema, device-link, recovery, and progression patches.

begin;

create or replace function public.is_current_teacher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select (p.account_type = 'staff' or p.is_admin) and not p.is_suspended
    from public.players p
    where p.id = public.current_player_id()
    limit 1
  ), false);
$$;

create or replace function public.normalize_assignment_intervals(p_keys text[])
returns text[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_allowed constant text[] := array['P1','m2','M2','m3','M3','P4','TT','P5','m6','M6','m7','M7','P8'];
  v_keys text[];
begin
  if p_keys is null or cardinality(p_keys) = 0 then
    return v_allowed;
  end if;

  select array_agg(k order by first_pos)
  into v_keys
  from (
    select k, min(ord)::integer as first_pos
    from unnest(p_keys) with ordinality as u(k, ord)
    group by k
  ) s;

  if v_keys is null or cardinality(v_keys) = 0 or cardinality(v_keys) > 13 then
    raise exception 'Assignment must contain 1-13 intervals';
  end if;

  if exists (
    select 1 from unnest(v_keys) k
    where not (k = any(v_allowed))
  ) then
    raise exception 'Invalid assignment interval';
  end if;

  return v_keys;
end;
$$;

create or replace function public.create_assignment(
  p_title text,
  p_description text,
  p_mode text,
  p_interval_keys text[],
  p_start_at timestamptz,
  p_deadline_at timestamptz,
  p_target_score integer default null,
  p_target_accuracy numeric default null,
  p_publish boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_teacher_id uuid := public.current_player_id();
  v_id uuid;
  v_keys text[];
begin
  if not public.is_current_teacher() then
    raise exception 'Teacher account required';
  end if;

  if char_length(btrim(coalesce(p_title,''))) not between 1 and 80 then
    raise exception 'Assignment title must be 1-80 characters';
  end if;
  if p_mode not in ('TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK') then
    raise exception 'Invalid assignment mode';
  end if;
  if p_start_at is null or p_deadline_at is null or p_deadline_at <= p_start_at then
    raise exception 'Invalid assignment period';
  end if;
  if p_target_score is not null and p_target_score < 0 then
    raise exception 'Invalid target score';
  end if;
  if p_target_accuracy is not null and (p_target_accuracy < 0 or p_target_accuracy > 100) then
    raise exception 'Invalid target accuracy';
  end if;

  v_keys := public.normalize_assignment_intervals(p_interval_keys);

  insert into public.assignments(
    title, description, mode, interval_keys, rule_config,
    start_at, deadline_at, target_score, target_accuracy,
    is_published, created_by
  )
  values(
    btrim(p_title), coalesce(p_description,''), p_mode, v_keys,
    jsonb_build_object('version',1,'retry','unlimited','best_policy','highest_score'),
    p_start_at, p_deadline_at, p_target_score, p_target_accuracy,
    coalesce(p_publish,false), v_teacher_id
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.update_assignment(
  p_assignment_id uuid,
  p_title text,
  p_description text,
  p_mode text,
  p_interval_keys text[],
  p_start_at timestamptz,
  p_deadline_at timestamptz,
  p_target_score integer default null,
  p_target_accuracy numeric default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_teacher_id uuid := public.current_player_id();
  v_assignment public.assignments%rowtype;
  v_attempts integer;
  v_keys text[];
begin
  if not public.is_current_teacher() then
    raise exception 'Teacher account required';
  end if;

  select * into v_assignment
  from public.assignments
  where id = p_assignment_id
    and (created_by = v_teacher_id or public.is_current_admin());

  if not found then
    raise exception 'Assignment not found';
  end if;

  select count(*) into v_attempts
  from public.play_sessions
  where assignment_id = p_assignment_id;

  if char_length(btrim(coalesce(p_title,''))) not between 1 and 80 then
    raise exception 'Assignment title must be 1-80 characters';
  end if;
  if p_deadline_at is null or p_deadline_at <= coalesce(p_start_at, v_assignment.start_at) then
    raise exception 'Invalid assignment period';
  end if;

  if v_attempts > 0 then
    if p_mode is distinct from v_assignment.mode
       or p_start_at is distinct from v_assignment.start_at
       or p_target_score is distinct from v_assignment.target_score
       or p_target_accuracy is distinct from v_assignment.target_accuracy
       or public.normalize_assignment_intervals(p_interval_keys) is distinct from v_assignment.interval_keys then
      raise exception 'Rules cannot be changed after students have attempted the assignment';
    end if;
    if p_deadline_at < v_assignment.deadline_at then
      raise exception 'Deadline cannot be shortened after attempts exist';
    end if;
  else
    if p_mode not in ('TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK') then
      raise exception 'Invalid assignment mode';
    end if;
    if p_target_score is not null and p_target_score < 0 then
      raise exception 'Invalid target score';
    end if;
    if p_target_accuracy is not null and (p_target_accuracy < 0 or p_target_accuracy > 100) then
      raise exception 'Invalid target accuracy';
    end if;
  end if;

  v_keys := public.normalize_assignment_intervals(p_interval_keys);

  update public.assignments
  set title = btrim(p_title),
      description = coalesce(p_description,''),
      mode = p_mode,
      interval_keys = v_keys,
      start_at = p_start_at,
      deadline_at = p_deadline_at,
      target_score = p_target_score,
      target_accuracy = p_target_accuracy,
      updated_at = now()
  where id = p_assignment_id;
end;
$$;

create or replace function public.set_assignment_published(
  p_assignment_id uuid,
  p_published boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_teacher_id uuid := public.current_player_id();
  v_assignment public.assignments%rowtype;
begin
  if not public.is_current_teacher() then
    raise exception 'Teacher account required';
  end if;

  select * into v_assignment
  from public.assignments
  where id = p_assignment_id
    and (created_by = v_teacher_id or public.is_current_admin());

  if not found then
    raise exception 'Assignment not found';
  end if;

  if coalesce(p_published,false) and v_assignment.deadline_at <= now() then
    raise exception 'Expired assignment cannot be published';
  end if;

  update public.assignments
  set is_published = coalesce(p_published,false),
      updated_at = now()
  where id = p_assignment_id;
end;
$$;

create or replace function public.get_my_assignments()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select public.current_player_id() as player_id
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', a.id,
        'title', a.title,
        'description', a.description,
        'mode', a.mode,
        'interval_keys', a.interval_keys,
        'rule_config', a.rule_config,
        'start_at', a.start_at,
        'deadline_at', a.deadline_at,
        'target_score', a.target_score,
        'target_accuracy', a.target_accuracy,
        'best_score', ab.best_score,
        'best_accuracy', ab.best_accuracy,
        'attempts', coalesce(ab.attempts,0),
        'achieved', coalesce(ab.achieved,false),
        'best_session_id', ab.best_session_id,
        'first_attempt_at', ab.first_attempt_at,
        'last_attempt_at', ab.last_attempt_at
      )
      order by
        case when a.deadline_at >= now() then 0 else 1 end,
        a.deadline_at asc
    ),
    '[]'::jsonb
  )
  from public.assignments a
  cross join me
  left join public.assignment_bests ab
    on ab.assignment_id = a.id
   and ab.player_id = me.player_id
  where a.is_published;
$$;

create or replace function public.get_my_assignment_status(p_assignment_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'assignment_id', a.id,
    'best_score', ab.best_score,
    'best_accuracy', ab.best_accuracy,
    'attempts', coalesce(ab.attempts,0),
    'achieved', coalesce(ab.achieved,false),
    'first_attempt_at', ab.first_attempt_at,
    'last_attempt_at', ab.last_attempt_at
  )
  from public.assignments a
  left join public.assignment_bests ab
    on ab.assignment_id = a.id
   and ab.player_id = public.current_player_id()
  where a.id = p_assignment_id
    and a.is_published;
$$;

create or replace function public.get_teacher_assignments()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_teacher_id uuid := public.current_player_id();
  v_result jsonb;
begin
  if not public.is_current_teacher() then
    raise exception 'Teacher account required';
  end if;

  select coalesce(
    jsonb_agg(row_data order by (row_data->>'deadline_at')::timestamptz desc),
    '[]'::jsonb
  )
  into v_result
  from (
    select jsonb_build_object(
      'id', a.id,
      'title', a.title,
      'description', a.description,
      'mode', a.mode,
      'interval_keys', a.interval_keys,
      'rule_config', a.rule_config,
      'start_at', a.start_at,
      'deadline_at', a.deadline_at,
      'target_score', a.target_score,
      'target_accuracy', a.target_accuracy,
      'is_published', a.is_published,
      'created_at', a.created_at,
      'updated_at', a.updated_at,
      'attempted_students', count(ab.player_id),
      'achieved_students', count(ab.player_id) filter (where ab.achieved),
      'total_attempts', coalesce(sum(ab.attempts),0),
      'total_students', (
        select count(*) from public.players p
        where p.account_type='student' and not p.is_suspended
      )
    ) as row_data
    from public.assignments a
    left join public.assignment_bests ab on ab.assignment_id = a.id
    where a.created_by = v_teacher_id or public.is_current_admin()
    group by a.id
  ) q;

  return v_result;
end;
$$;

create or replace function public.get_assignment_results(p_assignment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_teacher_id uuid := public.current_player_id();
  v_result jsonb;
begin
  if not public.is_current_teacher() then
    raise exception 'Teacher account required';
  end if;

  if not exists (
    select 1 from public.assignments a
    where a.id = p_assignment_id
      and (a.created_by = v_teacher_id or public.is_current_admin())
  ) then
    raise exception 'Assignment not found';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'player_id', p.id,
        'student_number', p.student_number,
        'player_name', p.player_name,
        'course_code', p.course_code,
        'avatar_id', p.avatar_id,
        'attempts', coalesce(ab.attempts,0),
        'best_score', ab.best_score,
        'best_accuracy', ab.best_accuracy,
        'achieved', coalesce(ab.achieved,false),
        'first_attempt_at', ab.first_attempt_at,
        'last_attempt_at', ab.last_attempt_at
      )
      order by p.student_number
    ),
    '[]'::jsonb
  )
  into v_result
  from public.players p
  left join public.assignment_bests ab
    on ab.player_id = p.id
   and ab.assignment_id = p_assignment_id
  where p.account_type='student'
    and not p.is_suspended;

  return v_result;
end;
$$;

revoke execute on function public.is_current_teacher() from public, anon;
revoke execute on function public.normalize_assignment_intervals(text[]) from public, anon, authenticated;
revoke execute on function public.create_assignment(text,text,text,text[],timestamptz,timestamptz,integer,numeric,boolean) from public, anon;
revoke execute on function public.update_assignment(uuid,text,text,text,text[],timestamptz,timestamptz,integer,numeric) from public, anon;
revoke execute on function public.set_assignment_published(uuid,boolean) from public, anon;
revoke execute on function public.get_my_assignments() from public, anon;
revoke execute on function public.get_my_assignment_status(uuid) from public, anon;
revoke execute on function public.get_teacher_assignments() from public, anon;
revoke execute on function public.get_assignment_results(uuid) from public, anon;

grant execute on function public.is_current_teacher() to authenticated;
grant execute on function public.create_assignment(text,text,text,text[],timestamptz,timestamptz,integer,numeric,boolean) to authenticated;
grant execute on function public.update_assignment(uuid,text,text,text,text[],timestamptz,timestamptz,integer,numeric) to authenticated;
grant execute on function public.set_assignment_published(uuid,boolean) to authenticated;
grant execute on function public.get_my_assignments() to authenticated;
grant execute on function public.get_my_assignment_status(uuid) to authenticated;
grant execute on function public.get_teacher_assignments() to authenticated;
grant execute on function public.get_assignment_results(uuid) to authenticated;

commit;
