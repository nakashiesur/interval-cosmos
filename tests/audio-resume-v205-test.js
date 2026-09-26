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
  }
  const sandbox = {window: {AudioContext: Context}, state: {settings:{volume:.72}}, localStorage:{getItem:()=>null}};
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
  console.log(`PASS ${name}: interrupted/suspended/running/closed`);
}
(async()=>{
  await testEngine('app.js','AudioEngine','const audio = new AudioEngine();');
  await testEngine('phase6-assignments-v205.js','AssignmentAudio','  function accidental');
})().catch(e=>{console.error(e);process.exitCode=1;});
