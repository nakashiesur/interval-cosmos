-- INTERVAL COSMOS ver.2.0.5
-- Phase 1 / fresh database build for pre-release testing.
-- IMPORTANT:
--   * This script intentionally drops the v2.0.4 application tables.
--   * Run only because v2.0.5 is still pre-release and no student production data exists.
--   * auth.users is NOT dropped here. Test Auth users can be cleaned separately after verification.

begin;

create extension if not exists pgcrypto;

-- =========================================================
-- 0. Clean v2.0.4 application objects
-- =========================================================

drop function if exists public.get_public_profile_card(uuid) cascade;
drop function if exists public.get_public_rankings(text,text,integer) cascade;
drop function if exists public.hide_all_my_rankings() cascade;
drop function if exists public.publish_play_session(uuid) cascade;
drop function if exists public.submit_play_session(uuid,text,text,integer,integer,integer,integer,double precision,jsonb,timestamptz,uuid) cascade;
drop function if exists public.update_my_profile(text,text,text,text,text) cascade;
drop function if exists public.get_my_player() cascade;
drop function if exists public.create_player_account(text,text,text,text,text) cascade;
drop function if exists public.sync_public_profile() cascade;
drop function if exists public.normalize_player_fields() cascade;
drop function if exists public.touch_updated_at() cascade;
drop function if exists public.is_current_admin() cascade;
drop function if exists public.current_player_id() cascade;
drop function if exists public.normalize_student_number(text) cascade;

drop function if exists public.submit_interval_cosmos_score(text,integer,integer,integer,integer,double precision) cascade;
drop function if exists public.sync_interval_cosmos_profile() cascade;

drop table if exists public.player_daily_mission_progress cascade;
drop table if exists public.daily_mission_catalog cascade;
drop table if exists public.assignment_bests cascade;
drop table if exists public.assignments cascade;
drop table if exists public.player_frames cascade;
drop table if exists public.frame_catalog cascade;
drop table if exists public.player_titles cascade;
drop table if exists public.title_catalog cascade;
drop table if exists public.player_achievements cascade;
drop table if exists public.achievement_catalog cascade;
drop table if exists public.ranking_bests cascade;
drop table if exists public.play_sessions cascade;
drop table if exists public.device_link_requests cascade;
drop table if exists public.public_profiles cascade;
drop table if exists public.player_devices cascade;
drop table if exists public.players cascade;
drop table if exists public.avatar_catalog cascade;
drop table if exists public.courses cascade;

-- v2.0.4 names
drop table if exists public.rankings cascade;
drop table if exists public.profiles cascade;

-- =========================================================
-- 1. Catalogs
-- =========================================================

create table public.courses (
  code text primary key,
  department_code text not null check (department_code in ('music', 'future_creation')),
  display_name text not null unique,
  sort_order integer not null check (sort_order > 0)
);

insert into public.courses (code, department_code, display_name, sort_order) values
  ('piano',             'music',           'ピアノコース',                 10),
  ('orchestral',        'music',           '管弦打楽コース',               20),
  ('vocal_musical',     'music',           '声楽・ミュージカルコース',      30),
  ('composition',       'music',           '作曲コース',                   40),
  ('rock_pops',         'music',           'ロック＆ポップスコース',        50),
  ('electronic_organ',  'music',           '電子オルガンコース',            60),
  ('sound_design',      'music',           'サウンドデザインコース',        70),
  ('music_education',   'music',           '音楽教育コース',               80),
  ('music_therapy',     'music',           '音楽療法コース',               90),
  ('child_culture',     'future_creation', 'こども文化コース',             100),
  ('voice_actor',       'future_creation', '声優コース',                   110);

create table public.avatar_catalog (
  id text primary key,
  display_name text not null,
  asset_path text,
  staff_only boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0
);

