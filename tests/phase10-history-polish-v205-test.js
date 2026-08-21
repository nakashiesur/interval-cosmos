const fs=require('fs');
const path=require('path');
const root=path.join(__dirname,'..');
const css=fs.readFileSync(path.join(root,'phase10-history-polish-v205.css'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');

const tests=[
  ['HISTORY polish stylesheet is loaded',index.includes('phase10-history-polish-v205.css?v=alpha10.1')],
  ['HISTORY polish is cached',sw.includes('phase10-history-polish-v205.css')&&sw.includes('alpha10-15')],
  ['mobile summary uses compact 2x2 grid',css.includes('.v205-history-summary')&&css.includes('repeat(2,minmax(0,1fr))')],
  ['mobile mode analysis uses two columns',css.includes('.v205-history-modes')&&css.includes('repeat(2,minmax(0,1fr))')],
  ['mobile insights use three compact columns',css.includes('.v205-history-insights')&&css.includes('repeat(3,minmax(0,1fr))')],
  ['mobile interval analysis remains five columns',css.includes('.v205-history-intervals')&&css.includes('repeat(5,minmax(0,1fr))')],
  ['FOCUS practice choice remains responsive',css.includes('.v205-practice-choice')&&css.includes('height:64px')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
