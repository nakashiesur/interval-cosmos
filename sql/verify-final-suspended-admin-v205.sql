-- Dedicated final QA project only. All suspension/grants roll back.
begin;
select set_config('request.jwt.claim.sub',(select auth_user_id::text from public.player_devices where player_id='c8877363-e272-4ada-99a0-9e4e12227b8c' limit 1),true);
select set_config('request.jwt.claim.role','authenticated',true);
update public.players set is_admin=true,is_suspended=false where id='c8877363-e272-4ada-99a0-9e4e12227b8c';
set local role authenticated;
do $$ begin if not public.is_current_admin() then raise exception 'Active admin access broken'; end if; perform public.get_admin_dashboard_overview(); end $$;
reset role;
update public.players set is_suspended=true where id='c8877363-e272-4ada-99a0-9e4e12227b8c';
set local role authenticated;
do $$ begin if public.is_current_admin() then raise exception 'Suspended admin access retained'; end if; end $$;
do $$
declare operation text; target uuid:=public.current_player_id();
begin
  if target is null then raise exception 'QA-FINAL-0927 fixture required'; end if;
  foreach operation in array array[
    format('select public.admin_get_player_management(%L)',target),
    format('select public.admin_update_player_profile(%L,%L,%L,%L)',target,'QA0912','piano','nova'),
    format('select public.admin_set_player_suspended(%L,true)',target),
    format('select public.admin_unpublish_player_rankings(%L)',target),
    format('select public.admin_delete_player_rankings(%L)',target),
    'select public.get_admin_dashboard_overview()',
    format('select public.get_admin_student_dashboard(%L)',target),
    'select public.get_teacher_assignments()',
    format('select public.get_assignment_results(%L)',gen_random_uuid()),
    format('select public.set_assignment_published(%L,true)',gen_random_uuid()),
    $q$select public.create_assignment('DENY','DENY','TEXT',array['P1'],now(),now()+interval '1 hour')$q$,
    $q$select public.create_assignment_v2('DENY','DENY',array['TEXT','KEYS'],array['P1'],now(),now()+interval '1 hour')$q$,
    format($q$select public.update_assignment(%L,'DENY','DENY','TEXT',array['P1'],now(),now()+interval '1 hour')$q$,gen_random_uuid())
  ] loop
    begin execute operation; raise exception 'Non-admin operation accepted';
    exception when raise_exception then
      if sqlerrm not ilike '%admin%required%' and sqlerrm <> 'Teacher account required' then raise; end if;
    end;
  end loop;
  if has_function_privilege('authenticated','public.admin_delete_player_application_row(uuid)','execute') then
    raise exception 'Client can execute complete deletion';
  end if;
end;
$$;


reset role;
update public.players set is_suspended=false,is_admin=false where id='c8877363-e272-4ada-99a0-9e4e12227b8c';
set local role authenticated;
do $$
declare operation text; target uuid:=public.current_player_id();
begin
  if target is null then raise exception 'QA-FINAL-0927 fixture required'; end if;
  foreach operation in array array[
    format('select public.admin_get_player_management(%L)',target),
    format('select public.admin_update_player_profile(%L,%L,%L,%L)',target,'QA0912','piano','nova'),
    format('select public.admin_set_player_suspended(%L,true)',target),
    format('select public.admin_unpublish_player_rankings(%L)',target),
    format('select public.admin_delete_player_rankings(%L)',target),
    'select public.get_admin_dashboard_overview()',
    format('select public.get_admin_student_dashboard(%L)',target),
    'select public.get_teacher_assignments()',
    format('select public.get_assignment_results(%L)',gen_random_uuid()),
    format('select public.set_assignment_published(%L,true)',gen_random_uuid()),
    $q$select public.create_assignment('DENY','DENY','TEXT',array['P1'],now(),now()+interval '1 hour')$q$,
    $q$select public.create_assignment_v2('DENY','DENY',array['TEXT','KEYS'],array['P1'],now(),now()+interval '1 hour')$q$,
    format($q$select public.update_assignment(%L,'DENY','DENY','TEXT',array['P1'],now(),now()+interval '1 hour')$q$,gen_random_uuid())
  ] loop
    begin execute operation; raise exception 'Non-admin operation accepted';
    exception when raise_exception then
      if sqlerrm not ilike '%admin%required%' and sqlerrm <> 'Teacher account required' then raise; end if;
    end;
  end loop;
  if has_function_privilege('authenticated','public.admin_delete_player_application_row(uuid)','execute') then
    raise exception 'Client can execute complete deletion';
  end if;
end;
$$;


reset role;
rollback;