-- Placeholder IDs. Original visual assets are added later.
insert into public.avatar_catalog (id, display_name, asset_path, staff_only, sort_order) values
  ('default', 'COSMOS DEFAULT', null, false, 0),
  ('teacher', 'TEACHER',        null, true,  1);

create table public.title_catalog (
  id text primary key,
  display_name text not null,
  description text not null default '',
  hidden boolean not null default false,
  unlock_rule jsonb not null default '{}'::jsonb,
  sort_order integer not null default 0,
  is_active boolean not null default true
);

create table public.frame_catalog (
  id text primary key,
  display_name text not null,
  tier integer not null check (tier >= 0),
  points_required integer not null default 0 check (points_required >= 0),
  animated boolean not null default false,
  hidden boolean not null default false,
  unlock_rule jsonb not null default '{}'::jsonb,
  sort_order integer not null default 0,
  is_active boolean not null default true
);

insert into public.frame_catalog
  (id, display_name, tier, points_required, animated, hidden, unlock_rule, sort_order)
values
  ('normal',   'NORMAL',   0,    0, false, false, '{}'::jsonb, 0),
  ('bronze',   'BRONZE',   1,  100, false, false, '{"type":"points"}'::jsonb, 10),
  ('silver',   'SILVER',   2,  300, false, false, '{"type":"points"}'::jsonb, 20),
  ('gold',     'GOLD',     3,  700, false, false, '{"type":"points"}'::jsonb, 30),
  ('platinum', 'PLATINUM', 4, 1200, false, false, '{"type":"points"}'::jsonb, 40),
  ('cosmic',   'COSMIC',   5, 2000, true,  false, '{"type":"points"}'::jsonb, 50);

create table public.achievement_catalog (
  id text primary key,
  display_name text not null,
  description text not null default '',
  category text not null check (
    category in ('basic','accuracy','combo','interval','mode','streak','improvement','assignment','ranking','hidden')
  ),
  points integer not null default 0 check (points >= 0),
  hidden boolean not null default false,
  requirement jsonb not null default '{}'::jsonb,
  reward_title_id text references public.title_catalog(id) on delete set null,
  reward_frame_id text references public.frame_catalog(id) on delete set null,
  sort_order integer not null default 0,
  is_active boolean not null default true
);

create table public.daily_mission_catalog (
  id text primary key,
  display_name text not null,
  description text not null default '',
  mission_type text not null,
  target_value integer not null default 1 check (target_value > 0),
  config jsonb not null default '{}'::jsonb,
  reward_points integer not null default 0 check (reward_points >= 0),
  is_active boolean not null default true
);

-- =========================================================
-- 2. Player identity
-- =========================================================

create table public.players (
  id uuid primary key default gen_random_uuid(),
  account_type text not null check (account_type in ('student','staff')),
  student_number text,
  player_name text not null check (char_length(btrim(player_name)) between 2 and 16),
  course_code text references public.courses(code) on update cascade on delete restrict,
  avatar_id text not null default 'default' references public.avatar_catalog(id) on update cascade on delete restrict,
  ranking_visibility text not null default 'ask'
    check (ranking_visibility in ('ask','always_public','always_private')),
  main_title_id text references public.title_catalog(id) on update cascade on delete set null,
  equipped_frame_id text not null default 'normal'
    references public.frame_catalog(id) on update cascade on delete restrict,
  achievement_points integer not null default 0 check (achievement_points >= 0),
  is_suspended boolean not null default false,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (account_type = 'student'
      and student_number is not null
      and student_number ~ '^[0-9]{3,20}$'
      and course_code is not null
      and avatar_id <> 'teacher')
    or
    (account_type = 'staff'
      and student_number is null
      and course_code is null
      and avatar_id = 'teacher')
  )
);

create unique index players_student_number_unique_idx
  on public.players (student_number)
  where account_type = 'student';

create index players_course_idx on public.players(course_code);
create index players_account_type_idx on public.players(account_type);

create table public.player_devices (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  device_label text,
  linked_at timestamptz not null default now(),
