-- INTERVAL COSMOS v2.0.5 — fresh-build structural verification
-- Run AFTER the complete v2.0.5 SQL chain on an EMPTY test Supabase project.
-- Any failed invariant raises an exception; success ends with one PASS row.

begin;

do $$
declare
  v_count integer;
  v_missing text;
  v_default text;
  v_args text;
  v_def text;
begin
  select count(*) into v_count
  from information_schema.tables
  where table_schema = 'public'
    and table_name = any(array[
      'courses','avatar_catalog','title_catalog','frame_catalog','achievement_catalog',
      'daily_mission_catalog','players','player_devices','public_profiles',
      'device_link_requests','assignments','play_sessions','ranking_bests',
      'assignment_bests','player_achievements','player_titles','player_frames',
      'player_daily_mission_progress','player_recovery_credentials','assignment_mode_bests'
    ]);
  if v_count <> 20 then
    raise exception 'Expected 20 current application tables, found %', v_count;
  end if;

  if exists (
    select 1 from information_schema.tables
    where table_schema='public' and table_name in ('profiles','rankings')
  ) then
    raise exception 'Legacy v2.0.4 profiles/rankings tables still exist';
  end if;

  select count(*) into v_count from public.courses;
  if v_count <> 11 then
    raise exception 'Expected 11 courses, found %', v_count;
  end if;

  select count(*) into v_count
  from public.avatar_catalog
  where is_active
    and id = any(array['nova','orbit','pulse','prism','comet','nebula','vector','echo','quasar','lumen','wave','aster','teacher']);
  if v_count <> 13 then
    raise exception 'Expected 13 active v2.0.5 avatars, found %', v_count;
  end if;

  if not exists (
    select 1 from public.avatar_catalog
    where id='teacher' and staff_only and is_active
  ) then
    raise exception 'Teacher avatar is not active/staff-only';
  end if;

  if exists (
    select 1 from public.avatar_catalog
    where id='default' and is_active
  ) then
    raise exception 'Legacy default avatar should be inactive';
  end if;

  select column_default into v_default
  from information_schema.columns
  where table_schema='public' and table_name='players' and column_name='avatar_id';
  if coalesce(v_default,'') not like '%nova%' then
    raise exception 'players.avatar_id default is not nova: %', v_default;
  end if;

  select pg_get_function_arguments('public.create_player_account(text,text,text,text,text,text)'::regprocedure),
         pg_get_functiondef('public.create_player_account(text,text,text,text,text,text)'::regprocedure)
    into v_args, v_def;
  if coalesce(v_args,'') not like '%DEFAULT ''nova''%' then
    raise exception 'create_player_account avatar argument does not default to nova: %', v_args;
  end if;
  if coalesce(v_def,'') not like '%coalesce(nullif(p_avatar_id,''''), ''nova'')%' then
    raise exception 'create_player_account empty avatar fallback is not nova';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='assignments' and column_name='allowed_modes'
  ) then
    raise exception 'assignments.allowed_modes is missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='players' and column_name='real_name'
  ) then
    raise exception 'players.real_name is missing';
  end if;

  select string_agg(c.relname, ', ' order by c.relname) into v_missing
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind='r'
    and c.relname = any(array[
      'courses','avatar_catalog','title_catalog','frame_catalog','achievement_catalog',
      'daily_mission_catalog','players','player_devices','public_profiles',
      'device_link_requests','assignments','play_sessions','ranking_bests',
      'assignment_bests','player_achievements','player_titles','player_frames',
      'player_daily_mission_progress','player_recovery_credentials','assignment_mode_bests'
    ])
    and not c.relrowsecurity;
  if v_missing is not null then
    raise exception 'RLS disabled on: %', v_missing;
  end if;

  select string_agg(req.name, ', ' order by req.name) into v_missing
  from unnest(array[
    'current_player_id','is_current_admin','create_player_account','get_my_player','update_my_profile',
    'submit_play_session','publish_play_session','get_public_rankings','get_public_profile_card',
    'create_device_link_request','claim_device_link_request','confirm_device_link_request',
    'get_device_link_source_status','get_device_link_target_status','cancel_device_link_request',
    'set_my_recovery_code','get_my_recovery_status','recover_student_account',
    'evaluate_my_progress','get_my_cosmos_progress','toggle_featured_achievement',
    'create_assignment_v2','get_my_assignments','get_my_assignment_status','submit_assignment_session_v2','get_assignment_results',
    'normalize_assignment_modes','get_admin_dashboard_overview','get_admin_student_dashboard',
    'create_staff_account','get_my_private_identity',
    'admin_get_player_management','admin_update_player_profile','admin_set_player_suspended',
    'admin_unpublish_player_rankings','admin_delete_player_rankings','admin_delete_player_application_row'
  ]) as req(name)
  where not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=req.name
  );
  if v_missing is not null then
    raise exception 'Missing required current functions: %', v_missing;
  end if;

  if has_function_privilege('authenticated', 'public.admin_delete_player_application_row(uuid)', 'EXECUTE') then
    raise exception 'authenticated must not execute admin_delete_player_application_row';
  end if;
  if not has_function_privilege('service_role', 'public.admin_delete_player_application_row(uuid)', 'EXECUTE') then
    raise exception 'service_role must be able to execute admin_delete_player_application_row';
  end if;

  if has_function_privilege('anon','public.sync_public_profile()','EXECUTE')
     or has_function_privilege('authenticated','public.sync_public_profile()','EXECUTE') then
    raise exception 'internal sync_public_profile trigger function is exposed';
  end if;
  if has_function_privilege('anon','public.rls_auto_enable()','EXECUTE')
     or has_function_privilege('authenticated','public.rls_auto_enable()','EXECUTE') then
    raise exception 'internal rls_auto_enable event-trigger function is exposed';
  end if;
end;
$$;

select
  'PASS' as fresh_build_structure,
  (select count(*) from public.courses) as courses,
  (select count(*) from public.avatar_catalog where is_active) as active_avatars,
  (select count(*) from information_schema.tables where table_schema='public' and table_name in ('profiles','rankings')) as legacy_tables;

rollback;
