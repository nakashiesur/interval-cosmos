const fs=require('fs');
const path=require('path');
const root=path.join(__dirname,'..');
const css=fs.readFileSync(path.join(root,'phase10-history-folders-v205.css'),'utf8');
const js=fs.readFileSync(path.join(root,'phase10-history-folders-v205.js'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');

const tests=[
  ['folder stylesheet loaded',index.includes('phase10-history-folders-v205.css?v=alpha10.2')],
  ['folder script loaded',index.includes('phase10-history-folders-v205.js?v=alpha10.2')],
  ['folder assets cached',sw.includes('phase10-history-folders-v205.css')&&sw.includes('phase10-history-folders-v205.js')&&sw.includes('alpha10-36')],
  ['three history folders exist',js.includes('overview')&&js.includes('analysis')&&js.includes('sessions')&&js.includes('概要')&&js.includes('音程分析')&&js.includes('プレイ履歴')],
  ['desktop keeps expanded layout',css.includes('.v205-history-folder-pane{display:contents}')],
  ['mobile shows only active pane',css.includes('.v205-history-folder-pane{display:none}')&&css.includes('.v205-history-folder-pane.is-active{display:block}')],
  ['dynamic history rerenders are enhanced',js.includes('MutationObserver')&&js.includes("dataset.v205HistoryFolders")],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
// Exercise the actual close handler with both supported dismissal paths.
const vm=require('vm');
let onClick;
const overlay={};
const context={
  document:{documentElement:{},querySelectorAll:()=>[],querySelector:()=>null,
    addEventListener:(type,handler)=>{if(type==='click')onClick=handler;}},
  MutationObserver:class{observe(){}},
};
vm.createContext(context);
vm.runInContext(js.replace(/\}\)\(\);\s*$/, `
  globalThis.folderTest={get:()=>activeFolder,set:value=>{activeFolder=value;}};
})();`),context);
for(const [name,target,expected] of [
  ['close button resets folder',{closest:()=>({})},'overview'],
  ['backdrop dismissal resets folder',Object.assign(overlay,{closest:()=>null,matches:selector=>selector==='.v205-history-overlay'}),'overview'],
  ['click inside card preserves folder',{closest:()=>null,matches:()=>false},'sessions'],
]){
  context.folderTest.set('sessions');
  onClick({target});
  const ok=context.folderTest.get()===expected;
  console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;
}
process.exitCode=fail?1:0;
