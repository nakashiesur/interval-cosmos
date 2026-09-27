-- Dedicated Final Fresh Build 0927 ONLY; requires synthetic student 99092701.
-- All mutations are rolled back. No persistent grants or scores are created.
-- Dedicated QA project only. Temporary role/profile changes all roll back.
begin;
select set_config('request.jwt.claim.sub',(select d.auth_user_id::text from public.player_devices d
  join public.players p on p.id=d.player_id where p.student_number='99092701' limit 1),true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
do $$
declare operation text; target uuid:=public.current_player_id();
begin
  if target is null then raise exception 'QA-FINAL-0927 fixture required'; end if;
  foreach operation in array array[
    format('select public.admin_get_player_management(%L)',target),
    format('select public.admin_update_player_profile(%L,%L,%L,%L)',target,'QA0912','piano','nova'),
    format('select public.admin_set_player_suspended(%L,true)',target),
    format('select public.admin_unpublish_player_rankings(%L)',target),
    format('select public.admin_delete_player_rankings(%L)',target),
    'select public.get_admin_dashboard_overview()'
  ] loop
    begin execute operation; raise exception 'Non-admin operation accepted';
    exception when raise_exception then
      if sqlerrm not ilike '%admin%required%' then raise; end if;
    end;
  end loop;
  if has_function_privilege('authenticated','public.admin_delete_player_application_row(uuid)','execute') then
    raise exception 'Client can execute complete deletion';
  end if;
end;
$$;

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
  if player_id is null then raise exception 'QA-FINAL-0927 fixture required'; end if;
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
end;
$$;
reset role;
rollback;
