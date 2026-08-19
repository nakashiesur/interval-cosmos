        when excluded.best_score > public.ranking_bests.best_score
        then excluded.best_max_combo else public.ranking_bests.best_max_combo end,
      best_avg_response = case
        when excluded.best_score > public.ranking_bests.best_score
        then excluded.best_avg_response else public.ranking_bests.best_avg_response end,
      best_updated_at = case
        when excluded.best_score > public.ranking_bests.best_score
        then excluded.best_updated_at else public.ranking_bests.best_updated_at end,
      public_session_id = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_session_id else public.ranking_bests.public_session_id end,
      public_score = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_score else public.ranking_bests.public_score end,
      public_total_answers = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_total_answers else public.ranking_bests.public_total_answers end,
      public_correct_answers = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_correct_answers else public.ranking_bests.public_correct_answers end,
      public_max_combo = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_max_combo else public.ranking_bests.public_max_combo end,
      public_avg_response = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_avg_response else public.ranking_bests.public_avg_response end,
      public_updated_at = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_updated_at else public.ranking_bests.public_updated_at end;

  -- ALL-time row
  insert into public.ranking_bests (
    player_id, mode, period,
    best_session_id, best_score, best_total_answers, best_correct_answers,
    best_max_combo, best_avg_response, best_updated_at,
    public_session_id, public_score, public_total_answers, public_correct_answers,
    public_max_combo, public_avg_response, public_updated_at
  )
  values (
    v_player_id, p_mode, 'ALL',
    v_session_id, p_score, p_total_answers, p_correct_answers,
    p_max_combo, p_avg_response, now(),
    case when v_is_public then v_session_id else null end,
    case when v_is_public then p_score else null end,
    case when v_is_public then p_total_answers else null end,
    case when v_is_public then p_correct_answers else null end,
    case when v_is_public then p_max_combo else null end,
    case when v_is_public then p_avg_response else null end,
    case when v_is_public then now() else null end
  )
  on conflict (player_id, mode, period) do update
  set best_session_id = case
        when excluded.best_score > public.ranking_bests.best_score
        then excluded.best_session_id else public.ranking_bests.best_session_id end,
      best_score = greatest(public.ranking_bests.best_score, excluded.best_score),
      best_total_answers = case
        when excluded.best_score > public.ranking_bests.best_score
        then excluded.best_total_answers else public.ranking_bests.best_total_answers end,
      best_correct_answers = case
        when excluded.best_score > public.ranking_bests.best_score
        then excluded.best_correct_answers else public.ranking_bests.best_correct_answers end,
      best_max_combo = case
        when excluded.best_score > public.ranking_bests.best_score
        then excluded.best_max_combo else public.ranking_bests.best_max_combo end,
      best_avg_response = case
        when excluded.best_score > public.ranking_bests.best_score
        then excluded.best_avg_response else public.ranking_bests.best_avg_response end,
      best_updated_at = case
        when excluded.best_score > public.ranking_bests.best_score
        then excluded.best_updated_at else public.ranking_bests.best_updated_at end,
      public_session_id = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_session_id else public.ranking_bests.public_session_id end,
      public_score = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_score else public.ranking_bests.public_score end,
      public_total_answers = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_total_answers else public.ranking_bests.public_total_answers end,
      public_correct_answers = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_correct_answers else public.ranking_bests.public_correct_answers end,
      public_max_combo = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_max_combo else public.ranking_bests.public_max_combo end,
      public_avg_response = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_avg_response else public.ranking_bests.public_avg_response end,
      public_updated_at = case
        when excluded.public_score is not null
         and (public.ranking_bests.public_score is null or excluded.public_score > public.ranking_bests.public_score)
        then excluded.public_updated_at else public.ranking_bests.public_updated_at end;

  select rb.best_score into v_month_best
  from public.ranking_bests rb
  where rb.player_id = v_player_id and rb.mode = p_mode and rb.period = v_month;

  select rb.best_score into v_hall_best
  from public.ranking_bests rb
  where rb.player_id = v_player_id and rb.mode = p_mode and rb.period = 'ALL';

  monthly_best_score := v_month_best;
  hall_best_score := v_hall_best;

  monthly_rank := (
    select 1 + count(*)
    from public.ranking_bests rb
    where rb.mode = p_mode and rb.period = v_month
      and rb.public_score is not null
      and rb.public_score > v_month_best
  );

  hall_rank := (
    select 1 + count(*)
    from public.ranking_bests rb
    where rb.mode = p_mode and rb.period = 'ALL'
      and rb.public_score is not null
      and rb.public_score > v_hall_best
  );

  publication_required :=
    (v_visibility = 'ask')
    and (monthly_best_improved or hall_best_improved);

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
