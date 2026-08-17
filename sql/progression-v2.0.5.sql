-- INTERVAL COSMOS v2.0.5
-- Phase 5: achievements / titles / frames / daily missions
-- Run AFTER the Phase 1 base schema and Phase 2 device-link patch.

begin;

-- NOTE: full Phase 5 progression patch. Catalog seed + evaluated unlock rules + daily missions.

insert into public.title_catalog
  (id, display_name, description, hidden, unlock_rule, sort_order, is_active)
values
  ('first_signal','FIRST SIGNAL','最初の記録を宇宙へ送った証。',false,'{"type":"achievement","id":"first_signal"}',10,true),
  ('orbit_regular','ORBIT REGULAR','継続してトレーニングを重ねたプレイヤー。',false,'{"type":"achievement","id":"sessions_20"}',20,true),
  ('precision_pilot','PRECISION PILOT','高い正確性で音程を見抜くプレイヤー。',false,'{"type":"achievement","id":"perfect_20"}',30,true),
  ('combo_driver','COMBO DRIVER','連続正解の流れを維持するプレイヤー。',false,'{"type":"achievement","id":"combo_10"}',40,true),
  ('chain_reactor','CHAIN REACTOR','長いコンボを作り出したプレイヤー。',false,'{"type":"achievement","id":"combo_30"}',50,true),
  ('cosmos_explorer','COSMOS EXPLORER','すべての主要モードを体験した探究者。',false,'{"type":"achievement","id":"all_modes"}',60,true),
  ('interval_navigator','INTERVAL NAVIGATOR','13音程を高い精度で結びつけるナビゲーター。',false,'{"type":"achievement","id":"interval_80"}',70,true),
  ('seven_day_orbit','SEVEN DAY ORBIT','7日間の学習軌道をつないだ継続者。',false,'{"type":"achievement","id":"streak_7"}',80,true),
  ('top_ten','TOP TEN','公開ランキングTOP10到達者。',false,'{"type":"achievement","id":"rank_top10"}',90,true),
  ('number_one','NUMBER ONE','公開ランキングの頂点へ到達したプレイヤー。',false,'{"type":"achievement","id":"rank_first"}',100,true),
  ('inner_ear','INNER EAR','視覚情報なしで極めて高い聴覚精度を示した証。',true,'{"type":"achievement","id":"hidden_ear_perfect"}',200,true),
  ('singularity','SINGULARITY','INTERVAL COSMOSの深部へ到達した者だけが得る称号。',true,'{"type":"achievement","id":"hidden_singularity"}',300,true)
on conflict (id) do update set display_name=excluded.display_name,description=excluded.description,hidden=excluded.hidden,unlock_rule=excluded.unlock_rule,sort_order=excluded.sort_order,is_active=true;

insert into public.frame_catalog
  (id, display_name, tier, points_required, animated, hidden, unlock_rule, sort_order, is_active)
values
  ('aurora','AURORA',6,0,true,false,'{"type":"achievement_combo","ids":["perfect_20","all_modes"]}'::jsonb,60,true),
  ('supernova','SUPERNOVA',7,0,true,true,'{"type":"achievement_combo","ids":["interval_90","combo_30","streak_14"]}'::jsonb,70,true),
  ('event_horizon','EVENT HORIZON',8,0,true,true,'{"type":"achievement_combo","ids":["rank_first","hidden_ear_perfect"]}'::jsonb,80,true)
on conflict (id) do update set display_name=excluded.display_name,tier=excluded.tier,points_required=excluded.points_required,animated=excluded.animated,hidden=excluded.hidden,unlock_rule=excluded.unlock_rule,sort_order=excluded.sort_order,is_active=true;

insert into public.achievement_catalog
  (id,display_name,description,category,points,hidden,requirement,reward_title_id,reward_frame_id,sort_order,is_active)
