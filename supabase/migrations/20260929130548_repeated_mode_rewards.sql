-- Five qualifying plays per mode/day, with immutable historical awards.
begin;
alter table public.player_mode_clear_rewards add column reward_slot smallint not null default 1 check(reward_slot between 1 and 5);
alter table public.player_mode_clear_rewards drop constraint player_mode_clear_rewards_pkey;
alter table public.player_mode_clear_rewards add primary key(player_id,reward_date,mode,reward_slot);
alter table public.player_achievements add column points_awarded integer check(points_awarded>=0);
update public.player_achievements p set points_awarded=a.points from public.achievement_catalog a where a.id=p.achievement_id;
update public.mode_clear_reward_catalog set reward_points=case mode when 'TEXT' then 20 when 'KEYS' then 20 when 'HD_TEXT' then 25 when 'HD_KEYS' then 25 when 'EAR_LINK' then 30 end;
update public.achievement_catalog set points=10,requirement='{"type": "sessions", "count": 1}'::jsonb,description='はじめてプレイ記録を保存する。' where id='first_signal';
update public.achievement_catalog set points=20,requirement='{"type": "sessions", "count": 5}'::jsonb,description='累計5回プレイする。' where id='sessions_5';
update public.achievement_catalog set points=40,requirement='{"type": "sessions", "count": 30}'::jsonb,description='累計30回プレイする。' where id='sessions_20';
update public.achievement_catalog set points=80,requirement='{"type": "sessions", "count": 75}'::jsonb,description='累計75回プレイする。' where id='sessions_50';
update public.achievement_catalog set points=150,requirement='{"type": "sessions", "count": 150}'::jsonb,description='累計150回プレイする。' where id='sessions_100';
update public.achievement_catalog set points=20,requirement='{"type": "perfect_session", "min_answers": 15, "min_sessions": 5, "repeat_count": 2}'::jsonb,description='1プレイで15問以上・全問正解を2回。累計5プレイ。' where id='perfect_5';
update public.achievement_catalog set points=40,requirement='{"type": "perfect_session", "min_answers": 20, "min_sessions": 25, "repeat_count": 3}'::jsonb,description='1プレイで20問以上・全問正解を3回。累計25プレイ。' where id='perfect_10';
update public.achievement_catalog set points=80,requirement='{"type": "perfect_session", "min_answers": 30, "min_sessions": 50, "repeat_count": 5}'::jsonb,description='1プレイで30問以上・全問正解を5回。累計50プレイ。' where id='perfect_20';
update public.achievement_catalog set points=15,requirement='{"type": "combo", "value": 10, "min_sessions": 5, "repeat_count": 2}'::jsonb,description='10コンボ以上を2回。累計5プレイ。' where id='combo_5';
update public.achievement_catalog set points=30,requirement='{"type": "combo", "value": 15, "min_sessions": 25, "repeat_count": 3}'::jsonb,description='15コンボ以上を3回。累計25プレイ。' where id='combo_10';
update public.achievement_catalog set points=60,requirement='{"type": "combo", "value": 25, "min_sessions": 50, "repeat_count": 3}'::jsonb,description='25コンボ以上を3回。累計50プレイ。' where id='combo_20';
update public.achievement_catalog set points=100,requirement='{"type": "combo", "value": 35, "min_sessions": 75, "repeat_count": 5}'::jsonb,description='35コンボ以上を5回。累計75プレイ。' where id='combo_30';
update public.achievement_catalog set points=30,requirement='{"mode": "TEXT", "type": "mode_sessions", "count": 10}'::jsonb,description='TEXTを10回プレイする。' where id='text_10';
update public.achievement_catalog set points=30,requirement='{"mode": "KEYS", "type": "mode_sessions", "count": 10}'::jsonb,description='KEYSを10回プレイする。' where id='keys_10';
update public.achievement_catalog set points=25,requirement='{"type": "any_mode", "count": 5, "modes": ["HD_TEXT", "HD_KEYS"]}'::jsonb,description='HD TEXT / HD KEYSを合計5回プレイする。' where id='hyper_first';
update public.achievement_catalog set points=35,requirement='{"mode": "EAR_LINK", "type": "mode_sessions", "count": 5}'::jsonb,description='EAR LINKを5回プレイする。' where id='ear_first';
update public.achievement_catalog set points=100,requirement='{"type": "all_modes", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_sessions": 15}'::jsonb,description='主要5モードをすべてプレイする。累計15回プレイ。' where id='all_modes';
update public.achievement_catalog set points=50,requirement='{"type": "interval_mastery", "min_seen": 15, "min_accuracy": 0}'::jsonb,description='13音程すべてに15回答以上。' where id='interval_all_seen';
update public.achievement_catalog set points=120,requirement='{"type": "interval_mastery", "min_seen": 30, "min_accuracy": 80}'::jsonb,description='13音程すべてに30回答以上、正答率80%以上。' where id='interval_80';
update public.achievement_catalog set points=200,requirement='{"type": "interval_mastery", "min_seen": 50, "min_accuracy": 90}'::jsonb,description='13音程すべてに50回答以上、正答率90%以上。' where id='interval_90';
update public.achievement_catalog set points=30,requirement='{"days": 3, "type": "streak_days"}'::jsonb,description='3日連続でプレイする。' where id='streak_3';
update public.achievement_catalog set points=150,requirement='{"days": 7, "type": "streak_days"}'::jsonb,description='7日連続でプレイする。' where id='streak_7';
update public.achievement_catalog set points=300,requirement='{"days": 10, "type": "streak_days"}'::jsonb,description='10日連続でプレイする。' where id='streak_14';
update public.achievement_catalog set points=20,requirement='{"rank": 999999, "type": "public_rank", "min_sessions": 10, "precision_runs": 5, "precision_min_answers": 20, "precision_min_accuracy": 90, "precision_ear_min_answers": 10}'::jsonb,description='ランキングへ記録を公開する、または20問以上・正答率90%以上を5回（EAR LINKは10問以上）。累計10回プレイ。' where id='public_record';
update public.achievement_catalog set points=80,requirement='{"rank": 10, "type": "public_rank", "min_sessions": 50, "precision_runs": 15, "precision_min_answers": 20, "precision_min_accuracy": 90, "precision_ear_min_answers": 10}'::jsonb,description='殿堂ランキング10位以内に入る、または20問以上・正答率90%以上を15回（EAR LINKは10問以上）。累計50回プレイ。' where id='rank_top10';
update public.achievement_catalog set points=120,requirement='{"rank": 3, "type": "public_rank", "min_sessions": 100, "precision_runs": 30, "precision_min_answers": 20, "precision_min_accuracy": 90, "precision_ear_min_answers": 10}'::jsonb,description='殿堂ランキング3位以内に入る、または20問以上・正答率90%以上を30回（EAR LINKは10問以上）。累計100回プレイ。' where id='rank_podium';
update public.achievement_catalog set points=200,requirement='{"rank": 1, "type": "public_rank", "min_sessions": 150, "precision_runs": 50, "precision_min_answers": 20, "precision_min_accuracy": 90, "precision_ear_min_answers": 10}'::jsonb,description='殿堂ランキング1位以内に入る、または20問以上・正答率90%以上を50回（EAR LINKは10問以上）。累計150回プレイ。' where id='rank_first';
update public.achievement_catalog set points=180,requirement='{"mode": "EAR_LINK", "type": "perfect_session", "min_answers": 15, "min_sessions": 50, "repeat_count": 3}'::jsonb,description='???' where id='hidden_ear_perfect';
update public.achievement_catalog set points=220,requirement='{"type": "all_modes_perfect", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_answers": 20, "min_sessions": 75, "mode_min_answers": {"EAR_LINK": 10}}'::jsonb,description='???' where id='hidden_all_mode_perfect';
update public.achievement_catalog set points=220,requirement='{"type": "combo", "value": 40, "min_sessions": 100, "repeat_count": 3}'::jsonb,description='???' where id='hidden_combo_50';
update public.achievement_catalog set points=350,requirement='{"ids": ["interval_90", "streak_14", "rank_first", "hidden_ear_perfect"], "type": "achievement_combo"}'::jsonb,description='???' where id='hidden_singularity';
update public.achievement_catalog set points=150,requirement='{"type": "sessions", "count": 250}'::jsonb,description='累計250回プレイする。' where id='sessions_250';
update public.achievement_catalog set points=300,requirement='{"type": "sessions", "count": 450}'::jsonb,description='累計450回プレイする。' where id='sessions_1000';
update public.achievement_catalog set points=180,requirement='{"type": "perfect_session", "min_answers": 40, "min_sessions": 100, "repeat_count": 3}'::jsonb,description='1プレイで40問以上・全問正解を3回。累計100プレイ。' where id='perfect_40';
update public.achievement_catalog set points=200,requirement='{"type": "combo", "value": 45, "min_sessions": 150, "repeat_count": 3}'::jsonb,description='45コンボ以上を3回。累計150プレイ。' where id='combo_100';
update public.achievement_catalog set points=80,requirement='{"days": 7, "type": "active_days"}'::jsonb,description='通算7日プレイする。連続でなくてもよい。' where id='streak_30';
update public.achievement_catalog set points=150,requirement='{"days": 15, "type": "active_days"}'::jsonb,description='通算15日プレイする。連続でなくてもよい。' where id='streak_60';
update public.achievement_catalog set points=300,requirement='{"type": "all_modes_perfect", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_answers": 30, "min_sessions": 100, "mode_min_answers": {"EAR_LINK": 15}}'::jsonb,description='主要5モードそれぞれで30問以上・全問正解（EAR LINKは15問以上）。累計100プレイ。' where id='all_modes_perfect_30';
update public.achievement_catalog set points=250,requirement='{"mode": "EAR_LINK", "type": "perfect_session", "min_answers": 20, "min_sessions": 75, "repeat_count": 3}'::jsonb,description='EAR LINKで20問以上・全問正解を3回。累計75プレイ。' where id='ear_perfect_40';
update public.frame_catalog set points_required=6500 where id='aurora';
update public.frame_catalog set points_required=10000 where id='supernova';
update public.frame_catalog set points_required=13500 where id='event_horizon';
update public.frame_catalog set points_required=17500 where id='pulsar';
update public.frame_catalog set points_required=23500 where id='omega';
create or replace function public.achievement_requirement_met(p_player_id uuid,p_requirement jsonb)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_type text:=coalesce(p_requirement->>'type',''); v_count integer; v_value integer; v_mode text; v_modes text[]; v_min_answers integer; v_min_accuracy numeric; v_rank_target integer; v_snapshot jsonb; v_total integer; v_met integer;
begin
  if p_player_id is null then return false; end if;
  if coalesce((p_requirement->>'min_sessions')::integer,0)>0 then
    select count(*) into v_count from public.play_sessions where player_id=p_player_id;
    if v_count<(p_requirement->>'min_sessions')::integer then return false; end if;
  end if;
  if coalesce((p_requirement->>'min_active_days')::integer,0)>0 then
    select count(distinct (played_at at time zone 'Asia/Tokyo')::date) into v_count from public.play_sessions where player_id=p_player_id;
    if v_count<(p_requirement->>'min_active_days')::integer then return false; end if;
  end if;
  if v_type='active_days' then select count(distinct (played_at at time zone 'Asia/Tokyo')::date) into v_count from public.play_sessions where player_id=p_player_id; return v_count>=coalesce((p_requirement->>'days')::integer,1);
  elsif v_type='sessions' then select count(*) into v_count from public.play_sessions where player_id=p_player_id; return v_count>=coalesce((p_requirement->>'count')::integer,1);
  elsif v_type='perfect_session' then v_min_answers:=coalesce((p_requirement->>'min_answers')::integer,1); v_mode:=nullif(p_requirement->>'mode',''); select count(*) into v_count from public.play_sessions where player_id=p_player_id and total_answers>=v_min_answers and correct_answers=total_answers and (v_mode is null or mode=v_mode); return v_count>=coalesce((p_requirement->>'repeat_count')::integer,1);
  elsif v_type='combo' then v_value:=coalesce((p_requirement->>'value')::integer,1); select count(*) into v_count from public.play_sessions where player_id=p_player_id and max_combo>=v_value; return v_count>=coalesce((p_requirement->>'repeat_count')::integer,1);
  elsif v_type='mode_sessions' then v_mode:=p_requirement->>'mode'; select count(*) into v_count from public.play_sessions where player_id=p_player_id and mode=v_mode; return v_count>=coalesce((p_requirement->>'count')::integer,1);
  elsif v_type='any_mode' then select array_agg(value::text) into v_modes from jsonb_array_elements_text(p_requirement->'modes'); select count(*) into v_count from public.play_sessions where player_id=p_player_id and mode=any(v_modes); return v_count>=coalesce((p_requirement->>'count')::integer,1);
  elsif v_type='all_modes' then select array_agg(value::text) into v_modes from jsonb_array_elements_text(p_requirement->'modes'); select count(distinct mode) into v_count from public.play_sessions where player_id=p_player_id and mode=any(v_modes); return v_count=cardinality(v_modes);
  elsif v_type='streak_days' then return public.longest_play_streak(p_player_id)>=coalesce((p_requirement->>'days')::integer,1);
  elsif v_type='public_rank' then v_rank_target:=coalesce((p_requirement->>'rank')::integer,999999); return exists(select 1 from public.ranking_bests mine where mine.player_id=p_player_id and mine.period='ALL' and mine.public_score is not null and (1+(select count(*) from public.ranking_bests other where other.mode=mine.mode and other.period='ALL' and other.public_score is not null and other.public_score>mine.public_score))<=v_rank_target) or (coalesce((p_requirement->>'precision_runs')::integer,0)>0 and
 (select count(*) from public.play_sessions where player_id=p_player_id and source='ranked'
 and total_answers>=case when mode='EAR_LINK' then coalesce((p_requirement->>'precision_ear_min_answers')::integer,10) else coalesce((p_requirement->>'precision_min_answers')::integer,20) end
 and correct_answers::numeric*100/greatest(total_answers,1)>=coalesce((p_requirement->>'precision_min_accuracy')::integer,90)) >=(p_requirement->>'precision_runs')::integer);
  elsif v_type='interval_mastery' then
    v_min_answers:=coalesce((p_requirement->>'min_seen')::integer,1); v_min_accuracy:=coalesce((p_requirement->>'min_accuracy')::numeric,0);
    select interval_stats into v_snapshot from public.play_sessions where player_id=p_player_id and jsonb_typeof(interval_stats->'intervals')='object' order by played_at desc limit 1;
    if v_snapshot is null then return false; end if;
    select count(*),count(*) filter(where coalesce((e.value->>'seen')::integer,0)>=v_min_answers and case when coalesce((e.value->>'seen')::integer,0)=0 then false else ((coalesce((e.value->>'correct')::numeric,0)*100)/greatest((e.value->>'seen')::numeric,1))>=v_min_accuracy end) into v_total,v_met from jsonb_each(v_snapshot->'intervals') e;
    return v_total>=13 and v_met>=13;
  elsif v_type='all_modes_perfect' then v_min_answers:=coalesce((p_requirement->>'min_answers')::integer,1); select array_agg(value::text) into v_modes from jsonb_array_elements_text(p_requirement->'modes'); select count(distinct mode) into v_count from public.play_sessions where player_id=p_player_id and mode=any(v_modes) and total_answers>=coalesce((p_requirement->'mode_min_answers'->>mode)::integer,v_min_answers) and correct_answers=total_answers; return v_count=cardinality(v_modes);
  elsif v_type='achievement_combo' then select count(*) into v_total from jsonb_array_elements_text(p_requirement->'ids'); select count(*) into v_met from jsonb_array_elements_text(p_requirement->'ids') j(id) where exists(select 1 from public.player_achievements pa where pa.player_id=p_player_id and pa.achievement_id=j.id); return v_total>0 and v_met=v_total;
  end if; return false;
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
 insert into public.player_achievements(player_id,achievement_id,points_awarded) select v_player_id,a.id,a.points from public.achievement_catalog a where a.is_active and a.requirement->>'type'<>'achievement_combo' and public.achievement_requirement_met(v_player_id,a.requirement) on conflict do nothing;
 insert into public.player_achievements(player_id,achievement_id,points_awarded) select v_player_id,a.id,a.points from public.achievement_catalog a where a.is_active and a.requirement->>'type'='achievement_combo' and public.achievement_requirement_met(v_player_id,a.requirement) on conflict do nothing;
 insert into public.player_titles(player_id,title_id) select distinct v_player_id,a.reward_title_id from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id and a.reward_title_id is not null on conflict do nothing;
 select coalesce(sum(coalesce(pa.points_awarded,a.points)),0) into v_points from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id;
 v_points:=v_points+coalesce((select sum(coalesce(p.reward_points_awarded,d.reward_points)) from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.completed),0);
 -- Slot uniqueness and the player-row lock make retries and concurrent devices idempotent.
 insert into public.player_mode_clear_rewards(player_id,reward_date,mode,reward_slot,reward_points)
 select v_player_id,q.reward_date,q.mode,q.slot::smallint,q.reward_points from (
 select (s.played_at at time zone 'Asia/Tokyo')::date reward_date,s.mode,c.reward_points,
 row_number() over(partition by (s.played_at at time zone 'Asia/Tokyo')::date,s.mode order by s.played_at,s.id) slot
 from public.play_sessions s join public.mode_clear_reward_catalog c on c.mode=s.mode
 where s.player_id=v_player_id and s.source='ranked' and s.played_at>=c.enabled_from and s.played_at<=now()
 and s.total_answers>=c.min_answers and s.correct_answers::numeric*100/greatest(s.total_answers,1)>=c.min_accuracy
 ) q where q.slot<=5 on conflict do nothing;
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
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.display_name,'description',a.description,'points',coalesce(pa.points_awarded,a.points),'hidden',a.hidden) order by a.sort_order),'[]'::jsonb) into v_new_ach from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id and not(pa.achievement_id=any(v_before_ach));
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
 select coalesce(jsonb_agg(item order by sort_order),'[]'::jsonb) into v_achievements from (select a.sort_order,case when a.hidden and pa.achievement_id is null then jsonb_build_object('id',null,'name','???','description','???','category','hidden','points',null,'hidden',true,'unlocked',false,'featured_order',null) else jsonb_build_object('id',a.id,'name',a.display_name,'description',a.description,'category',a.category,'points',coalesce(pa.points_awarded,a.points),'hidden',a.hidden,'unlocked',(pa.achievement_id is not null),'unlocked_at',pa.unlocked_at,'featured_order',pa.featured_order,'requirement',case when a.hidden and pa.achievement_id is null then null else a.requirement end) end item from public.achievement_catalog a left join public.player_achievements pa on pa.player_id=v_player_id and pa.achievement_id=a.id where a.is_active) q;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.display_name,'description',t.description,'hidden',t.hidden,'unlocked',(pt.title_id is not null),'unlocked_at',pt.unlocked_at,'equipped',(t.id=(select main_title_id from public.players where id=v_player_id))) order by t.sort_order),'[]'::jsonb) into v_titles from public.title_catalog t left join public.player_titles pt on pt.player_id=v_player_id and pt.title_id=t.id where t.is_active and (not t.hidden or pt.title_id is not null);
 select coalesce(jsonb_agg(item order by tier),'[]'::jsonb) into v_frames from (select f.tier,case when f.hidden and pf.frame_id is null then jsonb_build_object('id',null,'name','???','tier',f.tier,'animated',true,'hidden',true,'unlocked',false) else jsonb_build_object('id',f.id,'name',f.display_name,'tier',f.tier,'points_required',f.points_required,'animated',f.animated,'hidden',f.hidden,'unlock_rule',f.unlock_rule,'unlocked',(pf.frame_id is not null),'unlocked_at',pf.unlocked_at,'equipped',(f.id=(select equipped_frame_id from public.players where id=v_player_id))) end item from public.frame_catalog f left join public.player_frames pf on pf.player_id=v_player_id and pf.frame_id=f.id where f.is_active) q;
 select coalesce(jsonb_agg(jsonb_build_object('slot',p.slot,'date',p.mission_date,'id',d.id,'name',d.display_name,'description',d.description,'progress',p.progress,'target',d.target_value,'completed',p.completed,'completed_at',p.completed_at,'reward_points',coalesce(p.reward_points_awarded,d.reward_points)) order by p.slot),'[]'::jsonb) into v_daily from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=v_date;
 return jsonb_build_object('player',v_player,'achievements',v_achievements,'titles',v_titles,'frames',v_frames,'daily_missions',v_daily,'mission_date',v_date,
 'mode_clear_rewards',(select jsonb_agg(jsonb_build_object('mode',c.mode,'reward_points',c.reward_points,'min_answers',c.min_answers,'min_accuracy',c.min_accuracy,'earned_count',coalesce(r.n,0),'daily_limit',5,'completed',coalesce(r.n,0)>=5) order by c.reward_points,c.mode) from public.mode_clear_reward_catalog c left join (select mode,count(*) n from public.player_mode_clear_rewards where player_id=v_player_id and reward_date=v_date group by mode) r on r.mode=c.mode),
 'point_breakdown',jsonb_build_object('achievements',(select coalesce(sum(coalesce(p.points_awarded,a.points)),0) from public.player_achievements p join public.achievement_catalog a on a.id=p.achievement_id where p.player_id=v_player_id),'daily',(select coalesce(sum(coalesce(p.reward_points_awarded,d.reward_points)),0) from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.completed),'mode_clear',(select coalesce(sum(reward_points),0) from public.player_mode_clear_rewards where player_id=v_player_id)));
end; $$;
commit;
