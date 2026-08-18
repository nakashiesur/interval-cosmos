const fs=require('fs');
const path=require('path');
const phase4=fs.readFileSync(path.join(__dirname,'..','phase4-v205.js'),'utf8');
const focus=fs.readFileSync(path.join(__dirname,'..','phase4-hotfix-v205.js'),'utf8');
const analysis=fs.readFileSync(path.join(__dirname,'..','phase4-analysis-hotfix-v205.js'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

const tests=[
  ['learning history remains implemented',phase4.includes('LEARNING TELEMETRY')&&phase4.includes('INTERVAL ANALYSIS')],
  ['weak judgment requires minimum 3 answers',analysis.includes('MIN_SAMPLE = 3')&&analysis.includes('r.seen >= MIN_SAMPLE')],
  ['insufficient weak data is held',analysis.includes('判定保留')&&analysis.includes('3回答以上の音程がまだありません')],
  ['weak practice button is hidden without reliable sample',analysis.includes('button.hidden = true')],
  ['focus transition veil exists',focus.includes('v205-focus-transition-veil')&&focus.includes('練習範囲を準備しています')],
  ['focus veil has fail-safe removal',focus.includes('1400')&&focus.includes('fail-safe only')],
  ['focus veil clears after interval selection',focus.includes('later(hideFocusVeil, 90)')],
  ['history hotfix loaded after phase4',index.indexOf('phase4-analysis-hotfix-v205.js')>index.indexOf('phase4-v205.js')],
  ['focus hotfix remains loaded before phase4',index.indexOf('phase4-hotfix-v205.js')<index.indexOf('phase4-v205.js')],
  ['history hotfix cached',sw.includes('phase4-analysis-hotfix-v205.js')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
