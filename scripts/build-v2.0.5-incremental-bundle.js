// One-time update for the production shape inspected on 2026-09-27.
// Never includes the destructive fresh-build base or progression catalog seeds.
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const unwrap = sql => sql.replace(/^begin;\s*$/gmi, '').replace(/^commit;\s*$/gmi, '');
const progression = read('sql/progression-v2.0.5.sql');
const frame = progression.match(/create or replace function public\.evaluate_my_progress\(\)[\s\S]*?end; \$\$;/i);
if (!frame) throw new Error('Progression function boundary changed; review extraction');
const sources = [
  'sql/avatar-catalog-v2.0.5.sql',
  'supabase/migrations/20260915032833_offline_submission_guard.sql',
  'supabase/migrations/20260924145138_shared_learning_answers.sql',
];
const preflight = `do $preflight$
begin
  if to_regclass('public.players') is null or to_regclass('public.ranking_bests') is null then
    raise exception 'Expected an existing v2.0.5 database; refusing update';
  end if;
  if to_regclass('public.profiles') is not null or to_regclass('public.rankings') is not null then
    raise exception 'Legacy database requires a different migration';
  end if;
  if to_regclass('public.learning_answers') is not null then
    raise exception 'Shared answers already installed; refusing to replay update';
  end if;
  if exists(select 1 from pg_policies where schemaname='public' and tablename='ranking_bests' and qual like '%public_score%') then
    raise exception 'Apply ranking privacy hardening before this update';
  end if;
end;
$preflight$;`;
const sql = '-- ONE-TIME INCREMENTAL UPDATE. Review and back up before production use.\n'
  + 'begin;\nset local lock_timeout = \'5s\';\n' + preflight + '\n'
  + sources.map(name => `-- SOURCE: ${name}\n${unwrap(read(name))}`).join('\n')
  + '\n-- Only the selected-frame fix, without reseeding progression.\n' + frame[0]
  + '\ncommit;\n';
fs.mkdirSync(path.join(root, 'dist'), { recursive: true });
fs.writeFileSync(path.join(root, 'dist/interval-cosmos-v2.0.5-incremental.sql'), sql);
console.log('WROTE dist/interval-cosmos-v2.0.5-incremental.sql');
