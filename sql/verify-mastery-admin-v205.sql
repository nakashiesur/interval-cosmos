-- Disposable fixtures only. Execute the entire file; ROLLBACK preserves all data.
begin;
set local lock_timeout='5s';
insert into auth.users(id,aud,role,is_anonymous)
values(gen_random_uuid(),'authenticated','authenticated',true)
returning set_config('ic.qa_auth',id::text,true);
insert into public.players(id,account_type,player_name,avatar_id,is_admin)
values(gen_random_uuid(),'staff','QA-MASTERY','teacher',true)
returning set_config('ic.qa_player',id::text,true);
insert into public.player_devices(auth_user_id,player_id)
values(current_setting('ic.qa_auth')::uuid,current_setting('ic.qa_player')::uuid);
select set_config('request.jwt.claim.sub',current_setting('ic.qa_auth'),true);
-- A spectacular first session still earns only FIRST SIGNAL.
insert into public.play_sessions(client_event_id,player_id,mode,score,total_answers,correct_answers,max_combo,played_at)
values(gen_random_uuid(),current_setting('ic.qa_player')::uuid,'EAR_LINK',10000,100,100,100,now());
set local role authenticated;
do $test$ declare p uuid:=public.current_player_id(); begin
 perform public.evaluate_my_progress();
 if (select count(*) from public.player_achievements where player_id=p)<>1
 or not exists(select 1 from public.player_achievements where player_id=p and achievement_id='first_signal') then
 raise exception 'A first session unlocked multiple achievements'; end if;
end; $test$;
reset role;
-- Simulate an award earned under the old rules; keep it even without new eligibility.
insert into public.player_achievements(player_id,achievement_id) values(current_setting('ic.qa_player')::uuid,'perfect_5');
set local role authenticated;
do $test$ begin
 perform public.evaluate_my_progress();
 if not exists(select 1 from public.player_achievements where player_id=public.current_player_id() and achievement_id='perfect_5') then raise exception 'Legacy reward revoked'; end if;
end; $test$;
reset role;
-- AURORA cannot bypass COSMIC even when its own achievements are present.
insert into public.player_achievements(player_id,achievement_id) values
(current_setting('ic.qa_player')::uuid,'perfect_20'),(current_setting('ic.qa_player')::uuid,'all_modes') on conflict do nothing;
set local role authenticated;
do $test$ begin
 perform public.evaluate_my_progress();
 if exists(select 1 from public.player_frames where player_id=public.current_player_id() and frame_id='aurora') then raise exception 'AURORA bypassed COSMIC'; end if;
end; $test$;
reset role;
insert into public.player_frames(player_id,frame_id) values(current_setting('ic.qa_player')::uuid,'cosmic') on conflict do nothing;
set local role authenticated;
do $test$ begin
 perform public.evaluate_my_progress();
 if not exists(select 1 from public.player_frames where player_id=public.current_player_id() and frame_id='aurora') then raise exception 'AURORA failed after predecessor unlocked'; end if;
end; $test$;
reset role;
-- Check each new threshold below and at the exact boundary.
do $test$
declare p uuid:=current_setting('ic.qa_player')::uuid; r record; n int; target int; modes text[]; baseline int;
begin
for r in select * from public.achievement_catalog where sort_order between 1100 and 1107 loop
 delete from public.play_sessions where player_id=p;
 baseline:=greatest(coalesce((r.requirement->>'min_sessions')::int,0),coalesce((r.requirement->>'min_active_days')::int,0));
 insert into public.play_sessions(client_event_id,player_id,mode,score,played_at)
 select gen_random_uuid(),p,'TEXT',0,now()-((seed.day_index-1)%greatest(coalesce((r.requirement->>'min_active_days')::int,1),1))*interval '1 day' from generate_series(1,baseline) as seed(day_index);
 case r.requirement->>'type'
 when 'sessions' then
  target:=(r.requirement->>'count')::int;
  for n in 1..target loop
   insert into public.play_sessions(client_event_id,player_id,mode,score,played_at) values(gen_random_uuid(),p,'TEXT',0,now());
   if n=target-1 and public.achievement_requirement_met(p,r.requirement) then raise exception '% unlocked early',r.id; end if;
  end loop;
 when 'active_days' then
  target:=(r.requirement->>'days')::int;
  for n in 1..target loop
   insert into public.play_sessions(client_event_id,player_id,mode,score,played_at) values(gen_random_uuid(),p,'TEXT',0,now()-n*interval '2 days');
   insert into public.play_sessions(client_event_id,player_id,mode,score,played_at) values(gen_random_uuid(),p,'TEXT',0,now()-n*interval '2 days');
   if n=target-1 and public.achievement_requirement_met(p,r.requirement) then raise exception '% counted repeated same-day sessions as days',r.id; end if;
  end loop;
  if public.longest_play_streak(p)>1 then raise exception 'Nonconsecutive test fixture invalid'; end if;
 when 'streak_days' then
  target:=(r.requirement->>'days')::int;
  for n in 1..target loop
   insert into public.play_sessions(client_event_id,player_id,mode,score,played_at) values(gen_random_uuid(),p,'TEXT',0,now()-n*interval '1 day');
   if n=target-1 and public.achievement_requirement_met(p,r.requirement) then raise exception '% unlocked early',r.id; end if;
  end loop;
 when 'combo' then
  target:=(r.requirement->>'value')::int;
  insert into public.play_sessions(client_event_id,player_id,mode,score,max_combo,played_at) values(gen_random_uuid(),p,'TEXT',0,target-1,now());
  if public.achievement_requirement_met(p,r.requirement) then raise exception '% unlocked early',r.id; end if;
  for n in 1..coalesce((r.requirement->>'repeat_count')::int,1) loop
   insert into public.play_sessions(client_event_id,player_id,mode,score,max_combo,played_at) values(gen_random_uuid(),p,'TEXT',0,target,now());
   if n<coalesce((r.requirement->>'repeat_count')::int,1) and public.achievement_requirement_met(p,r.requirement) then raise exception '% unlocked before repetition threshold',r.id; end if;
  end loop;
 when 'perfect_session' then
  target:=(r.requirement->>'min_answers')::int;
  insert into public.play_sessions(client_event_id,player_id,mode,score,total_answers,correct_answers,played_at) values(gen_random_uuid(),p,coalesce(r.requirement->>'mode','TEXT'),0,target,target-1,now());
  if public.achievement_requirement_met(p,r.requirement) then raise exception '% unlocked with a wrong answer',r.id; end if;
  for n in 1..coalesce((r.requirement->>'repeat_count')::int,1) loop
   insert into public.play_sessions(client_event_id,player_id,mode,score,total_answers,correct_answers,played_at) values(gen_random_uuid(),p,coalesce(r.requirement->>'mode','TEXT'),0,target,target,now());
   if n<coalesce((r.requirement->>'repeat_count')::int,1) and public.achievement_requirement_met(p,r.requirement) then raise exception '% unlocked before repetition threshold',r.id; end if;
  end loop;
 when 'all_modes_perfect' then
  target:=(r.requirement->>'min_answers')::int;
  select array_agg(value) into modes from jsonb_array_elements_text(r.requirement->'modes');
  for n in 1..cardinality(modes) loop
   insert into public.play_sessions(client_event_id,player_id,mode,score,total_answers,correct_answers,played_at) values(gen_random_uuid(),p,modes[n],0,coalesce((r.requirement->'mode_min_answers'->>modes[n])::int,target),coalesce((r.requirement->'mode_min_answers'->>modes[n])::int,target),now());
   if n=cardinality(modes)-1 and public.achievement_requirement_met(p,r.requirement) then raise exception '% unlocked missing a mode',r.id; end if;
  end loop;
 else raise exception 'Unexpected requirement %',r.id;
 end case;
 if not public.achievement_requirement_met(p,r.requirement) then raise exception '% did not unlock at threshold',r.id; end if;
