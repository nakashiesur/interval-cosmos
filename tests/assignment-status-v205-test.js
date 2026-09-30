const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');
const code=fs.readFileSync(require('path').join(__dirname,'..','assignment-status-v205.js'),'utf8');
const button={dataset:{},setAttribute(k,v){this[k]=v},removeAttribute(k){delete this[k]}};
let profile={id:'alice'}, response=[], pendingRpc=null, calls=0, fail=false, studentView=false;
const events={},window={IntervalCosmosCloud:{getCachedPlayer:()=>profile,init:async()=>{}},IntervalCosmosAssignmentAdminPolicyV205:{isStudentView:()=>studentView},IntervalCosmosSupabaseSingleton:{getClient:()=>({rpc:async()=>{calls++;if(pendingRpc)return pendingRpc;return {data:response,error:fail?new Error('offline'):null}}})},addEventListener:(n,fn)=>events[n]=fn,setInterval(){}};
const document={documentElement:{},visibilityState:'visible',querySelector:()=>button};
const context={window,document,navigator:{onLine:true},queueMicrotask,MutationObserver:class{observe(){}},Date,console};
vm.runInNewContext(code,context);const api=window.IntervalCosmosAssignmentStatusV205;
const tick=()=>new Promise(setImmediate);
const row=(over={})=>({start_at:new Date(Date.now()-100000).toISOString(),deadline_at:new Date(Date.now()+100000).toISOString(),attempts:0,achieved:false,...over});
(async()=>{
 await tick();response=[row(),row({attempts:2}),row({achieved:true})];await api.refresh(true);
 assert.equal(button.dataset.assignmentStatus,'pending');assert(button.innerHTML.includes('>2</span>'));assert(button['aria-label'].includes('未回答 1件'));console.log('PASS pending badge counts unanswered and attempted-but-not-cleared assignments');
 response=[row({achieved:true})];await api.refresh(true);assert.equal(button.dataset.assignmentStatus,'complete');console.log('PASS all currently active assignments cleared');
 response=[];await api.refresh(true);assert.equal(button.dataset.assignmentStatus,'empty');
 response=[row({start_at:new Date(Date.now()+50000).toISOString()})];await api.refresh(true);assert.equal(button.dataset.assignmentStatus,'upcoming');
 response=[row({deadline_at:new Date(Date.now()-1).toISOString()})];await api.refresh(true);assert.equal(button.dataset.assignmentStatus,'closed');console.log('PASS no-assignment, upcoming and expired states never claim completion');
 fail=true;await api.refresh(true);assert.equal(button.dataset.assignmentStatus,'error');fail=false;
 context.navigator.onLine=false;await api.refresh(true);assert.equal(button.dataset.assignmentStatus,'offline');context.navigator.onLine=true;console.log('PASS failed/offline reads never become all-clear');
 let release;pendingRpc=new Promise(r=>release=r);const stale=api.refresh(true);await tick();profile={id:'bob'};pendingRpc=null;response=[];await api.refresh(true);release({data:[row()]});await stale;assert.equal(button.dataset.assignmentStatus,'empty');console.log('PASS late prior-account response cannot leak task counts');
 profile={id:'admin',is_admin:true};await api.refresh(true);assert.equal(button.dataset.assignmentStatus,undefined);studentView=true;response=[row()];await api.refresh(true);assert.equal(button.dataset.assignmentStatus,'pending');console.log('PASS admin tools remain plain; student view gets its own status');
 profile={id:null,is_guest:true};await api.refresh(true);assert.equal(button.dataset.assignmentStatus,undefined);console.log('PASS guest/logout clears status');
 profile={id:'alice'};response=[row()];await api.refresh(true);const before=calls;await api.refresh();assert.equal(calls,before);response=[row({achieved:true})];events['interval-cosmos-sync']();await tick();assert.equal(button.dataset.assignmentStatus,'complete');console.log('PASS cached observer renders do not refetch; sync refreshes completion');
 // A sync arriving during a stale read must be retried after that read.
 pendingRpc=new Promise(r=>release=r);const inFlight=api.refresh(true);await tick();api.refresh(true);pendingRpc=null;response=[];release({data:[row()]});await inFlight;await tick();assert.equal(button.dataset.assignmentStatus,'empty');console.log('PASS sync arriving during an existing request is not lost');
})().catch(e=>{console.error(e);process.exitCode=1});
