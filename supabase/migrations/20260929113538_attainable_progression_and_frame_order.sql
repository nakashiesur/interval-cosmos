-- Preserve existing awards; attainable future goals and ordered frame progression.
begin;
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
  elsif v_type='public_rank' then v_rank_target:=coalesce((p_requirement->>'rank')::integer,999999); return exists(select 1 from public.ranking_bests mine where mine.player_id=p_player_id and mine.period='ALL' and mine.public_score is not null and (1+(select count(*) from public.ranking_bests other where other.mode=mine.mode and other.period='ALL' and other.public_score is not null and other.public_score>mine.public_score))<=v_rank_target);
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
 v_points:=v_points+coalesce((select sum(d.reward_points) from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.completed),0);
 update public.players set achievement_points=v_points where id=v_player_id;
 -- Tier order is deterministic: each new frame requires ownership of its predecessor.
 for v_frame in select * from public.frame_catalog where is_active order by tier,sort_order,id loop
  if (nullif(v_frame.unlock_rule->>'requires_frame','') is null or exists(
      select 1 from public.player_frames where player_id=v_player_id and frame_id=v_frame.unlock_rule->>'requires_frame'))
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
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.display_name,'reward_points',d.reward_points) order by p.slot),'[]'::jsonb) into v_new_missions from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=(now() at time zone 'Asia/Tokyo')::date and p.completed and not(p.mission_id=any(v_before_completed));
 return jsonb_build_object('achievement_points',v_points,'new_achievements',v_new_ach,'new_titles',v_new_titles,'new_frames',v_new_frames,'new_daily_completions',v_new_missions,'player',(select to_jsonb(x) from public.get_my_player() x));
end; $$;

