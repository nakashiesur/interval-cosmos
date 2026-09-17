-- Test-only synthetic fixture QA0912. Every change rolls back.
begin;
select set_config('request.jwt.claim.sub',
  (select d.auth_user_id::text from public.player_devices d join public.players p on p.id=d.player_id
   where p.student_number='990912' limit 1),true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
do $$
declare
  player_id uuid := public.current_player_id();
  visibility text;
  event_id uuid := gen_random_uuid();
  payload jsonb;
  result jsonb;
  count_rows integer;
  task public.assignments%rowtype;
  before_attempts integer;
  after_attempts integer;
begin
  if player_id is null then raise exception 'Synthetic QA0912 fixture required'; end if;
  select ranking_visibility into visibility from public.players where id=player_id;
  payload := jsonb_build_object('clientEventId',event_id,'source','ranked','mode','TEXT','score',17,
    'totalAnswers',2,'correctAnswers',1,'maxCombo',1,'avgResponse',500,'playedAt',now());
  result := public.submit_saved_play(player_id,visibility,payload);
  if (result->>'duplicate')::boolean then raise exception 'First submission duplicated'; end if;
  result := public.submit_saved_play(player_id,visibility,payload);
  if not (result->>'duplicate')::boolean then raise exception 'Retry not recognized'; end if;
  select count(*) into count_rows from public.play_sessions where client_event_id=event_id;
  if count_rows <> 1 then raise exception 'Duplicate row created'; end if;
  begin
    perform public.submit_saved_play(gen_random_uuid(),visibility,payload);
    raise exception 'Wrong account accepted';
  exception when insufficient_privilege then null; end;
  begin
    perform public.submit_saved_play(player_id,case when visibility='ask' then 'always_public' else 'ask' end,
      payload || jsonb_build_object('clientEventId',gen_random_uuid()));
    raise exception 'Changed policy accepted';
  exception when sqlstate 'IC001' then null; end;
  if has_function_privilege('anon','public.submit_saved_play(uuid,text,jsonb)','execute') then
    raise exception 'Anonymous API access';
  end if;
  select * into strict task from public.assignments where id='086bd71c-9d18-497f-9e0b-ae76570853be';
  select coalesce((public.get_my_assignment_status(task.id)->>'attempts')::integer,0) into before_attempts;
  payload := payload || jsonb_build_object('clientEventId',gen_random_uuid(),'source','assignment',
    'assignmentId',task.id,'playedAt',task.start_at+(task.deadline_at-task.start_at)/2);
  perform public.submit_saved_play(player_id,visibility,payload);
  result := public.submit_saved_play(player_id,visibility,payload);
  if not (result->>'duplicate')::boolean then raise exception 'Assignment retry duplicated'; end if;
  select (public.get_my_assignment_status(task.id)->>'attempts')::integer into after_attempts;
  if after_attempts <> before_attempts+1 then raise exception 'Assignment attempt count duplicated'; end if;
  begin
    perform public.submit_saved_play(player_id,visibility,payload || jsonb_build_object('clientEventId',gen_random_uuid(),'playedAt',task.deadline_at+interval '1 second'));
    raise exception 'Late assignment accepted';
  exception when raise_exception then
    if sqlerrm not like '%outside the allowed time window%' then raise; end if;
  end;
end;
$$;
rollback;
