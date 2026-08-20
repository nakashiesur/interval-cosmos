const fs=require('fs');
const path=require('path');
const root=path.join(__dirname,'..');
const css=fs.readFileSync(path.join(root,'phase10-cosmos-polish-v205.css'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');

const tests=[
  ['MY COSMOS polish stylesheet is loaded',index.includes('phase10-cosmos-polish-v205.css?v=alpha10.2')],
  ['MY COSMOS polish is cached',sw.includes('phase10-cosmos-polish-v205.css')&&sw.includes('alpha10-14')],
  ['mobile hero keeps identity and points in one row',css.includes('grid-template-columns:64px minmax(0,1fr) auto')&&css.includes('.v205-points')&&css.includes('grid-column:auto')],
  ['mobile section headings remain horizontal',css.includes('.v205-cosmos-section-head')&&css.includes('flex-direction:row')],
  ['desktop frames stay on one nine-card row',css.includes('@media(min-width:1080px)')&&css.includes('grid-template-columns:repeat(9,minmax(0,1fr))')],
  ['mobile frames use a three-column compact grid',css.includes('@media(max-width:780px)')&&css.includes('grid-template-columns:repeat(3,minmax(0,1fr))')&&css.includes('min-height:104px')],
  ['mobile titles use two columns when space allows',css.includes('.v205-title-grid')&&css.includes('repeat(2,minmax(0,1fr))')],
  ['very narrow phones fall back safely',css.includes('@media(max-width:360px)')&&css.includes('grid-template-columns:repeat(2,minmax(0,1fr))')&&css.includes('grid-template-columns:1fr')],
  ['achievement featured controls stay available',css.includes('.v205-feature-btn')&&css.includes('min-width:48px')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
