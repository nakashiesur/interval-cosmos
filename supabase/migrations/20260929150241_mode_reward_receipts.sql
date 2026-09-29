begin;
alter table public.player_mode_clear_rewards add column session_id uuid references public.play_sessions(id) on delete set null;
create unique index mode_reward_session_unique on public.player_mode_clear_rewards(session_id) where session_id is not null;
do $$ declare definition text; begin
 select pg_get_functiondef('public.evaluate_my_progress()'::regprocedure) into definition;
 definition:=replace(definition,'reward_slot,reward_points)','reward_slot,reward_points,session_id)');
 definition:=replace(definition,'q.slot::smallint,q.reward_points from (','q.slot::smallint,q.reward_points,q.session_id from (');
 definition:=replace(definition,'reward_date,s.mode,c.reward_points,','reward_date,s.mode,c.reward_points,s.id as session_id,');
 if position('q.session_id from (' in definition)=0 then raise exception 'Reward evaluator shape changed';end if;
 execute definition;
end $$;
create function public.get_my_mode_reward_receipt(p_client_event_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p uuid:=public.current_player_id();s public.play_sessions%rowtype;c public.mode_clear_reward_catalog%rowtype;points integer;used integer;
begin
 if p is null then raise exception 'Account required';end if;
 select * into s from public.play_sessions where player_id=p and client_event_id=p_client_event_id;
 if not found then raise exception 'Play not found';end if;
 select * into c from public.mode_clear_reward_catalog where mode=s.mode;
 if not found or s.source<>'ranked' then return jsonb_build_object('status','ineligible','points',0);end if;
 select coalesce(sum(reward_points),0) into points from public.player_mode_clear_rewards where player_id=p and session_id=s.id;
 select count(*) into used from public.player_mode_clear_rewards where player_id=p and mode=s.mode and reward_date=(s.played_at at time zone 'Asia/Tokyo')::date;
 return jsonb_build_object('mode',s.mode,'points',points,'remaining',greatest(0,5-used),'limit',5,'min_answers',c.min_answers,'min_accuracy',c.min_accuracy,'status',case when points>0 then 'earned' when s.total_answers<c.min_answers or s.correct_answers::numeric*100/greatest(s.total_answers,1)<c.min_accuracy then 'conditions_not_met' when used>=5 then 'daily_limit' else 'ineligible' end);
end $$;
revoke all on function public.get_my_mode_reward_receipt(uuid) from public,anon;
grant execute on function public.get_my_mode_reward_receipt(uuid) to authenticated;
commit;
