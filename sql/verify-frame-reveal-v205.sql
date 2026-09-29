begin;
insert into auth.users(id,aud,role,is_anonymous) values(gen_random_uuid(),'authenticated','authenticated',true) returning set_config('ic.reveal_auth',id::text,true);
insert into public.players(id,account_type,player_name,avatar_id) values(gen_random_uuid(),'staff','QA-REVEAL','teacher') returning set_config('ic.reveal_player',id::text,true);
insert into public.player_devices(auth_user_id,player_id) values(current_setting('ic.reveal_auth')::uuid,current_setting('ic.reveal_player')::uuid);
select set_config('request.jwt.claim.sub',current_setting('ic.reveal_auth'),true);
set local role authenticated;
do $$ declare f jsonb; begin
 for f in select * from jsonb_array_elements(public.get_my_cosmos_progress()->'frames') loop
 if f->>'id' in ('supernova','event_horizon','pulsar','omega') then
  if f->>'name'<>'???' or f->>'appearance_hidden'<>'true' or f->>'conditions_revealed'<>'false' or f->>'unlock_rule' is not null or f->>'points_required' is not null then raise exception 'Locked frame leaks'; end if;
 elsif f->>'name'='???' then raise exception 'Early frame hidden'; end if;
 end loop;
end; $$;
reset role;
insert into public.player_frames(player_id,frame_id) values(current_setting('ic.reveal_player')::uuid,'aurora'),(current_setting('ic.reveal_player')::uuid,'event_horizon');
set local role authenticated;
do $$ declare f jsonb; begin
 for f in select * from jsonb_array_elements(public.get_my_cosmos_progress()->'frames') loop
 if f->>'id' in ('supernova','pulsar') then
  if f->>'name'<>'???' or f->>'appearance_hidden'<>'true' or f->>'conditions_revealed'<>'true' or jsonb_array_length(f->'requirement_descriptions')<1 then raise exception 'Next frame conditions missing'; end if;
 elsif f->>'id'='omega' and f->>'conditions_revealed'<>'false' then raise exception 'Skipped predecessor';
 elsif f->>'id'='event_horizon' and (f->>'appearance_hidden'<>'false' or f->>'unlocked'<>'true') then raise exception 'Owned frame lost'; end if;
 end loop;
end; $$;
reset role;
select 'PASS secret artwork and requirements, predecessor reveal, legacy-owned frames' result;
rollback;
