-- Dedicated Final Fresh Build 0927 only. Every mutation rolls back.
begin;
update public.players set is_admin=true where player_name='QA-ADMIN-0927' and account_type='staff';
select set_config('request.jwt.claim.sub',(select d.auth_user_id::text from public.player_devices d join public.players p on p.id=d.player_id where p.player_name='QA-ADMIN-0927' limit 1),true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select set_config('qa.assignment',public.create_assignment_v2('QA rollback boundary','synthetic',array['TEXT','KEYS'],array['P1','M2'],now()-interval '1 hour',now()+interval '1 hour',50,80,true)::text,true);
reset role;
select set_config('request.jwt.claim.sub',(select d.auth_user_id::text from public.player_devices d join public.players p on p.id=d.player_id where p.student_number='99092701' limit 1),true);
set local role authenticated;
do $$
declare a uuid:=current_setting('qa.assignment')::uuid; event uuid:=gen_random_uuid(); r jsonb; t timestamptz;
begin
  if public.current_player_id() is null then raise exception 'Student fixture missing'; end if;
  select start_at into t from public.assignments where id=a;
  r:=public.submit_assignment_session_v2(event,a,'TEXT',80,5,5,5,500,'{}',t);
  if not (r->>'this_run_achieved')::boolean then raise exception 'Exact start rejected'; end if;
  r:=public.submit_assignment_session_v2(event,a,'TEXT',80,5,5,5,500,'{}',t);
  if not (r->>'duplicate')::boolean then raise exception 'Duplicate not recognized'; end if;
  select deadline_at into t from public.assignments where id=a;
  r:=public.submit_assignment_session_v2(gen_random_uuid(),a,'KEYS',10,5,1,1,500,'{}',t);
  if (r->>'this_run_achieved')::boolean then raise exception 'Low run incorrectly achieved'; end if;
  if not (r->>'achieved')::boolean then raise exception 'Prior achievement lost'; end if;
  if (r->>'attempts')::integer <> 2 then raise exception 'Attempt count incorrect'; end if;
  begin
    perform public.submit_assignment_session_v2(gen_random_uuid(),a,'TEXT',10,5,1,1,500,'{}',t+interval '1 microsecond');
    raise exception 'Late accepted';
  exception when raise_exception then
    if sqlerrm not like '%outside the allowed time window%' then raise; end if;
  end;
  select start_at into t from public.assignments where id=a;
  begin
    perform public.submit_assignment_session_v2(gen_random_uuid(),a,'TEXT',10,5,1,1,500,'{}',t-interval '1 microsecond');
    raise exception 'Early accepted';
  exception when raise_exception then
    if sqlerrm not like '%outside the allowed time window%' then raise; end if;
  end;
  begin
    perform public.submit_assignment_session_v2(gen_random_uuid(),a,'EAR_LINK',10,5,1,1,500,'{}',now());
    raise exception 'Wrong mode accepted';
  exception when raise_exception then
    if sqlerrm not like '%mode is not allowed%' then raise; end if;
  end;
  begin
    perform public.get_assignment_results(a);
    raise exception 'Student could read teacher results';
  exception when raise_exception then
    if sqlerrm not ilike '%admin%required%' then raise; end if;
  end;
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select d.auth_user_id::text from public.player_devices d join public.players p on p.id=d.player_id where p.player_name='QA-ADMIN-0927' limit 1),true);
set local role authenticated;
select public.get_assignment_results(current_setting('qa.assignment')::uuid) as teacher_results;
reset role;
rollback;
