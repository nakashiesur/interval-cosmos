begin;

-- Internal ledger; one durable milestone per player, JST month and mode.
create schema if not exists ic_progress_private;
revoke all on schema ic_progress_private from public, anon, authenticated;
create table ic_progress_private.monthly_firsts (
  player_id uuid not null references public.players(id) on delete cascade,
  period text not null,
  mode text not null,
  achieved_at timestamptz not null default now(),
  primary key (player_id, period, mode)
);
alter table ic_progress_private.monthly_firsts enable row level security;
revoke all on ic_progress_private.monthly_firsts from public, anon, authenticated;

create function ic_progress_private.record_monthly_first()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.public_score is null or new.period <> to_char(timezone('Asia/Tokyo',now()),'YYYY-MM') then return new; end if;
  if tg_op='UPDATE' then
    if new.public_score is not distinct from old.public_score
        and new.public_session_id is not distinct from old.public_session_id then return new; end if;
  end if;
  -- Serialize competing publications in the same month/mode. Read the standings
  -- after taking the lock, without locking any competitor's ranking row.
  perform pg_advisory_xact_lock(hashtext('ic-monthly-first:'||new.period),hashtext(new.mode));
  if exists(select 1 from public.public_profiles p join public.players u on u.id=p.player_id
      where p.player_id=new.player_id and not u.is_suspended)
     and not exists(select 1 from public.ranking_bests b
       join public.public_profiles p on p.player_id=b.player_id
       join public.players u on u.id=b.player_id
       where b.mode=new.mode and b.period=new.period and b.public_score>new.public_score and not u.is_suspended)
  then
    insert into ic_progress_private.monthly_firsts(player_id,period,mode)
      values(new.player_id,new.period,new.mode) on conflict do nothing;
  end if;
  return new;
end; $$;
revoke all on function ic_progress_private.record_monthly_first() from public, anon, authenticated;
create trigger ic_record_monthly_first after insert or update of public_score,public_session_id
  on public.ranking_bests for each row execute function ic_progress_private.record_monthly_first();

-- Synced answer events are deduplicated by the existing (player_id,event_id) key.
-- Do not add the old per-device cumulative snapshots to these counts.
create function ic_progress_private.interval_mastery(p_player uuid,p_seen integer,p_accuracy integer)
returns boolean language sql stable set search_path='' as $$
  select count(*)=13 from (
    select interval_key from public.learning_answers
    where player_id=p_player
    group by interval_key
    having count(*)>=p_seen
       and count(*) filter (where interval_key=chosen_key)::numeric*100>=count(*)::numeric*p_accuracy
  ) qualifying;
$$;
revoke all on function ic_progress_private.interval_mastery(uuid,integer,integer) from public, anon, authenticated;

update public.frame_catalog
set unlock_rule=(unlock_rule || '{"mastery_seen":20,"mastery_accuracy":75}'::jsonb)
  || jsonb_build_object('ids',(unlock_rule->'ids') - 'interval_90')
where id='supernova';
update public.frame_catalog
set unlock_rule=unlock_rule || '{"mastery_seen":30,"mastery_accuracy":80,"monthly_firsts":2}'::jsonb
where id='pulsar';
update public.frame_catalog
set unlock_rule=unlock_rule || '{"requires_frame":"event_horizon","mastery_seen":50,"mastery_accuracy":90}'::jsonb
where id='omega';

-- The existing evaluator still checks PT, achievements, and predecessor order.
-- Guard new frame inserts on every award path without rewriting the evaluator
-- or revoking existing ownership.
create function ic_progress_private.guard_frame_award()
returns trigger language plpgsql security definer set search_path='' as $$
declare rule jsonb;
begin
  if new.frame_id not in ('supernova','pulsar','omega') then return new; end if;
  select unlock_rule into strict rule from public.frame_catalog where id=new.frame_id;
  if not ic_progress_private.interval_mastery(new.player_id,
       (rule->>'mastery_seen')::integer,(rule->>'mastery_accuracy')::integer) then return null; end if;
  if rule?'monthly_firsts' and (select count(*) from ic_progress_private.monthly_firsts
       where player_id=new.player_id)<(rule->>'monthly_firsts')::integer then return null; end if;
  return new;
end; $$;
revoke all on function ic_progress_private.guard_frame_award() from public, anon, authenticated;
create trigger ic_guard_frame_award before insert on public.player_frames
  for each row execute function ic_progress_private.guard_frame_award();

create function public.get_admin_recent_plays(p_days integer default 7,p_course text default null)
returns table(player_id uuid,player_name text,course_name text,mode text,source text,
  played_at timestamptz,score integer,total_answers integer,correct_answers integer)
language plpgsql stable security definer set search_path='' as $$
begin
  if not coalesce(public.is_current_admin(),false) then
    raise exception 'Admin account required' using errcode='42501';
  end if;
  return query
    select p.id,p.player_name,c.display_name,s.mode,s.source,s.played_at,s.score,s.total_answers,s.correct_answers
    from public.play_sessions s
    join public.players p on p.id=s.player_id
    left join public.courses c on c.code=p.course_code
    where p.account_type='student' and not p.is_suspended
      and s.played_at>=now()-make_interval(days=>case when p_days=30 then 30 else 7 end)
      and (p_course is null or p.course_code=p_course)
    order by s.played_at desc,s.id desc limit 50;
end; $$;
revoke all on function public.get_admin_recent_plays(integer,text) from public, anon, authenticated;
grant execute on function public.get_admin_recent_plays(integer,text) to authenticated;

commit;
