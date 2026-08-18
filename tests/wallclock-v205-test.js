const fs=require('fs');
const vm=require('vm');
const path=require('path');

const code=fs.readFileSync(path.join(__dirname,'..','phase0-wallclock-v205.js'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

let wall=0;
let nativeId=1;
let queue=[];
let timerText='60';
const listeners={};
const windowObj={
  requestAnimationFrame(cb){queue.push(cb);return nativeId++;},
  cancelAnimationFrame(){},
  addEventListener(name,cb){(listeners[name]??=[]).push(cb);},
};
const documentObj={
  visibilityState:'visible',
  querySelector(sel){if(sel==='#timerText')return{textContent:timerText};return null;},
  addEventListener(name,cb){(listeners[`d:${name}`]??=[]).push(cb);},
};
const context={window:windowObj,document:documentObj,Date:{now:()=>wall},Number,Math,console};
vm.createContext(context);
vm.runInContext(code,context,{filename:'phase0-wallclock-v205.js'});

let calls=[];
function gameLoop(now){calls.push(now);windowObj.requestAnimationFrame(gameLoop);}
function runNext(perf,wallTime){
  const cb=queue.shift();
  if(!cb)throw new Error('no queued frame');
  wall=wallTime;cb(perf);
}

// Initial frame and a normal 16ms frame: exactly one callback each.
wall=0;windowObj.requestAnimationFrame(gameLoop);
runNext(100,1000);
const initialCount=calls.length;
runNext(116,1016);
const normalCount=calls.length-initialCount;

// The next frame was already registered. Simulate a 10s background pause before it fires.
const beforeGap=calls.length;
runNext(10116,11016);
const catchupCount=calls.length-beforeGap;

// Discard the pending frame and simulate a completely new game after time on menus.
queue=[];
wall=20000;
windowObj.requestAnimationFrame(gameLoop); // schedule gap > NEW_SESSION_GAP_MS => baseline reset
const beforeNew=calls.length;
runNext(10132,20016);
const newSessionCount=calls.length-beforeNew;

// Unlimited mode must not synthesize time-decrement frames.
queue=[];timerText='∞';
wall=21000;windowObj.requestAnimationFrame(gameLoop);
runNext(11132,21016);
const beforeUnlimitedGap=calls.length;
runNext(21132,31016);
const unlimitedGapCount=calls.length-beforeUnlimitedGap;

const tests=[
  ['normal frame is not duplicated',normalCount===1],
  ['10 second hidden gap is caught up',catchupCount>=39&&catchupCount<=41],
  ['new session does not inherit menu elapsed time',newSessionCount===1],
  ['unlimited practice skips catch-up',unlimitedGapCount===1],
  ['only named core gameLoop is targeted',code.includes("callback.name === 'gameLoop'")],
  ['synthetic rAF scheduling is suppressed',code.includes('if (insideCatchup) return suppressedId--')],
  ['wallclock layer loads before account gate/core import',index.indexOf('phase0-wallclock-v205.js')>=0&&index.indexOf('phase0-wallclock-v205.js')<index.indexOf('account-gate.js')],
  ['wallclock asset cached',sw.includes('phase0-wallclock-v205.js')],
  ['versioned local assets can use precache',sw.includes('ignoreSearch: true')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
