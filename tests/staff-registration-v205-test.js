const fs=require('fs');
const path=require('path');

const sql=fs.readFileSync(path.join(__dirname,'..','sql','staff-self-registration-v2.0.5.sql'),'utf8');
const js=fs.readFileSync(path.join(__dirname,'..','phase9-staff-registration-v205.js'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

const tests=[
  ['private real-name column added',sql.includes('add column if not exists real_name text')],
  ['real name explicitly private',sql.includes('never copied to public_profiles')&&js.includes('氏名 <em>PRIVATE</em>')],
  ['staff self-registration rpc exists',sql.includes('create or replace function public.create_staff_account')],
  ['self-registered staff never becomes admin',sql.includes("'teacher',\n    false")&&!sql.includes('is_admin\n  ) values (\n    true')],
  ['staff keeps teacher avatar',sql.includes("'staff'")&&sql.includes("'teacher'")],
  ['staff has no student number/course',sql.includes('student_number')&&sql.includes('course_code')&&sql.includes("'staff',\n    null")],
  ['real name required server-side',sql.includes('Real name must be 2-40 characters')],
  ['private identity getter exists',sql.includes('get_my_private_identity')],
  ['private identity updater is staff-only',sql.includes('update_my_staff_identity')&&sql.includes("v_type <> 'staff'")],
  ['rpc exposed only to authenticated role',sql.includes('grant execute on function public.create_staff_account(text, text) to authenticated')],
  ['staff registration form has distinct public player name',js.includes('プレイヤー名 <em>PUBLIC</em>')&&js.includes('v205StaffPlayerName')],
  ['staff button overrides legacy admin-issued screen',js.includes('[data-v205-action="staff-info"]')&&js.includes('showStaffForm()')],
  ['student registration path untouched',!js.includes('create_player_account')&&!js.includes('v205StudentForm')],
  ['staff profile editor can update private identity',js.includes('v205StaffEditRealName')&&js.includes('updateMyStaffIdentity')],
  ['staff layer uses existing singleton client',js.includes('IntervalCosmosSupabaseSingleton')&&!js.includes('createClient(')],
  ['staff layer loads after cloud and before account gate',index.indexOf('cloud.js')<index.indexOf('phase9-staff-registration-v205.js')&&index.indexOf('phase9-staff-registration-v205.js')<index.indexOf('account-gate.js')],
  ['staff layer is cached',sw.includes('phase9-staff-registration-v205.js')&&sw.includes('alpha8')],
];

let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