values
  ('first_signal','FIRST SIGNAL','はじめてプレイ記録を保存する。','basic',10,false,'{"type":"sessions","count":1}','first_signal',null,10,true),
  ('sessions_5','ORBIT STARTER','5セッションプレイする。','basic',20,false,'{"type":"sessions","count":5}',null,null,20,true),
  ('sessions_20','ORBIT REGULAR','20セッションプレイする。','basic',40,false,'{"type":"sessions","count":20}','orbit_regular',null,30,true),
  ('sessions_50','STAR TRACKER','50セッションプレイする。','basic',80,false,'{"type":"sessions","count":50}',null,null,40,true),
  ('sessions_100','STELLAR VETERAN','100セッションプレイする。','basic',150,false,'{"type":"sessions","count":100}',null,null,50,true),
  ('perfect_5','CLEAN CONTACT','5問以上のセッションを正答率100%で完了する。','accuracy',20,false,'{"type":"perfect_session","min_answers":5}',null,null,110,true),
  ('perfect_10','CLEAR ORBIT','10問以上のセッションを正答率100%で完了する。','accuracy',40,false,'{"type":"perfect_session","min_answers":10}',null,null,120,true),
  ('perfect_20','PRECISION PILOT','20問以上のセッションを正答率100%で完了する。','accuracy',80,false,'{"type":"perfect_session","min_answers":20}','precision_pilot',null,130,true),
  ('combo_5','COMBO 5','最大5コンボに到達する。','combo',15,false,'{"type":"combo","value":5}',null,null,210,true),
  ('combo_10','COMBO DRIVER','最大10コンボに到達する。','combo',30,false,'{"type":"combo","value":10}','combo_driver',null,220,true),
  ('combo_20','CHAIN 20','最大20コンボに到達する。','combo',60,false,'{"type":"combo","value":20}',null,null,230,true),
  ('combo_30','CHAIN REACTOR','最大30コンボに到達する。','combo',100,false,'{"type":"combo","value":30}','chain_reactor',null,240,true),
  ('text_10','TEXT SPECIALIST','TEXTを10セッションプレイする。','mode',30,false,'{"type":"mode_sessions","mode":"TEXT","count":10}',null,null,310,true),
  ('keys_10','KEYS SPECIALIST','KEYSを10セッションプレイする。','mode',30,false,'{"type":"mode_sessions","mode":"KEYS","count":10}',null,null,320,true),
  ('hyper_first','HYPER IGNITION','HYPER DRIVEをプレイする。','mode',25,false,'{"type":"any_mode","modes":["HD_TEXT","HD_KEYS"]}',null,null,330,true),
  ('ear_first','EAR CONTACT','EAR LINKをプレイする。','mode',35,false,'{"type":"mode_sessions","mode":"EAR_LINK","count":1}',null,null,340,true),
  ('all_modes','COSMOS EXPLORER','TEXT / KEYS / HD TEXT / HD KEYS / EAR LINKをすべてプレイする。','mode',100,false,'{"type":"all_modes","modes":["TEXT","KEYS","HD_TEXT","HD_KEYS","EAR_LINK"]}','cosmos_explorer',null,350,true),
  ('interval_all_seen','13 SIGNALS','13音程すべてに3回答以上取り組む。','interval',50,false,'{"type":"interval_mastery","min_seen":3,"min_accuracy":0}',null,null,410,true),
  ('interval_80','INTERVAL NAVIGATOR','13音程すべて3回答以上・正答率80%以上に到達する。','interval',120,false,'{"type":"interval_mastery","min_seen":3,"min_accuracy":80}','interval_navigator',null,420,true),
  ('interval_90','INTERVAL MASTER','13音程すべて5回答以上・正答率90%以上に到達する。','interval',200,false,'{"type":"interval_mastery","min_seen":5,"min_accuracy":90}',null,null,430,true),
  ('streak_3','THREE DAY ORBIT','3日連続でプレイする。','streak',30,false,'{"type":"streak_days","days":3}',null,null,510,true),
  ('streak_7','SEVEN DAY ORBIT','7日連続でプレイする。','streak',80,false,'{"type":"streak_days","days":7}','seven_day_orbit',null,520,true),
  ('streak_14','FOURTEEN DAY ORBIT','14日連続でプレイする。','streak',160,false,'{"type":"streak_days","days":14}',null,null,530,true),
  ('public_record','OPEN CHANNEL','ランキングへ記録を1件公開する。','ranking',20,false,'{"type":"public_rank","rank":999999}',null,null,610,true),
  ('rank_top10','TOP TEN','いずれかの殿堂ランキングでTOP10に入る。','ranking',80,false,'{"type":"public_rank","rank":10}','top_ten',null,620,true),
  ('rank_podium','PODIUM','いずれかの殿堂ランキングで3位以内に入る。','ranking',120,false,'{"type":"public_rank","rank":3}',null,null,630,true),
  ('rank_first','NUMBER ONE','いずれかの殿堂ランキングで1位になる。','ranking',200,false,'{"type":"public_rank","rank":1}','number_one',null,640,true),
  ('hidden_ear_perfect','INNER EAR','???','hidden',180,true,'{"type":"perfect_session","mode":"EAR_LINK","min_answers":10}','inner_ear',null,910,true),
  ('hidden_all_mode_perfect','FIVE PERFECT ORBITS','???','hidden',220,true,'{"type":"all_modes_perfect","min_answers":10,"modes":["TEXT","KEYS","HD_TEXT","HD_KEYS","EAR_LINK"]}',null,null,920,true),
  ('hidden_combo_50','GRAVITY CHAIN','???','hidden',220,true,'{"type":"combo","value":50}',null,null,930,true),
  ('hidden_singularity','SINGULARITY','???','hidden',350,true,'{"type":"achievement_combo","ids":["interval_90","streak_14","rank_first","hidden_ear_perfect"]}','singularity',null,990,true)
