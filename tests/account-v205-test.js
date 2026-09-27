const fs = require('fs');
const path = require('path');
const gate = fs.readFileSync(path.join(__dirname,'..','account-gate.js'),'utf8');
const cloud = fs.readFileSync(path.join(__dirname,'..','cloud.js'),'utf8');
const css = fs.readFileSync(path.join(__dirname,'..','account-v205.css'),'utf8');
const index = fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw = fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');
const tests = [
  ['account gate loaded before app', index.includes('account-gate.js') && !index.includes('type="module" src="app.js"')],
  ['student registration fields', gate.includes('v205StudentNumber') && gate.includes('v205PlayerName') && gate.includes('v205Course')],
  ['11 official courses', (gate.match(/department: '/g)||[]).length === 11],
  ['guest mode', gate.includes('GUEST MODE') && gate.includes('setGuestMode(true)')],
  ['existing account pin path', gate.includes('6 DIGIT PIN') && gate.includes('claimDeviceLinkPin')],
  ['source confirmation required', gate.includes('confirm-source-link') && gate.includes('confirmDeviceLink')],
  ['teacher self registration blocked in UI', gate.includes('管理者から発行') && gate.includes('TEACHER IDENTITY')],
  ['ranking visibility editor', gate.includes('always_public') && gate.includes('always_private') && gate.includes('毎回確認する')],
  ['original avatar ids', gate.includes("['nova','NOVA']") && gate.includes("['aster','ASTER']") && !gate.includes('🚀')],
  ['student number normalized', cloud.includes('normalizeStudentNumber') && cloud.includes("replace(/[^0-9]/g, '')")],
  ['multi-device rpc wrappers', ['createDeviceLinkPin','claimDeviceLinkPin','getDeviceLinkSourceStatus','getDeviceLinkTargetStatus','confirmDeviceLink'].every(k=>cloud.includes(k))],
  ['hold text selection disabled', css.includes('.hold-btn,.hold-btn *') && css.includes('user-select:none')],
  ['v205 cache contains gate assets', sw.includes("const CACHE = 'interval-cosmos-v2-0-5-") && sw.includes('account-gate.js') && sw.includes('account-v205.css')],
];
let fail=0;
for(const [name,ok] of tests){ console.log(ok?'PASS':'FAIL',name); if(!ok) fail++; }
process.exitCode=fail?1:0;
