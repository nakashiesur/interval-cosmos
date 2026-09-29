-- Practice-led progression. Existing awards and completed daily PT are retained.
begin;
alter table public.player_daily_mission_progress add column reward_points_awarded integer check (reward_points_awarded>=0);
update public.player_daily_mission_progress p set reward_points_awarded=d.reward_points from public.daily_mission_catalog d where d.id=p.mission_id and p.completed;
create table public.mode_clear_reward_catalog (
 mode text primary key, reward_points integer not null check(reward_points>0),
 min_answers integer not null check(min_answers>0), min_accuracy integer not null check(min_accuracy between 0 and 100),
 enabled_from timestamptz not null default now()
);
insert into public.mode_clear_reward_catalog(mode,reward_points,min_answers,min_accuracy) values
 ('TEXT',20,10,50),('KEYS',20,10,50),('HD_TEXT',25,10,50),('HD_KEYS',25,10,50),('EAR_LINK',30,5,50);
create table public.player_mode_clear_rewards (
 player_id uuid not null references public.players(id) on delete cascade,
 reward_date date not null, mode text not null references public.mode_clear_reward_catalog(mode),
 reward_points integer not null check(reward_points>0), awarded_at timestamptz not null default now(),
 primary key(player_id,reward_date,mode)
);
alter table public.mode_clear_reward_catalog enable row level security;
alter table public.player_mode_clear_rewards enable row level security;
revoke all on public.mode_clear_reward_catalog,public.player_mode_clear_rewards from public,anon,authenticated;
grant select on public.mode_clear_reward_catalog,public.player_mode_clear_rewards to authenticated;
create policy mode_clear_catalog_read on public.mode_clear_reward_catalog for select to authenticated using(true);
create policy mode_clear_rewards_own on public.player_mode_clear_rewards for select to authenticated using(player_id=(select public.current_player_id()));
-- New completions receive the increased reward; historical completions keep their award.
update public.daily_mission_catalog set reward_points=case when reward_points<=10 then 30 else 40 end;
update public.achievement_catalog set requirement='{"type": "sessions", "count": 10, "min_active_days": 2}'::jsonb,description='累計10回・2日以上プレイする。',display_name='ORBIT STARTER' where id='sessions_5';
update public.achievement_catalog set requirement='{"type": "sessions", "count": 30, "min_active_days": 3}'::jsonb,description='累計30回・3日以上プレイする。',display_name='ORBIT REGULAR' where id='sessions_20';
update public.achievement_catalog set requirement='{"type": "sessions", "count": 75, "min_active_days": 7}'::jsonb,description='累計75回・7日以上プレイする。',display_name='STAR TRACKER' where id='sessions_50';
update public.achievement_catalog set requirement='{"type": "sessions", "count": 150, "min_active_days": 14}'::jsonb,description='累計150回・14日以上プレイする。',display_name='STELLAR VETERAN' where id='sessions_100';
update public.achievement_catalog set requirement='{"type": "perfect_session", "min_answers": 15, "min_sessions": 10, "repeat_count": 2, "min_active_days": 2}'::jsonb,description='1プレイで15問以上・全問正解を2回。累計10プレイ・通算2日以上。',display_name='CLEAN CONTACT' where id='perfect_5';
update public.achievement_catalog set requirement='{"type": "perfect_session", "min_answers": 20, "min_sessions": 25, "repeat_count": 3, "min_active_days": 5}'::jsonb,description='1プレイで20問以上・全問正解を3回。累計25プレイ・通算5日以上。',display_name='CLEAR ORBIT' where id='perfect_10';
update public.achievement_catalog set requirement='{"type": "perfect_session", "min_answers": 30, "min_sessions": 50, "repeat_count": 5, "min_active_days": 7}'::jsonb,description='1プレイで30問以上・全問正解を5回。累計50プレイ・通算7日以上。',display_name='PRECISION PILOT' where id='perfect_20';
update public.achievement_catalog set requirement='{"type": "combo", "value": 10, "min_sessions": 10, "repeat_count": 2, "min_active_days": 2}'::jsonb,description='10コンボ以上を2回。累計10プレイ・通算2日以上。',display_name='COMBO 10' where id='combo_5';
update public.achievement_catalog set requirement='{"type": "combo", "value": 15, "min_sessions": 25, "repeat_count": 3, "min_active_days": 5}'::jsonb,description='15コンボ以上を3回。累計25プレイ・通算5日以上。',display_name='COMBO DRIVER' where id='combo_10';
update public.achievement_catalog set requirement='{"type": "combo", "value": 25, "min_sessions": 50, "repeat_count": 3, "min_active_days": 7}'::jsonb,description='25コンボ以上を3回。累計50プレイ・通算7日以上。',display_name='CHAIN 25' where id='combo_20';
update public.achievement_catalog set requirement='{"type": "combo", "value": 35, "min_sessions": 75, "repeat_count": 5, "min_active_days": 10}'::jsonb,description='35コンボ以上を5回。累計75プレイ・通算10日以上。',display_name='CHAIN REACTOR' where id='combo_30';
update public.achievement_catalog set requirement='{"mode": "TEXT", "type": "mode_sessions", "count": 25, "min_active_days": 2}'::jsonb,description='TEXTを25回プレイする。2日以上プレイ。',display_name='TEXT SPECIALIST' where id='text_10';
update public.achievement_catalog set requirement='{"mode": "KEYS", "type": "mode_sessions", "count": 25, "min_active_days": 2}'::jsonb,description='KEYSを25回プレイする。2日以上プレイ。',display_name='KEYS SPECIALIST' where id='keys_10';
update public.achievement_catalog set requirement='{"type": "any_mode", "count": 10, "modes": ["HD_TEXT", "HD_KEYS"], "min_active_days": 2}'::jsonb,description='HD TEXT / HD KEYSを合計10回プレイする。2日以上プレイ。',display_name='HYPER IGNITION' where id='hyper_first';
update public.achievement_catalog set requirement='{"mode": "EAR_LINK", "type": "mode_sessions", "count": 10, "min_active_days": 2}'::jsonb,description='EAR_LINKを10回プレイする。2日以上プレイ。',display_name='EAR CONTACT' where id='ear_first';
update public.achievement_catalog set requirement='{"type": "all_modes", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_sessions": 50, "min_active_days": 5}'::jsonb,description='主要5モードをすべてプレイする。累計50回・5日以上プレイ。',display_name='COSMOS EXPLORER' where id='all_modes';
update public.achievement_catalog set requirement='{"type": "interval_mastery", "min_seen": 15, "min_accuracy": 0, "min_active_days": 2}'::jsonb,description='13音程すべてに15回答以上、正答率0%以上。2日以上プレイ。',display_name='13 SIGNALS' where id='interval_all_seen';
update public.achievement_catalog set requirement='{"type": "interval_mastery", "min_seen": 30, "min_accuracy": 80, "min_active_days": 5}'::jsonb,description='13音程すべてに30回答以上、正答率80%以上。5日以上プレイ。',display_name='INTERVAL NAVIGATOR' where id='interval_80';
update public.achievement_catalog set requirement='{"type": "interval_mastery", "min_seen": 50, "min_accuracy": 90, "min_active_days": 10}'::jsonb,description='13音程すべてに50回答以上、正答率90%以上。10日以上プレイ。',display_name='INTERVAL MASTER' where id='interval_90';
update public.achievement_catalog set requirement='{"rank": 999999, "type": "public_rank", "min_sessions": 10, "min_active_days": 2}'::jsonb,description='ランキングへ記録を公開する。累計10回・2日以上プレイ。',display_name='OPEN CHANNEL' where id='public_record';
update public.achievement_catalog set requirement='{"rank": 10, "type": "public_rank", "min_sessions": 50, "min_active_days": 5}'::jsonb,description='殿堂ランキング10位以内に入る。累計50回・5日以上プレイ。',display_name='TOP TEN' where id='rank_top10';
update public.achievement_catalog set requirement='{"rank": 3, "type": "public_rank", "min_sessions": 100, "min_active_days": 10}'::jsonb,description='殿堂ランキング3位以内に入る。累計100回・10日以上プレイ。',display_name='PODIUM' where id='rank_podium';
update public.achievement_catalog set requirement='{"rank": 1, "type": "public_rank", "min_sessions": 150, "min_active_days": 20}'::jsonb,description='殿堂ランキング1位以内に入る。累計150回・20日以上プレイ。',display_name='NUMBER ONE' where id='rank_first';
update public.achievement_catalog set requirement='{"mode": "EAR_LINK", "type": "perfect_session", "min_answers": 15, "min_sessions": 50, "repeat_count": 3, "min_active_days": 7}'::jsonb,description='???',display_name='INNER EAR' where id='hidden_ear_perfect';
update public.achievement_catalog set requirement='{"type": "all_modes_perfect", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_answers": 20, "min_sessions": 75, "min_active_days": 10, "mode_min_answers": {"EAR_LINK": 10}}'::jsonb,description='???',display_name='FIVE PERFECT ORBITS' where id='hidden_all_mode_perfect';
update public.achievement_catalog set requirement='{"type": "combo", "value": 40, "min_sessions": 100, "repeat_count": 3, "min_active_days": 14}'::jsonb,description='???',display_name='GRAVITY CHAIN' where id='hidden_combo_50';
update public.achievement_catalog set requirement='{"type": "perfect_session", "min_answers": 40, "min_sessions": 100, "repeat_count": 3, "min_active_days": 10}'::jsonb,description='1プレイで40問以上・全問正解を3回。累計100プレイ・通算10日以上。',display_name='PRECISION ACE' where id='perfect_40';
update public.achievement_catalog set requirement='{"type": "combo", "value": 45, "min_sessions": 150, "repeat_count": 3, "min_active_days": 18}'::jsonb,description='45コンボ以上を3回。累計150プレイ・通算18日以上。',display_name='APEX CHAIN' where id='combo_100';
update public.achievement_catalog set requirement='{"days": 10, "type": "active_days"}'::jsonb,description='通算10日プレイする。連続でなくてもよい。',display_name='TEN DAY JOURNEY' where id='streak_30';
update public.achievement_catalog set requirement='{"days": 20, "type": "active_days"}'::jsonb,description='通算20日プレイする。連続でなくてもよい。',display_name='TWENTY DAY CONSTELLATION' where id='streak_60';
update public.achievement_catalog set requirement='{"type": "all_modes_perfect", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_answers": 30, "min_sessions": 100, "min_active_days": 14, "mode_min_answers": {"EAR_LINK": 15}}'::jsonb,description='主要5モードそれぞれで30問以上・全問正解（EAR LINKは15問以上）。累計100プレイ・通算14日以上。',display_name='FIVE STAR PRECISION' where id='all_modes_perfect_30';
update public.achievement_catalog set requirement='{"mode": "EAR_LINK", "type": "perfect_session", "min_answers": 20, "min_sessions": 75, "repeat_count": 3, "min_active_days": 10}'::jsonb,description='EAR LINKで20問以上・全問正解を3回。累計75プレイ・通算10日以上。',display_name='DEEP LISTENER' where id='ear_perfect_40';
update public.frame_catalog set points_required=0 where id='normal';
update public.frame_catalog set points_required=150 where id='bronze';
update public.frame_catalog set points_required=500 where id='silver';
update public.frame_catalog set points_required=1200 where id='gold';
update public.frame_catalog set points_required=2200 where id='platinum';
update public.frame_catalog set points_required=3500 where id='cosmic';
update public.frame_catalog set points_required=5000 where id='aurora';
update public.frame_catalog set points_required=7000 where id='supernova';
update public.frame_catalog set points_required=9000 where id='event_horizon';
update public.frame_catalog set points_required=11500 where id='pulsar';
update public.frame_catalog set points_required=14500 where id='omega';
create or replace function public.refresh_my_daily_missions()
returns void language plpgsql security definer set search_path='' as $$
declare v_player_id uuid:=public.current_player_id(); v_date date:=(now() at time zone 'Asia/Tokyo')::date; r record; v_progress integer; v_min_answers integer; v_min_accuracy numeric; v_mode text; v_modes text[];
begin
 if v_player_id is null then raise exception 'Player account required'; end if; perform public.ensure_my_daily_missions();
 for r in select p.slot,p.mission_id,d.mission_type,d.target_value,d.config,d.reward_points from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=v_date and not p.completed loop
  v_progress:=0;
  if r.mission_type='play_count' then select count(*) into v_progress from public.play_sessions where player_id=v_player_id and (played_at at time zone 'Asia/Tokyo')::date=v_date;
  elsif r.mission_type='answer_count' then select coalesce(sum(total_answers),0)::integer into v_progress from public.play_sessions where player_id=v_player_id and (played_at at time zone 'Asia/Tokyo')::date=v_date;
  elsif r.mission_type='correct_answers' then select coalesce(sum(correct_answers),0)::integer into v_progress from public.play_sessions where player_id=v_player_id and (played_at at time zone 'Asia/Tokyo')::date=v_date;
  elsif r.mission_type='combo_peak' then select coalesce(max(max_combo),0)::integer into v_progress from public.play_sessions where player_id=v_player_id and (played_at at time zone 'Asia/Tokyo')::date=v_date;
  elsif r.mission_type='mode_play' then v_mode:=r.config->>'mode'; select count(*) into v_progress from public.play_sessions where player_id=v_player_id and mode=v_mode and (played_at at time zone 'Asia/Tokyo')::date=v_date;
  elsif r.mission_type='mode_group_play' then select array_agg(value::text) into v_modes from jsonb_array_elements_text(r.config->'modes'); select count(*) into v_progress from public.play_sessions where player_id=v_player_id and mode=any(v_modes) and (played_at at time zone 'Asia/Tokyo')::date=v_date;
  elsif r.mission_type='distinct_modes' then select count(distinct mode) into v_progress from public.play_sessions where player_id=v_player_id and (played_at at time zone 'Asia/Tokyo')::date=v_date;
  elsif r.mission_type='perfect_session' then v_min_answers:=coalesce((r.config->>'min_answers')::integer,1); select count(*) into v_progress from public.play_sessions where player_id=v_player_id and (played_at at time zone 'Asia/Tokyo')::date=v_date and total_answers>=v_min_answers and correct_answers=total_answers;
  elsif r.mission_type='accuracy_session' then v_min_answers:=coalesce((r.config->>'min_answers')::integer,1); v_min_accuracy:=coalesce((r.config->>'min_accuracy')::numeric,90); select count(*) into v_progress from public.play_sessions where player_id=v_player_id and (played_at at time zone 'Asia/Tokyo')::date=v_date and total_answers>=v_min_answers and ((correct_answers::numeric*100)/greatest(total_answers,1))>=v_min_accuracy;
  end if;
  update public.player_daily_mission_progress p set reward_points_awarded=case when v_progress>=r.target_value then coalesce(p.reward_points_awarded,r.reward_points) else p.reward_points_awarded end,progress=least(v_progress,r.target_value),completed=(v_progress>=r.target_value),completed_at=case when v_progress>=r.target_value then coalesce(p.completed_at,now()) else null end where p.player_id=v_player_id and p.mission_date=v_date and p.slot=r.slot;
 end loop;
