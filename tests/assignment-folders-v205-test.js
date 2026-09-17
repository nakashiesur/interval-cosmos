const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'..','phase6-assignments-v205.js'),'utf8');
const body=source.slice(source.indexOf('  async function renderStudent(){'),source.indexOf('  function studentCard('));
const display={innerHTML:''};
const rows=[{id:'active',status:'active'},{id:'upcoming',status:'upcoming'},
  {id:'closed-1',status:'closed'},{id:'closed-2',status:'closed'}];
const context={rpc:async()=>rows,overlay:()=>display,statusOf:a=>a.status,
  studentCard:a=>`<article>${a.id}</article>`,head:()=>'',console,document:{querySelector:()=>null},
  archiveBreakpoint:{matches:false}};
vm.createContext(context);
vm.runInContext(`${body}\nglobalThis.run=renderStudent;`,context);
(async()=>{
  await context.run();
  assert(display.innerHTML.indexOf('active')<display.innerHTML.indexOf('<details'));
  assert(display.innerHTML.indexOf('upcoming')<display.innerHTML.indexOf('<details'));
  assert(display.innerHTML.includes('終了した課題 <span>2件</span>'));
  assert(display.innerHTML.includes('<details class="v205-a-closed" >'));
  assert(display.innerHTML.indexOf('closed-1')>display.innerHTML.indexOf('<details'));
  assert(display.innerHTML.indexOf('closed-2')<display.innerHTML.indexOf('</details>'));
  context.archiveBreakpoint.matches=true;
  await context.run();
  assert(display.innerHTML.includes('<details class="v205-a-closed" open>'));
  console.log('PASS active and upcoming visible; expired tasks remain in expandable history');
})().catch(e=>{console.error(e);process.exitCode=1});
