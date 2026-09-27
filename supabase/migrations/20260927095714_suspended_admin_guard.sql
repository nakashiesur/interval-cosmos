-- Suspension must revoke authorization even for an already signed-in administrator.
create or replace function public.is_current_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.is_admin and not p.is_suspended
    from public.players p
    join public.player_devices pd on pd.player_id = p.id
    where pd.auth_user_id = (select auth.uid())
    limit 1
  ), false);
$$;
