-- READ ONLY. Inspect actual production shape before designing an upgrade.
-- Contains no account rows, student numbers, names, tokens, or record contents.
begin read only;
select jsonb_build_object(
  'tables', (select coalesce(jsonb_agg(jsonb_build_object(
    'name', c.relname, 'rls', c.relrowsecurity,
    'estimated_rows', c.reltuples::bigint
  ) order by c.relname),'[]'::jsonb)
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'),
  'columns', (select coalesce(jsonb_agg(jsonb_build_object(
    'table', table_name, 'column', column_name, 'type', data_type,
    'nullable', is_nullable
  ) order by table_name,ordinal_position),'[]'::jsonb)
    from information_schema.columns where table_schema='public'
      and table_name in ('profiles','rankings','players','player_devices','play_sessions','ranking_bests','learning_answers')),
  'functions', (select coalesce(jsonb_agg(jsonb_build_object(
    'name',p.proname,'arguments',pg_get_function_identity_arguments(p.oid),
    'security_definer',p.prosecdef
  ) order by p.proname),'[]'::jsonb)
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'),
  'legacy_present', to_regclass('public.profiles') is not null or to_regclass('public.rankings') is not null,
  'v205_present', to_regclass('public.players') is not null,
  'migration_history_present', to_regclass('supabase_migrations.schema_migrations') is not null
) as upgrade_shape;
rollback;
