-- Dedicated QA project only. Temporary role/profile changes all roll back.
begin;
select set_config('request.jwt.claim.sub',(select d.auth_user_id::text from public.player_devices d
  join public.players p on p.id=d.player_id where p.student_number='990912' limit 1),true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
do $$
declare operation text; target uuid:=public.current_player_id();
begin
  if target is null then raise exception 'QA0912 fixture required'; end if;
  foreach operation in array array[
    format('select public.admin_get_player_management(%L)',target),
    format('select public.admin_update_player_profile(%L,%L,%L,%L)',target,'QA0912','piano','nova'),
    format('select public.admin_set_player_suspended(%L,true)',target),
    format('select public.admin_unpublish_player_rankings(%L)',target),
    format('select public.admin_delete_player_rankings(%L)',target),
    'select public.get_admin_dashboard_overview()'
  ] loop
    begin execute operation; raise exception 'Non-admin operation accepted';
    exception when raise_exception then
      if sqlerrm not ilike '%admin%required%' then raise; end if;
    end;
  end loop;
  if has_function_privilege('authenticated','public.admin_delete_player_application_row(uuid)','execute') then
    raise exception 'Client can execute complete deletion';
  end if;
end;
$$;
reset role;
-- Exercise staff admin paths inside this transaction only, never grant persistent access.
update public.players set is_admin=true where id='f14b4ea7-da9d-4943-82a0-b6312ec3b6d3' and account_type='staff';
select set_config('request.jwt.claim.sub','8c97b4a8-0fab-4106-ae10-9a4ac2631e00',true);
set local role authenticated;
do $$
declare target uuid:='5fe4d787-b653-4f78-85cd-ff6e6a509093'; info jsonb;
begin
  if not public.is_current_admin() then raise exception 'Staff admin fixture unavailable'; end if;
  perform public.get_admin_dashboard_overview();
  info:=public.admin_get_player_management(target);
  perform public.admin_update_player_profile(target,info->>'player_name',info->>'course_code',info->>'avatar_id');
  perform public.admin_set_player_suspended(target,true);
  if not (public.admin_get_player_management(target)->>'is_suspended')::boolean then raise exception 'Suspension failed'; end if;
  perform public.admin_set_player_suspended(target,false);
  perform public.admin_unpublish_player_rankings(target);
  begin
    perform public.admin_set_player_suspended(public.current_player_id(),true);
    raise exception 'Self suspension accepted';
  exception when raise_exception then
    if sqlerrm not like '%cannot suspend your own%' then raise; end if;
  end;
end;
$$;
rollback;
