const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const cp=require('child_process');

const root=path.join(__dirname,'..');
const canonicalHash='1949b4dc9aed25c72e93ebce746af363ef51fb771a64ae73817a85be385bba23';
const baseParts=Array.from({length:8},(_,i)=>path.join(root,'sql','base-v2.0.5',`part-${String(i+1).padStart(2,'0')}.sql`));
const currentMigrations=[
  'sql/avatar-catalog-v2.0.5.sql',
  'sql/device-link-v2.0.5.sql',
  'sql/account-recovery-v2.0.5.sql',
  'sql/progression-v2.0.5.sql',
  'sql/assignments-v2.0.5.sql',
  'sql/assignments-admin-only-v2.0.5.sql',
  'sql/assignments-multimode-v2.0.5.sql',
  'sql/admin-dashboard-v2.0.5.sql',
  'sql/staff-self-registration-v2.0.5.sql',
  'sql/admin-player-management-v2.0.5.sql',
];

function sha256(buffer){return crypto.createHash('sha256').update(buffer).digest('hex');}
function check(name,ok){console.log(ok?'PASS':'FAIL',name);if(!ok)process.exitCode=1;}

const restored=Buffer.concat(baseParts.map(file=>fs.readFileSync(file)));
check('restored Phase 1 base matches canonical hash',sha256(restored)===canonicalHash);

cp.execFileSync(process.execPath,[path.join(root,'scripts','build-v2.0.5-supabase-bundle.js')],{cwd:root,stdio:'inherit'});
const bundlePath=path.join(root,'dist','interval-cosmos-v2.0.5-complete.sql');
const bundle=fs.readFileSync(bundlePath,'utf8');

check('generated bundle is substantial',bundle.length>100000);
check('generated bundle has no placeholder',!bundle.includes('__TOO_LARGE_PLACEHOLDER__'));
check('generated bundle has no psql include commands',!/^\\ir\s/m.test(bundle));
check('generated bundle includes every Phase 1 part marker',baseParts.every((_,i)=>bundle.includes(`part-${String(i+1).padStart(2,'0')}.sql`)));
check('generated bundle includes every current migration marker',currentMigrations.every(file=>bundle.includes(file)));
check('generated bundle includes current avatar seed',[
  'nova','orbit','pulse','prism','comet','nebula','vector','echo','quasar','lumen','wave','aster','teacher'
].every(id=>bundle.includes(`'${id}'`)));
check('generated bundle includes admin management RPCs',[
  'admin_get_player_management','admin_update_player_profile','admin_set_player_suspended',
  'admin_unpublish_player_rankings','admin_delete_player_rankings','admin_delete_player_application_row'
].every(name=>bundle.includes(name)));
check('complete deletion server function exists',fs.existsSync(path.join(root,'supabase','functions','admin-delete-player','index.ts')));
check('fresh-build verification SQL exists',fs.existsSync(path.join(root,'sql','verify-v2.0.5-fresh-build.sql')));

try{fs.rmSync(path.join(root,'dist'),{recursive:true,force:true});}catch{}
