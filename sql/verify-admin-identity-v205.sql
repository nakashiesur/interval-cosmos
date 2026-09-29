-- TEST project only. All fixtures rolled back.
begin;
insert into auth.users(id,aud,role,is_anonymous) values(gen_random_uuid(),'authenticated','authenticated',true)
returning set_config('ic.identity_auth',id::text,true);
insert into public.players(id,account_type,player_name,avatar_id,is_admin) values(gen_random_uuid(),'staff','QA-IDENTITY','teacher',true)
returning set_config('ic.identity_player',id::text,true);
insert into public.player_devices(auth_user_id,player_id) values(current_setting('ic.identity_auth')::uuid,current_setting('ic.identity_player')::uuid);
select set_config('request.jwt.claim.sub',current_setting('ic.identity_auth'),true);
set local role authenticated;
do $$ declare p uuid:=public.current_player_id(); begin
 perform public.admin_set_player_real_name(p,'  架空 確認用  ');
 if public.admin_get_player_management(p)->>'admin_real_name'<>'架空 確認用' then raise exception 'Save/read failed'; end if;
 perform public.admin_set_player_real_name(p,'');
 if public.admin_get_player_management(p)->>'admin_real_name' is not null then raise exception 'Clear failed'; end if;
 perform public.admin_set_player_real_name(p,'架空 確認用');
 begin
  perform public.admin_set_player_real_name(p,repeat('あ',101));
  raise exception 'Length accepted';
 exception when others then if sqlerrm='Length accepted' then raise; end if; end;
 begin
  perform * from public.admin_player_identity;
  raise exception 'Direct table access allowed';
 exception when insufficient_privilege then null; end;
end; $$;
reset role;
update public.players set is_admin=false where id=current_setting('ic.identity_player')::uuid;
set local role authenticated;
do $$ declare p uuid:=public.current_player_id(); begin
 begin perform public.admin_get_player_management(p); raise exception 'Non-admin read allowed';
 exception when others then if sqlerrm<>'Admin account required' then raise; end if; end;
 begin perform public.admin_set_player_real_name(p,'forged'); raise exception 'Non-admin write allowed';
 exception when others then if sqlerrm<>'Admin account required' then raise; end if; end;
 begin perform * from public.admin_player_identity; raise exception 'Non-admin table read allowed';
 exception when insufficient_privilege then null; end;
end; $$;
reset role;
update public.players set is_admin=true,is_suspended=true where id=current_setting('ic.identity_player')::uuid;
set local role authenticated;
do $$ begin
 begin perform public.admin_set_player_real_name(public.current_player_id(),'forged'); raise exception 'Suspended write allowed';
 exception when others then if sqlerrm<>'Admin account required' then raise; end if; end;
end; $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.admin_set_player_real_name(current_setting('ic.identity_player')::uuid,'forged'); raise exception 'Anonymous write allowed';
 exception when insufficient_privilege then null; end;
end; $$;
reset role;
select 'PASS admin save/read/clear, length, private table, non-admin/anonymous/suspended denial' result;
rollback;