end loop;
delete from public.play_sessions where player_id=p;
end; $test$;
insert into public.player_achievements(player_id,achievement_id)
select current_setting('ic.qa_player')::uuid,id from public.achievement_catalog where id<>'streak_60' and is_active on conflict do nothing;
set local role authenticated;
do $test$ declare p uuid:=public.current_player_id(); begin
 perform public.evaluate_my_progress();
 if exists(select 1 from public.player_frames where player_id=p and frame_id='omega') then raise exception 'OMEGA unlocked before all achievements'; end if;
 perform public.get_admin_student_dashboard(p);
 perform public.admin_update_player_profile(p,'QA-MASTERY',null,'teacher');
end; $test$;
reset role;
insert into public.player_achievements(player_id,achievement_id) values(current_setting('ic.qa_player')::uuid,'streak_60');
set local role authenticated;
do $test$ declare p uuid:=public.current_player_id(); n int; begin
 perform public.evaluate_my_progress();
 if not exists(select 1 from public.player_frames where player_id=p and frame_id='omega') then raise exception 'OMEGA did not unlock'; end if;
 select count(*) into n from public.player_achievements where player_id=p;
 perform public.evaluate_my_progress();
 if (select count(*) from public.player_achievements where player_id=p)<>n then raise exception 'Repeated evaluation changed achievements'; end if;
end; $test$;
do $test$
declare p uuid:=public.current_player_id(); result jsonb;
begin
 result:=public.submit_saved_play(p,'ask',jsonb_build_object('clientEventId',gen_random_uuid(),'source','ranked','mode','TEXT','score',200,'totalAnswers',2,'correctAnswers',1,'maxCombo',1,'avgResponse',500,'playedAt',now()));
 perform public.publish_play_session((result->>'session_id')::uuid);
 perform public.admin_unpublish_player_rankings(p);
 if exists(select 1 from public.ranking_bests where player_id=p and public_score is not null) then raise exception 'Self ranking stayed public'; end if;
 perform public.admin_delete_player_rankings(p);
 if exists(select 1 from public.ranking_bests where player_id=p) then raise exception 'Self ranking deletion failed'; end if;
 if not exists(select 1 from public.play_sessions where player_id=p) then raise exception 'Ranking deletion removed history'; end if;
end; $test$;
reset role;
update public.players set is_admin=false where id=current_setting('ic.qa_player')::uuid;
set local role authenticated;
do $test$ declare denied boolean:=false; begin
 begin perform public.get_admin_student_dashboard(public.current_player_id()); exception when others then denied:=sqlerrm='Admin account required'; end;
 if not denied then raise exception 'Nonadmin dashboard access permitted'; end if;
 denied:=false;
 begin perform public.admin_update_player_profile(public.current_player_id(),'QA-MASTERY',null,'teacher'); exception when others then denied:=sqlerrm='Admin account required'; end;
 if not denied then raise exception 'Nonadmin edit permitted'; end if;
end; $test$;
reset role;
select 'PASS: predecessor frame gating; cumulative days across breaks without duplicates; first-session flood prevented and earned rewards retained; eight thresholds; OMEGA 38/39 locked and 39/39 unlocked; repeated evaluation stable; staff null-course self-edit; self ranking unpublish/delete preserves history; nonadmin denied' as result;
rollback;
