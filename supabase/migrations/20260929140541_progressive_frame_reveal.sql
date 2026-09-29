-- Progressive frame appearance and condition disclosure; no owned awards change.
begin;
create or replace function public.get_my_cosmos_progress()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_player_id uuid:=public.current_player_id(); v_date date:=(now() at time zone 'Asia/Tokyo')::date; v_player jsonb; v_achievements jsonb; v_titles jsonb; v_frames jsonb; v_daily jsonb;
begin
 if v_player_id is null then raise exception 'Player account required'; end if; perform public.evaluate_my_progress(); select to_jsonb(x) into v_player from public.get_my_player() x;
 select coalesce(jsonb_agg(item order by sort_order),'[]'::jsonb) into v_achievements from (select a.sort_order,case when a.hidden and pa.achievement_id is null then jsonb_build_object('id',null,'name','???','description','???','category','hidden','points',null,'hidden',true,'unlocked',false,'featured_order',null) else jsonb_build_object('id',a.id,'name',a.display_name,'description',a.description,'category',a.category,'points',coalesce(pa.points_awarded,a.points),'hidden',a.hidden,'unlocked',(pa.achievement_id is not null),'unlocked_at',pa.unlocked_at,'featured_order',pa.featured_order,'requirement',case when a.hidden and pa.achievement_id is null then null else a.requirement end) end item from public.achievement_catalog a left join public.player_achievements pa on pa.player_id=v_player_id and pa.achievement_id=a.id where a.is_active) q;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.display_name,'description',t.description,'hidden',t.hidden,'unlocked',(pt.title_id is not null),'unlocked_at',pt.unlocked_at,'equipped',(t.id=(select main_title_id from public.players where id=v_player_id))) order by t.sort_order),'[]'::jsonb) into v_titles from public.title_catalog t left join public.player_titles pt on pt.player_id=v_player_id and pt.title_id=t.id where t.is_active and (not t.hidden or pt.title_id is not null);
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',f.id,'name',case when f.secret and not f.owned then '???' else f.display_name end,
 'tier',f.tier,'points_required',case when f.revealed then f.points_required else null end,
 'animated',f.animated,'hidden',f.secret,'appearance_hidden',f.secret and not f.owned,
 'conditions_revealed',f.revealed,'unlock_rule',case when f.revealed then f.unlock_rule else null end,
 'requirement_descriptions',case when f.revealed then (select jsonb_agg(a.description order by a.sort_order) from public.achievement_catalog a where f.unlock_rule->'ids' ? a.id) else null end,
 'unlocked',f.owned,'unlocked_at',f.unlocked_at,'equipped',f.id=(select equipped_frame_id from public.players where id=v_player_id)
 ) order by f.tier),'[]'::jsonb) into v_frames from (
 select f.*,pf.frame_id is not null as owned,pf.unlocked_at,
 f.id in ('supernova','event_horizon','pulsar','omega') as secret,
 (f.id not in ('supernova','event_horizon','pulsar','omega') or pf.frame_id is not null or exists(
 select 1 from public.player_frames previous where previous.player_id=v_player_id and previous.frame_id=f.unlock_rule->>'requires_frame')) as revealed
 from public.frame_catalog f left join public.player_frames pf on pf.player_id=v_player_id and pf.frame_id=f.id where f.is_active
 ) f;
 select coalesce(jsonb_agg(jsonb_build_object('slot',p.slot,'date',p.mission_date,'id',d.id,'name',d.display_name,'description',d.description,'progress',p.progress,'target',d.target_value,'completed',p.completed,'completed_at',p.completed_at,'reward_points',coalesce(p.reward_points_awarded,d.reward_points)) order by p.slot),'[]'::jsonb) into v_daily from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.mission_date=v_date;
 return jsonb_build_object('player',v_player,'achievements',v_achievements,'titles',v_titles,'frames',v_frames,'daily_missions',v_daily,'mission_date',v_date,
 'mode_clear_rewards',(select jsonb_agg(jsonb_build_object('mode',c.mode,'reward_points',c.reward_points,'min_answers',c.min_answers,'min_accuracy',c.min_accuracy,'earned_count',coalesce(r.n,0),'daily_limit',5,'completed',coalesce(r.n,0)>=5) order by c.reward_points,c.mode) from public.mode_clear_reward_catalog c left join (select mode,count(*) n from public.player_mode_clear_rewards where player_id=v_player_id and reward_date=v_date group by mode) r on r.mode=c.mode),
 'point_breakdown',jsonb_build_object('achievements',(select coalesce(sum(coalesce(p.points_awarded,a.points)),0) from public.player_achievements p join public.achievement_catalog a on a.id=p.achievement_id where p.player_id=v_player_id),'daily',(select coalesce(sum(coalesce(p.reward_points_awarded,d.reward_points)),0) from public.player_daily_mission_progress p join public.daily_mission_catalog d on d.id=p.mission_id where p.player_id=v_player_id and p.completed),'mode_clear',(select coalesce(sum(reward_points),0) from public.player_mode_clear_rewards where player_id=v_player_id)));
end; $$;
commit;
