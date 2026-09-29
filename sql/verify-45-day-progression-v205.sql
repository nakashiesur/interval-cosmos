-- Synthetic pacing scenario, not measured student progress. All fixtures roll back.
begin;
insert into auth.users(id,aud,role,is_anonymous) values(gen_random_uuid(),'authenticated','authenticated',true) returning set_config('ic.qa_auth',id::text,true);
insert into public.players(id,account_type,player_name,avatar_id) values(gen_random_uuid(),'staff','QA-45-DAYS','teacher') returning set_config('ic.qa_player',id::text,true);
insert into public.player_devices(auth_user_id,player_id) values(current_setting('ic.qa_auth')::uuid,current_setting('ic.qa_player')::uuid);
select set_config('request.jwt.claim.sub',current_setting('ic.qa_auth'),true);
insert into public.player_frames(player_id,frame_id) values(current_setting('ic.qa_player')::uuid,'normal');
update public.mode_clear_reward_catalog set enabled_from=now()-interval '60 days';
-- Ten daily plays: each of five modes twice. Skill goals are achieved in the final week.
insert into public.play_sessions(client_event_id,player_id,mode,score,total_answers,correct_answers,max_combo,played_at,interval_stats)
select gen_random_uuid(),current_setting('ic.qa_player')::uuid,m.mode,0,
 case when d>40 then case when m.mode like 'HD_%' then 45 when m.mode='EAR_LINK' then 20 else 30 end else case when m.mode='EAR_LINK' then 10 else 20 end end,
 case when d>40 then case when m.mode like 'HD_%' then 45 when m.mode='EAR_LINK' then 20 else 30 end else case when m.mode='EAR_LINK' then 9 else 18 end end,
 case when d>40 and m.mode like 'HD_%' then 45 else 10 end,
 now()-(45-d)*interval '1 day',
 jsonb_build_object('intervals',(select jsonb_object_agg(k,jsonb_build_object('seen',50,'correct',48)) from unnest(array['P1','m2','M2','m3','M3','P4','TT','P5','m6','M6','m7','M7','P8']) k))
from generate_series(1,44) d cross join unnest(array['TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK']) m(mode) cross join generate_series(1,2) repeat;
insert into public.player_daily_mission_progress(player_id,mission_date,slot,mission_id,progress,completed,completed_at,reward_points_awarded)
select current_setting('ic.qa_player')::uuid,(now() at time zone 'Asia/Tokyo')::date-(45-d),s.slot,s.id,100,true,now(),60
from generate_series(1,44) d cross join (values(1,'daily_play_2'),(2,'daily_answers_15'),(3,'daily_correct_10')) s(slot,id);
set local role authenticated;
do $test$ begin
 perform public.evaluate_my_progress();
 if exists(select 1 from public.player_frames where player_id=public.current_player_id() and frame_id='omega') then raise exception 'Scenario unlocked pinnacle before day 45'; end if;
 if (select count(*) from public.player_achievements where player_id=public.current_player_id())<>38 then raise exception 'Day 44 should have 38 achievements'; end if;
end; $test$;
reset role;
insert into public.play_sessions(client_event_id,player_id,mode,score,total_answers,correct_answers,max_combo,played_at,interval_stats)
select gen_random_uuid(),player_id,mode,score,total_answers,correct_answers,max_combo,now(),interval_stats from public.play_sessions where player_id=current_setting('ic.qa_player')::uuid order by played_at desc limit 10;
delete from public.player_daily_mission_progress where player_id=current_setting('ic.qa_player')::uuid and mission_date=(now() at time zone 'Asia/Tokyo')::date;
insert into public.player_daily_mission_progress(player_id,mission_date,slot,mission_id,progress,completed,completed_at,reward_points_awarded)
select current_setting('ic.qa_player')::uuid,(now() at time zone 'Asia/Tokyo')::date,s.slot,s.id,100,true,now(),60 from (values(1,'daily_play_2'),(2,'daily_answers_15'),(3,'daily_correct_10')) s(slot,id)
on conflict(player_id,mission_date,slot) do update set mission_id=excluded.mission_id,completed=true,reward_points_awarded=60;
set local role authenticated;
do $test$ declare r jsonb; begin
 r:=public.get_my_cosmos_progress();
 if (select count(*) from public.player_achievements where player_id=public.current_player_id())<>39 then raise exception 'Day 45 did not unlock all achievements'; end if;
 if not exists(select 1 from public.player_frames where player_id=public.current_player_id() and frame_id='omega') then raise exception 'Day 45 did not unlock pinnacle'; end if;
 if (r->'player'->>'achievement_points')::int<>23615 then raise exception 'Unexpected scenario total %',r->'player'->>'achievement_points'; end if;
 if exists(select 1 from public.ranking_bests where player_id=public.current_player_id()) then raise exception 'Scenario unexpectedly required ranking publication'; end if;
end; $test$;
reset role;
select 'PASS: 44 days / 440 plays locked; 45 days / 450 plays / 23,615 PT and all 39 achievements unlock COSMO SOVEREIGN without ranking publication. This is a qualifying-practice scenario, not a calendar guarantee.' result;
rollback;
