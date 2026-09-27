-- INTERVAL COSMOS v2.0.5
-- Phase 6 refinement: multi-mode assignments + per-mode bests
-- Run AFTER sql/assignments-v2.0.5.sql and sql/assignments-admin-only-v2.0.5.sql.
-- Existing single-mode assignments and their play_sessions are preserved and migrated.

begin;

alter table public.assignments
  add column if not exists allowed_modes text[];

update public.assignments
set allowed_modes = array[mode]
where allowed_modes is null or cardinality(allowed_modes) = 0;

create or replace function public.normalize_assignment_modes(p_modes text[])
returns text[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_allowed constant text[] := array['TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK'];
  v_modes text[];
begin
  if p_modes is null or cardinality(p_modes) = 0 then
    raise exception 'Assignment must allow at least one mode';
  end if;

  select array_agg(m order by first_pos)
  into v_modes
  from (
    select m, min(ord)::integer as first_pos
    from unnest(p_modes) with ordinality as u(m, ord)
    group by m
  ) s;

  if v_modes is null or cardinality(v_modes) < 1 or cardinality(v_modes) > 5 then
    raise exception 'Assignment must allow 1-5 modes';
  end if;

  if exists (
    select 1 from unnest(v_modes) m
    where not (m = any(v_allowed))
  ) then
    raise exception 'Invalid assignment mode';
  end if;

  return v_modes;
end;
$$;

create table if not exists public.assignment_mode_bests (
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  mode text not null check (mode in ('TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK')),
  best_session_id uuid not null references public.play_sessions(id) on delete cascade,
  best_score integer not null,
  best_accuracy numeric(5,2) not null,
  attempts integer not null default 1 check (attempts > 0),
  achieved boolean not null default false,
  first_attempt_at timestamptz not null,
  last_attempt_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (assignment_id, player_id, mode)
);

create index if not exists assignment_mode_bests_player_idx
  on public.assignment_mode_bests(player_id);
create index if not exists assignment_mode_bests_assignment_idx
  on public.assignment_mode_bests(assignment_id);

-- Reconstruct per-mode records from durable assignment play_sessions.
with session_rows as (
  select
    ps.id,
    ps.assignment_id,
    ps.player_id,
    ps.mode,
    ps.score,
    case when ps.total_answers = 0 then 0::numeric
         else round((ps.correct_answers::numeric * 100) / ps.total_answers, 2) end as accuracy,
    ps.played_at,
    a.target_score,
    a.target_accuracy,
    row_number() over (
      partition by ps.assignment_id, ps.player_id, ps.mode
      order by ps.score desc, ps.played_at asc, ps.id
    ) as best_rank,
    count(*) over (partition by ps.assignment_id, ps.player_id, ps.mode) as attempts,
    min(ps.played_at) over (partition by ps.assignment_id, ps.player_id, ps.mode) as first_attempt_at,
    max(ps.played_at) over (partition by ps.assignment_id, ps.player_id, ps.mode) as last_attempt_at
  from public.play_sessions ps
  join public.assignments a on a.id = ps.assignment_id
  where ps.source = 'assignment'
    and ps.assignment_id is not null
), achieved_groups as (
  select
    assignment_id,
    player_id,
    mode,
    bool_or(
      (target_score is null or score >= target_score)
      and (target_accuracy is null or accuracy >= target_accuracy)
    ) as achieved
  from session_rows
  group by assignment_id, player_id, mode
)
insert into public.assignment_mode_bests (
  assignment_id, player_id, mode, best_session_id, best_score, best_accuracy,
  attempts, achieved, first_attempt_at, last_attempt_at
)
select
  s.assignment_id, s.player_id, s.mode, s.id, s.score, s.accuracy,
  s.attempts::integer, g.achieved, s.first_attempt_at, s.last_attempt_at
from session_rows s
join achieved_groups g using (assignment_id, player_id, mode)
where s.best_rank = 1
on conflict (assignment_id, player_id, mode) do update
set best_session_id = excluded.best_session_id,
    best_score = excluded.best_score,
    best_accuracy = excluded.best_accuracy,
    attempts = excluded.attempts,
    achieved = excluded.achieved,
    first_attempt_at = excluded.first_attempt_at,
    last_attempt_at = excluded.last_attempt_at,
    updated_at = now();

create or replace function public.refresh_assignment_aggregate(
  p_assignment_id uuid,
  p_player_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempts integer;
  v_achieved boolean;
  v_first timestamptz;
  v_last timestamptz;
  v_best public.assignment_mode_bests%rowtype;
begin
  select
    coalesce(sum(m.attempts),0)::integer,
    coalesce(bool_or(m.achieved),false),
    min(m.first_attempt_at),
    max(m.last_attempt_at)
  into v_attempts, v_achieved, v_first, v_last
  from public.assignment_mode_bests m
  where m.assignment_id = p_assignment_id
    and m.player_id = p_player_id;

  if v_attempts = 0 then
    delete from public.assignment_bests
    where assignment_id = p_assignment_id and player_id = p_player_id;
    return;
  end if;

  select * into v_best
  from public.assignment_mode_bests m
  where m.assignment_id = p_assignment_id
    and m.player_id = p_player_id
  order by m.best_score desc, m.first_attempt_at asc, m.mode
  limit 1;

  insert into public.assignment_bests (
    assignment_id, player_id, best_session_id, best_score, best_accuracy,
    attempts, achieved, first_attempt_at, last_attempt_at
  ) values (
    p_assignment_id, p_player_id, v_best.best_session_id, v_best.best_score,
    v_best.best_accuracy, v_attempts, v_achieved, v_first, v_last
  )
  on conflict (assignment_id, player_id) do update
  set best_session_id = excluded.best_session_id,
      best_score = excluded.best_score,
      best_accuracy = excluded.best_accuracy,
      attempts = excluded.attempts,
      achieved = excluded.achieved,
      first_attempt_at = excluded.first_attempt_at,
      last_attempt_at = excluded.last_attempt_at,
      updated_at = now();
end;
$$;

-- Synchronize legacy aggregate rows after migration.
do $$
declare r record;
begin
  for r in
    select distinct assignment_id, player_id
    from public.assignment_mode_bests
  loop
    perform public.refresh_assignment_aggregate(r.assignment_id, r.player_id);
  end loop;
end
$$;

create or replace function public.create_assignment_v2(
  p_title text,
  p_description text,
  p_allowed_modes text[],
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
  v_admin_id uuid := public.current_player_id();
  v_id uuid;
  v_modes text[];
  v_keys text[];
  v_has_hyper boolean;
  v_has_standard boolean;
begin
  if not public.is_current_admin() then
    raise exception 'Administrator account required';
  end if;

  if char_length(btrim(coalesce(p_title,''))) not between 1 and 80 then
    raise exception 'Assignment title must be 1-80 characters';
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

  v_modes := public.normalize_assignment_modes(p_allowed_modes);
  v_keys := public.normalize_assignment_intervals(p_interval_keys);
  v_has_hyper := ('HD_TEXT' = any(v_modes) or 'HD_KEYS' = any(v_modes));
  v_has_standard := ('TEXT' = any(v_modes) or 'KEYS' = any(v_modes) or 'EAR_LINK' = any(v_modes));

  -- HYPER DRIVE has a different score scale. A single shared score target would be unfair.
  if p_target_score is not null and v_has_hyper and v_has_standard then
    raise exception 'Mixed STANDARD/HYPER assignments cannot use one shared score target. Use accuracy only or choose modes from one score family.';
  end if;

  insert into public.assignments (
    title, description, mode, allowed_modes, interval_keys, rule_config,
    start_at, deadline_at, target_score, target_accuracy,
    is_published, created_by
  ) values (
    btrim(p_title), coalesce(p_description,''), v_modes[1], v_modes, v_keys,
    jsonb_build_object(
      'version', 2,
      'retry', 'unlimited',
      'best_policy', 'per_mode_highest_score',
      'achievement_policy', 'any_allowed_mode'
    ),
    p_start_at, p_deadline_at, p_target_score, p_target_accuracy,
    coalesce(p_publish,false), v_admin_id
  )
  returning id into v_id;

  return v_id;
end;
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
    'allowed_modes', coalesce(a.allowed_modes, array[a.mode]),
    'best_score', ab.best_score,
    'best_accuracy', ab.best_accuracy,
    'attempts', coalesce(ab.attempts,0),
    'achieved', coalesce(ab.achieved,false),
    'first_attempt_at', ab.first_attempt_at,
    'last_attempt_at', ab.last_attempt_at,
    'mode_bests', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'mode', mb.mode,
          'best_score', mb.best_score,
          'best_accuracy', mb.best_accuracy,
          'attempts', mb.attempts,
          'achieved', mb.achieved,
          'best_session_id', mb.best_session_id,
          'first_attempt_at', mb.first_attempt_at,
          'last_attempt_at', mb.last_attempt_at
        ) order by array_position(coalesce(a.allowed_modes,array[a.mode]), mb.mode)
      )
      from public.assignment_mode_bests mb
      where mb.assignment_id = a.id
        and mb.player_id = public.current_player_id()
    ), '[]'::jsonb)
  )
  from public.assignments a
  left join public.assignment_bests ab
    on ab.assignment_id = a.id
   and ab.player_id = public.current_player_id()
  where a.id = p_assignment_id
    and a.is_published;
