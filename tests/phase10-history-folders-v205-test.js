const fs=require('fs');
const path=require('path');
const root=path.join(__dirname,'..');
const css=fs.readFileSync(path.join(root,'phase10-history-folders-v205.css'),'utf8');
const js=fs.readFileSync(path.join(root,'phase10-history-folders-v205.js'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');

const tests=[
  ['folder stylesheet loaded',index.includes('phase10-history-folders-v205.css?v=alpha10.2')],
  ['folder script loaded',index.includes('phase10-history-folders-v205.js?v=alpha10.3')],
  ['folder assets cached',sw.includes('phase10-history-folders-v205.css')&&sw.includes('phase10-history-folders-v205.js')&&sw.includes('alpha10-48')],
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
  globalThis.folderTest={navigate,setActive,get:()=>activeFolder,set:value=>{activeFolder=value;}};
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
// Exercise focus, selection, wrapping, ignored keys, and reduced-motion scrolling.
const assert=require('assert');
let focused=null, scroll=null, reduced=false;
context.window={matchMedia:q=>({matches:q.includes('max-width')||reduced})};
const buttons=['overview','analysis','sessions'].map(name=>({
 dataset:{v205HistoryFolderTab:name},classList:{toggle(){}},attrs:{},
 setAttribute(k,v){this.attrs[k]=v;},focus(){focused=name;},closest(){return this;}
}));
const panes=buttons.map(b=>({dataset:{v205HistoryFolderPane:b.dataset.v205HistoryFolderTab},classList:{toggle(k,v){this.active=v;}}}));
const card={querySelectorAll:q=>q.includes('folder-tab')?buttons:panes,scrollTo:v=>{scroll=v;}};
const nav={querySelector:q=>buttons.find(b=>q.includes('"'+b.dataset.v205HistoryFolderTab+'"'))};
for(const [from,key,wanted] of [['overview','ArrowRight','analysis'],['analysis','ArrowRight','sessions'],['sessions','ArrowRight','overview'],['overview','ArrowLeft','sessions'],['analysis','Home','overview'],['overview','End','sessions']]){
 let prevented=false;
 context.folderTest.navigate(card,nav,{key,target:buttons.find(b=>b.dataset.v205HistoryFolderTab===from),preventDefault(){prevented=true;}});
 assert(prevented);assert.equal(focused,wanted);
 assert.equal(buttons.filter(b=>b.tabIndex===0).length,1);
 assert.equal(buttons.find(b=>b.tabIndex===0).dataset.v205HistoryFolderTab,wanted);
 assert.equal(panes.filter(p=>p.classList.active).length,1);
 assert.equal(scroll.behavior,'smooth');
}
reduced=true;context.folderTest.setActive(card,'analysis',true);assert.equal(scroll.behavior,'auto');
context.folderTest.navigate(card,nav,{key:'Tab',preventDefault(){throw Error('Tab intercepted');}});
console.log('PASS keyboard navigation, focus, selection and reduced motion');
process.exitCode=fail?1:0;
