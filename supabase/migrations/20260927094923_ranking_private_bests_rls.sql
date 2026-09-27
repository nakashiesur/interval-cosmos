-- ranking_bests mixes private personal bests with a public snapshot.
-- Public callers must use get_public_rankings/get_public_profile_card,
-- which explicitly project public_* columns. Never expose the mixed row.
drop policy if exists "Public or own ranking bests readable" on public.ranking_bests;
drop policy if exists "Own ranking bests readable" on public.ranking_bests;
create policy "Own ranking bests readable"
  on public.ranking_bests for select to authenticated
  using (player_id = (select public.current_player_id()) or (select public.is_current_admin()));
