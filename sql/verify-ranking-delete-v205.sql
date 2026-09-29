begin;
insert into auth.users(id,aud,role,is_anonymous) values(gen_random_uuid(),'authenticated','authenticated',true) returning set_config('ic.rank_auth',id::text,true);
insert into public.players(id,account_type,player_name,avatar_id,is_admin,ranking_visibility) values(gen_random_uuid(),'staff','QA-RANK-DELETE','teacher',true,'always_public') returning set_config('ic.rank_player',id::text,true);
insert into public.player_devices(auth_user_id,player_id) values(current_setting('ic.rank_auth')::uuid,current_setting('ic.rank_player')::uuid);
select set_config('request.jwt.claim.sub',current_setting('ic.rank_auth'),true);
insert into public.play_sessions(player_id,client_event_id,mode,score,total_answers,correct_answers,max_combo,avg_response,played_at,is_public) values(current_setting('ic.rank_player')::uuid,gen_random_uuid(),'TEXT',9000,20,20,20,1,now()-interval '1 hour',true) returning set_config('ic.rank_session',id::text,true);
insert into public.ranking_bests(player_id,mode,period,best_session_id,best_score,best_total_answers,best_correct_answers,best_max_combo,best_avg_response,public_session_id,public_score,public_total_answers,public_correct_answers,public_max_combo,public_avg_response,public_updated_at)
select current_setting('ic.rank_player')::uuid,'TEXT',period,current_setting('ic.rank_session')::uuid,9000,20,20,20,1,current_setting('ic.rank_session')::uuid,9000,20,20,20,1,now() from unnest(array['ALL',to_char(now(),'YYYY-MM')]) period;
create temporary table original_rank as select * from public.ranking_bests where player_id=current_setting('ic.rank_player')::uuid and period='ALL';
-- A second player proves that the public ranking closes the gap.
insert into public.players(id,account_type,player_name,avatar_id,ranking_visibility) values(gen_random_uuid(),'staff','QA-RANK-NEXT','teacher','always_public') returning set_config('ic.rank_next',id::text,true);
insert into public.public_profiles(player_id,player_name,account_type,avatar_id,equipped_frame_id) values(current_setting('ic.rank_next')::uuid,'QA-RANK-NEXT','staff','teacher','normal') on conflict(player_id) do nothing;
insert into public.public_profiles(player_id,player_name,account_type,avatar_id,equipped_frame_id) values(current_setting('ic.rank_player')::uuid,'QA-RANK-DELETE','staff','teacher','normal') on conflict(player_id) do nothing;
insert into public.play_sessions(player_id,client_event_id,mode,score,total_answers,correct_answers,max_combo,avg_response,played_at,is_public) values(current_setting('ic.rank_next')::uuid,gen_random_uuid(),'TEXT',8000,20,20,20,1,now(),true) returning set_config('ic.rank_next_session',id::text,true);
insert into public.ranking_bests(player_id,mode,period,best_session_id,best_score,best_total_answers,best_correct_answers,best_max_combo,best_avg_response,public_session_id,public_score,public_total_answers,public_correct_answers,public_max_combo,public_avg_response,public_updated_at) values(current_setting('ic.rank_next')::uuid,'TEXT','ALL',current_setting('ic.rank_next_session')::uuid,8000,20,20,20,1,current_setting('ic.rank_next_session')::uuid,8000,20,20,20,1,now());
select set_config('ic.rank_before',(select rank::text from public.get_public_rankings('TEXT','hall',100) where player_id=current_setting('ic.rank_next')::uuid),true);
set local role authenticated;
do $$ declare p uuid:=public.current_player_id();begin
 begin perform public.admin_delete_ranking_entry(p,'TEXT','ALL',9000,now(),'DELETE');raise exception 'Wrong confirmation accepted';exception when others then if sqlerrm<>'Type Delete to confirm' then raise;end if;end;
 begin perform public.admin_delete_ranking_entry(p,'TEXT','ALL',1,now(),'Delete');raise exception 'Stale score accepted';exception when others then if sqlerrm not like 'Ranking changed.%' then raise;end if;end;
 perform public.admin_delete_ranking_entry(p,'TEXT','ALL',9000,now(),'Delete');
end; $$;
reset role;
do $$ begin
 if exists(select 1 from public.ranking_bests where player_id=current_setting('ic.rank_player')::uuid and period='ALL') then raise exception 'Row not removed';end if;
 if not exists(select 1 from public.ranking_bests where player_id=current_setting('ic.rank_player')::uuid and period<>'ALL') then raise exception 'Other period affected';end if;
 if not exists(select 1 from public.play_sessions where id=current_setting('ic.rank_session')::uuid) then raise exception 'History removed';end if;
end; $$;
do $$ begin
 if (select rank from public.get_public_rankings('TEXT','hall',100) where player_id=current_setting('ic.rank_next')::uuid) is distinct from current_setting('ic.rank_before')::bigint-1 then raise exception 'Public rank did not advance';end if;
end; $$;
-- A stale retransmission cannot recreate the row.
insert into public.ranking_bests select * from original_rank;
do $$ begin if exists(select 1 from public.ranking_bests where player_id=current_setting('ic.rank_player')::uuid and period='ALL') then raise exception 'Deleted row resurrected';end if;end; $$;
-- A genuinely new, lower-scoring play can register normally.
insert into public.play_sessions(player_id,client_event_id,mode,score,total_answers,correct_answers,max_combo,avg_response,played_at,is_public) values(current_setting('ic.rank_player')::uuid,gen_random_uuid(),'TEXT',100,10,8,3,2,clock_timestamp()+interval '1 second',true) returning set_config('ic.new_rank_session',id::text,true);
update original_rank set best_session_id=current_setting('ic.new_rank_session')::uuid,public_session_id=current_setting('ic.new_rank_session')::uuid,best_score=100,public_score=100;
insert into public.ranking_bests select * from original_rank;
-- Old public session cannot overwrite a new lower result.
update public.ranking_bests set public_session_id=current_setting('ic.rank_session')::uuid,public_score=9000 where player_id=current_setting('ic.rank_player')::uuid and period='ALL';
do $$ begin if not exists(select 1 from public.ranking_bests where player_id=current_setting('ic.rank_player')::uuid and period='ALL' and public_score=100) then raise exception 'New result affected by old record';end if;end; $$;
update public.players set is_admin=false where id=current_setting('ic.rank_player')::uuid;
set local role authenticated;
do $$ begin
 begin perform public.admin_delete_ranking_entry(public.current_player_id(),'TEXT','ALL',100,now(),'Delete');raise exception 'Student deletion allowed';exception when others then if sqlerrm<>'Admin account required' then raise;end if;end;
end; $$;
reset role;
select 'PASS confirmation, stale row, scoped delete, preserved history, replay protection, new score, admin authorization' result;
rollback;