end; $$;
create or replace function public.evaluate_my_progress()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_frame record; v_player_id uuid:=public.current_player_id(); v_before_ach text[]; v_before_titles text[]; v_before_frames text[]; v_before_completed text[]; v_points integer; v_best_point_frame text; v_current_frame text; v_current_tier integer; v_best_tier integer; v_new_ach jsonb; v_new_titles jsonb; v_new_frames jsonb; v_new_missions jsonb;
begin
 if v_player_id is null then raise exception 'Player account required'; end if;
 perform 1 from public.players where id=v_player_id for update;
 select coalesce(array_agg(achievement_id),'{}') into v_before_ach from public.player_achievements where player_id=v_player_id;
 select coalesce(array_agg(title_id),'{}') into v_before_titles from public.player_titles where player_id=v_player_id;
 select coalesce(array_agg(frame_id),'{}') into v_before_frames from public.player_frames where player_id=v_player_id;
 perform public.ensure_my_daily_missions();
 select coalesce(array_agg(mission_id),'{}') into v_before_completed from public.player_daily_mission_progress where player_id=v_player_id and mission_date=(now() at time zone 'Asia/Tokyo')::date and completed;
 perform public.refresh_my_daily_missions();
 insert into public.player_achievements(player_id,achievement_id) select v_player_id,a.id from public.achievement_catalog a where a.is_active and a.requirement->>'type'<>'achievement_combo' and public.achievement_requirement_met(v_player_id,a.requirement) on conflict do nothing;
 insert into public.player_achievements(player_id,achievement_id) select v_player_id,a.id from public.achievement_catalog a where a.is_active and a.requirement->>'type'='achievement_combo' and public.achievement_requirement_met(v_player_id,a.requirement) on conflict do nothing;
 insert into public.player_titles(player_id,title_id) select distinct v_player_id,a.reward_title_id from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id and a.reward_title_id is not null on conflict do nothing;
 select coalesce(sum(a.points),0) into v_points from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id;
 v_points:=v_points+coalesce((select sum(coalesce(p.reward_points_awarded,d.reward_points)) from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.completed),0);
 -- One award per mode per JST day, shared across devices, including delayed offline sync.
 insert into public.player_mode_clear_rewards(player_id,reward_date,mode,reward_points)
 select distinct v_player_id,(s.played_at at time zone 'Asia/Tokyo')::date,s.mode,c.reward_points
 from public.play_sessions s join public.mode_clear_reward_catalog c on c.mode=s.mode
 where s.player_id=v_player_id and s.source='ranked' and s.played_at>=c.enabled_from and s.played_at<=now()
 and s.total_answers>=c.min_answers and s.correct_answers::numeric*100/greatest(s.total_answers,1)>=c.min_accuracy
 on conflict do nothing;
 v_points:=v_points+coalesce((select sum(reward_points) from public.player_mode_clear_rewards where player_id=v_player_id),0);
 update public.players set achievement_points=v_points where id=v_player_id;
 -- Tier order is deterministic: each new frame requires ownership of its predecessor.
 for v_frame in select * from public.frame_catalog where is_active order by tier,sort_order,id loop
  if (nullif(v_frame.unlock_rule->>'requires_frame','') is null or exists(
      select 1 from public.player_frames where player_id=v_player_id and frame_id=v_frame.unlock_rule->>'requires_frame'))
    and v_points>=v_frame.points_required
    and ((v_frame.unlock_rule->>'type'='points' and v_points>=v_frame.points_required)
      or (v_frame.unlock_rule->>'type'='achievement_combo' and public.achievement_requirement_met(v_player_id,v_frame.unlock_rule))
      or exists(select 1 from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id and a.reward_frame_id=v_frame.id)) then
   insert into public.player_frames(player_id,frame_id) values(v_player_id,v_frame.id) on conflict do nothing;
  end if;
 end loop;
 select p.equipped_frame_id,coalesce(f.tier,0) into v_current_frame,v_current_tier from public.players p left join public.frame_catalog f on f.id=p.equipped_frame_id where p.id=v_player_id;
 select f.id,f.tier into v_best_point_frame,v_best_tier from public.player_frames pf join public.frame_catalog f on f.id=pf.frame_id where pf.player_id=v_player_id and (f.id='normal' or f.unlock_rule->>'type'='points') order by f.tier desc limit 1;
 if v_best_point_frame is not null and not(v_best_point_frame=any(v_before_frames)) and coalesce((select unlock_rule->>'type' from public.frame_catalog where id=v_current_frame),'points') in('points','') and coalesce(v_best_tier,0)>coalesce(v_current_tier,0) then update public.players set equipped_frame_id=v_best_point_frame where id=v_player_id; end if;
 update public.players p set main_title_id=(select pt.title_id from public.player_titles pt join public.title_catalog t on t.id=pt.title_id where pt.player_id=v_player_id order by t.sort_order,pt.unlocked_at limit 1) where p.id=v_player_id and p.main_title_id is null and exists(select 1 from public.player_titles where player_id=v_player_id);
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.display_name,'description',a.description,'points',a.points,'hidden',a.hidden) order by a.sort_order),'[]'::jsonb) into v_new_ach from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id and not(pa.achievement_id=any(v_before_ach));
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.display_name) order by t.sort_order),'[]'::jsonb) into v_new_titles from public.player_titles pt join public.title_catalog t on t.id=pt.title_id where pt.player_id=v_player_id and not(pt.title_id=any(v_before_titles));
 select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'name',f.display_name,'tier',f.tier,'animated',f.animated,'hidden',f.hidden) order by f.tier),'[]'::jsonb) into v_new_frames from public.player_frames pf join public.frame_catalog f on f.id=pf.frame_id where pf.player_id=v_player_id and not(pf.frame_id=any(v_before_frames));
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.display_name,'reward_points',coalesce(p.reward_points_awarded,d.reward_points)) order by p.slot),'[]'::jsonb) into v_new_missions from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=(now() at time zone 'Asia/Tokyo')::date and p.completed and not(p.mission_id=any(v_before_completed));
 return jsonb_build_object('achievement_points',v_points,'new_achievements',v_new_ach,'new_titles',v_new_titles,'new_frames',v_new_frames,'new_daily_completions',v_new_missions,'player',(select to_jsonb(x) from public.get_my_player() x));
