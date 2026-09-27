-- INTERVAL COSMOS v2.0.5
-- Security hardening for internal trigger/event-trigger helpers and privileged RPCs.
-- Run after the base schema and current migrations.
--
-- Some helpers are supplied by the Supabase project template rather than by
-- the INTERVAL COSMOS base schema. Keep this migration idempotent so a truly
-- fresh project and an already-initialized development project both work.

begin;

do $$
begin
  if to_regprocedure('public.set_updated_at()') is not null then
    execute 'alter function public.set_updated_at() set search_path = ''''';
    execute 'revoke execute on function public.set_updated_at() from public, anon, authenticated';
  end if;

  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke execute on function public.rls_auto_enable() from public, anon, authenticated';
  end if;

  if to_regprocedure('public.sync_public_profile()') is not null then
    execute 'revoke execute on function public.sync_public_profile() from public, anon, authenticated';
  end if;

  -- Device-link RPCs require auth.uid() and are intended for signed-in
  -- (including Supabase anonymous-auth) users only. Some project templates may
  -- retain an explicit anon EXECUTE grant even after PUBLIC is revoked, so
  -- revoke anon explicitly while preserving the authenticated grant.
  if to_regprocedure('public.create_device_link_request()') is not null then
    execute 'revoke execute on function public.create_device_link_request() from public, anon';
    execute 'grant execute on function public.create_device_link_request() to authenticated';
  end if;
  if to_regprocedure('public.claim_device_link_request(text)') is not null then
    execute 'revoke execute on function public.claim_device_link_request(text) from public, anon';
    execute 'grant execute on function public.claim_device_link_request(text) to authenticated';
  end if;
  if to_regprocedure('public.get_device_link_source_status(uuid)') is not null then
    execute 'revoke execute on function public.get_device_link_source_status(uuid) from public, anon';
    execute 'grant execute on function public.get_device_link_source_status(uuid) to authenticated';
  end if;
  if to_regprocedure('public.get_device_link_target_status(uuid)') is not null then
    execute 'revoke execute on function public.get_device_link_target_status(uuid) from public, anon';
    execute 'grant execute on function public.get_device_link_target_status(uuid) to authenticated';
  end if;
  if to_regprocedure('public.confirm_device_link_request(uuid)') is not null then
    execute 'revoke execute on function public.confirm_device_link_request(uuid) from public, anon';
    execute 'grant execute on function public.confirm_device_link_request(uuid) to authenticated';
  end if;
  if to_regprocedure('public.cancel_device_link_request(uuid)') is not null then
    execute 'revoke execute on function public.cancel_device_link_request(uuid) from public, anon';
    execute 'grant execute on function public.cancel_device_link_request(uuid) to authenticated';
  end if;
end;
$$;

commit;
