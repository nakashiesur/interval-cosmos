const fs=require('fs');
const path=require('path');
const root=path.join(__dirname,'..');
const css=fs.readFileSync(path.join(root,'phase10-cosmos-polish-v205.css'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');

const tests=[
  ['MY COSMOS polish stylesheet is loaded',index.includes('phase10-cosmos-polish-v205.css?v=alpha10.1')],
  ['MY COSMOS polish is cached',sw.includes('phase10-cosmos-polish-v205.css')&&sw.includes('alpha10-13')],
  ['mobile hero keeps identity and points in one row',css.includes('grid-template-columns:64px minmax(0,1fr) auto')&&css.includes('.v205-points')&&css.includes('grid-column:auto')],
  ['mobile section headings remain horizontal',css.includes('.v205-cosmos-section-head')&&css.includes('flex-direction:row')],
  ['mobile frames use a three-column compact grid',css.includes('.v205-frame-grid')&&css.includes('repeat(3,minmax(0,1fr))')&&css.includes('min-height:112px')],
  ['mobile titles use two columns when space allows',css.includes('.v205-title-grid')&&css.includes('repeat(2,minmax(0,1fr))')],
  ['small phones fall back safely',css.includes('@media(max-width:390px)')&&css.includes('grid-template-columns:repeat(2,minmax(0,1fr))')&&css.includes('grid-template-columns:1fr')],
  ['achievement featured controls stay available',css.includes('.v205-feature-btn')&&css.includes('min-width:48px')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
