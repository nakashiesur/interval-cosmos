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

  v_def := replace(v_def, $q$DEFAULT 'default'::text$q$, $q$DEFAULT 'nova'::text$q$);
  v_def := replace(v_def, $q$default 'default'$q$, $q$default 'nova'$q$);
  v_def := replace(v_def, $q$coalesce(nullif(p_avatar_id,''), 'default')$q$, $q$coalesce(nullif(p_avatar_id,''), 'nova')$q$);

  execute v_def;
end;
$$;

notify pgrst, 'reload schema';
commit;
