-- Ask after every new ranked play, including below-best scores.
-- Practice, assignments, automatic privacy policies and duplicate handling stay unchanged.
begin;
create or replace function public.submit_play_session(
  p_client_event_id uuid,
  p_source text,
  p_mode text,
  p_score integer,
  p_total_answers integer,
  p_correct_answers integer,
  p_max_combo integer,
  p_avg_response double precision,
  p_interval_stats jsonb default '{}'::jsonb,
  p_played_at timestamptz default now(),
  p_assignment_id uuid default null
)
returns table (
  session_id uuid,
  duplicate boolean,
  publication_required boolean,
  monthly_rank bigint,
  hall_rank bigint,
  monthly_best_score integer,
  hall_best_score integer,
  monthly_best_improved boolean,
  hall_best_improved boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player_id uuid := public.current_player_id();
  v_visibility text;
  v_suspended boolean;
  v_session_id uuid;
  v_month text;
  v_is_public boolean := false;
  v_existing_session uuid;
  v_month_old integer;
  v_hall_old integer;
  v_month_best integer;
  v_hall_best integer;
  v_accuracy numeric(5,2);
  v_assignment public.assignments%rowtype;
  v_played_at timestamptz;
begin
  if v_player_id is null then
    raise exception 'Player account required';
  end if;

  select p.ranking_visibility, p.is_suspended
  into v_visibility, v_suspended
  from public.players p
  where p.id = v_player_id;

  if v_suspended then
    raise exception 'Account suspended';
  end if;

  if p_client_event_id is null then
    raise exception 'client_event_id is required';
  end if;
  if p_source not in ('ranked','practice','assignment') then
    raise exception 'Invalid source';
  end if;
  if p_mode not in ('TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK') then
    raise exception 'Invalid mode';
  end if;
  if p_score < 0 or p_score > 500000 then
    raise exception 'Invalid score';
  end if;
  if p_total_answers < 0 or p_correct_answers < 0 or p_correct_answers > p_total_answers then
    raise exception 'Invalid answer counts';
  end if;
  if p_max_combo < 0 or p_avg_response < 0 then
    raise exception 'Invalid performance values';
  end if;

  v_played_at := coalesce(p_played_at, now());
  v_month := to_char(timezone('Asia/Tokyo', v_played_at), 'YYYY-MM');

  if p_source = 'assignment' then
    if p_assignment_id is null then
      raise exception 'Assignment is required';
    end if;
    select * into v_assignment
    from public.assignments a
    where a.id = p_assignment_id and a.is_published;
    if not found then
      raise exception 'Assignment not found';
    end if;
    if v_assignment.mode <> p_mode then
      raise exception 'Assignment mode mismatch';
    end if;
    if v_played_at < v_assignment.start_at or v_played_at > v_assignment.deadline_at then
      raise exception 'Assignment is outside the allowed time window';
    end if;
  elsif p_assignment_id is not null then
    raise exception 'assignment_id is only valid for assignment source';
  end if;

  select ps.id into v_existing_session
  from public.play_sessions ps
  where ps.player_id = v_player_id
    and ps.client_event_id = p_client_event_id;

  if v_existing_session is not null then
    session_id := v_existing_session;
    duplicate := true;
    publication_required := false;
    monthly_best_improved := false;
    hall_best_improved := false;

    if p_source <> 'ranked' then
      monthly_rank := null;
      hall_rank := null;
      monthly_best_score := null;
      hall_best_score := null;
      return next;
      return;
    end if;

    select rb.best_score into v_month_best
    from public.ranking_bests rb
    where rb.player_id = v_player_id and rb.mode = p_mode and rb.period = v_month;

    select rb.best_score into v_hall_best
    from public.ranking_bests rb
    where rb.player_id = v_player_id and rb.mode = p_mode and rb.period = 'ALL';

    monthly_best_score := v_month_best;
    hall_best_score := v_hall_best;

    monthly_rank := case when v_month_best is null then null else
      (select 1 + count(*)
       from public.ranking_bests rb
       where rb.mode = p_mode and rb.period = v_month
         and rb.public_score is not null and rb.public_score > v_month_best)
    end;

    hall_rank := case when v_hall_best is null then null else
      (select 1 + count(*)
       from public.ranking_bests rb
       where rb.mode = p_mode and rb.period = 'ALL'
         and rb.public_score is not null and rb.public_score > v_hall_best)
    end;

    return next;
    return;
  end if;

  -- Ranking publication is decided automatically only for "always_public".
  -- "ask" starts private, then publish_play_session() is called after player confirmation.
  if p_source = 'ranked' and v_visibility = 'always_public' then
    v_is_public := true;
  end if;

  insert into public.play_sessions (
    client_event_id, player_id, source, mode, score,
    total_answers, correct_answers, max_combo, avg_response,
    interval_stats, is_public, assignment_id, played_at
  ) values (
    p_client_event_id, v_player_id, p_source, p_mode, p_score,
    p_total_answers, p_correct_answers, p_max_combo, p_avg_response,
    coalesce(p_interval_stats, '{}'::jsonb), v_is_public, p_assignment_id, v_played_at
  )
  returning id into v_session_id;

  session_id := v_session_id;
  duplicate := false;

  if p_total_answers = 0 then
    v_accuracy := 0;
  else
    v_accuracy := round((p_correct_answers::numeric * 100) / p_total_answers, 2);
  end if;

  if p_source = 'assignment' then
    insert into public.assignment_bests (
      assignment_id, player_id, best_session_id, best_score, best_accuracy,
      attempts, achieved, first_attempt_at, last_attempt_at
    )
    values (
      p_assignment_id, v_player_id, v_session_id, p_score, v_accuracy,
      1,
      ((v_assignment.target_score is null or p_score >= v_assignment.target_score)
       and (v_assignment.target_accuracy is null or v_accuracy >= v_assignment.target_accuracy)),
      v_played_at, v_played_at
    )
    on conflict (assignment_id, player_id) do update
    set attempts = public.assignment_bests.attempts + 1,
        last_attempt_at = greatest(public.assignment_bests.last_attempt_at, excluded.last_attempt_at),
        best_session_id = case
          when excluded.best_score > public.assignment_bests.best_score
          then excluded.best_session_id else public.assignment_bests.best_session_id end,
        best_score = greatest(public.assignment_bests.best_score, excluded.best_score),
        best_accuracy = case
          when excluded.best_score > public.assignment_bests.best_score
          then excluded.best_accuracy else public.assignment_bests.best_accuracy end,
        achieved = public.assignment_bests.achieved or excluded.achieved,
        updated_at = now();

    publication_required := false;
    monthly_rank := null;
    hall_rank := null;
    monthly_best_score := null;
    hall_best_score := null;
    monthly_best_improved := false;
    hall_best_improved := false;
    return next;
    return;
  end if;

  if p_source <> 'ranked' then
    publication_required := false;
    monthly_rank := null;
    hall_rank := null;
    monthly_best_score := null;
    hall_best_score := null;
    monthly_best_improved := false;
    hall_best_improved := false;
    return next;
    return;
  end if;

  select rb.best_score into v_month_old
  from public.ranking_bests rb
  where rb.player_id = v_player_id and rb.mode = p_mode and rb.period = v_month;

  select rb.best_score into v_hall_old
  from public.ranking_bests rb
  where rb.player_id = v_player_id and rb.mode = p_mode and rb.period = 'ALL';

  monthly_best_improved := v_month_old is null or p_score > v_month_old;
  hall_best_improved := v_hall_old is null or p_score > v_hall_old;

  insert into public.ranking_bests (
    player_id, mode, period,
    best_session_id, best_score, best_total_answers, best_correct_answers,
    best_max_combo, best_avg_response, best_updated_at,
    public_session_id, public_score, public_total_answers, public_correct_answers,
    public_max_combo, public_avg_response, public_updated_at
  )
  values (
    v_player_id, p_mode, v_month,
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
    (v_visibility = 'ask');

  return next;
end;
$$;
commit;
