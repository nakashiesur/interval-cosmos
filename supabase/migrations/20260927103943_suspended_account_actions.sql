-- Reject stale device-link and publication actions after suspension.
-- Existing function signatures and grants are preserved.

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

  -- Recheck at the action, not only when the PIN was issued. Hold the
  -- account row while linking so suspension cannot interleave the decision.
  perform 1 from public.players p
  where p.id = v_request.player_id and not p.is_suspended
    and exists (select 1 from public.player_devices d
                where d.auth_user_id = v_request.source_auth_user_id
                  and d.player_id = p.id)
  for share;
  if not found then
    raise exception 'This account is suspended or the source device is no longer linked';
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

  -- Recheck at the action, not only when the PIN was issued. Hold the
  -- account row while linking so suspension cannot interleave the decision.
  perform 1 from public.players p
  where p.id = v_request.player_id and not p.is_suspended
    and exists (select 1 from public.player_devices d
                where d.auth_user_id = v_request.source_auth_user_id
                  and d.player_id = p.id)
  for share;
  if not found then
    raise exception 'This account is suspended or the source device is no longer linked';
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

create or replace function public.publish_play_session(p_session_id uuid)
returns table (
  monthly_rank bigint,
  hall_rank bigint,
  monthly_public_score integer,
  hall_public_score integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player_id uuid := public.current_player_id();
  v_mode text;
  v_score integer;
  v_total integer;
  v_correct integer;
  v_combo integer;
  v_avg double precision;
  v_played_at timestamptz;
  v_month text;
begin
  if v_player_id is null then
    raise exception 'Player account required';
  end if;

  perform 1 from public.players p
  where p.id = v_player_id and not p.is_suspended
  for share;
  if not found then
    raise exception 'This account is suspended';
  end if;

  select ps.mode, ps.score, ps.total_answers, ps.correct_answers,
         ps.max_combo, ps.avg_response, ps.played_at
  into v_mode, v_score, v_total, v_correct, v_combo, v_avg, v_played_at
  from public.play_sessions ps
  where ps.id = p_session_id
    and ps.player_id = v_player_id
    and ps.source = 'ranked';

  if not found then
    raise exception 'Ranked session not found';
  end if;

  update public.play_sessions
  set is_public = true
  where id = p_session_id and player_id = v_player_id;

  v_month := to_char(timezone('Asia/Tokyo', v_played_at), 'YYYY-MM');

  update public.ranking_bests rb
  set public_session_id = p_session_id,
      public_score = v_score,
      public_total_answers = v_total,
      public_correct_answers = v_correct,
      public_max_combo = v_combo,
      public_avg_response = v_avg,
      public_updated_at = now()
  where rb.player_id = v_player_id
    and rb.mode = v_mode
    and rb.period in (v_month, 'ALL')
    and (rb.public_score is null or v_score > rb.public_score);

  select rb.public_score into monthly_public_score
  from public.ranking_bests rb
  where rb.player_id = v_player_id and rb.mode = v_mode and rb.period = v_month;

  select rb.public_score into hall_public_score
  from public.ranking_bests rb
  where rb.player_id = v_player_id and rb.mode = v_mode and rb.period = 'ALL';

  monthly_rank := case when monthly_public_score is null then null else (
    select 1 + count(*)
    from public.ranking_bests rb
    where rb.mode = v_mode and rb.period = v_month
      and rb.public_score is not null
      and rb.public_score > monthly_public_score
  ) end;

  hall_rank := case when hall_public_score is null then null else (
    select 1 + count(*)
    from public.ranking_bests rb
    where rb.mode = v_mode and rb.period = 'ALL'
      and rb.public_score is not null
      and rb.public_score > hall_public_score
  ) end;

  return next;
end;
$$;