on conflict (id) do update set display_name=excluded.display_name,description=excluded.description,category=excluded.category,points=excluded.points,hidden=excluded.hidden,requirement=excluded.requirement,reward_title_id=excluded.reward_title_id,reward_frame_id=excluded.reward_frame_id,sort_order=excluded.sort_order,is_active=true;

insert into public.daily_mission_catalog
  (id,display_name,description,mission_type,target_value,config,reward_points,is_active)
values
  ('daily_play_2','WARM UP ORBIT','今日2セッションプレイする。','play_count',2,'{}',10,true),
  ('daily_answers_15','15 CONTACTS','今日15問回答する。','answer_count',15,'{}',10,true),
  ('daily_correct_10','10 CLEAR SIGNALS','今日10問正解する。','correct_answers',10,'{}',10,true),
  ('daily_combo_5','COMBO 5','今日の最大コンボ5に到達する。','combo_peak',5,'{}',10,true),
  ('daily_text','TEXT ORBIT','今日TEXTを1セッションプレイする。','mode_play',1,'{"mode":"TEXT"}',10,true),
  ('daily_keys','KEYS ORBIT','今日KEYSを1セッションプレイする。','mode_play',1,'{"mode":"KEYS"}',10,true),
  ('daily_two_modes','DUAL ROUTE','今日2種類のモードをプレイする。','distinct_modes',2,'{}',15,true),
  ('daily_perfect','CLEAN RUN','5問以上のセッションを正答率100%で1回完了する。','perfect_session',1,'{"min_answers":5}',15,true),
  ('daily_accuracy90','PRECISION CHECK','5問以上・正答率90%以上のセッションを1回完了する。','accuracy_session',1,'{"min_answers":5,"min_accuracy":90}',15,true),
  ('daily_hyper','HYPER SPARK','今日HYPER DRIVEを1回プレイする。','mode_group_play',1,'{"modes":["HD_TEXT","HD_KEYS"]}',15,true),
  ('daily_ear','EAR SIGNAL','今日EAR LINKを1回プレイする。','mode_play',1,'{"mode":"EAR_LINK"}',20,true)
on conflict (id) do update set display_name=excluded.display_name,description=excluded.description,mission_type=excluded.mission_type,target_value=excluded.target_value,config=excluded.config,reward_points=excluded.reward_points,is_active=true;

create or replace function public.longest_play_streak(p_player_id uuid)
returns integer language sql stable security definer set search_path='' as $$
  with days as (select distinct (played_at at time zone 'Asia/Tokyo')::date d from public.play_sessions where player_id=p_player_id),
  numbered as (select d,d-(row_number() over(order by d))::integer grp from days),
  streaks as (select count(*)::integer n from numbered group by grp)
  select coalesce(max(n),0) from streaks;
$$;

