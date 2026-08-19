-- INTERVAL COSMOS v2.0.5
-- Security hardening for internal trigger/event-trigger helpers.
-- Run after the base schema and current migrations.

begin;

-- `set_updated_at` is a trigger helper and should not inherit a mutable caller
-- search_path. It is never meant to be invoked directly from PostgREST.
alter function public.set_updated_at() set search_path = '';

-- Internal trigger / event-trigger helpers must not be exposed as callable RPCs.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
revoke execute on function public.sync_public_profile() from public, anon, authenticated;
revoke execute on function public.set_updated_at() from public, anon, authenticated;

commit;
