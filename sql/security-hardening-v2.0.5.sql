-- INTERVAL COSMOS v2.0.5
-- Security hardening for internal trigger/event-trigger helpers.
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
end;
$$;

commit;