create or replace function public.achievement_requirement_met(p_player_id uuid,p_requirement jsonb)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_type text:=coalesce(p_requirement->>'type',''); v_count integer; v_value integer; v_mode text; v_modes text[]; v_min_answers integer; v_min_accuracy numeric; v_rank_target integer; v_snapshot jsonb; v_total integer; v_met integer;
begin
  if p_player_id is null then return false; end if;
  if v_type='sessions' then select count(*) into v_count from public.play_sessions where player_id=p_player_id; return v_count>=coalesce((p_requirement->>'count')::integer,1);
  elsif v_type='perfect_session' then v_min_answers:=coalesce((p_requirement->>'min_answers')::integer,1); v_mode:=nullif(p_requirement->>'mode',''); return exists(select 1 from public.play_sessions where player_id=p_player_id and total_answers>=v_min_answers and correct_answers=total_answers and (v_mode is null or mode=v_mode));
  elsif v_type='combo' then v_value:=coalesce((p_requirement->>'value')::integer,1); select coalesce(max(max_combo),0) into v_count from public.play_sessions where player_id=p_player_id; return v_count>=v_value;
  elsif v_type='mode_sessions' then v_mode:=p_requirement->>'mode'; select count(*) into v_count from public.play_sessions where player_id=p_player_id and mode=v_mode; return v_count>=coalesce((p_requirement->>'count')::integer,1);
  elsif v_type='any_mode' then select array_agg(value::text) into v_modes from jsonb_array_elements_text(p_requirement->'modes'); return exists(select 1 from public.play_sessions where player_id=p_player_id and mode=any(v_modes));
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

create or replace function public.ensure_my_daily_missions()
returns void language plpgsql security definer set search_path='' as $$
declare v_player_id uuid:=public.current_player_id(); v_date date:=(now() at time zone 'Asia/Tokyo')::date;
begin
 if v_player_id is null then raise exception 'Player account required'; end if;
 if (select count(*) from public.player_daily_mission_progress where player_id=v_player_id and mission_date=v_date)<3 then
   delete from public.player_daily_mission_progress where player_id=v_player_id and mission_date=v_date;
   insert into public.player_daily_mission_progress(player_id,mission_date,slot,mission_id,progress,completed)
   select v_player_id,v_date,row_number() over(order by pick_key)::smallint,mission_id,0,false from (select id mission_id,md5(v_player_id::text||v_date::text||id) pick_key from public.daily_mission_catalog where is_active order by pick_key limit 3) q;
 end if;
end; $$;

create or replace function public.refresh_my_daily_missions()
returns void language plpgsql security definer set search_path='' as $$
declare v_player_id uuid:=public.current_player_id(); v_date date:=(now() at time zone 'Asia/Tokyo')::date; r record; v_progress integer; v_min_answers integer; v_min_accuracy numeric; v_mode text; v_modes text[];
begin
 if v_player_id is null then raise exception 'Player account required'; end if; perform public.ensure_my_daily_missions();
 for r in select p.slot,p.mission_id,d.mission_type,d.target_value,d.config from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=v_date loop
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
  update public.player_daily_mission_progress p set progress=least(v_progress,r.target_value),completed=(v_progress>=r.target_value),completed_at=case when v_progress>=r.target_value then coalesce(p.completed_at,now()) else null end where p.player_id=v_player_id and p.mission_date=v_date and p.slot=r.slot;
 end loop;
end; $$;

