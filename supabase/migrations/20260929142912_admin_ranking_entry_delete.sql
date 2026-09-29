begin;
create table public.ranking_removal_cutoffs (
 player_id uuid not null references public.players(id) on delete cascade,
 mode text not null,
 period text not null,
 removed_at timestamptz not null,
 primary key(player_id,mode,period)
);
alter table public.ranking_removal_cutoffs enable row level security;
revoke all on public.ranking_removal_cutoffs from public,anon,authenticated;
create function public.guard_removed_ranking_entry() returns trigger
language plpgsql security definer set search_path='' as $$
declare cutoff timestamptz;
begin
 perform 1 from public.players where id=new.player_id for update;
 select removed_at into cutoff from public.ranking_removal_cutoffs where player_id=new.player_id and mode=new.mode and period=new.period;
 if cutoff is not null and exists(select 1 from public.play_sessions where id in(new.best_session_id,new.public_session_id) and played_at<=cutoff) then
  return null;
 end if;
 return new;
end; $$;
revoke all on function public.guard_removed_ranking_entry() from public,anon,authenticated;
create trigger guard_removed_ranking_entry before insert or update on public.ranking_bests for each row execute function public.guard_removed_ranking_entry();
create function public.admin_delete_ranking_entry(p_player_id uuid,p_mode text,p_period text,p_expected_score integer,p_expected_updated_at timestamptz,p_confirmation text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.ranking_bests%rowtype;
begin
 if not public.is_current_admin() then raise exception 'Admin account required'; end if;
 if p_confirmation is distinct from 'Delete' then raise exception 'Type Delete to confirm'; end if;
 perform 1 from public.players where id=p_player_id for update;
 select * into r from public.ranking_bests where player_id=p_player_id and mode=p_mode and period=p_period for update;
 if not found or r.public_score is null then raise exception 'Ranking entry no longer exists'; end if;
 if r.public_score is distinct from p_expected_score or r.public_updated_at is distinct from p_expected_updated_at then raise exception 'Ranking changed. Reopen the ranking and try again.'; end if;
 insert into public.ranking_removal_cutoffs values(p_player_id,p_mode,p_period,clock_timestamp())
 on conflict(player_id,mode,period) do update set removed_at=excluded.removed_at;
 delete from public.ranking_bests where player_id=p_player_id and mode=p_mode and period=p_period;
 return jsonb_build_object('ok',true);
end; $$;
revoke all on function public.admin_delete_ranking_entry(uuid,text,text,integer,timestamptz,text) from public,anon;
grant execute on function public.admin_delete_ranking_entry(uuid,text,text,integer,timestamptz,text) to authenticated;
commit;
