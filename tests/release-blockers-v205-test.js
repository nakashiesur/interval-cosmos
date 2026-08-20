const fs=require('fs');
const path=require('path');
const crypto=require('crypto');

const root=fs.readFileSync(path.join(__dirname,'..','supabase_setup.sql'),'utf8').trim();
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const migrationOrder=fs.readFileSync(path.join(__dirname,'..','sql','V2.0.5_MIGRATION_ORDER.md'),'utf8');
const migrationRunner=fs.readFileSync(path.join(__dirname,'..','scripts','apply-v2.0.5-db.sh'),'utf8');
const avatarMigration=fs.readFileSync(path.join(__dirname,'..','sql','avatar-catalog-v2.0.5.sql'),'utf8');
const avatarFallback=fs.readFileSync(path.join(__dirname,'..','sql','account-avatar-default-v2.0.5.sql'),'utf8');
const adminManagement=fs.readFileSync(path.join(__dirname,'..','sql','admin-player-management-v2.0.5.sql'),'utf8');
const securityHardening=fs.readFileSync(path.join(__dirname,'..','sql','security-hardening-v2.0.5.sql'),'utf8');

const currentLayers=[
  'supabase-singleton-v205.js','phase0-wallclock-v205.js','phase9-staff-registration-v205.js',
  'phase3-ranking-hotfix-v205.js','phase4-analysis-hotfix-v205.js','phase5-unlock-copy-hotfix-v205.js',
  'phase6-multimode-v205.js','phase7-admin-dashboard-v205.js','phase7-admin-home-dock-v205.js',
  'phase8-admin-player-management-v205.js','phase8-pc-controls-v205.js',
];

const dbChain=[
  'supabase_setup.sql',
  'sql/avatar-catalog-v2.0.5.sql',
  'sql/device-link-v2.0.5.sql',
  'sql/account-recovery-v2.0.5.sql',
  'sql/account-avatar-default-v2.0.5.sql',
  'sql/progression-v2.0.5.sql',
  'sql/assignments-v2.0.5.sql',
  'sql/assignments-admin-only-v2.0.5.sql',
  'sql/assignments-multimode-v2.0.5.sql',
  'sql/admin-dashboard-v2.0.5.sql',
  'sql/staff-self-registration-v2.0.5.sql',
  'sql/admin-player-management-v2.0.5.sql',
  'sql/security-hardening-v2.0.5.sql',
];

const baseParts=Array.from({length:8},(_,i)=>
  path.join(__dirname,'..','sql','base-v2.0.5',`part-${String(i+1).padStart(2,'0')}.sql`)
);
const restoredBase=baseParts.map(file=>fs.readFileSync(file)).reduce((all,part)=>Buffer.concat([all,part]),Buffer.alloc(0));
const restoredBaseHash=crypto.createHash('sha256').update(restoredBase).digest('hex');
const CANONICAL_PHASE1_SHA256='1949b4dc9aed25c72e93ebce746af363ef51fb771a64ae73817a85be385bba23';

const currentAvatars=['nova','orbit','pulse','prism','comet','nebula','vector','echo','quasar','lumen','wave','aster','teacher'];

const tests=[
  ['root supabase_setup.sql is not placeholder',root.length>1000&&!root.includes('__TOO_LARGE_PLACEHOLDER__')],
  ['root setup includes every restored Phase 1 part',baseParts.every((_,i)=>root.includes(`part-${String(i+1).padStart(2,'0')}.sql`))],
  ['restored Phase 1 SQL matches canonical source hash',restoredBaseHash===CANONICAL_PHASE1_SHA256],
  ['database migration order documents the complete chain',dbChain.every(x=>migrationOrder.includes(x))],
  ['database migration runner applies the complete chain',dbChain.every(x=>migrationRunner.includes(x))],
  ['database migration runner stops on SQL errors',migrationRunner.includes('ON_ERROR_STOP=1')&&migrationRunner.includes('set -euo pipefail')],
  ['canonical avatar migration includes every current avatar',currentAvatars.every(x=>avatarMigration.includes(`'${x}'`))],
  ['canonical avatar migration retires Phase 1 default and defaults new rows to nova',avatarMigration.includes("where id = 'default'")&&avatarMigration.includes("set default 'nova'")),
  ['account RPC fallback follows canonical nova',avatarFallback.includes("DEFAULT 'nova'::text")&&avatarFallback.includes("coalesce(nullif(p_avatar_id,''), 'nova')")],
  ['admin final delete is service-role only',adminManagement.includes("v_role <> 'service_role'")&&adminManagement.includes('grant execute on function public.admin_delete_player_application_row(uuid) to service_role')&&adminManagement.includes('from public, anon, authenticated')],
  ['security hardening is part of release chain',securityHardening.includes('sync_public_profile')&&securityHardening.includes('rls_auto_enable')],
  ['service worker precaches current extension layers',currentLayers.every(x=>sw.includes(x))],
  ['current extension layers are loaded',currentLayers.every(x=>index.includes(x))],
];

let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
if(fail){
  console.error('\nRelease blockers remain. Do not merge v2.0.5 into main.');
}
process.exitCode=fail?1:0;