$$;

create or replace function public.get_my_assignments()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with me as (select public.current_player_id() as player_id)
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', a.id,
        'title', a.title,
        'description', a.description,
        'mode', a.mode,
        'allowed_modes', coalesce(a.allowed_modes,array[a.mode]),
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
        'last_attempt_at', ab.last_attempt_at,
        'mode_bests', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'mode', mb.mode,
              'best_score', mb.best_score,
              'best_accuracy', mb.best_accuracy,
              'attempts', mb.attempts,
              'achieved', mb.achieved
            ) order by array_position(coalesce(a.allowed_modes,array[a.mode]), mb.mode)
          )
          from public.assignment_mode_bests mb
          where mb.assignment_id = a.id and mb.player_id = me.player_id
        ), '[]'::jsonb)
      )
      order by case when a.deadline_at >= now() then 0 else 1 end, a.deadline_at asc
    ),
    '[]'::jsonb
  )
  from public.assignments a
  cross join me
  left join public.assignment_bests ab
    on ab.assignment_id = a.id and ab.player_id = me.player_id
  where a.is_published;
$$;

create or replace function public.get_teacher_assignments()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := public.current_player_id();
  v_result jsonb;
begin
  if not public.is_current_admin() then
    raise exception 'Administrator account required';
  end if;

  select coalesce(
    jsonb_agg(row_data order by (row_data->>'deadline_at')::timestamptz desc),
    '[]'::jsonb
  ) into v_result
  from (
    select jsonb_build_object(
      'id', a.id,
      'title', a.title,
      'description', a.description,
      'mode', a.mode,
      'allowed_modes', coalesce(a.allowed_modes,array[a.mode]),
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
    where a.created_by = v_admin_id or public.is_current_admin()
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
  v_result jsonb;
begin
  if not public.is_current_admin() then
    raise exception 'Administrator account required';
  end if;

  if not exists (select 1 from public.assignments a where a.id = p_assignment_id) then
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
        'last_attempt_at', ab.last_attempt_at,
        'mode_bests', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'mode', mb.mode,
              'best_score', mb.best_score,
              'best_accuracy', mb.best_accuracy,
              'attempts', mb.attempts,
              'achieved', mb.achieved
            ) order by array_position(coalesce(a.allowed_modes,array[a.mode]), mb.mode)
          )
          from public.assignment_mode_bests mb
          join public.assignments a on a.id = mb.assignment_id
          where mb.player_id = p.id and mb.assignment_id = p_assignment_id
        ), '[]'::jsonb)
      ) order by p.student_number
    ), '[]'::jsonb
  ) into v_result
  from public.players p
  left join public.assignment_bests ab
    on ab.player_id = p.id and ab.assignment_id = p_assignment_id
  where p.account_type='student' and not p.is_suspended;

  return v_result;
