const fs = require('fs');
const path = require('path');

const sql = fs.readFileSync(path.join(__dirname,'..','sql','progression-v2.0.5.sql'),'utf8');
const js = fs.readFileSync(path.join(__dirname,'..','phase5-progression-v205.js'),'utf8');
const copy = fs.readFileSync(path.join(__dirname,'..','phase5-unlock-copy-hotfix-v205.js'),'utf8');
const css = fs.readFileSync(path.join(__dirname,'..','phase5-v205.css'),'utf8');
const index = fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw = fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

const assertions = [
  ['visible achievement catalog', sql.includes("'first_signal'") && sql.includes("'interval_80'") && sql.includes("'streak_7'")],
  ['hidden endgame achievements', sql.includes("'hidden_ear_perfect'") && sql.includes("'hidden_singularity'") && sql.includes("'???'")],
  ['point frame progression', sql.includes("'bronze'") || sql.includes("unlock_rule->>'type'='points'")],
  ['combination frames', sql.includes("'aurora'") && sql.includes("'supernova'") && sql.includes("'event_horizon'") && sql.includes('achievement_combo')],
  ['three daily slots', sql.includes('slot') && sql.includes('limit 3') && sql.includes('ensure_my_daily_missions')],
  ['daily has no score mutation', !sql.includes('update public.ranking_bests set public_score = public_score +')],
  ['idempotent progression evaluation', sql.includes('on conflict do nothing') && sql.includes('evaluate_my_progress')],
  ['featured achievement rpc', sql.includes('toggle_featured_achievement') && js.includes('data-v205-feature')],
  ['my cosmos ui', js.includes('MY COSMOS') && js.includes('DAILY MISSIONS') && js.includes('FRAME EVOLUTION') && js.includes('ACHIEVEMENTS')],
  ['hidden ui stays secret', js.includes("secret?'CONDITION ???'") || js.includes('CONDITION ???')],
  ['title and frame equip', js.includes('mainTitleId') && js.includes('equippedFrameId')],
  ['unlock presentation', js.includes('v205-unlock-burst') && css.includes('.v205-unlock-burst')],
  ['unlock copy explicitly says achievement unlocked', copy.includes('実績を解除しました') && copy.includes('称号を獲得しました') && copy.includes('フレームを解放しました')],
  ['unlock copy hotfix loaded after progression', index.indexOf('phase5-unlock-copy-hotfix-v205.js') > index.indexOf('phase5-progression-v205.js')],
  ['unlock copy hotfix cached', sw.includes('phase5-unlock-copy-hotfix-v205.js')],
  ['cut-ins wait for ranking/privacy presentation', js.includes('rankingPresentationBusy') && js.includes('.rank-burst,.v205-publication-overlay') && js.includes('publication_required')],
  ['mobile layout', css.includes('@media(max-width:780px)')],
];

let fail=0;
for(const [name,ok] of assertions){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
