const fs=require('fs');
const path=require('path');
const root=path.join(__dirname,'..');
const css=fs.readFileSync(path.join(root,'phase10-result-polish-v205.css'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');

const tests=[
  ['RESULT polish stylesheet is loaded',index.includes('phase10-result-polish-v205.css?v=alpha10.1')],
  ['RESULT polish is cached',sw.includes('phase10-result-polish-v205.css')&&sw.includes('alpha10-11')],
  ['desktop RESULT actions use one compact row',css.includes('@media (min-width:621px)')&&css.includes('grid-template-columns:1.35fr 1fr 1fr 1fr')],
  ['mobile RESULT rank cards stay 2x2',css.includes('@media (max-width:620px)')&&css.includes('.v205-result-rank-grid')&&css.includes('grid-template-columns:repeat(2,minmax(0,1fr))')],
  ['mobile RESULT stats compact to three columns',css.includes('.stat-grid')&&css.includes('grid-template-columns:repeat(3,minmax(0,1fr))')],
  ['mobile RESULT actions use a two-column grid',css.includes('.result-actions')&&css.includes('grid-template-columns:repeat(2,minmax(0,1fr))')],
  ['small phones fall back to five mastery columns',css.includes('@media (max-width:390px)')&&css.includes('grid-template-columns:repeat(5,minmax(0,1fr))')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