end;
$$;

create or replace function public.submit_assignment_session_v2(
  p_client_event_id uuid,
  p_assignment_id uuid,
  p_mode text,
  p_score integer,
  p_total_answers integer,
  p_correct_answers integer,
  p_max_combo integer,
  p_avg_response double precision,
  p_interval_stats jsonb default '{}'::jsonb,
  p_played_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player_id uuid := public.current_player_id();
  v_assignment public.assignments%rowtype;
  v_modes text[];
  v_session_id uuid;
  v_existing public.play_sessions%rowtype;
  v_played_at timestamptz := coalesce(p_played_at,now());
  v_accuracy numeric(5,2);
  v_this_achieved boolean;
  v_status jsonb;
begin
  if v_player_id is null then
    raise exception 'Player account required';
  end if;
  if exists (select 1 from public.players p where p.id=v_player_id and p.is_suspended) then
    raise exception 'Player account is suspended';
  end if;
  if p_client_event_id is null or p_assignment_id is null then
    raise exception 'Assignment submission identifiers are required';
  end if;
  if p_score < 0 or p_total_answers < 0 or p_correct_answers < 0 or p_correct_answers > p_total_answers then
    raise exception 'Invalid assignment performance values';
  end if;
  if p_max_combo < 0 or p_avg_response < 0 then
    raise exception 'Invalid assignment performance values';
  end if;

  select * into v_assignment
  from public.assignments a
  where a.id = p_assignment_id and a.is_published;
  if not found then
    raise exception 'Assignment not found';
  end if;

  v_modes := coalesce(v_assignment.allowed_modes,array[v_assignment.mode]);
  if not (p_mode = any(v_modes)) then
    raise exception 'This mode is not allowed for the assignment';
  end if;
  if v_played_at < v_assignment.start_at or v_played_at > v_assignment.deadline_at then
    raise exception 'Assignment is outside the allowed time window';
  end if;

  select * into v_existing
  from public.play_sessions ps
  where ps.player_id = v_player_id and ps.client_event_id = p_client_event_id
  limit 1;

  if found then
    v_accuracy := case when v_existing.total_answers=0 then 0
      else round((v_existing.correct_answers::numeric*100)/v_existing.total_answers,2) end;
    v_this_achieved :=
      (v_assignment.target_score is null or v_existing.score >= v_assignment.target_score)
      and (v_assignment.target_accuracy is null or v_accuracy >= v_assignment.target_accuracy);
    v_status := public.get_my_assignment_status(p_assignment_id);
    return coalesce(v_status,'{}'::jsonb) || jsonb_build_object(
      'session_id',v_existing.id,'duplicate',true,'played_mode',v_existing.mode,
      'this_run_achieved',v_this_achieved
    );
  end if;

  v_accuracy := case when p_total_answers=0 then 0
    else round((p_correct_answers::numeric*100)/p_total_answers,2) end;
  v_this_achieved :=
    (v_assignment.target_score is null or p_score >= v_assignment.target_score)
    and (v_assignment.target_accuracy is null or v_accuracy >= v_assignment.target_accuracy);

  insert into public.play_sessions (
    client_event_id, player_id, source, mode, score,
    total_answers, correct_answers, max_combo, avg_response,
    interval_stats, is_public, assignment_id, played_at
  ) values (
    p_client_event_id, v_player_id, 'assignment', p_mode, p_score,
    p_total_answers, p_correct_answers, p_max_combo, p_avg_response,
    coalesce(p_interval_stats,'{}'::jsonb), false, p_assignment_id, v_played_at
  ) returning id into v_session_id;

  insert into public.assignment_mode_bests (
    assignment_id, player_id, mode, best_session_id, best_score, best_accuracy,
    attempts, achieved, first_attempt_at, last_attempt_at
  ) values (
    p_assignment_id, v_player_id, p_mode, v_session_id, p_score, v_accuracy,
    1, v_this_achieved, v_played_at, v_played_at
  )
  on conflict (assignment_id, player_id, mode) do update
  set attempts = public.assignment_mode_bests.attempts + 1,
      last_attempt_at = greatest(public.assignment_mode_bests.last_attempt_at, excluded.last_attempt_at),
      best_session_id = case
        when excluded.best_score > public.assignment_mode_bests.best_score
        then excluded.best_session_id else public.assignment_mode_bests.best_session_id end,
      best_score = greatest(public.assignment_mode_bests.best_score, excluded.best_score),
      best_accuracy = case
        when excluded.best_score > public.assignment_mode_bests.best_score
        then excluded.best_accuracy else public.assignment_mode_bests.best_accuracy end,
      achieved = public.assignment_mode_bests.achieved or excluded.achieved,
      updated_at = now();

  perform public.refresh_assignment_aggregate(p_assignment_id,v_player_id);
  v_status := public.get_my_assignment_status(p_assignment_id);

  return coalesce(v_status,'{}'::jsonb) || jsonb_build_object(
    'session_id',v_session_id,'duplicate',false,'played_mode',p_mode,
    'this_run_achieved',v_this_achieved
  );
end;
$$;

alter table public.assignment_mode_bests enable row level security;
drop policy if exists "Players can read own assignment mode bests" on public.assignment_mode_bests;
create policy "Players can read own assignment mode bests"
  on public.assignment_mode_bests for select to authenticated
  using (player_id = public.current_player_id() or public.is_current_admin());

revoke all on public.assignment_mode_bests from anon, authenticated;
grant select on public.assignment_mode_bests to authenticated;

revoke execute on function public.normalize_assignment_modes(text[]) from public, anon, authenticated;
revoke execute on function public.refresh_assignment_aggregate(uuid,uuid) from public, anon, authenticated;
revoke execute on function public.create_assignment_v2(text,text,text[],text[],timestamptz,timestamptz,integer,numeric,boolean) from public, anon;
revoke execute on function public.submit_assignment_session_v2(uuid,uuid,text,integer,integer,integer,integer,double precision,jsonb,timestamptz) from public, anon;
revoke execute on function public.get_my_assignments() from public, anon;
revoke execute on function public.get_my_assignment_status(uuid) from public, anon;
revoke execute on function public.get_teacher_assignments() from public, anon;
revoke execute on function public.get_assignment_results(uuid) from public, anon;

grant execute on function public.create_assignment_v2(text,text,text[],text[],timestamptz,timestamptz,integer,numeric,boolean) to authenticated;
grant execute on function public.submit_assignment_session_v2(uuid,uuid,text,integer,integer,integer,integer,double precision,jsonb,timestamptz) to authenticated;
grant execute on function public.get_my_assignments() to authenticated;
grant execute on function public.get_my_assignment_status(uuid) to authenticated;
grant execute on function public.get_teacher_assignments() to authenticated;
grant execute on function public.get_assignment_results(uuid) to authenticated;

commit;
