const fs=require('fs');
const path=require('path');
const sql=fs.readFileSync(path.join(__dirname,'..','sql','assignments-v2.0.5.sql'),'utf8');
const js=fs.readFileSync(path.join(__dirname,'..','phase6-assignments-v205.js'),'utf8');
const singleton=fs.readFileSync(path.join(__dirname,'..','supabase-singleton-v205.js'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

const tests=[
  ['teacher is staff not admin-only', sql.includes("p.account_type = 'staff' or p.is_admin")],
  ['teacher assignment create rpc', sql.includes('create or replace function public.create_assignment(')],
  ['published toggle rpc', sql.includes('set_assignment_published')],
  ['student assignment list rpc', sql.includes('get_my_assignments()')],
  ['teacher results rpc', sql.includes('get_assignment_results')],
  ['highest score policy preserved', js.includes("source:'assignment'") && js.includes('最高スコア')],
  ['unlimited retry copy', js.includes('何度でも挑戦')],
  ['all five ranked modes supported', ['TEXT','KEYS','HD_TEXT','HD_KEYS','EAR_LINK'].every(x=>js.includes(x))],
  ['assignment interval selection', js.includes('data-a-interval') && js.includes('CORE 7')],
  ['wall clock timer', js.includes('wallDeadline:Date.now()') && js.includes('visibilitychange')],
  ['student/teacher ui split', js.includes("p.account_type==='staff'") && js.includes('renderTeacher') && js.includes('renderStudent')],
  ['shared supabase singleton', singleton.includes('__intervalCosmosSingletonWrapped') && singleton.includes('return singleton.client')],
  ['singleton loaded before cloud', index.indexOf('supabase-singleton-v205.js') < index.indexOf('cloud.js')],
  ['assignment assets loaded', index.includes('phase6-assignments-v205.js') && index.includes('phase6-assignments-v205.css')],
  ['assignment assets cached', sw.includes('phase6-assignments-v205.js') && sw.includes('phase6-assignments-v205.css')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
