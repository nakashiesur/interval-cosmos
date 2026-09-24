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

// Exercise the first-visit guide interruption with the real navigation handler.
const vm=require('vm'),assert=require('assert');
function focusHarness(guideSeen=false){
  let screen='home',handler,veil=null,now=0,view='text',selected=new Set(['P1','M3']);
  const timers=[];
  const button=fn=>({click:fn});
  const query=selector=>{
    if(selector==='.v205-focus-transition-veil')return veil;
    if(selector==='[data-action="practice"]'&&screen==='home')return button(()=>screen=guideSeen?'practice':'guide');
    if(selector==='[data-action="guide-complete"]'&&screen==='guide')return button(()=>{});
    if(selector.startsWith('[data-view=')&&screen==='practice')return button(()=>view=selector.includes('keys')?'keys':'text');
    if(selector==='[data-practice="manual"]'&&screen==='practice')return button(()=>screen='select');
    if(selector==='[data-action="clear-all"]'&&screen==='select')return button(()=>selected.clear());
    const match=selector.match(/^\[data-interval="(.+)"\]$/);
    if(match&&screen==='select')return button(()=>selected.has(match[1])?selected.delete(match[1]):selected.add(match[1]));
    return null;
  };
  const ctx={Set,Object,document:{querySelector:query,body:{appendChild:n=>veil=n},createElement:()=>({style:{},querySelector:()=>null,remove(){if(veil===this)veil=null;}})},
    setTimeout:(fn,ms)=>timers.push({fn,at:now+ms}),addEventListener:(_,fn)=>handler=fn};
  ctx.window=ctx;vm.createContext(ctx);vm.runInContext(focus,ctx);
  const drain=()=>{while(timers.length){timers.sort((a,b)=>a.at-b.at);const t=timers.shift();now=t.at;t.fn();}};
  return {start(key,method){handler({target:{closest:s=>s==='[data-v205-focus-view]'?{dataset:{interval:key,v205FocusView:method}}:null},preventDefault(){},stopImmediatePropagation(){}});drain();},
    guide(action){handler({target:{closest:s=>s==='[data-action]'?{dataset:{action}}:null}});if(action==='guide-complete'){guideSeen=true;screen='practice';}else screen='home';drain();},
    result:()=>({screen,view,selected:[...selected],veil:!!veil})};
}
for(const method of ['text','keys']){
  const h=focusHarness();h.start('m6',method);assert.equal(h.result().screen,'guide');assert.equal(h.result().veil,false);
  h.guide('guide-complete');assert.deepEqual(h.result(),{screen:'select',view:method,selected:['m6'],veil:false});
  const returning=focusHarness(true);returning.start('P8',method);assert.deepEqual(returning.result(),{screen:'select',view:method,selected:['P8'],veil:false});
}
const cancelled=focusHarness();cancelled.start('M7','keys');cancelled.guide('guide-back');cancelled.guide('guide-complete');assert.equal(cancelled.result().screen,'practice','cancelled focus must not resume later');
console.log('PASS first-visit guide preserves TEXT/KEYS focus, returning flow, and cancellation');

(async()=>{
  const vm=require('vm'),assert=require('assert');
  const requests=[],renders=[];
  const ctx={opening:false,historyRequest:0,historyCache:[],console,
    cloud:{getCachedPlayer:()=>({id:'fixture'}),fetchLearningHistory:()=>new Promise((resolve,reject)=>requests.push({resolve,reject}))},
    window:{IntervalCosmosLearningSync:{fetchAnalysis:async()=>({rows:[]})}},
    document:{querySelector:()=>({remove(){}})},renderLoading(){},renderHistory:rows=>renders.push(rows),
    createOverlay(){throw Error('stale error reopened overlay')},esc:String};
  vm.createContext(ctx);
  vm.runInContext(phase4.slice(phase4.indexOf('  function closeHistory()'),phase4.indexOf('  function renderLoading()'))+
    phase4.slice(phase4.indexOf('  async function openHistory()'),phase4.indexOf('  function injectButtons()')),ctx);
  const old=ctx.openHistory();ctx.closeHistory();const current=ctx.openHistory();
  requests[0].resolve(['old']);await old;assert.equal(ctx.opening,true);assert.equal(renders.length,0);
  requests[1].resolve(['current']);await current;assert.deepEqual(renders,[['current']]);assert.deepEqual(ctx.historyCache,['current']);
  const failing=ctx.openHistory();ctx.closeHistory();requests[2].reject(Error('late failure'));await failing;assert.equal(renders.length,1);
  let analysisResolve,analysisStarted;
  const started=new Promise(r=>analysisStarted=r);
  ctx.window.IntervalCosmosLearningSync.fetchAnalysis=()=>{analysisStarted();return new Promise(r=>analysisResolve=r)};
  const analysisPending=ctx.openHistory();requests[3].resolve(['next']);await started;ctx.closeHistory();analysisResolve({rows:[]});await analysisPending;
  assert.equal(renders.length,1);assert.deepEqual(ctx.historyCache,['current']);
  console.log('PASS closing/reopening history discards late history, analysis, and error responses');
})().catch(error=>{console.error(error);process.exitCode=1});
