const fs=require('fs');
const path=require('path');
const sql=fs.readFileSync(path.join(__dirname,'..','sql','admin-dashboard-v2.0.5.sql'),'utf8');
const js=fs.readFileSync(path.join(__dirname,'..','phase7-admin-dashboard-v205.js'),'utf8');
const dock=fs.readFileSync(path.join(__dirname,'..','phase7-admin-home-dock-v205.js'),'utf8');
const css=fs.readFileSync(path.join(__dirname,'..','phase7-admin-dashboard-v205.css'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

const tests=[
  ['overview RPC exists',sql.includes('get_admin_dashboard_overview()')],
  ['student detail RPC exists',sql.includes('get_admin_student_dashboard(p_player_id uuid)')],
  ['both RPCs require admin', (sql.match(/if not public\.is_current_admin\(\) then/g)||[]).length>=2],
  ['student list excludes staff',sql.includes("p.account_type = 'student'")],
  ['30 day aggregation',sql.includes("interval '30 days'")],
  ['mode analysis included',sql.includes('group by ps.mode')],
  ['assignment analysis included',sql.includes('assignment_mode_bests') && sql.includes('assignment_bests')],
  ['latest interval snapshot is explicit',sql.includes("ps.interval_stats ? 'intervals'") && js.includes('最新の習熟スナップショット')],
  ['dashboard button admin-only',js.includes("p?.is_admin") && js.includes('ADMIN DASHBOARD')],
  ['dashboard uses shared singleton only',js.includes('IntervalCosmosSupabaseSingleton') && !js.includes('createClient(')],
  ['student search and course filter',js.includes('v205AdminSearch') && js.includes('v205AdminCourse')],
  ['student drilldown',js.includes('get_admin_student_dashboard') && js.includes('STUDENT DETAIL')],
  ['play-hour analysis',js.includes('PLAY HOURS') && sql.includes("extract(hour from timezone('Asia/Tokyo'"))],
  ['responsive styles included',css.includes('@media(max-width:700px)')],
  ['dashboard assets loaded',index.includes('phase7-admin-dashboard-v205.js') && index.includes('phase7-admin-dashboard-v205.css')],
  ['dashboard assets cached',sw.includes('phase7-admin-dashboard-v205.js') && sw.includes('phase7-admin-dashboard-v205.css')],
  ['admin home dock loaded after dashboard',index.indexOf('phase7-admin-dashboard-v205.js') < index.indexOf('phase7-admin-home-dock-v205.js')],
  ['admin home dock cached',sw.includes('phase7-admin-home-dock-v205.js')],
  ['admin dock gated by is_admin',dock.includes('getCachedPlayer') && dock.includes('is_admin')],
  ['admin dock does not move source controls',dock.includes('v205-admin-dock-source') && !dock.includes('actions.appendChild(dashboard)') && !dock.includes('actions.appendChild(assignment)')],
  ['admin dock uses dedicated entry controls',dock.includes('data-v205-admin-dock-dashboard') && dock.includes('data-v205-admin-dock-assignments')],
  ['ordinary player controls restored outside admin',dock.includes('restoreSources') && dock.includes("classList.remove('v205-admin-dock-source')")],
  ['dock observer is guarded',dock.includes('if (queued) return') && dock.includes('if (arranging) return')],
  ['dashboard injector checks whole document',js.includes("document.querySelector('[data-v205-admin-dashboard-open]')") && !js.includes("footer.querySelector('[data-v205-admin-dashboard-open]')")),
  ['cache version includes freeze fix',sw.includes('alpha6-2') && index.includes('phase7-admin-home-dock-v205.js?v=alpha6.2')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
