-- Dedicated Final Fresh Build 0927 ONLY; publication is transaction-local and rolled back.
begin;
select set_config('request.jwt.claim.sub',(select d.auth_user_id::text from public.player_devices d join public.players p on p.id=d.player_id where p.student_number='99092701' limit 1),true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
do $$
declare p uuid:=public.current_player_id(); a uuid; b uuid;
begin
  if p is null then raise exception 'Synthetic student missing'; end if;
  perform public.update_my_profile(p_ranking_visibility=>'ask');
  select session_id into a from public.submit_play_session(gen_random_uuid(),'ranked','TEXT',200,5,5,5,500);
  perform public.publish_play_session(a);
  perform public.update_my_profile(p_ranking_visibility=>'always_private');
  select session_id into b from public.submit_play_session(gen_random_uuid(),'ranked','TEXT',300,6,6,6,500);
  if (select is_public from public.play_sessions where id=b) then raise exception 'Private run published'; end if;
  if not exists(select 1 from public.ranking_bests where player_id=p and mode='TEXT' and period='ALL' and best_score=300 and public_score=200 and public_session_id=a) then
    raise exception 'Public best lost or overwritten by private run';
  end if;
  perform public.hide_all_my_rankings();
  if exists(select 1 from public.ranking_bests where player_id=p and public_session_id is not null) then raise exception 'Unpublish failed'; end if;
  if not exists(select 1 from public.ranking_bests where player_id=p and period='ALL' and best_score=300) then raise exception 'Private best lost after unpublish'; end if;
end $$;
reset role;
rollback;
