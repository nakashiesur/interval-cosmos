const fs = require('fs');
const vm = require('vm');
const path = require('path');

const app = { innerHTML:'', addEventListener(){} };
const overlayRoot = { append(){} };
const ctx2d = { setTransform(){}, fillRect(){}, beginPath(){}, arc(){}, fill(){}, fillStyle:'' };
const canvas = { style:{}, getContext(){ return ctx2d; } };
const document = {
  documentElement:{ classList:{toggle(){}} },
  querySelector(sel){ if(sel==='#app')return app; if(sel==='#overlay-root')return overlayRoot; if(sel==='#starfield')return canvas; return null; },
  querySelectorAll(){return[];},
  createElement(){return {style:{},append(){},remove(){},click(){}};}
};
const storage = new Map();
const localStorage = { getItem:k=>storage.get(k)||null, setItem:(k,v)=>storage.set(k,String(v)) };
const windowObj = {
  INTERVAL_COSMOS_CLOUD:{}, IntervalCosmosCloud:{configured:()=>false},
  addEventListener(){}, setTimeout(fn){ fn(); return 1; }, clearTimeout(){},
  requestAnimationFrame(){return 0;}, cancelAnimationFrame(){},
  innerWidth:430, innerHeight:932, devicePixelRatio:1, localStorage,
};
const context = {
  console, document, window:windowObj, localStorage, navigator:{}, location:{protocol:'file:'},
  innerWidth:430, innerHeight:932, performance:{now:()=>1000},
  requestAnimationFrame:()=>0, cancelAnimationFrame(){}, setTimeout:windowObj.setTimeout, clearTimeout(){},
  crypto:{randomUUID:()=> 'uuid'}, Blob, URL, confirm:()=>true,
};
windowObj.document=document; windowObj.performance=context.performance; windowObj.crypto=context.crypto;
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(__dirname,'..','app.js'),'utf8'), context, {filename:'app.js'});
const val = expr => vm.runInContext(expr, context);

async function runOrder(order, style='both') {
  return await val(`(async()=>{
    const e = new AudioEngine();
    e.ctx = { currentTime: 10 };
    e.master = {};
    e.unlock = async()=>{};
    const log = [];
    e.playMelodic = ()=>log.push('M');
    e.playHarmonic = ()=>log.push('H');
    state.settings.sound = true;
    state.settings.bothOrder = '${order}';
    await e.playInterval({baseMidi:60,targetMidi:64}, '${style}');
    return log.join('');
  })()`);
}

(async()=>{
  const cases = [
    ['BOTH default H→M behavior', await runOrder('harmonicFirst') === 'HM'],
    ['BOTH selectable M→H behavior', await runOrder('melodicFirst') === 'MH'],
    ['MELODIC unchanged', await runOrder('harmonicFirst','melodic') === 'M'],
    ['HARMONIC unchanged', await runOrder('harmonicFirst','harmonic') === 'H'],
  ];
  let fail=0;
  for(const [name,ok] of cases){ console.log(ok?'PASS':'FAIL', name); if(!ok)fail++; }
  process.exitCode = fail ? 1 : 0;
})();
