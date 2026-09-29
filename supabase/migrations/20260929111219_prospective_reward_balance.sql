-- Prospective requirements only: never revoke or rewrite player rewards.
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
  if v_type='sessions' then select count(*) into v_count from public.play_sessions where player_id=p_player_id; return v_count>=coalesce((p_requirement->>'count')::integer,1);
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
  elsif v_type='all_modes_perfect' then v_min_answers:=coalesce((p_requirement->>'min_answers')::integer,1); select array_agg(value::text) into v_modes from jsonb_array_elements_text(p_requirement->'modes'); select count(distinct mode) into v_count from public.play_sessions where player_id=p_player_id and mode=any(v_modes) and total_answers>=v_min_answers and correct_answers=total_answers; return v_count=cardinality(v_modes);
  elsif v_type='achievement_combo' then select count(*) into v_total from jsonb_array_elements_text(p_requirement->'ids'); select count(*) into v_met from jsonb_array_elements_text(p_requirement->'ids') j(id) where exists(select 1 from public.player_achievements pa where pa.player_id=p_player_id and pa.achievement_id=j.id); return v_total>0 and v_met=v_total;
  end if; return false;
end; $$;


update public.achievement_catalog set description='累計10回・2日以上プレイする。', requirement='{"type": "sessions", "count": 10, "min_active_days": 2}'::jsonb where id='sessions_5';
update public.achievement_catalog set description='累計30回・5日以上プレイする。', requirement='{"type": "sessions", "count": 30, "min_active_days": 5}'::jsonb where id='sessions_20';
update public.achievement_catalog set description='累計75回・10日以上プレイする。', requirement='{"type": "sessions", "count": 75, "min_active_days": 10}'::jsonb where id='sessions_50';
update public.achievement_catalog set description='累計150回・20日以上プレイする。', requirement='{"type": "sessions", "count": 150, "min_active_days": 20}'::jsonb where id='sessions_100';
update public.achievement_catalog set description='15問以上・全問正解を3回達成する。累計10回・3日以上プレイ。', requirement='{"type": "perfect_session", "min_answers": 15, "repeat_count": 3, "min_sessions": 10, "min_active_days": 3}'::jsonb where id='perfect_5';
update public.achievement_catalog set description='25問以上・全問正解を5回達成する。累計25回・7日以上プレイ。', requirement='{"type": "perfect_session", "min_answers": 25, "repeat_count": 5, "min_sessions": 25, "min_active_days": 7}'::jsonb where id='perfect_10';
update public.achievement_catalog set description='35問以上・全問正解を10回達成する。累計50回・14日以上プレイ。', requirement='{"type": "perfect_session", "min_answers": 35, "repeat_count": 10, "min_sessions": 50, "min_active_days": 14}'::jsonb where id='perfect_20';
update public.achievement_catalog set description='10コンボ以上を3回達成する。累計10回・3日以上プレイ。', requirement='{"type": "combo", "value": 10, "repeat_count": 3, "min_sessions": 10, "min_active_days": 3}'::jsonb where id='combo_5';
update public.achievement_catalog set description='20コンボ以上を5回達成する。累計25回・7日以上プレイ。', requirement='{"type": "combo", "value": 20, "repeat_count": 5, "min_sessions": 25, "min_active_days": 7}'::jsonb where id='combo_10';
update public.achievement_catalog set description='30コンボ以上を5回達成する。累計50回・14日以上プレイ。', requirement='{"type": "combo", "value": 30, "repeat_count": 5, "min_sessions": 50, "min_active_days": 14}'::jsonb where id='combo_20';
update public.achievement_catalog set description='50コンボ以上を10回達成する。累計100回・20日以上プレイ。', requirement='{"type": "combo", "value": 50, "repeat_count": 10, "min_sessions": 100, "min_active_days": 20}'::jsonb where id='combo_30';
update public.achievement_catalog set description='TEXTを25回プレイする。3日以上プレイ。', requirement='{"type": "mode_sessions", "mode": "TEXT", "count": 25, "min_active_days": 3}'::jsonb where id='text_10';
update public.achievement_catalog set description='KEYSを25回プレイする。3日以上プレイ。', requirement='{"type": "mode_sessions", "mode": "KEYS", "count": 25, "min_active_days": 3}'::jsonb where id='keys_10';
update public.achievement_catalog set description='EAR_LINKを10回プレイする。3日以上プレイ。', requirement='{"type": "mode_sessions", "mode": "EAR_LINK", "count": 10, "min_active_days": 3}'::jsonb where id='ear_first';
update public.achievement_catalog set description='HD TEXT / HD KEYSを合計10回プレイする。3日以上プレイ。', requirement='{"type": "any_mode", "modes": ["HD_TEXT", "HD_KEYS"], "count": 10, "min_active_days": 3}'::jsonb where id='hyper_first';
update public.achievement_catalog set description='主要5モードをすべてプレイする。累計50回・7日以上プレイ。', requirement='{"type": "all_modes", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_sessions": 50, "min_active_days": 7}'::jsonb where id='all_modes';
update public.achievement_catalog set description='13音程すべてに15回答以上、正答率0%以上。3日以上プレイ。', requirement='{"type": "interval_mastery", "min_seen": 15, "min_accuracy": 0, "min_active_days": 3}'::jsonb where id='interval_all_seen';
update public.achievement_catalog set description='13音程すべてに30回答以上、正答率80%以上。7日以上プレイ。', requirement='{"type": "interval_mastery", "min_seen": 30, "min_accuracy": 80, "min_active_days": 7}'::jsonb where id='interval_80';
update public.achievement_catalog set description='13音程すべてに50回答以上、正答率90%以上。14日以上プレイ。', requirement='{"type": "interval_mastery", "min_seen": 50, "min_accuracy": 90, "min_active_days": 14}'::jsonb where id='interval_90';
update public.achievement_catalog set description='ランキングへ記録を公開する。累計10回・3日以上プレイ。', requirement='{"type": "public_rank", "rank": 999999, "min_sessions": 10, "min_active_days": 3}'::jsonb where id='public_record';
update public.achievement_catalog set description='殿堂ランキング10位以内に入る。累計50回・7日以上プレイ。', requirement='{"type": "public_rank", "rank": 10, "min_sessions": 50, "min_active_days": 7}'::jsonb where id='rank_top10';
update public.achievement_catalog set description='殿堂ランキング3位以内に入る。累計100回・14日以上プレイ。', requirement='{"type": "public_rank", "rank": 3, "min_sessions": 100, "min_active_days": 14}'::jsonb where id='rank_podium';
update public.achievement_catalog set description='殿堂ランキング1位以内に入る。累計150回・30日以上プレイ。', requirement='{"type": "public_rank", "rank": 1, "min_sessions": 150, "min_active_days": 30}'::jsonb where id='rank_first';
update public.achievement_catalog set description='???', requirement='{"type": "perfect_session", "mode": "EAR_LINK", "min_answers": 25, "repeat_count": 5, "min_sessions": 75, "min_active_days": 14}'::jsonb where id='hidden_ear_perfect';
update public.achievement_catalog set description='???', requirement='{"type": "all_modes_perfect", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_answers": 20, "min_sessions": 100, "min_active_days": 20}'::jsonb where id='hidden_all_mode_perfect';
update public.achievement_catalog set description='???', requirement='{"type": "combo", "value": 75, "repeat_count": 5, "min_sessions": 150, "min_active_days": 30}'::jsonb where id='hidden_combo_50';
update public.achievement_catalog set description='40問以上・全問正解を10回達成する。累計100回・14日以上プレイ。', requirement='{"type": "perfect_session", "min_answers": 40, "repeat_count": 10, "min_sessions": 100, "min_active_days": 14}'::jsonb where id='perfect_40';
update public.achievement_catalog set description='EAR LINKで40問以上・全問正解を10回達成する。累計100回・14日以上プレイ。', requirement='{"type": "perfect_session", "mode": "EAR_LINK", "min_answers": 40, "repeat_count": 10, "min_sessions": 100, "min_active_days": 14}'::jsonb where id='ear_perfect_40';
update public.achievement_catalog set description='100コンボを3回達成する。累計150回・30日以上プレイ。', requirement='{"type": "combo", "value": 100, "repeat_count": 3, "min_sessions": 150, "min_active_days": 30}'::jsonb where id='combo_100';
update public.achievement_catalog set display_name='COMBO 10' where id='combo_5';
update public.achievement_catalog set display_name='CHAIN 30' where id='combo_20';
update public.frame_catalog set display_name='COSMO SOVEREIGN' where id='omega';
commit;
