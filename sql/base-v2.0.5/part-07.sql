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

create or replace function public.hide_all_my_rankings()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player_id uuid := public.current_player_id();
begin
  if v_player_id is null then
    raise exception 'Player account required';
  end if;

  update public.play_sessions
  set is_public = false
  where player_id = v_player_id and source = 'ranked' and is_public;

  update public.ranking_bests
  set public_session_id = null,
      public_score = null,
      public_total_answers = null,
      public_correct_answers = null,
      public_max_combo = null,
      public_avg_response = null,
      public_updated_at = null
  where player_id = v_player_id;
end;
$$;

create or replace function public.get_public_rankings(
  p_mode text,
  p_scope text default 'monthly',
  p_limit integer default 50
)
returns table (
  rank bigint,
  player_id uuid,
  player_name text,
  account_type text,
  course_code text,
  avatar_id text,
  main_title_id text,
  equipped_frame_id text,
  achievement_points integer,
  score integer,
  total_answers integer,
  correct_answers integer,
  max_combo integer,
  avg_response double precision,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with params as (
    select
      case
        when p_scope = 'hall' then 'ALL'
        else to_char(timezone('Asia/Tokyo', now()), 'YYYY-MM')
      end as period_value,
      greatest(1, least(coalesce(p_limit, 50), 100)) as row_limit
  ),
  ranked as (
    select
      rank() over (order by rb.public_score desc) as rank,
      rb.player_id,
      pp.player_name,
      pp.account_type,
      pp.course_code,
      pp.avatar_id,
      pp.main_title_id,
      pp.equipped_frame_id,
      pp.achievement_points,
      rb.public_score as score,
      rb.public_total_answers as total_answers,
      rb.public_correct_answers as correct_answers,
      rb.public_max_combo as max_combo,
      rb.public_avg_response as avg_response,
      rb.public_updated_at as updated_at
    from public.ranking_bests rb
    join public.public_profiles pp on pp.player_id = rb.player_id
    cross join params
    where rb.mode = p_mode
      and rb.period = params.period_value
      and rb.public_score is not null
      and exists (
        select 1 from public.players p
        where p.id = rb.player_id and not p.is_suspended
      )
  )
  select r.*
  from ranked r
  cross join params
  order by r.rank
  limit (select row_limit from params);
$$;


create or replace function public.get_public_profile_card(p_player_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.public_profiles%rowtype;
  v_achievements jsonb;
  v_records jsonb;
begin
  if p_player_id is null then
    return null;
  end if;

  select pp.* into v_profile
  from public.public_profiles pp
  join public.players p on p.id = pp.player_id
  where pp.player_id = p_player_id
    and not p.is_suspended;

  if not found then
    return null;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ac.id,
        'name', ac.display_name,
        'description', ac.description,
        'category', ac.category,
        'points', ac.points,
        'unlocked_at', pa.unlocked_at
      )
      order by pa.featured_order
    ),
    '[]'::jsonb
  )
  into v_achievements
  from public.player_achievements pa
  join public.achievement_catalog ac on ac.id = pa.achievement_id
  where pa.player_id = p_player_id
    and pa.featured_order is not null;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'mode', rb.mode,
        'score', rb.public_score,
        'total_answers', rb.public_total_answers,
        'correct_answers', rb.public_correct_answers,
        'accuracy',
          case
            when rb.public_total_answers is null or rb.public_total_answers = 0 then 0
            else round((rb.public_correct_answers::numeric * 100) / rb.public_total_answers, 2)
          end,
        'max_combo', rb.public_max_combo,
        'avg_response', rb.public_avg_response,
        'updated_at', rb.public_updated_at
      )
      order by rb.mode
    ),
    '[]'::jsonb
  )
  into v_records
  from public.ranking_bests rb
  where rb.player_id = p_player_id
    and rb.period = 'ALL'
    and rb.public_score is not null;

  return jsonb_build_object(
    'player_id', v_profile.player_id,
