-- Transaction-only fixtures, including Auth identities. No existing account is used.
-- Always execute the entire file; successful checks ROLLBACK all fixtures.
begin;
set local lock_timeout = '5s';
select set_config('ic.qa_owner_auth',gen_random_uuid()::text,true),
       set_config('ic.qa_other_auth',gen_random_uuid()::text,true),
       set_config('ic.qa_owner',gen_random_uuid()::text,true),
       set_config('ic.qa_other',gen_random_uuid()::text,true);
insert into auth.users(id,aud,role,is_anonymous) values
 (current_setting('ic.qa_owner_auth')::uuid,'authenticated','authenticated',true),
 (current_setting('ic.qa_other_auth')::uuid,'authenticated','authenticated',true);
insert into public.players(id,account_type,player_name,avatar_id) values
 (current_setting('ic.qa_owner')::uuid,'staff','QA-ROLLBACK-A','teacher'),
 (current_setting('ic.qa_other')::uuid,'staff','QA-ROLLBACK-B','teacher');
insert into public.player_devices(auth_user_id,player_id) values
 (current_setting('ic.qa_owner_auth')::uuid,current_setting('ic.qa_owner')::uuid),
 (current_setting('ic.qa_other_auth')::uuid,current_setting('ic.qa_other')::uuid);
select set_config('request.jwt.claim.sub',current_setting('ic.qa_owner_auth'),true),
       set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
do $test$
declare p uuid:=public.current_player_id(); event uuid:=gen_random_uuid(); result jsonb; payload jsonb; answer jsonb;
begin
 payload:=jsonb_build_object('clientEventId',event,'source','ranked','mode','TEXT','score',200,
   'totalAnswers',2,'correctAnswers',1,'maxCombo',1,'avgResponse',500,'playedAt',now());
 result:=public.submit_saved_play(p,'ask',payload);
 perform public.publish_play_session((result->>'session_id')::uuid);
 result:=public.submit_saved_play(p,'ask',payload);
 if not (result->>'duplicate')::boolean then raise exception 'Retry was not deduplicated'; end if;
 perform public.update_my_profile(p_ranking_visibility=>'always_private');
 perform public.submit_saved_play(p,'always_private',payload||jsonb_build_object('clientEventId',gen_random_uuid(),'score',300));
 if not exists(select 1 from public.ranking_bests where player_id=p and period='ALL' and best_score=300 and public_score=200) then
   raise exception 'Private best overwrote public snapshot';
 end if;
 answer:=jsonb_build_array(jsonb_build_object('event_id',gen_random_uuid(),'interval_key','P1','chosen_key','P1','response_ms',500,'answered_at',now()));
 perform public.submit_learning_answers(p,answer);
 perform public.submit_learning_answers(p,answer);
 if (select sum(answers) from public.get_my_learning_analysis())<>1 then raise exception 'Shared answer duplicate'; end if;
end;
$test$;
reset role;
select set_config('request.jwt.claim.sub',current_setting('ic.qa_other_auth'),true);
set local role authenticated;
do $test$
declare owner_id uuid:=current_setting('ic.qa_owner')::uuid;
begin
 if exists(select 1 from public.ranking_bests where player_id=owner_id) then raise exception 'Private ranking leaked'; end if;
 if exists(select 1 from public.play_sessions where player_id=owner_id) then raise exception 'Private history leaked'; end if;
 if exists(select 1 from public.learning_answers where player_id=owner_id) then raise exception 'Private analysis leaked'; end if;
 if not exists(select 1 from public.get_public_rankings('TEXT','hall',100) where player_id=owner_id and score=200) then
   raise exception 'Public score is unavailable';
 end if;
 if public.is_current_admin() then raise exception 'Staff unexpectedly has admin access'; end if;
end;
$test$;
reset role;
update public.players set is_admin=true,is_suspended=true where id=current_setting('ic.qa_other')::uuid;
set local role authenticated;
do $test$ begin
 if public.is_current_admin() then raise exception 'Suspended administrator accepted'; end if;
end; $test$;
reset role;
select 'PASS: private data isolated, public score retained, offline/answer retries deduplicated, suspended admin denied; rollback follows' as result;
rollback;
