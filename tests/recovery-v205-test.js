const fs = require('fs');
const path = require('path');

const sql = fs.readFileSync(path.join(__dirname,'..','sql','account-recovery-v2.0.5.sql'),'utf8');
const js = fs.readFileSync(path.join(__dirname,'..','phase2-recovery-v205.js'),'utf8');
const css = fs.readFileSync(path.join(__dirname,'..','phase2-recovery-v205.css'),'utf8');
const index = fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw = fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

const assertions = [
  ['private recovery credential table', sql.includes('player_recovery_credentials') && sql.includes('recovery_code_hash') && sql.includes('revoke all on table public.player_recovery_credentials')],
  ['bcrypt hash only', sql.includes("extensions.crypt") && sql.includes("extensions.gen_salt('bf', 10)") && !sql.includes('recovery_code text not null')],
  ['student code validation', sql.includes("^[A-Z0-9]{8,20}$") && sql.includes("~ '[A-Z]'") && sql.includes("~ '[0-9]'" )],
  ['registration requires recovery code', sql.includes('p_recovery_code text') && js.includes('v205RecoveryCodeConfirm')],
  ['self-service recovery rpc', sql.includes('recover_student_account') && js.includes('recoverStudentAccount')],
  ['wrong attempts persist without exception', sql.includes('remaining_attempts') && sql.includes("interval '15 minutes'") && sql.includes('v_new_failed >= 5')],
  ['recovery links auth to existing player', sql.includes("'Recovered device'") && sql.includes('insert into public.player_devices')],
  ['settings can change code', sql.includes('set_my_recovery_code') && js.includes('v205RecoverySettingsForm')],
  ['PIN path remains available', js.includes('v205LinkForm') && js.includes('data-v205-recovery-open')],
  ['cookie loss copy present', js.includes('Cookie') && js.includes('学習履歴・ランキング・COSMOS PT・フレーム')],
  ['recovery assets loaded', index.includes('phase2-recovery-v205.js?v=alpha4.2') && index.includes('phase2-recovery-v205.css?v=alpha4.2')],
  ['recovery assets cached', sw.includes('phase2-recovery-v205.js') && sw.includes('phase2-recovery-v205.css')],
  ['recovery mobile styling', css.includes('@media(max-width:700px)')],
];

let fail=0;
for(const [name,ok] of assertions){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
