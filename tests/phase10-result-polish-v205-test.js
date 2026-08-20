const fs=require('fs');
const path=require('path');
const root=path.join(__dirname,'..');
const css=fs.readFileSync(path.join(root,'phase10-result-polish-v205.css'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');

const tests=[
  ['RESULT polish stylesheet is loaded',index.includes('phase10-result-polish-v205.css?v=alpha10.2')],
  ['RESULT polish is cached',sw.includes('phase10-result-polish-v205.css')&&sw.includes('alpha10-12')],
  ['desktop RESULT actions use one compact row',css.includes('@media (min-width:621px)')&&css.includes('grid-template-columns:1.35fr 1fr 1fr 1fr')],
  ['mobile RESULT rank cards stay 2x2',css.includes('.result-panel .v205-result-rank-grid')&&css.includes('grid-template-columns:repeat(2,minmax(0,1fr))!important')],
  ['mobile RESULT stats use a six-track two-row layout',css.includes('grid-template-columns:repeat(6,minmax(0,1fr))!important')&&css.includes('nth-child(1)')&&css.includes('grid-column:span 3!important')&&css.includes('nth-child(n+3)')&&css.includes('grid-column:span 2!important')],
  ['mobile RESULT mastery is forced to seven columns',css.includes('.result-panel .mastery-grid')&&css.includes('grid-template-columns:repeat(7,minmax(0,1fr))!important')],
  ['mobile RESULT actions override older flex-column rules',css.includes('.result-panel .result-actions')&&css.includes('display:grid!important')&&css.includes('grid-template-columns:repeat(2,minmax(0,1fr))!important')],
  ['very small phones fall back to five mastery columns',css.includes('@media (max-width:360px)')&&css.includes('grid-template-columns:repeat(5,minmax(0,1fr))!important')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
