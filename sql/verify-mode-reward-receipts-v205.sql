begin;
insert into auth.users(id,aud,role,is_anonymous) values(gen_random_uuid(),'authenticated','authenticated',true) returning set_config('ic.rank_auth',id::text,true);
insert into public.players(id,account_type,player_name,avatar_id,is_admin,ranking_visibility) values(gen_random_uuid(),'staff','QA-RANK-DELETE','teacher',true,'always_public') returning set_config('ic.rank_player',id::text,true);
insert into public.player_devices(auth_user_id,player_id) values(current_setting('ic.rank_auth')::uuid,current_setting('ic.rank_player')::uuid);
select set_config('request.jwt.claim.sub',current_setting('ic.rank_auth'),true);
do $$ declare event uuid; receipt jsonb; i integer; begin
 for i in 1..7 loop
  event:=gen_random_uuid();
  insert into public.play_sessions(player_id,client_event_id,source,mode,score,total_answers,correct_answers,max_combo,avg_response,played_at,is_public) values(current_setting('ic.rank_player')::uuid,event,'ranked','TEXT',100,30,case when i=1 then 1 else 30 end,1,2,clock_timestamp()-interval '1 second',false);
  perform public.evaluate_my_progress();
  receipt:=public.get_my_mode_reward_receipt(event);
  if i=1 and (receipt->>'status'<>'conditions_not_met' or (receipt->>'remaining')::int<>5 or (receipt->>'points')::int<>0) then raise exception 'Failed play consumed reward: %',receipt;end if;
  if i between 2 and 6 and ((receipt->>'points')::int<>20 or (receipt->>'remaining')::int<>6-i) then raise exception 'Earned receipt incorrect: %',receipt;end if;
  if i=7 and (receipt->>'status'<>'daily_limit' or (receipt->>'points')::int<>0) then raise exception 'Limit failed: %',receipt;end if;
  perform public.evaluate_my_progress();
  if receipt<>public.get_my_mode_reward_receipt(event) then raise exception 'Retry changed award';end if;
 end loop;
 begin perform public.get_my_mode_reward_receipt(gen_random_uuid());raise exception 'Unknown play exposed';exception when others then if sqlerrm<>'Play not found' then raise;end if;end;
end $$;
select 'PASS failed attempt, five awards, exhausted limit, retry idempotency, receipt ownership' result;
rollback;