update public.achievement_catalog set display_name='TEN DAY ORBIT', description='10日連続でプレイする。', requirement='{"type": "streak_days", "days": 10}'::jsonb where id='streak_14';
update public.achievement_catalog set display_name='FIFTEEN DAY JOURNEY', description='通算15日プレイする。連続でなくてもよい。', requirement='{"type": "active_days", "days": 15}'::jsonb where id='streak_30';
update public.achievement_catalog set display_name='THIRTY DAY CONSTELLATION', description='通算30日プレイする。連続でなくてもよい。', requirement='{"type": "active_days", "days": 30}'::jsonb where id='streak_60';
update public.achievement_catalog set display_name='COMBO 10', description='10コンボ以上を2回。累計10プレイ・通算3日以上。', requirement='{"type": "combo", "value": 10, "repeat_count": 2, "min_sessions": 10, "min_active_days": 3}'::jsonb where id='combo_5';
update public.achievement_catalog set display_name='COMBO DRIVER', description='15コンボ以上を3回。累計25プレイ・通算7日以上。', requirement='{"type": "combo", "value": 15, "repeat_count": 3, "min_sessions": 25, "min_active_days": 7}'::jsonb where id='combo_10';
update public.achievement_catalog set display_name='CHAIN 25', description='25コンボ以上を3回。累計50プレイ・通算10日以上。', requirement='{"type": "combo", "value": 25, "repeat_count": 3, "min_sessions": 50, "min_active_days": 10}'::jsonb where id='combo_20';
update public.achievement_catalog set display_name='CHAIN REACTOR', description='35コンボ以上を5回。累計75プレイ・通算15日以上。', requirement='{"type": "combo", "value": 35, "repeat_count": 5, "min_sessions": 75, "min_active_days": 15}'::jsonb where id='combo_30';
update public.achievement_catalog set display_name='GRAVITY CHAIN', description='???', requirement='{"type": "combo", "value": 40, "repeat_count": 3, "min_sessions": 100, "min_active_days": 20}'::jsonb where id='hidden_combo_50';
update public.achievement_catalog set display_name='APEX CHAIN', description='45コンボ以上を3回。累計150プレイ・通算25日以上。', requirement='{"type": "combo", "value": 45, "repeat_count": 3, "min_sessions": 150, "min_active_days": 25}'::jsonb where id='combo_100';
update public.achievement_catalog set display_name='CLEAN CONTACT', description='1プレイで15問以上・全問正解を2回。累計10プレイ・通算3日以上。', requirement='{"type": "perfect_session", "min_answers": 15, "repeat_count": 2, "min_sessions": 10, "min_active_days": 3}'::jsonb where id='perfect_5';
update public.achievement_catalog set display_name='CLEAR ORBIT', description='1プレイで20問以上・全問正解を3回。累計25プレイ・通算7日以上。', requirement='{"type": "perfect_session", "min_answers": 20, "repeat_count": 3, "min_sessions": 25, "min_active_days": 7}'::jsonb where id='perfect_10';
update public.achievement_catalog set display_name='PRECISION PILOT', description='1プレイで30問以上・全問正解を5回。累計50プレイ・通算10日以上。', requirement='{"type": "perfect_session", "min_answers": 30, "repeat_count": 5, "min_sessions": 50, "min_active_days": 10}'::jsonb where id='perfect_20';
update public.achievement_catalog set display_name='PRECISION ACE', description='1プレイで40問以上・全問正解を3回。累計100プレイ・通算15日以上。', requirement='{"type": "perfect_session", "min_answers": 40, "repeat_count": 3, "min_sessions": 100, "min_active_days": 15}'::jsonb where id='perfect_40';
update public.achievement_catalog set display_name='INNER EAR', description='???', requirement='{"type": "perfect_session", "mode": "EAR_LINK", "min_answers": 15, "repeat_count": 3, "min_sessions": 50, "min_active_days": 10}'::jsonb where id='hidden_ear_perfect';
update public.achievement_catalog set display_name='DEEP LISTENER', description='EAR LINKで20問以上・全問正解を3回。累計75プレイ・通算15日以上。', requirement='{"type": "perfect_session", "mode": "EAR_LINK", "min_answers": 20, "repeat_count": 3, "min_sessions": 75, "min_active_days": 15}'::jsonb where id='ear_perfect_40';
update public.achievement_catalog set display_name='FIVE PERFECT ORBITS', description='???', requirement='{"type": "all_modes_perfect", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_answers": 20, "mode_min_answers": {"EAR_LINK": 10}, "min_sessions": 75, "min_active_days": 15}'::jsonb where id='hidden_all_mode_perfect';
update public.achievement_catalog set display_name='FIVE STAR PRECISION', description='主要5モードそれぞれで30問以上・全問正解（EAR LINKは15問以上）。累計100プレイ・通算20日以上。', requirement='{"type": "all_modes_perfect", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_answers": 30, "mode_min_answers": {"EAR_LINK": 15}, "min_sessions": 100, "min_active_days": 20}'::jsonb where id='all_modes_perfect_30';
update public.achievement_catalog set display_name='DEEP SPACE LEGEND', description='累計500回プレイする。', requirement='{"type": "sessions", "count": 500}'::jsonb where id='sessions_1000';
update public.frame_catalog set unlock_rule=unlock_rule||jsonb_build_object('requires_frame','normal') where id='bronze';
update public.frame_catalog set unlock_rule=unlock_rule||jsonb_build_object('requires_frame','bronze') where id='silver';
update public.frame_catalog set unlock_rule=unlock_rule||jsonb_build_object('requires_frame','silver') where id='gold';
update public.frame_catalog set unlock_rule=unlock_rule||jsonb_build_object('requires_frame','gold') where id='platinum';
update public.frame_catalog set unlock_rule=unlock_rule||jsonb_build_object('requires_frame','platinum') where id='cosmic';
update public.frame_catalog set unlock_rule=unlock_rule||jsonb_build_object('requires_frame','cosmic') where id='aurora';
update public.frame_catalog set unlock_rule=unlock_rule||jsonb_build_object('requires_frame','aurora') where id='supernova';
update public.frame_catalog set unlock_rule=unlock_rule||jsonb_build_object('requires_frame','supernova') where id='event_horizon';
update public.frame_catalog set unlock_rule=unlock_rule||jsonb_build_object('requires_frame','event_horizon') where id='pulsar';
update public.frame_catalog set unlock_rule=unlock_rule||jsonb_build_object('requires_frame','pulsar') where id='omega';
update public.frame_catalog set unlock_rule=jsonb_build_object('type','achievement_combo','ids',jsonb_build_array('sessions_250','perfect_40','streak_14'),'requires_frame','event_horizon') where id='pulsar';
commit;
