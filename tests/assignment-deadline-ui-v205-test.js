const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('phase6-multimode-v205.js','utf8');
const code=source.slice(source.indexOf('  async function handlePlay('),source.indexOf('  function modeBestGrid('));
(async()=>{
  let opened=0,chosen=0,started=0;
  let task={start_at:new Date(Date.now()-60000).toISOString(),deadline_at:new Date(Date.now()-1).toISOString()};
  const c={Date,console,fetchStudentAssignment:async()=>task,allowedModes:()=>['TEXT','KEYS'],renderModeChooser:()=>chosen++,startWithMode:()=>started++,window:{IntervalCosmosAssignmentsV205:{open:()=>opened++}},alert:msg=>{throw Error(msg)}};
  vm.createContext(c);vm.runInContext(code,c);
  await c.handlePlay('expired');assert.equal(opened,1);assert.equal(chosen,0);assert.equal(started,0);
  task={start_at:new Date(Date.now()+60000).toISOString(),deadline_at:new Date(Date.now()+120000).toISOString()};
  await c.handlePlay('upcoming');assert.equal(opened,2);assert.equal(chosen,0);
  task.start_at=new Date(Date.now()-60000).toISOString();
  await c.handlePlay('active');assert.equal(chosen,1);assert.equal(opened,2);
  const base=fs.readFileSync('phase6-assignments-v205.js','utf8');
  let returned=false;
  const start=base.slice(base.indexOf('  async function startGame('),base.indexOf('  async function startGame(')+base.slice(base.indexOf('  async function startGame(')).indexOf('currentAssignment=a;'))+'}';
  const b={statusOf:()=> 'closed',openAssignments:()=>{returned=true}};vm.createContext(b);vm.runInContext(start,b);await b.startGame({});assert(returned);
  console.log('PASS expired/upcoming routes refresh listing, active multi-mode route opens, stale start/retry refreshes');
})().catch(e=>{console.error(e);process.exitCode=1});
