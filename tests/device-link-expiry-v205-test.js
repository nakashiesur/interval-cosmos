const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'..','account-gate.js'),'utf8');
const body=source.slice(source.indexOf('function renderSourcePin('),source.indexOf('function pollSourceLink('));
let tick,notice;
const ctx={Date,Math,String,sourceCountdownTimer:null,linkPollTimer:7,sourceLink:{request_id:'test'},document:{querySelector:()=>null},panel:()=>{},header:()=>'',esc:v=>v,setInterval:fn=>{tick=fn;return 1;},clearInterval:()=>{},showTransientModal:(title)=>{notice=title;}};
vm.createContext(ctx);vm.runInContext(body,ctx);
ctx.renderSourcePin({expires_at:new Date(Date.now()-1000).toISOString()},'awaiting_confirmation');
tick();assert(notice.includes('有効期限'));assert.equal(ctx.sourceLink,null);assert.equal(ctx.linkPollTimer,null);
console.log('PASS expired confirmation is dismissed even without PIN countdown element');

const targetCode=source.slice(source.indexOf('function pollTargetLink('),source.indexOf('async function openSourceLink('));
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b});return {promise,resolve,reject}};
function targetContext(){
  const calls=[], button={disabled:false}; let poll;
  const c={targetLink:{id:'request-a'},linkPollTimer:null,console,document:{querySelector:()=>button},
    cloud:{cancelDeviceLink:async id=>calls.push(id),getDeviceLinkTargetStatus:async()=>({status:'pending'}),setGuestMode(){},getMyPlayer:async()=>{}},
    setInterval:fn=>{poll=fn;return 1},clearInterval(){},setMessage(){},showLinkInput(){c.inputShown=true},startApp:async()=>{c.started=true}};
  vm.createContext(c);vm.runInContext(targetCode,c);return {c,calls,button,tick:()=>poll()};
}
(async()=>{
  let h=targetContext();
  await h.c.cancelTargetLink();
  assert.deepEqual(h.calls,['request-a']);assert.equal(h.c.targetLink,null);assert(h.c.inputShown);
  h=targetContext();h.c.cloud.cancelDeviceLink=async()=>{throw Error('offline')};
  await h.c.cancelTargetLink();assert.equal(h.c.targetLink.id,'request-a');assert(!h.button.disabled);assert(!h.c.inputShown);
  h=targetContext();const late=deferred();h.c.cloud.getDeviceLinkTargetStatus=()=>late.promise;
  h.c.pollTargetLink();const pending=h.tick();await h.c.cancelTargetLink();late.resolve({status:'confirmed'});await pending;assert(!h.c.started);
  h=targetContext();const old=deferred();h.c.cloud.getDeviceLinkTargetStatus=()=>old.promise;
  h.c.pollTargetLink();const stale=h.tick();h.c.targetLink={id:'request-b'};old.resolve({status:'expired'});await stale;assert(!h.c.inputShown);assert.equal(h.c.targetLink.id,'request-b');
  h=targetContext();h.c.cloud.getDeviceLinkTargetStatus=async()=>({status:'confirmed'});h.c.pollTargetLink();await h.tick();assert(h.c.started);assert.equal(h.c.targetLink,null);
  console.log('PASS target cancellation reaches server; failure remains retryable; stale polls cannot revive cancelled or replaced requests; confirmed login still starts');
})().catch(error=>{console.error(error);process.exitCode=1});

(async()=>{
 let tick, renders=0, notices=[];
 const c={sourceLink:{request_id:'source-a'},sourceCountdownTimer:2,linkPollTimer:null,console,
   cloud:{getDeviceLinkSourceStatus:async()=>({status:'awaiting_confirmation'})},
   setInterval:fn=>{tick=fn;return 1},clearInterval(){},renderSourcePin(){renders++},showTransientModal:title=>notices.push(title)};
 vm.createContext(c);vm.runInContext(source.slice(source.indexOf('function pollSourceLink('),source.indexOf('async function confirmSourceLink(')),c);
 c.pollSourceLink();await tick();await tick();assert.equal(renders,1);assert.equal(c.linkPollTimer,1);
 c.cloud.getDeviceLinkSourceStatus=async()=>({status:'cancelled'});await tick();
 assert.equal(c.sourceLink,null);assert.equal(c.linkPollTimer,null);assert.equal(c.sourceCountdownTimer,null);assert(notices[0].includes('キャンセル'));
 console.log('PASS source keeps watching approval and dismisses target cancellation');
})().catch(error=>{console.error(error);process.exitCode=1});
