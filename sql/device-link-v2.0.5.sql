-- INTERVAL COSMOS v2.0.5
-- Phase 2: secure six-digit device linking
-- Run after the v2.0.5 base database setup.

begin;

create or replace function public.create_device_link_request()
returns table (
  request_id uuid,
  pin text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := auth.uid();
  v_player_id uuid := public.current_player_id();
  v_request_id uuid := gen_random_uuid();
  v_pin text;
  v_expires_at timestamptz := now() + interval '5 minutes';
  v_try integer := 0;
begin
  if v_auth_uid is null or v_player_id is null then
    raise exception 'Linked player account required';
  end if;

  if exists (
    select 1
    from public.players p
    where p.id = v_player_id and p.is_suspended
  ) then
    raise exception 'This account is suspended';
  end if;

  update public.device_link_requests r
  set status = case
    when r.expires_at <= now() then 'expired'
    else 'cancelled'
  end
  where r.source_auth_user_id = v_auth_uid
    and r.status in ('pending', 'awaiting_confirmation');

  loop
    v_try := v_try + 1;

    v_pin := lpad(
      (
        (
          ('x' || substr(encode(extensions.gen_random_bytes(4), 'hex'), 1, 8))
            ::bit(32)::bigint
        ) % 1000000
      )::text,
      6,
      '0'
    );

    exit when not exists (
      select 1
      from public.device_link_requests r
      where r.status in ('pending', 'awaiting_confirmation')
        and r.expires_at > now()
        and r.pin_hash = extensions.crypt(v_pin, r.pin_hash)
    );

    if v_try >= 20 then
      raise exception 'Could not generate device PIN';
    end if;
  end loop;

  insert into public.device_link_requests (
    id,
    player_id,
    source_auth_user_id,
    pin_hash,
    status,
    expires_at
  )
  values (
    v_request_id,
    v_player_id,
    v_auth_uid,
    extensions.crypt(v_pin, extensions.gen_salt('bf', 8)),
    'pending',
    v_expires_at
  );

  request_id := v_request_id;
  pin := v_pin;
  expires_at := v_expires_at;
  return next;
end;
$$;

create or replace function public.claim_device_link_request(p_pin text)
returns table (
  request_id uuid,
  player_name text,
  status text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := auth.uid();
  v_pin text := regexp_replace(coalesce(p_pin, ''), '[^0-9]', '', 'g');
  v_request public.device_link_requests%rowtype;
  v_player_name text;
begin
  if v_auth_uid is null then
    raise exception 'Authentication required';
  end if;

  if exists (
    select 1 from public.player_devices d
    where d.auth_user_id = v_auth_uid
  ) then
    raise exception 'This device is already linked to a player';
  end if;

  if char_length(v_pin) <> 6 then
    raise exception 'PIN must be 6 digits';
  end if;

  update public.device_link_requests r
  set status = 'expired'
  where r.status in ('pending', 'awaiting_confirmation')
    and r.expires_at <= now();

  select r.*
  into v_request
  from public.device_link_requests r
  where r.status = 'pending'
    and r.expires_at > now()
    and r.pin_hash = extensions.crypt(v_pin, r.pin_hash)
  order by r.created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'PIN is invalid or expired';
  end if;

  if v_request.source_auth_user_id = v_auth_uid then
    raise exception 'Use a different device for device linking';
  end if;

  update public.device_link_requests r
  set target_auth_user_id = v_auth_uid,
      status = 'awaiting_confirmation'
  where r.id = v_request.id;

  select p.player_name
  into v_player_name
  from public.players p
  where p.id = v_request.player_id;

  request_id := v_request.id;
  player_name := v_player_name;
  status := 'awaiting_confirmation';
  expires_at := v_request.expires_at;
  return next;
end;
$$;

create or replace function public.get_device_link_source_status(p_request_id uuid)
returns table (
  request_id uuid,
  status text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := auth.uid();
  v_request public.device_link_requests%rowtype;
begin
  if v_auth_uid is null then
    raise exception 'Authentication required';
  end if;

  update public.device_link_requests r
  set status = 'expired'
  where r.id = p_request_id
    and r.source_auth_user_id = v_auth_uid
    and r.status in ('pending', 'awaiting_confirmation')
    and r.expires_at <= now();

  select r.*
  into v_request
  from public.device_link_requests r
  where r.id = p_request_id
    and r.source_auth_user_id = v_auth_uid;

  if not found then
    raise exception 'Device link request not found';
  end if;

  request_id := v_request.id;
  status := v_request.status;
  expires_at := v_request.expires_at;
  return next;
end;
$$;

create or replace function public.get_device_link_target_status(p_request_id uuid)
returns table (
  request_id uuid,
  player_name text,
  status text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := auth.uid();
  v_request public.device_link_requests%rowtype;
  v_player_name text;
begin
  if v_auth_uid is null then
    raise exception 'Authentication required';
  end if;

  update public.device_link_requests r
  set status = 'expired'
  where r.id = p_request_id
    and r.target_auth_user_id = v_auth_uid
    and r.status = 'awaiting_confirmation'
    and r.expires_at <= now();

  select r.*
  into v_request
  from public.device_link_requests r
  where r.id = p_request_id
    and r.target_auth_user_id = v_auth_uid;

  if not found then
    raise exception 'Device link request not found';
  end if;

  select p.player_name
  into v_player_name
  from public.players p
  where p.id = v_request.player_id;

  request_id := v_request.id;
  player_name := v_player_name;
  status := v_request.status;
  expires_at := v_request.expires_at;
  return next;
end;
$$;

create or replace function public.confirm_device_link_request(p_request_id uuid)
returns table (
  request_id uuid,
  status text,
  player_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := auth.uid();
  v_request public.device_link_requests%rowtype;
begin
  if v_auth_uid is null then
    raise exception 'Authentication required';
  end if;

  select r.*
  into v_request
  from public.device_link_requests r
  where r.id = p_request_id
    and r.source_auth_user_id = v_auth_uid
  for update;

  if not found then
    raise exception 'Device link request not found';
  end if;

  if v_request.expires_at <= now() then
    update public.device_link_requests
    set status = 'expired'
    where id = p_request_id;
    raise exception 'PIN has expired';
  end if;

  if v_request.status <> 'awaiting_confirmation'
     or v_request.target_auth_user_id is null then
    raise exception 'No device is awaiting confirmation';
  end if;

  if exists (
    select 1
    from public.player_devices d
    where d.auth_user_id = v_request.target_auth_user_id
  ) then
    raise exception 'Target device is already linked to another player';
  end if;

  insert into public.player_devices (
    auth_user_id,
    player_id,
    device_label,
    linked_at,
    last_seen_at
  )
  values (
    v_request.target_auth_user_id,
    v_request.player_id,
    'Linked device',
    now(),
    now()
  );

  update public.device_link_requests
  set status = 'confirmed',
      confirmed_at = now(),
      used_at = now()
  where id = p_request_id;

  request_id := v_request.id;
  status := 'confirmed';
  player_id := v_request.player_id;
  return next;
end;
$$;

create or replace function public.cancel_device_link_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := auth.uid();
begin
  if v_auth_uid is null then
    raise exception 'Authentication required';
  end if;

  update public.device_link_requests r
  set status = case
    when r.expires_at <= now() then 'expired'
    else 'cancelled'
  end
  where r.id = p_request_id
    and (r.source_auth_user_id = v_auth_uid or r.target_auth_user_id = v_auth_uid)
    and r.status in ('pending', 'awaiting_confirmation');

  if not found then
    raise exception 'Device link request not found or already finished';
  end if;
end;
$$;

revoke all on function public.create_device_link_request() from public;
revoke all on function public.claim_device_link_request(text) from public;
revoke all on function public.get_device_link_source_status(uuid) from public;
revoke all on function public.get_device_link_target_status(uuid) from public;
revoke all on function public.confirm_device_link_request(uuid) from public;
revoke all on function public.cancel_device_link_request(uuid) from public;

grant execute on function public.create_device_link_request() to authenticated;
grant execute on function public.claim_device_link_request(text) to authenticated;
grant execute on function public.get_device_link_source_status(uuid) to authenticated;
grant execute on function public.get_device_link_target_status(uuid) to authenticated;
grant execute on function public.confirm_device_link_request(uuid) to authenticated;
grant execute on function public.cancel_device_link_request(uuid) to authenticated;

commit;
