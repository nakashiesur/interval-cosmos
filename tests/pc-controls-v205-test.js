const fs=require('fs');
const path=require('path');
const js=fs.readFileSync(path.join(__dirname,'..','phase8-pc-controls-v205.js'),'utf8');
const css=fs.readFileSync(path.join(__dirname,'..','phase8-pc-controls-v205.css'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

const expected=[
  "P1: '1'","m2: '2'","M2: '3'","m3: '4'","M3: '5'","P4: '6'","TT: '7'","P5: '8'",
  "m6: '9'","M6: '0'","m7: 'Q'","M7: 'W'","P8: 'E'",
];
const tests=[
  ['keeps all 13 legacy answer hotkeys',expected.every(x=>js.includes(x))],
  ['does not duplicate answer or space handling',js.includes('This layer deliberately does not duplicate them') && !js.includes("event.code === 'Space'") && !js.includes('answerQuestion(')],
  ['editable fields are protected',js.includes('input, textarea, select') && js.includes('isEditable(event.target)')],
  ['R retries normal and assignment results',js.includes('[data-action=\\"retry\\"]') || (js.includes('[data-action="retry"]') && js.includes('[data-a-retry]'))],
  ['Esc closes admin dashboard',js.includes('[data-v205-admin-close]')],
  ['Esc handles assignment navigation',js.includes('[data-a-mode-back]') && js.includes('[data-a-back]') && js.includes('[data-a-close]')],
  ['active assignment cannot be escaped accidentally',js.includes("assignment.querySelector('.v205-a-game, .v205-a-countdown')") && js.includes('return false')],
  ['active normal timed play keeps long-press exit',js.includes("document.querySelector('.play-screen')") && js.includes('long-press exit remains the only exit path')],
  ['answer hints decorate both engines',js.includes('[data-answer]') && js.includes('[data-a-answer]') && js.includes('dataset.pcKey')],
  ['keyboard hints are desktop-only',css.includes('(hover:hover)') && css.includes('(pointer:fine)') && css.includes('(pointer:coarse)')],
  ['pc assets loaded',index.includes('phase8-pc-controls-v205.js?v=alpha7') && index.includes('phase8-pc-controls-v205.css?v=alpha7')],
  ['pc assets cached',sw.includes('phase8-pc-controls-v205.js') && sw.includes('phase8-pc-controls-v205.css') && sw.includes('alpha7')],
  ['observer only watches child list',js.includes("{ subtree: true, childList: true }") && !js.includes('attributes: true')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
