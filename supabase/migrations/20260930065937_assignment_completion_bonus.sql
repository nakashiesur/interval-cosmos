-- Prospective, once-per-assignment COSMOS PT; existing completions are excluded.
begin;
set local lock_timeout = '5s';
-- Serialize the transition with in-flight assignment submissions.
lock table public.players, public.assignments, public.play_sessions, public.assignment_bests, public.assignment_mode_bests in share row exclusive mode;
alter table public.assignments add column bonus_points integer not null default 100 check (bonus_points between 0 and 10000);
alter table public.assignments add column bonus_enabled_at timestamptz not null default now();
create table public.player_assignment_rewards (
 player_id uuid not null references public.players(id) on delete cascade,
 assignment_id uuid not null references public.assignments(id) on delete restrict,
 session_id uuid references public.play_sessions(id) on delete set null,
 reward_points integer not null check(reward_points between 0 and 10000),
 reason text not null check(reason in ('earned','completed_before_bonus')),
 awarded_at timestamptz not null default now(),
 primary key(player_id,assignment_id)
);
alter table public.player_assignment_rewards enable row level security;
revoke all on public.player_assignment_rewards from public,anon,authenticated;
-- Zero-value receipts preserve the explicit no-retroactive-award policy on retries.
insert into public.player_assignment_rewards(player_id,assignment_id,reward_points,reason)
select player_id,assignment_id,0,'completed_before_bonus' from public.assignment_bests where achieved;
create function public.create_assignment_v3(
 p_title text,p_description text,p_allowed_modes text[],p_interval_keys text[],p_start_at timestamptz,p_deadline_at timestamptz,
 p_target_score integer default null,p_target_accuracy numeric default null,p_publish boolean default false,p_bonus_points integer default 100
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if not public.is_current_admin() then raise exception 'Administrator account required';end if;
 if p_bonus_points is null or p_bonus_points<0 or p_bonus_points>10000 then raise exception 'Bonus must be an integer between 0 and 10000';end if;
 v_id:=public.create_assignment_v2(p_title,p_description,p_allowed_modes,p_interval_keys,p_start_at,p_deadline_at,p_target_score,p_target_accuracy,p_publish);
 update public.assignments set bonus_points=p_bonus_points where id=v_id;
 return v_id;
end; $$;
revoke all on function public.create_assignment_v3(text,text,text[],text[],timestamptz,timestamptz,integer,numeric,boolean,integer) from public,anon;
grant execute on function public.create_assignment_v3(text,text,text[],text[],timestamptz,timestamptz,integer,numeric,boolean,integer) to authenticated;

CREATE OR REPLACE FUNCTION public.get_my_assignment_status(p_assignment_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'assignment_id', a.id,
    'bonus_points', a.bonus_points,
    'bonus_awarded', (select reward_points from public.player_assignment_rewards where player_id=public.current_player_id() and assignment_id=a.id),
    'bonus_excluded', exists(select 1 from public.player_assignment_rewards where player_id=public.current_player_id() and assignment_id=a.id and reason='completed_before_bonus'),
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
$function$;

CREATE OR REPLACE FUNCTION public.get_my_assignments()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with me as (select public.current_player_id() as player_id)
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', a.id,
    'bonus_points', a.bonus_points,
    'bonus_awarded', (select reward_points from public.player_assignment_rewards where player_id=public.current_player_id() and assignment_id=a.id),
    'bonus_excluded', exists(select 1 from public.player_assignment_rewards where player_id=public.current_player_id() and assignment_id=a.id and reason='completed_before_bonus'),
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
$function$;

CREATE OR REPLACE FUNCTION public.get_teacher_assignments()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    'bonus_points', a.bonus_points,
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
$function$;

CREATE OR REPLACE FUNCTION public.submit_assignment_session_v2(p_client_event_id uuid, p_assignment_id uuid, p_mode text, p_score integer, p_total_answers integer, p_correct_answers integer, p_max_combo integer, p_avg_response double precision, p_interval_stats jsonb DEFAULT '{}'::jsonb, p_played_at timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_was_achieved boolean;
  v_bonus integer := 0;
begin
  if v_player_id is null then
    raise exception 'Player account required';
  end if;
  if exists (select 1 from public.players p where p.id=v_player_id and p.is_suspended) then
    raise exception 'Player account is suspended';
  end if;
  perform 1 from public.players where id=v_player_id and not is_suspended for update;
  if not found then raise exception 'Player account is suspended or missing';end if;
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
    if v_existing.source<>'assignment' or v_existing.assignment_id is distinct from p_assignment_id or v_existing.mode is distinct from p_mode then
      raise exception 'Submission identifier belongs to another play';
    end if;
    select reward_points into v_bonus from public.player_assignment_rewards where player_id=v_player_id and assignment_id=p_assignment_id and session_id=v_existing.id and reason='earned';
    v_accuracy := case when v_existing.total_answers=0 then 0
      else round((v_existing.correct_answers::numeric*100)/v_existing.total_answers,2) end;
    v_this_achieved := v_existing.total_answers > 0 and
      (v_assignment.target_score is null or v_existing.score >= v_assignment.target_score)
      and (v_assignment.target_accuracy is null or v_accuracy >= v_assignment.target_accuracy);
    v_status := public.get_my_assignment_status(p_assignment_id);
    return coalesce(v_status,'{}'::jsonb) || jsonb_build_object(
      'session_id',v_existing.id,'duplicate',true,'played_mode',v_existing.mode,
      'this_run_achieved',v_this_achieved,'bonus_earned',coalesce(v_bonus,0)
    );
  end if;

  v_accuracy := case when p_total_answers=0 then 0
    else round((p_correct_answers::numeric*100)/p_total_answers,2) end;
  v_this_achieved := p_total_answers > 0 and
    (v_assignment.target_score is null or p_score >= v_assignment.target_score)
    and (v_assignment.target_accuracy is null or v_accuracy >= v_assignment.target_accuracy);

  select coalesce(bool_or(achieved),false) into v_was_achieved from public.assignment_bests where player_id=v_player_id and assignment_id=p_assignment_id;

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
  if v_this_achieved and not v_was_achieved then
    insert into public.player_assignment_rewards(player_id,assignment_id,session_id,reward_points,reason)
    values(v_player_id,p_assignment_id,v_session_id,
      case when v_played_at>=v_assignment.bonus_enabled_at then v_assignment.bonus_points else 0 end,
      case when v_played_at>=v_assignment.bonus_enabled_at then 'earned' else 'completed_before_bonus' end)
    on conflict(player_id,assignment_id) do nothing returning reward_points into v_bonus;
    if coalesce(v_bonus,0)>0 then
      update public.players set achievement_points=achievement_points+v_bonus where id=v_player_id;
    end if;
  end if;

  v_status := public.get_my_assignment_status(p_assignment_id);

  return coalesce(v_status,'{}'::jsonb) || jsonb_build_object(
    'session_id',v_session_id,'duplicate',false,'played_mode',p_mode,
    'this_run_achieved',v_this_achieved,'bonus_earned',coalesce(v_bonus,0)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.submit_saved_play(p_player_id uuid, p_visibility text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_player public.players%rowtype;
  v_existing public.play_sessions%rowtype;
  v_result jsonb;
  v_event uuid := (p_payload->>'clientEventId')::uuid;
begin
  -- Lock the device binding and player until the entire submission commits.
  perform 1 from public.player_devices where auth_user_id = auth.uid() and player_id = p_player_id for share;
  if not found or p_player_id is distinct from public.current_player_id() then
    raise exception 'Saved play belongs to another account' using errcode = '42501';
  end if;
  select * into strict v_player from public.players where id = p_player_id for update;
  if v_player.is_suspended then raise exception 'Account suspended' using errcode = '42501'; end if;
  select * into v_existing from public.play_sessions where player_id = p_player_id and client_event_id = v_event;
  if found then
    if v_existing.source='assignment' then
      return coalesce(public.get_my_assignment_status(v_existing.assignment_id),'{}'::jsonb)||jsonb_build_object(
        'session_id',v_existing.id,'duplicate',true,'played_mode',v_existing.mode,'publication_required',false,
        'this_run_achieved',v_existing.total_answers>0 and exists(select 1 from public.assignments a where a.id=v_existing.assignment_id and (a.target_score is null or v_existing.score>=a.target_score) and (a.target_accuracy is null or round(v_existing.correct_answers::numeric*100/greatest(v_existing.total_answers,1),2)>=a.target_accuracy)),
        'bonus_earned',coalesce((select reward_points from public.player_assignment_rewards where player_id=p_player_id and session_id=v_existing.id and reason='earned'),0));
    end if;
    return jsonb_build_object('session_id',v_existing.id,'duplicate',true,
      'publication_required',v_existing.source = 'ranked' and not v_existing.is_public and v_player.ranking_visibility = 'ask');
  end if;
  if coalesce(p_payload->>'source','ranked') = 'ranked' and p_visibility is distinct from v_player.ranking_visibility then
    raise exception 'Publication setting changed' using errcode = 'IC001';
  end if;
  if p_payload->>'source' = 'assignment' then
    v_result := public.submit_assignment_session_v2(v_event,(p_payload->>'assignmentId')::uuid,
      p_payload->>'mode',(p_payload->>'score')::integer,(p_payload->>'totalAnswers')::integer,
      (p_payload->>'correctAnswers')::integer,(p_payload->>'maxCombo')::integer,
      (p_payload->>'avgResponse')::double precision,coalesce(p_payload->'intervalStats','{}'::jsonb),
      (p_payload->>'playedAt')::timestamptz);
  else
    select to_jsonb(r) into v_result from public.submit_play_session(v_event,
      coalesce(p_payload->>'source','ranked'),p_payload->>'mode',(p_payload->>'score')::integer,
      (p_payload->>'totalAnswers')::integer,(p_payload->>'correctAnswers')::integer,
      (p_payload->>'maxCombo')::integer,(p_payload->>'avgResponse')::double precision,
      coalesce(p_payload->'intervalStats','{}'::jsonb),(p_payload->>'playedAt')::timestamptz,null) r;
  end if;
  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.evaluate_my_progress()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_frame record; v_player_id uuid:=public.current_player_id(); v_before_ach text[]; v_before_titles text[]; v_before_frames text[]; v_before_completed text[]; v_points integer; v_best_point_frame text; v_current_frame text; v_current_tier integer; v_best_tier integer; v_new_ach jsonb; v_new_titles jsonb; v_new_frames jsonb; v_new_missions jsonb;
begin
 if v_player_id is null then raise exception 'Player account required'; end if;
 perform 1 from public.players where id=v_player_id for update;
 select coalesce(array_agg(achievement_id),'{}') into v_before_ach from public.player_achievements where player_id=v_player_id;
 select coalesce(array_agg(title_id),'{}') into v_before_titles from public.player_titles where player_id=v_player_id;
 select coalesce(array_agg(frame_id),'{}') into v_before_frames from public.player_frames where player_id=v_player_id;
 perform public.ensure_my_daily_missions();
 select coalesce(array_agg(mission_id),'{}') into v_before_completed from public.player_daily_mission_progress where player_id=v_player_id and mission_date=(now() at time zone 'Asia/Tokyo')::date and completed;
 perform public.refresh_my_daily_missions();
 insert into public.player_achievements(player_id,achievement_id,points_awarded) select v_player_id,a.id,a.points from public.achievement_catalog a where a.is_active and a.requirement->>'type'<>'achievement_combo' and public.achievement_requirement_met(v_player_id,a.requirement) on conflict do nothing;
 insert into public.player_achievements(player_id,achievement_id,points_awarded) select v_player_id,a.id,a.points from public.achievement_catalog a where a.is_active and a.requirement->>'type'='achievement_combo' and public.achievement_requirement_met(v_player_id,a.requirement) on conflict do nothing;
 insert into public.player_titles(player_id,title_id) select distinct v_player_id,a.reward_title_id from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id and a.reward_title_id is not null on conflict do nothing;
 select coalesce(sum(coalesce(pa.points_awarded,a.points)),0) into v_points from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id;
 v_points:=v_points+coalesce((select sum(coalesce(p.reward_points_awarded,d.reward_points)) from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.completed),0);
 -- Slot uniqueness and the player-row lock make retries and concurrent devices idempotent.
 insert into public.player_mode_clear_rewards(player_id,reward_date,mode,reward_slot,reward_points,session_id)
 select v_player_id,q.reward_date,q.mode,q.slot::smallint,q.reward_points,q.session_id from (
 select (s.played_at at time zone 'Asia/Tokyo')::date reward_date,s.mode,c.reward_points,s.id as session_id,
 row_number() over(partition by (s.played_at at time zone 'Asia/Tokyo')::date,s.mode order by s.played_at,s.id) slot
 from public.play_sessions s join public.mode_clear_reward_catalog c on c.mode=s.mode
 where s.player_id=v_player_id and s.source='ranked' and s.played_at>=c.enabled_from and s.played_at<=now()
 and s.total_answers>=c.min_answers and s.correct_answers::numeric*100/greatest(s.total_answers,1)>=c.min_accuracy
 ) q where q.slot<=5 on conflict do nothing;
 v_points:=v_points+coalesce((select sum(reward_points) from public.player_mode_clear_rewards where player_id=v_player_id),0);
 v_points:=v_points+coalesce((select sum(reward_points) from public.player_assignment_rewards where player_id=v_player_id),0);
 update public.players set achievement_points=v_points where id=v_player_id;
 -- Tier order is deterministic: each new frame requires ownership of its predecessor.
 for v_frame in select * from public.frame_catalog where is_active order by tier,sort_order,id loop
  if (nullif(v_frame.unlock_rule->>'requires_frame','') is null or exists(
      select 1 from public.player_frames where player_id=v_player_id and frame_id=v_frame.unlock_rule->>'requires_frame'))
    and v_points>=v_frame.points_required
    and ((v_frame.unlock_rule->>'type'='points' and v_points>=v_frame.points_required)
      or (v_frame.unlock_rule->>'type'='achievement_combo' and public.achievement_requirement_met(v_player_id,v_frame.unlock_rule))
      or exists(select 1 from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id and a.reward_frame_id=v_frame.id)) then
   insert into public.player_frames(player_id,frame_id) values(v_player_id,v_frame.id) on conflict do nothing;
  end if;
 end loop;
 select p.equipped_frame_id,coalesce(f.tier,0) into v_current_frame,v_current_tier from public.players p left join public.frame_catalog f on f.id=p.equipped_frame_id where p.id=v_player_id;
 select f.id,f.tier into v_best_point_frame,v_best_tier from public.player_frames pf join public.frame_catalog f on f.id=pf.frame_id where pf.player_id=v_player_id and (f.id='normal' or f.unlock_rule->>'type'='points') order by f.tier desc limit 1;
 if v_best_point_frame is not null and not(v_best_point_frame=any(v_before_frames)) and coalesce((select unlock_rule->>'type' from public.frame_catalog where id=v_current_frame),'points') in('points','') and coalesce(v_best_tier,0)>coalesce(v_current_tier,0) then update public.players set equipped_frame_id=v_best_point_frame where id=v_player_id; end if;
 update public.players p set main_title_id=(select pt.title_id from public.player_titles pt join public.title_catalog t on t.id=pt.title_id where pt.player_id=v_player_id order by t.sort_order,pt.unlocked_at limit 1) where p.id=v_player_id and p.main_title_id is null and exists(select 1 from public.player_titles where player_id=v_player_id);
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.display_name,'description',a.description,'points',coalesce(pa.points_awarded,a.points),'hidden',a.hidden) order by a.sort_order),'[]'::jsonb) into v_new_ach from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id and not(pa.achievement_id=any(v_before_ach));
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.display_name) order by t.sort_order),'[]'::jsonb) into v_new_titles from public.player_titles pt join public.title_catalog t on t.id=pt.title_id where pt.player_id=v_player_id and not(pt.title_id=any(v_before_titles));
 select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'name',f.display_name,'tier',f.tier,'animated',f.animated,'hidden',f.hidden) order by f.tier),'[]'::jsonb) into v_new_frames from public.player_frames pf join public.frame_catalog f on f.id=pf.frame_id where pf.player_id=v_player_id and not(pf.frame_id=any(v_before_frames));
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.display_name,'reward_points',coalesce(p.reward_points_awarded,d.reward_points)) order by p.slot),'[]'::jsonb) into v_new_missions from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=(now() at time zone 'Asia/Tokyo')::date and p.completed and not(p.mission_id=any(v_before_completed));
 return jsonb_build_object('achievement_points',v_points,'new_achievements',v_new_ach,'new_titles',v_new_titles,'new_frames',v_new_frames,'new_daily_completions',v_new_missions,'player',(select to_jsonb(x) from public.get_my_player() x));
