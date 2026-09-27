const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(require('path').join(__dirname,'..','offline-sync-ui-v205.js'),'utf8');
function deferred(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b});return {promise,resolve,reject};}
function harness(){
 const handlers={},requests=[],retries=[];
 const ctx={window:{IntervalCosmosCloud:{getSavedPlays:()=>[],getMyPlayer:()=>{const d=deferred();requests.push(d);return d.promise;},retrySavedPlay:async(...a)=>retries.push(a)},addEventListener(){}},
 document:{documentElement:{},querySelector:()=>null,querySelectorAll:()=>[],createElement:()=>({dataset:{}}),addEventListener:(k,fn)=>handlers[k]=fn},MutationObserver:class{observe(){}}};
 vm.createContext(ctx);vm.runInContext(source.replace(/\}\)\(\);\s*$/,`globalThis.test={set:d=>{dialog=d;},busy:()=>busy};})();`),ctx);
 const makeDialog=()=>{const message={textContent:'',append(){this.appended=true;}};return {message,contains:()=>true,querySelector:()=>message,remove(){this.removed=true;}};};
 const button=(accept=false)=>({dataset:accept?{syncAccept:'event',visibility:'ask'}:{syncRetry:'event'},hasAttribute:k=>!accept&&k==='data-sync-policy'});
 const click=b=>handlers.click({target:{closest:s=>s.startsWith('[data-sync-refresh]')?b:null}});
 const close=()=>handlers.click({target:{closest:s=>s==='[data-sync-close]'?{}:null}});
 return {ctx,requests,retries,makeDialog,button,click,close};
}
(async()=>{
 const h=harness(),first=h.makeDialog();h.ctx.test.set(first);
 const old=h.click(h.button());await h.close();assert(!h.ctx.test.busy());
 const next=h.makeDialog();h.ctx.test.set(next);const current=h.click(h.button());
 h.requests[0].resolve({ranking_visibility:'ask'});await old;
 assert.equal(next.message.textContent,'');assert(h.ctx.test.busy(),'old completion must not unlock new request');
 h.requests[1].resolve({ranking_visibility:'ask'});await current;
 assert(next.message.appended);assert(!h.ctx.test.busy());
 const pending=h.click(h.button());await h.close();const last=h.makeDialog();h.ctx.test.set(last);
 h.requests[2].reject(Error('old failure'));await pending;assert.equal(last.message.textContent,'');
 const consent=h.click(h.button(true));await h.close();h.requests[3].resolve({ranking_visibility:'ask'});await consent;
 assert.equal(h.retries.length,0,'closed policy check must not continue into resend');
 console.log('PASS sync dialog ignores stale success/failure, preserves new busy state, and cancels closed consent checks');
})().catch(e=>{console.error(e);process.exitCode=1;});
