-- Dedicated Final Fresh Build 0927 only; all links, publication and suspension roll back.
begin;
do $$
declare
  owner uuid := '3e470c7f-5ebb-498d-9452-3a66a6ec7085';
  source_auth uuid; target_auth uuid; r record; saved_session uuid; before_devices integer;
begin
  select auth_user_id into source_auth from public.player_devices where player_id=owner limit 1;
  select a.id into target_auth from auth.users a
    where a.raw_user_meta_data->>'qa_purpose'='final-fresh-nonadmin-edge-check'
      and not exists(select 1 from public.player_devices d where d.auth_user_id=a.id) limit 1;
  select id into saved_session from public.play_sessions where player_id=owner and source='ranked' and score=105 limit 1;
  if source_auth is null or target_auth is null or saved_session is null then raise exception 'Dedicated QA fixtures missing'; end if;
  select count(*) into before_devices from public.player_devices where player_id=owner;
  perform set_config('request.jwt.claim.sub',source_auth::text,true);
  set local role authenticated;
  select * into r from public.create_device_link_request();
  reset role;
  update public.players set is_suspended=true where id=owner;
  perform set_config('request.jwt.claim.sub',target_auth::text,true);
  set local role authenticated;
  begin
    perform public.claim_device_link_request(r.pin);
    raise exception 'Suspended PIN claim accepted';
  exception when raise_exception then
    if sqlerrm not like 'This account is suspended%' then raise; end if;
  end;
  reset role;
  update public.players set is_suspended=false where id=owner;
  set local role authenticated;
  perform public.claim_device_link_request(r.pin);
  reset role;
  update public.players set is_suspended=true where id=owner;
  perform set_config('request.jwt.claim.sub',source_auth::text,true);
  set local role authenticated;
  begin
    perform public.confirm_device_link_request(r.request_id);
    raise exception 'Suspended confirmation accepted';
  exception when raise_exception then
    if sqlerrm not like 'This account is suspended%' then raise; end if;
  end;
  begin
    perform public.publish_play_session(saved_session);
    raise exception 'Suspended publication accepted';
  exception when raise_exception then
    if sqlerrm <> 'This account is suspended' then raise; end if;
  end;
  reset role;
  if exists(select 1 from public.player_devices where auth_user_id=target_auth) then raise exception 'Rejected link created a device'; end if;
  update public.players set is_suspended=false where id=owner;
  set local role authenticated;
  perform public.confirm_device_link_request(r.request_id);
  perform public.publish_play_session(saved_session);
  begin
    perform public.confirm_device_link_request(r.request_id);
    raise exception 'Reused confirmation accepted';
  exception when raise_exception then
    if sqlerrm <> 'No device is awaiting confirmation' then raise; end if;
  end;
  reset role;
  if (select count(*) from public.player_devices where player_id=owner) <> before_devices+1 then raise exception 'Normal link failed or duplicated'; end if;
  if not (select is_public from public.play_sessions where id=saved_session) then raise exception 'Normal publication failed'; end if;

  -- A source session detached after issuing its PIN may not link new devices.
  delete from public.player_devices where auth_user_id=target_auth;
  set local role authenticated;
  select * into r from public.create_device_link_request();
  reset role;
  delete from public.player_devices where auth_user_id=source_auth;
  perform set_config('request.jwt.claim.sub',target_auth::text,true);
  set local role authenticated;
  begin
    perform public.claim_device_link_request(r.pin);
    raise exception 'Detached source claim accepted';
  exception when raise_exception then
    if sqlerrm not like 'This account is suspended%' then raise; end if;
  end;
  reset role;
end $$;
select 'PASS: suspended claim/confirm/publish denied; restored actions work; no duplicate; detached source denied' as result;
rollback;