create or replace function public.evaluate_my_progress()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_player_id uuid:=public.current_player_id(); v_before_ach text[]; v_before_titles text[]; v_before_frames text[]; v_before_completed text[]; v_points integer; v_best_point_frame text; v_current_frame text; v_current_tier integer; v_best_tier integer; v_new_ach jsonb; v_new_titles jsonb; v_new_frames jsonb; v_new_missions jsonb;
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
 insert into public.player_frames(player_id,frame_id) select distinct v_player_id,a.reward_frame_id from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id and a.reward_frame_id is not null on conflict do nothing;
 select coalesce(sum(a.points),0) into v_points from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id;
 v_points:=v_points+coalesce((select sum(d.reward_points) from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.completed),0);
 update public.players set achievement_points=v_points where id=v_player_id;
 insert into public.player_frames(player_id,frame_id) select v_player_id,f.id from public.frame_catalog f where f.is_active and f.unlock_rule->>'type'='points' and v_points>=f.points_required on conflict do nothing;
 insert into public.player_frames(player_id,frame_id) select v_player_id,f.id from public.frame_catalog f where f.is_active and f.unlock_rule->>'type'='achievement_combo' and public.achievement_requirement_met(v_player_id,f.unlock_rule) on conflict do nothing;
 select p.equipped_frame_id,coalesce(f.tier,0) into v_current_frame,v_current_tier from public.players p left join public.frame_catalog f on f.id=p.equipped_frame_id where p.id=v_player_id;
 select f.id,f.tier into v_best_point_frame,v_best_tier from public.player_frames pf join public.frame_catalog f on f.id=pf.frame_id where pf.player_id=v_player_id and (f.id='normal' or f.unlock_rule->>'type'='points') order by f.tier desc limit 1;
 if v_best_point_frame is not null and coalesce((select unlock_rule->>'type' from public.frame_catalog where id=v_current_frame),'points') in('points','') and coalesce(v_best_tier,0)>coalesce(v_current_tier,0) then update public.players set equipped_frame_id=v_best_point_frame where id=v_player_id; end if;
 update public.players p set main_title_id=(select pt.title_id from public.player_titles pt join public.title_catalog t on t.id=pt.title_id where pt.player_id=v_player_id order by t.sort_order,pt.unlocked_at limit 1) where p.id=v_player_id and p.main_title_id is null and exists(select 1 from public.player_titles where player_id=v_player_id);
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.display_name,'description',a.description,'points',a.points,'hidden',a.hidden) order by a.sort_order),'[]'::jsonb) into v_new_ach from public.player_achievements pa join public.achievement_catalog a on a.id=pa.achievement_id where pa.player_id=v_player_id and not(pa.achievement_id=any(v_before_ach));
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.display_name) order by t.sort_order),'[]'::jsonb) into v_new_titles from public.player_titles pt join public.title_catalog t on t.id=pt.title_id where pt.player_id=v_player_id and not(pt.title_id=any(v_before_titles));
 select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'name',f.display_name,'tier',f.tier,'animated',f.animated,'hidden',f.hidden) order by f.tier),'[]'::jsonb) into v_new_frames from public.player_frames pf join public.frame_catalog f on f.id=pf.frame_id where pf.player_id=v_player_id and not(pf.frame_id=any(v_before_frames));
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.display_name,'reward_points',d.reward_points) order by p.slot),'[]'::jsonb) into v_new_missions from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=(now() at time zone 'Asia/Tokyo')::date and p.completed and not(p.mission_id=any(v_before_completed));
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
 select coalesce(jsonb_agg(jsonb_build_object('slot',p.slot,'date',p.mission_date,'id',d.id,'name',d.display_name,'description',d.description,'progress',p.progress,'target',d.target_value,'completed',p.completed,'completed_at',p.completed_at,'reward_points',d.reward_points) order by p.slot),'[]'::jsonb) into v_daily from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=v_date;
 return jsonb_build_object('player',v_player,'achievements',v_achievements,'titles',v_titles,'frames',v_frames,'daily_missions',v_daily,'mission_date',v_date);
end; $$;

create or replace function public.toggle_featured_achievement(p_achievement_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_player_id uuid:=public.current_player_id(); v_existing smallint; v_slot smallint;
begin
 if v_player_id is null then raise exception 'Player account required'; end if;
 select featured_order into v_existing from public.player_achievements where player_id=v_player_id and achievement_id=p_achievement_id; if not found then raise exception 'Achievement is not unlocked'; end if;
 if v_existing is not null then update public.player_achievements set featured_order=null where player_id=v_player_id and achievement_id=p_achievement_id; return jsonb_build_object('featured',false,'slot',null); end if;
 select s::smallint into v_slot from generate_series(1,3) s where not exists(select 1 from public.player_achievements where player_id=v_player_id and featured_order=s) order by s limit 1; if v_slot is null then raise exception 'Three featured achievements are already selected'; end if;
 update public.player_achievements set featured_order=v_slot where player_id=v_player_id and achievement_id=p_achievement_id; return jsonb_build_object('featured',true,'slot',v_slot);
end; $$;

revoke execute on function public.longest_play_streak(uuid) from public,anon,authenticated;
revoke execute on function public.achievement_requirement_met(uuid,jsonb) from public,anon,authenticated;
revoke execute on function public.ensure_my_daily_missions() from public,anon;
revoke execute on function public.refresh_my_daily_missions() from public,anon;
revoke execute on function public.evaluate_my_progress() from public,anon;
revoke execute on function public.get_my_cosmos_progress() from public,anon;
revoke execute on function public.toggle_featured_achievement(text) from public,anon;
grant execute on function public.ensure_my_daily_missions() to authenticated;
grant execute on function public.refresh_my_daily_missions() to authenticated;
grant execute on function public.evaluate_my_progress() to authenticated;
grant execute on function public.get_my_cosmos_progress() to authenticated;
grant execute on function public.toggle_featured_achievement(text) to authenticated;

commit;
