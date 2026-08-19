const fs=require('fs');
const path=require('path');

const root=fs.readFileSync(path.join(__dirname,'..','supabase_setup.sql'),'utf8').trim();
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const migrationOrder=fs.readFileSync(path.join(__dirname,'..','sql','V2.0.5_MIGRATION_ORDER.md'),'utf8');
const migrationRunner=fs.readFileSync(path.join(__dirname,'..','scripts','apply-v2.0.5-db.sh'),'utf8');

const currentLayers=[
  'supabase-singleton-v205.js','phase0-wallclock-v205.js','phase9-staff-registration-v205.js',
  'phase3-ranking-hotfix-v205.js','phase4-analysis-hotfix-v205.js','phase5-unlock-copy-hotfix-v205.js',
  'phase6-multimode-v205.js','phase7-admin-dashboard-v205.js','phase7-admin-home-dock-v205.js',
  'phase8-pc-controls-v205.js',
];

const dbChain=[
  'supabase_setup.sql',
  'sql/device-link-v2.0.5.sql',
  'sql/account-recovery-v2.0.5.sql',
  'sql/progression-v2.0.5.sql',
  'sql/assignments-v2.0.5.sql',
  'sql/assignments-admin-only-v2.0.5.sql',
  'sql/assignments-multimode-v2.0.5.sql',
  'sql/admin-dashboard-v2.0.5.sql',
  'sql/staff-self-registration-v2.0.5.sql',
];

const tests=[
  ['root supabase_setup.sql is not placeholder',root.length>1000&&!root.includes('__TOO_LARGE_PLACEHOLDER__')],
  ['database migration order documents the complete chain',dbChain.every(x=>migrationOrder.includes(x))],
  ['database migration runner applies the complete chain',dbChain.every(x=>migrationRunner.includes(x))],
  ['database migration runner stops on SQL errors',migrationRunner.includes('ON_ERROR_STOP=1')&&migrationRunner.includes('set -euo pipefail')],
  ['service worker precaches current extension layers',currentLayers.every(x=>sw.includes(x))],
  ['current extension layers are loaded',currentLayers.every(x=>index.includes(x))],
];

let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
if(fail){
  console.error('\nRelease blockers remain. Do not merge v2.0.5 into main.');
}
process.exitCode=fail?1:0;
