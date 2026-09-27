-- New answers only. Never import cumulative mastery-v1 snapshots.
begin;
create table public.learning_answers (
  player_id uuid not null references public.players(id) on delete cascade,
  event_id uuid not null,
  interval_key text not null check (interval_key in ('P1','m2','M2','m3','M3','P4','TT','P5','m6','M6','m7','M7','P8')),
  chosen_key text not null check (chosen_key in ('P1','m2','M2','m3','M3','P4','TT','P5','m6','M6','m7','M7','P8')),
  response_ms integer not null check (response_ms between 0 and 86400000),
  answered_at timestamptz not null,
  received_at timestamptz not null default now(),
  primary key (player_id,event_id)
);
alter table public.learning_answers enable row level security;
revoke all on public.learning_answers from public, anon, authenticated;
grant select, insert on public.learning_answers to authenticated;
grant all on public.learning_answers to service_role;
create policy learning_answers_read on public.learning_answers for select to authenticated
  using (player_id = (select public.current_player_id()));
create policy learning_answers_insert on public.learning_answers for insert to authenticated
  with check (player_id = (select public.current_player_id()) and exists (
    select 1 from public.players p where p.id=player_id and not p.is_suspended
  ));

create function public.submit_learning_answers(p_player_id uuid, p_events jsonb)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or p_player_id is distinct from public.current_player_id() then
    raise exception 'Account mismatch' using errcode='42501';
  end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and not p.is_suspended) then
    raise exception 'Account unavailable' using errcode='42501';
  end if;
  if jsonb_typeof(p_events) is distinct from 'array' or jsonb_array_length(p_events)>100 then
    raise exception 'Expected at most 100 answer events' using errcode='22023';
  end if;
  insert into public.learning_answers(player_id,event_id,interval_key,chosen_key,response_ms,answered_at)
  select p_player_id, e.event_id,e.interval_key,e.chosen_key,e.response_ms,e.answered_at
  from jsonb_to_recordset(p_events) as e(event_id uuid,interval_key text,chosen_key text,response_ms integer,answered_at timestamptz)
  on conflict (player_id,event_id) do nothing;
end;
$$;
create function public.get_my_learning_analysis()
returns table(interval_key text,chosen_key text,answers bigint,response_ms bigint)
language sql stable security invoker set search_path = '' as $$
  select a.interval_key,a.chosen_key,count(*),sum(a.response_ms)::bigint
  from public.learning_answers a
  where a.player_id=(select public.current_player_id())
  group by a.interval_key,a.chosen_key;
$$;
revoke all on function public.submit_learning_answers(uuid,jsonb) from public,anon;
revoke all on function public.get_my_learning_analysis() from public,anon;
grant execute on function public.submit_learning_answers(uuid,jsonb) to authenticated;
grant execute on function public.get_my_learning_analysis() to authenticated;
commit;