end; $function$;

CREATE OR REPLACE FUNCTION public.get_my_cosmos_progress()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_player_id uuid:=public.current_player_id(); v_date date:=(now() at time zone 'Asia/Tokyo')::date; v_player jsonb; v_achievements jsonb; v_titles jsonb; v_frames jsonb; v_daily jsonb;
begin
 if v_player_id is null then raise exception 'Player account required'; end if; perform public.evaluate_my_progress(); select to_jsonb(x) into v_player from public.get_my_player() x;
 select coalesce(jsonb_agg(item order by sort_order),'[]'::jsonb) into v_achievements from (select a.sort_order,case when a.hidden and pa.achievement_id is null then jsonb_build_object('id',null,'name','???','description','???','category','hidden','points',null,'hidden',true,'unlocked',false,'featured_order',null) else jsonb_build_object('id',a.id,'name',a.display_name,'description',a.description,'category',a.category,'points',coalesce(pa.points_awarded,a.points),'hidden',a.hidden,'unlocked',(pa.achievement_id is not null),'unlocked_at',pa.unlocked_at,'featured_order',pa.featured_order,'requirement',case when a.hidden and pa.achievement_id is null then null else a.requirement end) end item from public.achievement_catalog a left join public.player_achievements pa on pa.player_id=v_player_id and pa.achievement_id=a.id where a.is_active) q;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.display_name,'description',t.description,'hidden',t.hidden,'unlocked',(pt.title_id is not null),'unlocked_at',pt.unlocked_at,'equipped',(t.id=(select main_title_id from public.players where id=v_player_id))) order by t.sort_order),'[]'::jsonb) into v_titles from public.title_catalog t left join public.player_titles pt on pt.player_id=v_player_id and pt.title_id=t.id where t.is_active and (not t.hidden or pt.title_id is not null);
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',f.id,'name',case when f.secret and not f.owned then '???' else f.display_name end,
 'tier',f.tier,'points_required',case when f.revealed then f.points_required else null end,
 'animated',f.animated,'hidden',f.secret,'appearance_hidden',f.secret and not f.owned,
 'conditions_revealed',f.revealed,'unlock_rule',case when f.revealed then f.unlock_rule else null end,
 'requirement_descriptions',case when f.revealed then (select jsonb_agg(a.description order by a.sort_order) from public.achievement_catalog a where f.unlock_rule->'ids' ? a.id) else null end,
 'unlocked',f.owned,'unlocked_at',f.unlocked_at,'equipped',f.id=(select equipped_frame_id from public.players where id=v_player_id)
 ) order by f.tier),'[]'::jsonb) into v_frames from (
 select f.*,pf.frame_id is not null as owned,pf.unlocked_at,
 f.id in ('supernova','event_horizon','pulsar','omega') as secret,
 (f.id not in ('supernova','event_horizon','pulsar','omega') or pf.frame_id is not null or exists(
 select 1 from public.player_frames previous where previous.player_id=v_player_id and previous.frame_id=f.unlock_rule->>'requires_frame')) as revealed
 from public.frame_catalog f left join public.player_frames pf on pf.player_id=v_player_id and pf.frame_id=f.id where f.is_active
 ) f;
 select coalesce(jsonb_agg(jsonb_build_object('slot',p.slot,'date',p.mission_date,'id',d.id,'name',d.display_name,'description',d.description,'progress',p.progress,'target',d.target_value,'completed',p.completed,'completed_at',p.completed_at,'reward_points',coalesce(p.reward_points_awarded,d.reward_points)) order by p.slot),'[]'::jsonb) into v_daily from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=v_date;
 return jsonb_build_object('player',v_player,'achievements',v_achievements,'titles',v_titles,'frames',v_frames,'daily_missions',v_daily,'mission_date',v_date,
 'mode_clear_rewards',(select jsonb_agg(jsonb_build_object('mode',c.mode,'reward_points',c.reward_points,'min_answers',c.min_answers,'min_accuracy',c.min_accuracy,'earned_count',coalesce(r.n,0),'daily_limit',5,'completed',coalesce(r.n,0)>=5) order by c.reward_points,c.mode) from public.mode_clear_reward_catalog c left join (select mode,count(*) n from public.player_mode_clear_rewards where player_id=v_player_id and reward_date=v_date group by mode) r on r.mode=c.mode),
 'point_breakdown',jsonb_build_object('assignments',(select coalesce(sum(reward_points),0) from public.player_assignment_rewards where player_id=v_player_id),'achievements',(select coalesce(sum(coalesce(p.points_awarded,a.points)),0) from public.player_achievements p join public.achievement_catalog a on a.id=p.achievement_id where p.player_id=v_player_id),'daily',(select coalesce(sum(coalesce(p.reward_points_awarded,d.reward_points)),0) from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.completed),'mode_clear',(select coalesce(sum(reward_points),0) from public.player_mode_clear_rewards where player_id=v_player_id)));
end; $function$;

commit;
