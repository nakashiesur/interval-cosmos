    'player_name', v_profile.player_name,
    'account_type', v_profile.account_type,
    'course_code', v_profile.course_code,
    'avatar_id', v_profile.avatar_id,
    'main_title_id', v_profile.main_title_id,
    'equipped_frame_id', v_profile.equipped_frame_id,
    'achievement_points', v_profile.achievement_points,
    'featured_achievements', v_achievements,
    'records', v_records,
    'updated_at', v_profile.updated_at
  );
end;
$$;

-- =========================================================
-- 9. RLS
-- =========================================================

alter table public.courses enable row level security;
alter table public.avatar_catalog enable row level security;
alter table public.title_catalog enable row level security;
alter table public.frame_catalog enable row level security;
alter table public.achievement_catalog enable row level security;
alter table public.daily_mission_catalog enable row level security;
alter table public.players enable row level security;
alter table public.player_devices enable row level security;
alter table public.public_profiles enable row level security;
alter table public.device_link_requests enable row level security;
alter table public.assignments enable row level security;
alter table public.play_sessions enable row level security;
alter table public.ranking_bests enable row level security;
alter table public.assignment_bests enable row level security;
alter table public.player_achievements enable row level security;
alter table public.player_titles enable row level security;
alter table public.player_frames enable row level security;
alter table public.player_daily_mission_progress enable row level security;

create policy "Catalog courses readable"
  on public.courses for select to authenticated using (true);
create policy "Catalog avatars readable"
  on public.avatar_catalog for select to authenticated using (is_active);
create policy "Catalog titles readable"
  on public.title_catalog for select to authenticated using (is_active and not hidden);
create policy "Catalog frames readable"
  on public.frame_catalog for select to authenticated using (is_active and not hidden);
create policy "Catalog achievements readable"
  on public.achievement_catalog for select to authenticated using (is_active and not hidden);
create policy "Catalog daily missions readable"
  on public.daily_mission_catalog for select to authenticated using (is_active);

create policy "Players can read own private account"
  on public.players for select to authenticated
  using (id = public.current_player_id());

create policy "Players can read own device links"
  on public.player_devices for select to authenticated
  using (player_id = public.current_player_id());

create policy "Public profiles readable"
  on public.public_profiles for select to authenticated
  using (true);

-- Device-link requests are deliberately not directly readable/writable from the browser.
-- They will be accessed via dedicated server/RPC flow in Phase 2.

create policy "Published assignments readable"
  on public.assignments for select to authenticated
  using (is_published or public.is_current_admin());

create policy "Players can read own play history"
  on public.play_sessions for select to authenticated
  using (player_id = public.current_player_id() or public.is_current_admin());

create policy "Public or own ranking bests readable"
  on public.ranking_bests for select to authenticated
  using (
    public_score is not null
    or player_id = public.current_player_id()
    or public.is_current_admin()
  );

create policy "Players can read own assignment bests"
  on public.assignment_bests for select to authenticated
  using (player_id = public.current_player_id() or public.is_current_admin());

create policy "Players can read own achievements"
  on public.player_achievements for select to authenticated
  using (player_id = public.current_player_id() or public.is_current_admin());

create policy "Players can read own titles"
  on public.player_titles for select to authenticated
  using (player_id = public.current_player_id() or public.is_current_admin());

create policy "Players can read own frames"
  on public.player_frames for select to authenticated
  using (player_id = public.current_player_id() or public.is_current_admin());

create policy "Players can read own daily progress"
  on public.player_daily_mission_progress for select to authenticated
  using (player_id = public.current_player_id() or public.is_current_admin());

-- =========================================================
-- 10. Grants: deny direct mutation from browser; use reviewed RPCs
-- =========================================================

revoke all on table
  public.courses,
  public.avatar_catalog,
  public.title_catalog,
  public.frame_catalog,
  public.achievement_catalog,
  public.daily_mission_catalog,
  public.players,
  public.player_devices,
  public.public_profiles,
  public.device_link_requests,
  public.assignments,
  public.play_sessions,
  public.ranking_bests,
  public.assignment_bests,
  public.player_achievements,
  public.player_titles,
  public.player_frames,
  public.player_daily_mission_progress
from anon, authenticated;

grant select on public.courses,
                public.avatar_catalog,
                public.title_catalog,
                public.frame_catalog,
                public.achievement_catalog,
                public.daily_mission_catalog,
                public.players,
                public.player_devices,
                public.public_profiles,
                public.assignments,
                public.play_sessions,
                public.ranking_bests,
                public.assignment_bests,
                public.player_achievements,
                public.player_titles,
                public.player_frames,
                public.player_daily_mission_progress
to authenticated;

-- No direct grant for device_link_requests.

revoke execute on function public.normalize_student_number(text) from public, anon, authenticated;
revoke execute on function public.current_player_id() from public, anon;
revoke execute on function public.is_current_admin() from public, anon;
revoke execute on function public.create_player_account(text,text,text,text,text) from public, anon;
revoke execute on function public.get_my_player() from public, anon;
revoke execute on function public.update_my_profile(text,text,text,text,text) from public, anon;
revoke execute on function public.submit_play_session(uuid,text,text,integer,integer,integer,integer,double precision,jsonb,timestamptz,uuid) from public, anon;
revoke execute on function public.publish_play_session(uuid) from public, anon;
revoke execute on function public.hide_all_my_rankings() from public, anon;
revoke execute on function public.get_public_rankings(text,text,integer) from public, anon;
revoke execute on function public.get_public_profile_card(uuid) from public, anon;

grant execute on function public.current_player_id() to authenticated;
grant execute on function public.is_current_admin() to authenticated;
grant execute on function public.create_player_account(text,text,text,text,text) to authenticated;
grant execute on function public.get_my_player() to authenticated;
grant execute on function public.update_my_profile(text,text,text,text,text) to authenticated;
grant execute on function public.submit_play_session(uuid,text,text,integer,integer,integer,integer,double precision,jsonb,timestamptz,uuid) to authenticated;
grant execute on function public.publish_play_session(uuid) to authenticated;
grant execute on function public.hide_all_my_rankings() to authenticated;
grant execute on function public.get_public_rankings(text,text,integer) to authenticated;
grant execute on function public.get_public_profile_card(uuid) to authenticated;

commit;
