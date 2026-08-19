const fs=require('fs');
const path=require('path');
const js=fs.readFileSync(path.join(__dirname,'..','phase8-pc-controls-v205.js'),'utf8');
const css=fs.readFileSync(path.join(__dirname,'..','phase8-pc-controls-v205.css'),'utf8');
const polishJs=fs.readFileSync(path.join(__dirname,'..','phase8-config-polish-v205.js'),'utf8');
const polishCss=fs.readFileSync(path.join(__dirname,'..','phase8-config-polish-v205.css'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

const defaults=[
  "P1:{prefix:null,key:'1'}",
  "m2:{prefix:'m',key:'2'}", "M2:{prefix:null,key:'2'}",
  "m3:{prefix:'m',key:'3'}", "M3:{prefix:null,key:'3'}",
  "P4:{prefix:null,key:'4'}", "TT:{prefix:null,key:'t'}", "P5:{prefix:null,key:'5'}",
  "m6:{prefix:'m',key:'6'}", "M6:{prefix:null,key:'6'}",
  "m7:{prefix:'m',key:'7'}", "M7:{prefix:null,key:'7'}",
  "P8:{prefix:null,key:'8'}",
];
const tests=[
  ['uses mnemonic default answer bindings',defaults.every(x=>js.includes(x))],
  ['minor intervals use two-stage prefix input',js.includes('armedPrefix') && js.includes('PREFIX_TIMEOUT') && js.includes('M → 度数')],
  ['same prefix can be shared while exact sequences conflict',js.includes('sequenceOwners') && js.includes('prefixes') && js.includes('directKeys')],
  ['Esc and Space are reserved',js.includes("new Set(['Escape', 'Space'])") && js.includes('システム操作')],
  ['settings receives PC KEY CONFIG entry',js.includes('PC KEY CONFIG') && js.includes('data-pc-config-open')],
  ['key capture and reset/save exist',js.includes('data-pc-record') && js.includes('data-pc-config-reset') && js.includes('data-pc-config-save')],
  ['bindings persist locally',js.includes('intervalCosmos.pcKeys.v205') && js.includes('localStorage.setItem')],
  ['editable fields are protected',js.includes('input, textarea, select') && js.includes('isEditable(event.target)')],
  ['R retries normal and assignment results',js.includes('[data-action="retry"]') && js.includes('[data-a-retry]')],
  ['Esc closes admin dashboard',js.includes('[data-v205-admin-close]')],
  ['Esc aborts active assignment through its existing control',js.includes("'.v205-a-game'") && js.includes('[data-a-abort]')],
  ['Esc exits active normal play immediately through delegated home action',js.includes('syntheticHome') && js.includes("button.dataset.action = 'home'" )],
  ['answer hints decorate both engines',js.includes('[data-answer]') && js.includes('[data-a-answer]') && js.includes('dataset.pcKey')],
  ['keyboard hints are desktop-only',css.includes('(hover:hover)') && css.includes('(pointer:fine)') && css.includes('(pointer:coarse)')],
  ['key config UI is present',css.includes('.v205-pc-config-overlay') && css.includes('.v205-pc-keybox.recording')],
  ['empty prefix is visually blank',polishJs.includes("button.textContent = ''") && polishJs.includes('予備キー：未設定')],
  ['decision keys receive distinct red styling',polishCss.includes('.v205-pc-keybox.primary') && polishCss.includes('rgba(255,112,136')],
  ['learning state uses red pulse and Japanese instruction',polishCss.includes('@keyframes v205PcLearn') && polishJs.includes('希望するキーを押してください') && polishJs.includes("recording.textContent = '…'" )],
  ['polish observer is child-list only',polishJs.includes('{ subtree: true, childList: true }') && !polishJs.includes('attributes: true')],
  ['PC controls load before assignment engine',index.indexOf('phase8-pc-controls-v205.js?v=alpha8.3') < index.indexOf('phase6-assignments-v205.js?v=alpha5.1')],
  ['polish assets are loaded',index.includes('phase8-config-polish-v205.css?v=alpha8.4') && index.includes('phase8-config-polish-v205.js?v=alpha8.4')],
  ['pc assets use new cache version',sw.includes('alpha8-4')],
  ['pc assets cached',sw.includes('phase8-pc-controls-v205.js') && sw.includes('phase8-pc-controls-v205.css') && sw.includes('phase8-config-polish-v205.js') && sw.includes('phase8-config-polish-v205.css')],
  ['observer only watches child list',js.includes("{ subtree: true, childList: true }") && !js.includes('attributes: true')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
