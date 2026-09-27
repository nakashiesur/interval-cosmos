const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

// Exercise the actual engines with Safari's interruption state, without hardware.
async function testEngine(file, name, end) {
  const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
  const code = source.slice(source.indexOf(`class ${name}`), source.indexOf(end));
  let created = 0;
  class Context {
    constructor() { created++; this.state = 'suspended'; this.currentTime = 0; this.resumes = 0; this.destination = {}; }
    createGain() { return { gain: { value: 0, setTargetAtTime() {} }, connect() {} }; }
    async resume() { this.resumes++; this.state = 'running'; }
    async close() { this.state = 'closed'; }
  }
  const handlers = {};
  const doc = {hidden:false,addEventListener:(name,fn)=>{handlers[name]=fn}};
  const sandbox = {document:doc,window: {AudioContext: Context,addEventListener:(name,fn)=>{handlers[name]=fn}}, state: {settings:{volume:.72}}, localStorage:{getItem:()=>null}};
  vm.createContext(sandbox);
  const engine = vm.runInContext(`${code}; new ${name}()`, sandbox);
  await engine.unlock();
  assert.equal(engine.ctx.state, 'running');
  const original = engine.ctx;
  for (const state of ['interrupted', 'suspended']) {
    original.state = state;
    const before = original.resumes;
    await engine.unlock();
    assert.equal(original.resumes, before + 1, `${name}: resume ${state}`);
    assert.equal(engine.ctx, original, 'Reuse existing audio graph');
  }
  const before = original.resumes;
  await engine.unlock();
  assert.equal(original.resumes, before, 'Do not resume an already-running context');
  original.state = 'closed';
  await engine.unlock();
  assert.notEqual(engine.ctx, original);
  assert.equal(created, 2);
  assert.equal(engine.ctx.state, 'running');
  const backgrounded = engine.ctx;
  doc.hidden = true;
  handlers.visibilitychange();
  assert.equal(engine.ctx, null);
  assert.equal(backgrounded.state, 'closed');
  assert.equal(await engine.unlock(), false);
  assert.equal(engine.ctx, null, 'Background timers cannot recreate audio');
  doc.hidden = false;
  handlers.visibilitychange();
  assert.equal(engine.ctx, null, 'No automatic foreground playback');
  await engine.unlock();
  assert.equal(engine.ctx.state, 'running');
  assert.notEqual(engine.ctx, backgrounded);
  handlers.pagehide();
  assert.equal(engine.ctx, null);
  console.log(`PASS ${name}: interrupted/suspended/running/closed/background/pagehide`);
}
async function testReplacement(file, name, end) {
  const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
  const code = source.slice(source.indexOf(`class ${name}`), source.indexOf(end));
  const timers = [], oscillators = [];
  const parameter = () => ({setValueAtTime(){}, exponentialRampToValueAtTime(){}, setTargetAtTime(){}});
  class Context {
    constructor(){this.state='running';this.currentTime=0;this.destination={};}
    createGain(){return {gain:parameter(),connect(){},disconnect(){}};}
    createOscillator(){const o={frequency:parameter(),detune:parameter(),connect(g){return g},start(t){this.started=t},stop(t){if(t===undefined)this.cancelled=true},disconnect(){this.disconnected=true}};oscillators.push(o);return o;}
  }
  const sandbox={document:{hidden:false,addEventListener(){}},window:{AudioContext:Context,addEventListener(){},setTimeout:fn=>timers.push(fn)},setTimeout:fn=>timers.push(fn),state:{settings:{sound:true,volume:.7,audioStyle:'both'}},localStorage:{getItem:()=>JSON.stringify({sound:true,audioStyle:'both'})}};
  vm.createContext(sandbox);
  const e=vm.runInContext(`${code};new ${name}()`,sandbox);
  const play=q=>name==='AudioEngine'?e.playInterval(q,'both'):e.play(q);
  const stop=()=>name==='AudioEngine'?e.stopPending():e.stop();
  const q={baseMidi:60,targetMidi:64};
  await play(q);
  const old=[...oscillators]; assert.equal(old.length,6);
  await play(q);
  assert(old.every(o=>o.cancelled&&o.disconnected),'Previous playing and scheduled voices are stopped');
  const before=oscillators.length; timers.shift()();
  assert.equal(oscillators.length,before,'Previous BOTH continuation cannot resume');
  stop(); timers.splice(0).forEach(fn=>fn());
  assert(oscillators.every(o=>o.cancelled),'End/next question cancels all voices');
  assert.equal(e.voices.size,0);
  let resume; e.unlock=()=>new Promise(resolve=>{resume=resolve});
  const pending=play(q); stop(); resume(); await pending;
  assert.equal(oscillators.length,before,'A pending unlock cannot resurrect stopped audio');
  const callbacks=[];e.unlock=()=>new Promise(resolve=>callbacks.push(resolve));
  const first=play(q),second=play(q); callbacks[1]();await second;const latest=oscillators.length;callbacks[0]();await first;
  assert.equal(oscillators.length,latest,'Latest request wins even when resume resolves out of order');
  console.log(`PASS ${name}: voice cancellation, BOTH timer, stop during resume, rapid replay`);
}
(async()=>{
  await testReplacement('app.js','AudioEngine','const audio = new AudioEngine();');
  await testReplacement('phase6-assignments-v205.js','AssignmentAudio','  function accidental');
  await testEngine('app.js','AudioEngine','const audio = new AudioEngine();');
  await testEngine('phase6-assignments-v205.js','AssignmentAudio','  function accidental');
})().catch(e=>{console.error(e);process.exitCode=1;});
