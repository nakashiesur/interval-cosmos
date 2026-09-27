const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('cloud.js','utf8');
const code=source.slice(source.indexOf('  async function ensureAccountAuth()'),source.indexOf('  async function loadActualPlayer()'));
async function run(error){
 let signouts=0,ensures=0,removed=0;
 const c={authUser:{id:'old'},player:{id:'old-player'},offlineProfileKey:'profile',localStorage:{removeItem:()=>removed++},ensureAuth:async()=>{ensures++;return {id:'new'}},client:{auth:{getUser:async()=>({data:{user:error?null:{id:'valid'}},error}),signOut:async opts=>{assert.equal(opts.scope,'local');signouts++;return {error:null}}}}};
 vm.createContext(c);vm.runInContext(code,c);
 let result,thrown;try{result=await c.ensureAccountAuth()}catch(e){thrown=e}
 return {c,result,thrown,signouts,ensures,removed};
}
(async()=>{
 let r=await run(null);assert.equal(r.result.id,'valid');assert.equal(r.signouts,0);
 for(const code of ['user_not_found','session_not_found']){r=await run({code});assert.equal(r.result.id,'new');assert.equal(r.signouts,1);assert.equal(r.ensures,2);assert.equal(r.c.player,null);assert.equal(r.removed,1)}
 for(const code of ['unexpected_failure','over_request_rate_limit',undefined]){r=await run({code,message:'network unavailable'});assert(r.thrown);assert.equal(r.signouts,0);assert.equal(r.removed,0);assert.equal(r.c.player.id,'old-player')}
 const recovery=fs.readFileSync('phase2-recovery-v205-fixed.js','utf8');assert.equal((recovery.match(/await cloud.ensureAccountAuth\(\)/g)||[]).length,2);
 console.log('PASS deleted Auth identity replacement; valid/network-error sessions preserved; registration and recovery guarded');
})().catch(e=>{console.error(e);process.exitCode=1});
