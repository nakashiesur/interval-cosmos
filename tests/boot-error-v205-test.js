const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'..','account-gate.js'),'utf8');
const fn=source.slice(source.indexOf('function showDatabaseRequired('),source.indexOf('async function startApp('));
let html='';
const ctx={panel:value=>{html=value;},header:(k,t,m)=>`${t} ${m}`,esc:value=>String(value)};
vm.createContext(ctx);vm.runInContext(fn,ctx);
for(const [error,expected] of [[{message:'Failed to fetch'},'CONNECTION ERROR'],[{code:'PGRST202'},'DATABASE UPDATE REQUIRED'],[{code:'42P01'},'DATABASE UPDATE REQUIRED'],[{code:'42501'},'CONNECTION ERROR']]){
 ctx.showDatabaseRequired(error);assert(html.includes(expected));assert(html.includes('retry-boot'));assert(html.includes('offline-start'));
 console.log('PASS boot error '+(error.code||'network'));
}

const bootSource=source.slice(source.indexOf('async function boot()'),source.indexOf('\nfunction setMessage('));
function bootHarness(init){
  const timers=new Map(),screens=[];let next=0;
  const context={cloud:{configured:()=>true,init},Promise,Error,console:{error(){}},
    setTimeout(fn){const id=++next;timers.set(id,fn);return id;},clearTimeout(id){timers.delete(id);},
    loadingScreen(){screens.push('loading');},showChooser(){screens.push('chooser');},
    showDatabaseRequired(error){screens.push(error.message);},
    startApp:async()=>{vm.runInContext('appStarted=true',context);screens.push('app');}};
  vm.createContext(context);
  vm.runInContext('let appStarted=false;let bootAttempt=0;const BOOT_TIMEOUT_MS=15000;'+bootSource,context);
  return {context,timers,screens,boot:()=>context.boot(),start:()=>context.startApp(),expire(){[...timers.values()].forEach(fn=>fn());}};
}
function deferred(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};}
(async()=>{
  for(const profile of [null,{id:'test'}]){
    const h=bootHarness(async()=>({profile}));await h.boot();
    assert.equal(h.screens.at(-1),profile?'app':'chooser');assert.equal(h.timers.size,0);
  }
  const delayed=deferred(),h=bootHarness(()=>delayed.promise);
  const waiting=h.boot();h.expire();await waiting;
  assert(h.screens.at(-1).includes('接続に時間がかかっています'));assert.equal(h.timers.size,0);
  await h.start();delayed.resolve({profile:null});await Promise.resolve();await Promise.resolve();
  assert.equal(h.screens.at(-1),'app','late init cannot replace offline gameplay');

  for(const fail of [false,true]){
    const old=deferred(),fresh=deferred();let calls=0;
    const retry=bootHarness(()=>++calls===1?old.promise:fresh.promise);
    const first=retry.boot(),second=retry.boot();fresh.resolve({profile:null});await second;
    if(fail)old.reject(new Error('old failure'));else old.resolve({profile:{id:'old'}});
    await first;
    assert.equal(retry.screens.at(-1),'chooser','obsolete response cannot replace retry result');
    assert.equal(retry.timers.size,0);
  }

  const aborted=deferred(),active=bootHarness(()=>aborted.promise);
  const pending=active.boot();await active.start();active.expire();await pending;
  assert.equal(active.screens.at(-1),'app','timeout does not reopen gate after app start');
  console.log('PASS bounded boot wait, retry ordering, cleared timers and late-response isolation');
})().catch(error=>{console.error(error);process.exitCode=1;});
