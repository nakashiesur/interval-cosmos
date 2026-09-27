  last_seen_at timestamptz not null default now()
);

create index player_devices_player_idx on public.player_devices(player_id);

-- Public-only mirror. This prevents student_number / admin flags / device IDs
-- from being exposed when rankings/profile cards are read.
create table public.public_profiles (
  player_id uuid primary key references public.players(id) on delete cascade,
  account_type text not null check (account_type in ('student','staff')),
  player_name text not null,
  course_code text references public.courses(code) on update cascade on delete set null,
  avatar_id text not null references public.avatar_catalog(id) on update cascade on delete restrict,
  main_title_id text references public.title_catalog(id) on update cascade on delete set null,
  equipped_frame_id text not null references public.frame_catalog(id) on update cascade on delete restrict,
  achievement_points integer not null default 0,
  updated_at timestamptz not null default now()
);

-- =========================================================
-- 3. Device linking
-- =========================================================

create table public.device_link_requests (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  source_auth_user_id uuid not null references auth.users(id) on delete cascade,
  target_auth_user_id uuid references auth.users(id) on delete cascade,
  pin_hash text not null,
  status text not null default 'pending'
    check (status in ('pending','awaiting_confirmation','confirmed','used','cancelled','expired')),
  expires_at timestamptz not null,
  confirmed_at timestamptz,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index device_link_requests_player_idx on public.device_link_requests(player_id);
create index device_link_requests_expiry_idx on public.device_link_requests(expires_at);

-- =========================================================
-- 4. Play history / offline-safe event log
-- =========================================================

create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 80),
  description text not null default '',
  mode text not null check (mode in ('TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK')),
  interval_keys text[] not null default '{}',
  rule_config jsonb not null default '{}'::jsonb,
  start_at timestamptz not null,
  deadline_at timestamptz not null,
  target_score integer check (target_score is null or target_score >= 0),
  target_accuracy numeric(5,2) check (target_accuracy is null or (target_accuracy >= 0 and target_accuracy <= 100)),
  is_published boolean not null default false,
  created_by uuid references public.players(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (deadline_at > start_at)
);

create index assignments_deadline_idx on public.assignments(deadline_at);
create index assignments_published_idx on public.assignments(is_published, start_at, deadline_at);

create table public.play_sessions (
  id uuid primary key default gen_random_uuid(),
  client_event_id uuid not null,
  player_id uuid not null references public.players(id) on delete cascade,
  source text not null default 'ranked'
    check (source in ('ranked','practice','assignment')),
  mode text not null check (mode in ('TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK')),
  score integer not null check (score between 0 and 500000),
  total_answers integer not null default 0 check (total_answers >= 0),
  correct_answers integer not null default 0 check (correct_answers >= 0 and correct_answers <= total_answers),
  max_combo integer not null default 0 check (max_combo >= 0),
  avg_response double precision not null default 0 check (avg_response >= 0),
  interval_stats jsonb not null default '{}'::jsonb,
  is_public boolean not null default false,
  assignment_id uuid references public.assignments(id) on delete set null,
  played_at timestamptz not null,
  received_at timestamptz not null default now(),
  unique (player_id, client_event_id),
  check (
    (source = 'assignment' and assignment_id is not null)
    or
    (source <> 'assignment' and assignment_id is null)
  )
);

create index play_sessions_player_time_idx
  on public.play_sessions(player_id, played_at desc);
create index play_sessions_player_mode_idx
  on public.play_sessions(player_id, mode, played_at desc);
create index play_sessions_assignment_idx
  on public.play_sessions(assignment_id, player_id)
  where assignment_id is not null;

-- One best row per mode and period.
-- best_* = player's actual best, regardless of publication.
-- public_* = best session the player explicitly allowed on the leaderboard.
create table public.ranking_bests (
  player_id uuid not null references public.players(id) on delete cascade,
  mode text not null check (mode in ('TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK')),
  period text not null check (period = 'ALL' or period ~ '^[0-9]{4}-[0-9]{2}$'),

  best_session_id uuid not null references public.play_sessions(id) on delete cascade,
  best_score integer not null,
  best_total_answers integer not null,
  best_correct_answers integer not null,
  best_max_combo integer not null,
  best_avg_response double precision not null,
  best_updated_at timestamptz not null default now(),

  public_session_id uuid references public.play_sessions(id) on delete set null,
  public_score integer,
  public_total_answers integer,
  public_correct_answers integer,
  public_max_combo integer,
  public_avg_response double precision,
  public_updated_at timestamptz,

  primary key (player_id, mode, period),
  check (
    (public_session_id is null
      and public_score is null
      and public_total_answers is null
      and public_correct_answers is null
      and public_max_combo is null
      and public_avg_response is null
      and public_updated_at is null)
    or
    (public_session_id is not null
      and public_score is not null
      and public_total_answers is not null
      and public_correct_answers is not null
      and public_max_combo is not null
      and public_avg_response is not null
      and public_updated_at is not null)
  )
);

create index ranking_bests_public_lookup_idx
  on public.ranking_bests(mode, period, public_score desc, public_updated_at asc)
  where public_score is not null;
create index ranking_bests_player_idx on public.ranking_bests(player_id);

create table public.assignment_bests (
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  best_session_id uuid not null references public.play_sessions(id) on delete cascade,
  best_score integer not null,
  best_accuracy numeric(5,2) not null,
  attempts integer not null default 1 check (attempts > 0),
  achieved boolean not null default false,
  first_attempt_at timestamptz not null,
  last_attempt_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (assignment_id, player_id)
);

create index assignment_bests_player_idx on public.assignment_bests(player_id);

-- =========================================================
-- 5. Achievements / titles / frames / daily progress
-- =========================================================

create table public.player_achievements (
  player_id uuid not null references public.players(id) on delete cascade,
  achievement_id text not null references public.achievement_catalog(id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  featured_order smallint check (featured_order is null or featured_order between 1 and 3),
  primary key (player_id, achievement_id)
);

create unique index player_achievements_featured_unique_idx
  on public.player_achievements(player_id, featured_order)
  where featured_order is not null;

create table public.player_titles (
  player_id uuid not null references public.players(id) on delete cascade,
  title_id text not null references public.title_catalog(id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  primary key (player_id, title_id)
);

create table public.player_frames (
  player_id uuid not null references public.players(id) on delete cascade,
  frame_id text not null references public.frame_catalog(id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  primary key (player_id, frame_id)
);

create table public.player_daily_mission_progress (
  player_id uuid not null references public.players(id) on delete cascade,
  mission_date date not null,
  slot smallint not null check (slot between 1 and 3),
  mission_id text not null references public.daily_mission_catalog(id) on delete restrict,
  progress integer not null default 0 check (progress >= 0),
  completed boolean not null default false,
