const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'..','account-gate.js'),'utf8');
const body=source.slice(source.indexOf('async function submitStudentForm('),source.indexOf('async function submitLinkForm('));
async function check(alreadyStarted){
 let reloaded=0,started=0;
 const values={'#v205StudentNumber':'990913','#v205PlayerName':'QA0913','#v205Course':'piano','#v205Avatar':'nova'};
 const context={appStarted:alreadyStarted,document:{querySelector:s=>({value:values[s]})},cloud:{normalizeStudentNumber:v=>v,createStudentAccount:async()=>({})},setMessage:()=>{},setTimeout:fn=>fn(),location:{reload:()=>{reloaded++;}},startApp:()=>{started++;},console};
 vm.createContext(context);vm.runInContext(body,context);
 await context.submitStudentForm({querySelector:()=>({})});
 assert.equal(reloaded,alreadyStarted?1:0);assert.equal(started,alreadyStarted?0:1);
}
async function checkLink(alreadyStarted, status){
 let tick,reloaded=0,started=0,guest=true;
 const request={id:'test-request'};
 const context={appStarted:alreadyStarted,linkPollTimer:null,targetLink:request,
 setInterval:fn=>{tick=fn;return 1;},clearInterval:()=>{},
 cloud:{getDeviceLinkTargetStatus:async()=>({status}),setGuestMode:v=>{guest=v;},getMyPlayer:async()=>({})},
 location:{reload:()=>{reloaded++;}},startApp:async()=>{started++;},console};
 vm.createContext(context);
 vm.runInContext(source.slice(source.indexOf('function pollTargetLink('),source.indexOf('async function cancelTargetLink(')),context);
 context.pollTargetLink();await tick();
 assert.equal(guest,status!=='confirmed');
 assert.equal(reloaded,status==='confirmed'&&alreadyStarted?1:0);
 assert.equal(started,status==='confirmed'&&!alreadyStarted?1:0);
}
async function checkClaimFailure(){
 const cloudSource=fs.readFileSync(path.join(__dirname,'..','cloud.js'),'utf8');
 let guest=true;
 const c={ensureAuth:async()=>{},loadActualPlayer:async()=>{},player:null,setGuestMode:v=>{guest=v;},client:{rpc:async()=>({error:new Error('invalid PIN')})}};
 vm.createContext(c);vm.runInContext(cloudSource.slice(cloudSource.indexOf('  async function claimDeviceLinkPin('),cloudSource.indexOf('  async function getDeviceLinkSourceStatus(')),c);
 await assert.rejects(c.claimDeviceLinkPin('000000'),/invalid PIN/);assert(guest,'invalid PIN must preserve guest mode');
}
(async()=>{await checkClaimFailure();await checkLink(true,'awaiting_confirmation');await checkLink(true,'confirmed');await checkLink(false,'confirmed');await check(true);await check(false);assert(!source.includes("'guest-convert') { cloud.setGuestMode(false)"));console.log('PASS guest conversion refresh and initial registration startup');})().catch(e=>{console.error(e);process.exitCode=1;});
