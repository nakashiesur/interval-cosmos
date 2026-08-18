const fs=require('fs');
const path=require('path');
const sql=fs.readFileSync(path.join(__dirname,'..','sql','assignments-v2.0.5.sql'),'utf8');
const adminSql=fs.readFileSync(path.join(__dirname,'..','sql','assignments-admin-only-v2.0.5.sql'),'utf8');
const multiSql=fs.readFileSync(path.join(__dirname,'..','sql','assignments-multimode-v2.0.5.sql'),'utf8');
const js=fs.readFileSync(path.join(__dirname,'..','phase6-assignments-v205.js'),'utf8');
const multiJs=fs.readFileSync(path.join(__dirname,'..','phase6-multimode-v205.js'),'utf8');
const adminPolicy=fs.readFileSync(path.join(__dirname,'..','phase6-admin-policy-v205.js'),'utf8');
const singleton=fs.readFileSync(path.join(__dirname,'..','supabase-singleton-v205.js'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

const tests=[
  ['assignment management corrected to admin-only', adminSql.includes('select p.is_admin and not p.is_suspended') && !adminSql.includes("p.account_type = 'staff' or p.is_admin")],
  ['ordinary staff routed as normal player', adminPolicy.includes("player.account_type === 'staff'") && adminPolicy.includes("account_type: 'student'")],
  ['admin routed to management view', adminPolicy.includes('player.is_admin') && adminPolicy.includes("account_type: 'staff'")],
  ['teacher helper direct browser access revoked', adminSql.includes('from public, anon, authenticated')],
  ['assignment create rpc', sql.includes('create or replace function public.create_assignment(')],
  ['published toggle rpc', sql.includes('set_assignment_published')],
  ['student assignment list rpc', sql.includes('get_my_assignments()')],
  ['admin results rpc', sql.includes('get_assignment_results')],
  ['highest score policy preserved', js.includes("source:'assignment'") && js.includes('最高スコア')],
  ['unlimited retry copy', js.includes('何度でも挑戦')],
  ['all five ranked modes supported', ['TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK'].every(x=>js.includes(x))],
  ['assignment interval selection', js.includes('data-a-interval') && js.includes('CORE 7')],
  ['wall clock timer', js.includes('wallDeadline:Date.now()') && js.includes('visibilitychange')],
  ['admin routing policy loaded before assignment module', index.indexOf('phase6-admin-policy-v205.js') < index.indexOf('phase6-assignments-v205.js')],
  ['shared supabase singleton', singleton.includes('__intervalCosmosSingletonWrapped') && singleton.includes('return singleton.client')],
  ['singleton loaded before cloud', index.indexOf('supabase-singleton-v205.js') < index.indexOf('cloud.js')],
  ['assignment assets loaded', index.includes('phase6-assignments-v205.js') && index.includes('phase6-assignments-v205.css')],
  ['admin policy cached', sw.includes('phase6-admin-policy-v205.js')],
  ['assignment assets cached', sw.includes('phase6-assignments-v205.js') && sw.includes('phase6-assignments-v205.css')],
  ['multi-mode column migration', multiSql.includes('add column if not exists allowed_modes text[]') && multiSql.includes('set allowed_modes = array[mode]')],
  ['per-mode best table', multiSql.includes('create table if not exists public.assignment_mode_bests') && multiSql.includes('primary key (assignment_id, player_id, mode)')],
  ['multi-mode admin create rpc', multiSql.includes('create or replace function public.create_assignment_v2(') && multiSql.includes('p_allowed_modes text[]')],
  ['assignment v2 dedicated submit rpc', multiSql.includes('submit_assignment_session_v2') && multiSql.includes("'this_run_achieved'")),
  ['assignment mode validation server side', multiSql.includes('p_mode = any(v_modes)')],
  ['mixed score families protected', multiSql.includes('Mixed STANDARD/HYPER assignments cannot use one shared score target')),
  ['existing assignment sessions migrated', multiSql.includes("where ps.source = 'assignment'") && multiSql.includes('row_number() over')),
  ['student chooses allowed mode', multiJs.includes('CHOOSE YOUR ROUTE') && multiJs.includes('data-a-mode-start')],
  ['admin can select multiple modes', multiJs.includes('複数選択可／学生が選択') && multiJs.includes('data-a-mode-option')],
  ['mode bests displayed independently', multiJs.includes('MODE BEST SCORE') && multiJs.includes('v205-a-mode-best-grid')],
  ['this run achievement distinguished', multiJs.includes('TARGET ALREADY ACHIEVED') && multiJs.includes('TARGET NOT REACHED') && multiJs.includes('this_run_achieved')],
  ['multi-mode patch loads before legacy assignment module', index.indexOf('phase6-multimode-v205.js') < index.indexOf('phase6-assignments-v205.js')],
  ['multi-mode assets loaded and cached', index.includes('phase6-multimode-v205.css') && sw.includes('phase6-multimode-v205.js') && sw.includes('phase6-multimode-v205.css')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