end; $$;
create or replace function public.get_my_cosmos_progress()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_player_id uuid:=public.current_player_id(); v_date date:=(now() at time zone 'Asia/Tokyo')::date; v_player jsonb; v_achievements jsonb; v_titles jsonb; v_frames jsonb; v_daily jsonb;
begin
 if v_player_id is null then raise exception 'Player account required'; end if; perform public.evaluate_my_progress(); select to_jsonb(x) into v_player from public.get_my_player() x;
 select coalesce(jsonb_agg(item order by sort_order),'[]'::jsonb) into v_achievements from (select a.sort_order,case when a.hidden and pa.achievement_id is null then jsonb_build_object('id',null,'name','???','description','???','category','hidden','points',null,'hidden',true,'unlocked',false,'featured_order',null) else jsonb_build_object('id',a.id,'name',a.display_name,'description',a.description,'category',a.category,'points',a.points,'hidden',a.hidden,'unlocked',(pa.achievement_id is not null),'unlocked_at',pa.unlocked_at,'featured_order',pa.featured_order,'requirement',case when a.hidden and pa.achievement_id is null then null else a.requirement end) end item from public.achievement_catalog a left join public.player_achievements pa on pa.player_id=v_player_id and pa.achievement_id=a.id where a.is_active) q;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.display_name,'description',t.description,'hidden',t.hidden,'unlocked',(pt.title_id is not null),'unlocked_at',pt.unlocked_at,'equipped',(t.id=(select main_title_id from public.players where id=v_player_id))) order by t.sort_order),'[]'::jsonb) into v_titles from public.title_catalog t left join public.player_titles pt on pt.player_id=v_player_id and pt.title_id=t.id where t.is_active and (not t.hidden or pt.title_id is not null);
 select coalesce(jsonb_agg(item order by tier),'[]'::jsonb) into v_frames from (select f.tier,case when f.hidden and pf.frame_id is null then jsonb_build_object('id',null,'name','???','tier',f.tier,'animated',true,'hidden',true,'unlocked',false) else jsonb_build_object('id',f.id,'name',f.display_name,'tier',f.tier,'points_required',f.points_required,'animated',f.animated,'hidden',f.hidden,'unlock_rule',f.unlock_rule,'unlocked',(pf.frame_id is not null),'unlocked_at',pf.unlocked_at,'equipped',(f.id=(select equipped_frame_id from public.players where id=v_player_id))) end item from public.frame_catalog f left join public.player_frames pf on pf.player_id=v_player_id and pf.frame_id=f.id where f.is_active) q;
 select coalesce(jsonb_agg(jsonb_build_object('slot',p.slot,'date',p.mission_date,'id',d.id,'name',d.display_name,'description',d.description,'progress',p.progress,'target',d.target_value,'completed',p.completed,'completed_at',p.completed_at,'reward_points',coalesce(p.reward_points_awarded,d.reward_points)) order by p.slot),'[]'::jsonb) into v_daily from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=v_date;
 return jsonb_build_object('player',v_player,'achievements',v_achievements,'titles',v_titles,'frames',v_frames,'daily_missions',v_daily,'mission_date',v_date,
 'mode_clear_rewards',(select jsonb_agg(jsonb_build_object('mode',c.mode,'reward_points',c.reward_points,'min_answers',c.min_answers,'min_accuracy',c.min_accuracy,'completed',r.mode is not null) order by c.reward_points,c.mode) from public.mode_clear_reward_catalog c left join public.player_mode_clear_rewards r on r.player_id=v_player_id and r.reward_date=v_date and r.mode=c.mode),
 'point_breakdown',jsonb_build_object('achievements',(select coalesce(sum(a.points),0) from public.player_achievements p join public.achievement_catalog a on a.id=p.achievement_id where p.player_id=v_player_id),'daily',(select coalesce(sum(coalesce(p.reward_points_awarded,d.reward_points)),0) from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.completed),'mode_clear',(select coalesce(sum(reward_points),0) from public.player_mode_clear_rewards where player_id=v_player_id)));
end; $$;
commit;
