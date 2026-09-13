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
(async()=>{await check(true);await check(false);assert(!source.includes("'guest-convert') { cloud.setGuestMode(false)"));console.log('PASS guest conversion refresh and initial registration startup');})().catch(e=>{console.error(e);process.exitCode=1;});
