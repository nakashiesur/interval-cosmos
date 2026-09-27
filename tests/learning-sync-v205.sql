-- Dedicated QA database only; every write is rolled back.
-- Before this script, set app.qa_player_id to an existing synthetic player's UUID.
begin;
select set_config('request.jwt.claim.sub', (select auth_user_id::text from public.player_devices
  where player_id=current_setting('app.qa_player_id')::uuid limit 1), true);
set local role authenticated;
do $$
declare p uuid:=public.current_player_id(); e uuid:=gen_random_uuid(); payload jsonb; n bigint;
begin
  if p is null then raise exception 'Synthetic linked account required'; end if;
  payload:=jsonb_build_array(jsonb_build_object('event_id',e,'interval_key','M3','chosen_key','m3','response_ms',1200,'answered_at',now()));
  perform public.submit_learning_answers(p,payload);
  perform public.submit_learning_answers(p,payload);
  select count(*) into n from public.learning_answers where event_id=e;
  if n<>1 then raise exception 'Duplicate event was counted'; end if;
  if not exists(select 1 from public.get_my_learning_analysis() where interval_key='M3' and chosen_key='m3' and answers>=1) then raise exception 'Missing aggregate'; end if;
  begin
    perform public.submit_learning_answers(gen_random_uuid(),payload);
    raise exception 'Wrong owner accepted';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.learning_answers(player_id,event_id,interval_key,chosen_key,response_ms,answered_at)
    values(gen_random_uuid(),gen_random_uuid(),'P1','P1',80,now());
    raise exception 'Direct cross-account insert accepted';
  exception when insufficient_privilege then null; end;
  begin
    perform public.submit_learning_answers(p,jsonb_build_array(jsonb_build_object('event_id',gen_random_uuid(),'interval_key','invalid','chosen_key','P1','response_ms',80,'answered_at',now())));
    raise exception 'Invalid interval accepted';
  exception when check_violation then null; end;
end $$;
reset role;
update public.players set is_suspended=true where id=current_setting('app.qa_player_id')::uuid;
set local role authenticated;
do $$ begin
  begin perform public.submit_learning_answers(public.current_player_id(),'[]'::jsonb);
    raise exception 'Suspended player accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
set local role authenticated;
do $$ begin
  if exists(select 1 from public.learning_answers) then raise exception 'Unlinked session can read answers'; end if;
  begin perform public.submit_learning_answers(current_setting('app.qa_player_id')::uuid,'[]'::jsonb);
    raise exception 'Unlinked session can submit';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
  begin perform public.get_my_learning_analysis(); raise exception 'Anon RPC access';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
select 'PASS: deduplication, aggregation, validation, owner isolation, suspension, and anon denial' as learning_sync_security;
