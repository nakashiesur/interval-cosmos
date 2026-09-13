const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'..','account-gate.js'),'utf8');
const body=source.slice(source.indexOf('function renderSourcePin('),source.indexOf('function pollSourceLink('));
let tick,notice;
const ctx={Date,Math,String,sourceCountdownTimer:null,linkPollTimer:7,sourceLink:{request_id:'test'},document:{querySelector:()=>null},panel:()=>{},header:()=>'',esc:v=>v,setInterval:fn=>{tick=fn;return 1;},clearInterval:()=>{},showTransientModal:(title)=>{notice=title;}};
vm.createContext(ctx);vm.runInContext(body,ctx);
ctx.renderSourcePin({expires_at:new Date(Date.now()-1000).toISOString()},'awaiting_confirmation');
tick();assert(notice.includes('有効期限'));assert.equal(ctx.sourceLink,null);assert.equal(ctx.linkPollTimer,null);
console.log('PASS expired confirmation is dismissed even without PIN countdown element');
