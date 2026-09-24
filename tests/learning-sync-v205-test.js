const fs=require('fs'),vm=require('vm'),assert=require('assert');
const code=fs.readFileSync(require('path').join(__dirname,'../learning-sync-v205.js'),'utf8');
const data=new Map([['intervalCosmos.mastery.v2',JSON.stringify({M3:{seen:7,correct:5}})]]);
const storage={get length(){return data.size},key:i=>[...data.keys()][i],getItem:k=>data.get(k)??null,setItem:(k,v)=>data.set(k,v),removeItem:k=>data.delete(k)};
function harness(backend='test'){
 let user='auth-a',player='player-a',seq=0,fail=false,hold=null;
 const timers=new Map();let timerSeq=0;
 const sent=new Map();const ctx={localStorage:storage,navigator:{onLine:true},Date,Math,JSON,console,setTimeout:(fn,ms)=>{const id=++timerSeq;timers.set(id,{fn,ms});return id},clearTimeout:id=>timers.delete(id)};
 ctx.window={INTERVAL_COSMOS_CLOUD:{supabaseUrl:backend},addEventListener(){},setInterval(){},IntervalCosmosCloud:{
  getCachedPlayer:()=>({id:player,is_guest:!player}),getAuthUser:()=>({id:user}),createClientEventId:()=>`event-${++seq}`,
  submitLearningAnswers:async(owner,events)=>{if(hold)await hold;for(const e of events)sent.set(e.event_id,e);if(fail)throw Error('lost acknowledgement')},
  fetchLearningAnalysis:async()=>[]}};
 vm.createContext(ctx);vm.runInContext(code,ctx);
 return {api:ctx.window.IntervalCosmosLearningSync,ctx,sent,timers,identity:(u,p)=>{user=u;player=p},fail:v=>fail=v,hold:p=>hold=p};
}
(async()=>{
 const h=harness();assert.equal(h.api.legacy().M3.seen,7);
 h.api.record('M3','m3',1200);assert.equal(h.api.pending().length,1);
 storage.setItem('intervalCosmos.mastery.v2','{"M3":{"seen":8}}');assert.equal(h.api.legacy().M3.seen,7);
 h.ctx.navigator.onLine=false;await h.api.flush();assert.equal(h.sent.size,0);
 h.ctx.navigator.onLine=true;h.fail(true);await h.api.flush();assert.equal(h.sent.size,1);assert.equal(h.api.pending().length,1);
 h.identity('auth-b','player-b');await h.api.flush();assert.equal(h.api.pending().length,0);assert.equal(h.sent.size,1);
 h.identity('auth-a','player-a');h.fail(false);await h.api.flush();assert.equal(h.api.pending().length,0);assert.equal(h.sent.size,1);
 h.identity('guest',null);h.api.record('P1','P1',20);assert.equal(h.api.pending().length,0);
 h.identity('auth-a','player-a');let release;h.hold(new Promise(r=>release=r));h.api.record('P1','P1',80);const running=h.api.flush();h.api.record('P5','P4',300);release();await running;assert.equal(h.sent.size,3);assert.equal(h.api.pending().length,0);
 const restored=harness();assert.equal(restored.api.legacy().M3.seen,7);
 h.hold(null);h.ctx.navigator.onLine=false;h.api.record('M2','M2',500);
 const pendingId=h.api.pending()[0].event.event_id;
 const otherBackend=harness('other-test');await otherBackend.api.flush();assert.equal(otherBackend.sent.size,0);
 const reloaded=harness();assert.equal(reloaded.api.pending()[0].event.event_id,pendingId);
 await reloaded.api.flush();assert.equal(reloaded.sent.size,1);assert.ok(reloaded.sent.has(pendingId));assert.equal(h.api.pending().length,0);
 const stalled=harness('stalled');let finish;
 stalled.hold(new Promise(r=>finish=r));stalled.api.record('P1','P1',20);
 const flushing=stalled.api.flush();
 [...stalled.timers.values()].find(t=>t.ms===15000).fn();await flushing;
 assert.equal(stalled.api.pending().length,1);
 finish();await Promise.resolve();stalled.hold(null);await stalled.api.flush();
 assert.equal(stalled.sent.size,1);assert.equal(stalled.api.pending().length,0);
 const accountSwitch=harness('account-switch');let resolveRead,readStarted;
 const started=new Promise(r=>readStarted=r);
 accountSwitch.ctx.window.IntervalCosmosCloud.fetchLearningAnalysis=()=>{readStarted();return new Promise(r=>resolveRead=r)};
 const reading=accountSwitch.api.fetchAnalysis();await started;
 accountSwitch.identity('different-auth','different-player');resolveRead([{interval_key:'P1',answers:1}]);
 await assert.rejects(reading,/Account changed/);
 console.log('PASS account change discards an in-flight analysis response');
 console.log('PASS stalled transport releases sync lock, preserves IDs, and retries without duplicates');
 console.log('PASS new answers persist offline, retry with stable IDs, isolate accounts, preserve legacy, and retain answers added during sync');
})().catch(e=>{console.error(e);process.exitCode=1});

// Aggregate only the new event groups; repeated cumulative legacy snapshots are never inputs.
{
 const src=fs.readFileSync(require('path').join(__dirname,'../phase4-v205.js'),'utf8');
 const ctx={INTERVAL_ORDER:['P1','m2','M2','m3','M3','P4','TT','P5','m6','M6','m7','M7','P8'],pct:(a,b)=>b?Math.round(a/b*100):0};
 vm.createContext(ctx);vm.runInContext(src.slice(src.indexOf('  function intervalRows('),src.indexOf('  function weakest(')),ctx);
 const rows=ctx.sharedRows([{interval_key:'M3',chosen_key:'M3',answers:2,response_ms:2000},{interval_key:'M3',chosen_key:'m3',answers:1,response_ms:2000}]);
 const major=rows.find(r=>r.key==='M3');assert.equal(major.seen,3);assert.equal(major.correct,2);assert.equal(major.wrong,1);assert.equal(major.accuracy,67);assert.equal(major.confusion[0],'m3');
 assert.equal(ctx.sharedRows([]).reduce((n,r)=>n+r.seen,0),0);
 console.log('PASS cross-device answer groups aggregate accuracy, confusion and speed without legacy snapshots');
}
