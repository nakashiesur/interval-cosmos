const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('cloud.js','utf8');
const sessions=fs.readFileSync('guest-sessions-v205.js','utf8');
function load(store,online){
 const c={console,navigator:{onLine:online},document:{hidden:false},localStorage:{getItem:k=>store.get(k)||null,setItem:(k,v)=>store.set(k,v),removeItem:k=>store.delete(k)},INTERVAL_COSMOS_CLOUD:{supabaseUrl:'https://example.supabase.co',supabaseAnonKey:'public'},addEventListener(){},setInterval(){},supabase:{createClient(){throw Error('Guest must not initialize network auth')}}};
 c.window=c;vm.createContext(c);vm.runInContext(sessions,c);vm.runInContext(source,c);return c;
}
(async()=>{
 const store=new Map([['intervalCosmos.guest.v205','1']]);
 for(const online of [false,true,false]){
  const c=load(store,online),data=await c.IntervalCosmosCloud.init();
  assert.equal(data.profile.is_guest,true);
  assert.equal(data.user,null);
  assert.equal(c.IntervalCosmosCloud.getCachedPlayer().is_guest,true);
  if(!store.has('interval-cosmos-guest-sessions-v205'))c.IntervalCosmosGuestSessions.save({mode:'TEXT',score:123});
  assert.equal(c.IntervalCosmosGuestSessions.read().length,1);
  assert.equal(c.IntervalCosmosGuestSessions.read()[0].score,123);
 }
 console.log('PASS offline guest initialization, SDK-free start, reload/reconnect local history retention');
})().catch(e=>{console.error(e);process.exitCode=1});
