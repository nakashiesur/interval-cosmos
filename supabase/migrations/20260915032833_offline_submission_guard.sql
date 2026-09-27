-- Durable client outbox entry point. Existing APIs and canonical base stay intact.
begin;
create or replace function public.submit_saved_play(
  p_player_id uuid, p_visibility text, p_payload jsonb
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_player public.players%rowtype;
  v_existing public.play_sessions%rowtype;
  v_result jsonb;
  v_event uuid := (p_payload->>'clientEventId')::uuid;
begin
  -- Lock the device binding and player until the entire submission commits.
  perform 1 from public.player_devices where auth_user_id = auth.uid() and player_id = p_player_id for share;
  if not found or p_player_id is distinct from public.current_player_id() then
    raise exception 'Saved play belongs to another account' using errcode = '42501';
  end if;
  select * into strict v_player from public.players where id = p_player_id for update;
  if v_player.is_suspended then raise exception 'Account suspended' using errcode = '42501'; end if;
  select * into v_existing from public.play_sessions where player_id = p_player_id and client_event_id = v_event;
  if found then
    return jsonb_build_object('session_id',v_existing.id,'duplicate',true,
      'publication_required',v_existing.source = 'ranked' and not v_existing.is_public and v_player.ranking_visibility = 'ask');
  end if;
  if coalesce(p_payload->>'source','ranked') = 'ranked' and p_visibility is distinct from v_player.ranking_visibility then
    raise exception 'Publication setting changed' using errcode = 'IC001';
  end if;
  if p_payload->>'source' = 'assignment' then
    v_result := public.submit_assignment_session_v2(v_event,(p_payload->>'assignmentId')::uuid,
      p_payload->>'mode',(p_payload->>'score')::integer,(p_payload->>'totalAnswers')::integer,
      (p_payload->>'correctAnswers')::integer,(p_payload->>'maxCombo')::integer,
      (p_payload->>'avgResponse')::double precision,coalesce(p_payload->'intervalStats','{}'::jsonb),
      (p_payload->>'playedAt')::timestamptz);
  else
    select to_jsonb(r) into v_result from public.submit_play_session(v_event,
      coalesce(p_payload->>'source','ranked'),p_payload->>'mode',(p_payload->>'score')::integer,
      (p_payload->>'totalAnswers')::integer,(p_payload->>'correctAnswers')::integer,
      (p_payload->>'maxCombo')::integer,(p_payload->>'avgResponse')::double precision,
      coalesce(p_payload->'intervalStats','{}'::jsonb),(p_payload->>'playedAt')::timestamptz,null) r;
  end if;
  return v_result;
end;
$$;
revoke all on function public.submit_saved_play(uuid,text,jsonb) from public, anon;
grant execute on function public.submit_saved_play(uuid,text,jsonb) to authenticated;
commit;
