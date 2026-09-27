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
end $$;
reset role;
-- An unrelated student must see the public 200, never the private 300.
select set_config('request.jwt.claim.sub',(select d.auth_user_id::text from public.player_devices d join public.players p on p.id=d.player_id where p.student_number='99092797' limit 1),true);
set local role authenticated;
do $$
declare target uuid:='3e470c7f-5ebb-498d-9452-3a66a6ec7085'; card jsonb;
begin
  if public.current_player_id() is null or public.current_player_id()=target then raise exception 'Unrelated student missing'; end if;
  if exists(select 1 from public.ranking_bests where player_id=target) then raise exception 'Private best leaked through direct table read'; end if;
  if exists(select 1 from public.play_sessions where player_id=target) then raise exception 'Private history leaked'; end if;
  if not exists(select 1 from public.get_public_rankings('TEXT','hall',100) where player_id=target and score=200) then raise exception 'Public ranking changed or disappeared'; end if;
  card:=public.get_public_profile_card(target);
  if not exists(select 1 from jsonb_array_elements(card->'records') r where r->>'mode'='TEXT' and (r->>'score')::integer=200) then raise exception 'Public profile changed or disappeared'; end if;
end $$;
reset role;
-- A revoked administrator is unrelated too; temporary elevation stays inside rollback.
select set_config('request.jwt.claim.sub',(select d.auth_user_id::text from public.player_devices d join public.players p on p.id=d.player_id where p.id='c8877363-e272-4ada-99a0-9e4e12227b8c' limit 1),true);
set local role authenticated;
do $$ begin
  if public.is_current_admin() then raise exception 'QA administrator must start revoked'; end if;
  if exists(select 1 from public.ranking_bests where player_id='3e470c7f-5ebb-498d-9452-3a66a6ec7085') then raise exception 'Revoked admin can read private best'; end if;
end $$;
reset role;
update public.players set is_admin=true where id='c8877363-e272-4ada-99a0-9e4e12227b8c';
set local role authenticated;
do $$ begin
  if not exists(select 1 from public.ranking_bests where player_id='3e470c7f-5ebb-498d-9452-3a66a6ec7085' and period='ALL' and best_score=300 and public_score=200) then raise exception 'Administrator access broken'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select d.auth_user_id::text from public.player_devices d join public.players p on p.id=d.player_id where p.student_number='99092701' limit 1),true);
set local role authenticated;
do $$ declare p uuid:=public.current_player_id(); begin
  perform public.hide_all_my_rankings();
  if exists(select 1 from public.ranking_bests where player_id=p and public_session_id is not null) then raise exception 'Unpublish failed'; end if;
  if not exists(select 1 from public.ranking_bests where player_id=p and period='ALL' and best_score=300) then raise exception 'Private best lost after unpublish'; end if;
end $$;
reset role;
rollback;
