-- Test fixtures only; all writes are rolled back.
begin;
insert into auth.users(id,aud,role,is_anonymous) values(gen_random_uuid(),'authenticated','authenticated',true) returning set_config('ic.qa_auth',id::text,true);
insert into public.players(id,account_type,player_name,avatar_id) values(gen_random_uuid(),'staff','QA-REWARDS','teacher') returning set_config('ic.qa_player',id::text,true);
insert into public.player_devices(auth_user_id,player_id) values(current_setting('ic.qa_auth')::uuid,current_setting('ic.qa_player')::uuid);
select set_config('request.jwt.claim.sub',current_setting('ic.qa_auth'),true);
update public.mode_clear_reward_catalog set enabled_from=now()-interval '2 days';
-- Same-day duplicate plays; EAR uses its lower answer threshold. Six attempts in each mode still earn only five awards, totaling 600 PT.
insert into public.play_sessions(client_event_id,player_id,mode,score,total_answers,correct_answers,played_at)
select gen_random_uuid(),current_setting('ic.qa_player')::uuid,mode,0,min_answers,ceil(min_answers*.5)::integer,now() from public.mode_clear_reward_catalog cross join generate_series(1,6);
-- A delayed offline record qualifies on its played date, not its upload date.
insert into public.play_sessions(client_event_id,player_id,mode,score,total_answers,correct_answers,played_at)
values(gen_random_uuid(),current_setting('ic.qa_player')::uuid,'TEXT',0,10,5,now()-interval '1 day');
-- Too few answers, low accuracy, pre-launch, future and practice records do not qualify.
insert into public.play_sessions(client_event_id,player_id,mode,source,score,total_answers,correct_answers,played_at) values
(gen_random_uuid(),current_setting('ic.qa_player')::uuid,'KEYS','ranked',0,9,9,now()-interval '1 day'),
(gen_random_uuid(),current_setting('ic.qa_player')::uuid,'HD_TEXT','ranked',0,10,4,now()-interval '1 day'),
(gen_random_uuid(),current_setting('ic.qa_player')::uuid,'HD_KEYS','ranked',0,10,10,now()-interval '3 days'),
(gen_random_uuid(),current_setting('ic.qa_player')::uuid,'EAR_LINK','ranked',0,10,10,now()+interval '1 day'),
(gen_random_uuid(),current_setting('ic.qa_player')::uuid,'EAR_LINK','practice',0,10,10,now()-interval '1 day');
-- Simulate a daily award already earned at the old rate.
insert into public.player_daily_mission_progress(player_id,mission_date,slot,mission_id,progress,completed,completed_at,reward_points_awarded)
values(current_setting('ic.qa_player')::uuid,current_date-100,1,'daily_text',1,true,now(),10);
insert into public.player_achievements(player_id,achievement_id,points_awarded) values(current_setting('ic.qa_player')::uuid,'streak_30',200);
set local role authenticated;
do $test$ declare n integer; total integer; result jsonb; begin
 result:=public.get_my_cosmos_progress();
 if (select points_awarded from public.player_achievements where player_id=public.current_player_id() and achievement_id='streak_30')<>200 then raise exception 'Old achievement reward decreased'; end if;
 select count(*),sum(reward_points) into n,total from public.player_mode_clear_rewards where player_id=public.current_player_id();
 if n<>26 or total<>620 then raise exception 'Daily mode cap/offline/boundary failure: %, %',n,total; end if;
 if (result->'point_breakdown'->>'mode_clear')::integer<>620 then raise exception 'Mode points missing in UI'; end if;
 if jsonb_array_length(result->'mode_clear_rewards')<>5 then raise exception 'Missing mode cards'; end if;
 perform public.get_my_cosmos_progress();
 if (select sum(reward_points) from public.player_mode_clear_rewards where player_id=public.current_player_id())<>620 then raise exception 'Repeated evaluation double-awarded'; end if;
 if (select reward_points_awarded from public.player_daily_mission_progress where player_id=public.current_player_id() and mission_date=current_date-100)<>10 then raise exception 'Old daily award changed'; end if;
 if (select achievement_points from public.players where id=public.current_player_id())<>(result->'point_breakdown'->>'achievements')::integer+(result->'point_breakdown'->>'daily')::integer+620 then raise exception 'Total PT mismatch'; end if;
 begin
 insert into public.player_mode_clear_rewards(player_id,reward_date,mode,reward_points) values(public.current_player_id(),current_date+10,'TEXT',1000);
 raise exception 'Client could forge PT';
 exception when insufficient_privilege then null; end;
end; $test$;
reset role;
-- Initial progress is available on day one, without weakening upper skill goals.
update public.play_sessions set played_at=now() where player_id=current_setting('ic.qa_player')::uuid;
insert into public.play_sessions(client_event_id,player_id,mode,score,total_answers,correct_answers,max_combo,played_at)
select gen_random_uuid(),current_setting('ic.qa_player')::uuid,'TEXT',0,15,15,10,now() from generate_series(1,2);
set local role authenticated;
do $test$ begin
 perform public.evaluate_my_progress();
 if (select count(*) from public.player_achievements where player_id=public.current_player_id() and achievement_id in ('sessions_5','perfect_5','combo_5'))<>3 then raise exception 'Early practice rewards unavailable'; end if;
 if exists(select 1 from public.player_achievements where player_id=public.current_player_id() and achievement_id in ('perfect_40','combo_100','streak_60')) then raise exception 'Upper rewards granted too early'; end if;
end; $test$;
reset role;
-- Switch to an unrelated authenticated account; reward rows must be private.
insert into auth.users(id,aud,role,is_anonymous) values(gen_random_uuid(),'authenticated','authenticated',true) returning set_config('request.jwt.claim.sub',id::text,true);
set local role authenticated;
do $test$ begin
 if exists(select 1 from public.player_mode_clear_rewards) then raise exception 'Other account can read rewards'; end if;
end; $test$;
reset role;
select 'PASS: per-mode daily cap, offline played-date, qualification boundaries, no repeat reward, historical daily PT retained, total breakdown, forged writes blocked, other-account isolation' result;
rollback;
