-- INTERVAL COSMOS v2.0.5
-- Compatibility patch: account-recovery-v2.0.5.sql historically redefined
-- create_player_account() with the old `default` avatar fallback.
-- The canonical v2.0.5 avatar catalog retires that placeholder, so omitted or
-- empty avatar values must resolve to `nova` as well.
-- Run AFTER sql/account-recovery-v2.0.5.sql.

begin;

do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.create_player_account(text,text,text,text,text,text)'::regprocedure)
    into v_def;

  if v_def is null then
    raise exception 'create_player_account(text,text,text,text,text,text) is missing';
  end if;

  v_def := replace(v_def, "DEFAULT 'default'::text", "DEFAULT 'nova'::text");
  v_def := replace(v_def, "default 'default'", "default 'nova'");
  v_def := replace(v_def, "coalesce(nullif(p_avatar_id,''), 'default')", "coalesce(nullif(p_avatar_id,''), 'nova')");

  execute v_def;
end;
$$;

notify pgrst, 'reload schema';
commit;
