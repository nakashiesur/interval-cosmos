const fs=require('fs');
const path=require('path');
const root=path.join(__dirname,'..');
const css=fs.readFileSync(path.join(root,'phase10-history-folders-v205.css'),'utf8');
const js=fs.readFileSync(path.join(root,'phase10-history-folders-v205.js'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');

const tests=[
  ['folder stylesheet loaded',index.includes('phase10-history-folders-v205.css?v=alpha10.1')],
  ['folder script loaded',index.includes('phase10-history-folders-v205.js?v=alpha10.1')],
  ['folder assets cached',sw.includes('phase10-history-folders-v205.css')&&sw.includes('phase10-history-folders-v205.js')&&sw.includes('alpha10-16')],
  ['three history folders exist',js.includes('overview')&&js.includes('analysis')&&js.includes('sessions')&&js.includes('概要')&&js.includes('音程分析')&&js.includes('プレイ履歴')],
  ['desktop keeps expanded layout',css.includes('.v205-history-folder-pane{display:contents}')],
  ['mobile shows only active pane',css.includes('.v205-history-folder-pane{display:none}')&&css.includes('.v205-history-folder-pane.is-active{display:block}')],
  ['dynamic history rerenders are enhanced',js.includes('MutationObserver')&&js.includes("dataset.v205HistoryFolders"))],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
