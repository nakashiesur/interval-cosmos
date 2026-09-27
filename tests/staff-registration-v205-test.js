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
  ['staff has no student number',sql.includes("'staff',\n    null")],
  ['staff course is required server-side',sql.includes('p_course_code text')&&sql.includes("raise exception 'Invalid course'")&&sql.includes('p_course_code,\n    \'teacher\'')],
  ['staff normalization preserves course',sql.includes('create or replace function public.normalize_player_fields()')&&!sql.includes('new.course_code := null')],
  ['legacy staff with null course remains migration-safe',sql.includes("account_type = 'staff'\n          and student_number is null\n          and avatar_id = 'teacher'")],
  ['real name required server-side',sql.includes('Real name must be 2-40 characters')],
  ['private identity getter includes course',sql.includes('get_my_private_identity')&&sql.includes('real_name text,\n  course_code text')],
  ['private identity updater is staff-only',sql.includes('update_my_staff_identity')&&sql.includes("v_type <> 'staff'")&&sql.includes('set real_name = btrim(p_real_name),\n      course_code = p_course_code')],
  ['rpc exposed only to authenticated role',sql.includes('grant execute on function public.create_staff_account(text, text, text) to authenticated')],
  ['staff registration form has distinct public player name',js.includes('プレイヤー名 <em>PUBLIC</em>')&&js.includes('v205StaffPlayerName')],
  ['staff registration form requires public course badge',js.includes('所属コース <em>PUBLIC BADGE</em>')&&js.includes('v205StaffCourse')&&js.includes('p_course_code: course')],
  ['all 11 courses are available to staff', ['piano','orchestral','vocal_musical','composition','rock_pops','electronic_organ','sound_design','music_education','music_therapy','child_culture','voice_actor'].every(x=>js.includes(`code:'${x}'`))],
  ['staff button overrides legacy admin-issued screen',js.includes('[data-v205-action="staff-info"]')&&js.includes('showStaffForm()')],
  ['student registration path untouched',!js.includes('create_player_account')&&!js.includes('v205StudentForm')],
  ['staff profile editor can update private identity and course',js.includes('v205StaffEditRealName')&&js.includes('v205StaffEditCourse')&&js.includes('updateMyStaffIdentity(realName, courseCode)')],
  ['staff layer uses existing singleton client',js.includes('IntervalCosmosSupabaseSingleton')&&!js.includes('createClient(')],
  ['staff layer loads after cloud and before account gate',index.indexOf('cloud.js')<index.indexOf('phase9-staff-registration-v205.js')&&index.indexOf('phase9-staff-registration-v205.js')<index.indexOf('account-gate.js')],
  ['staff layer is cached',sw.includes('phase9-staff-registration-v205.js')],
];

let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
