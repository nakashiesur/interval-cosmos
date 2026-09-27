const assert = require('assert');
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const {randomUUID} = require('crypto');
function storage() {
  const map = new Map();
  return {get length(){return map.size},key:i=>[...map.keys()][i],getItem:k=>map.get(k)||null,
    setItem:(k,v)=>map.set(k,v),removeItem:k=>map.delete(k)};
}
function harness(store, server) {
  const events = {};
  const ctx = {console:{warn(){},error(){}}, localStorage:store, navigator:{onLine:true}, document:{hidden:false},
    Date, Math, Intl, JSON, crypto:{randomUUID}, CustomEvent: class {constructor(type){this.type=type}},
    INTERVAL_COSMOS_CLOUD:{supabaseUrl:'https://test.supabase.co',supabaseAnonKey:'public'},
    addEventListener:(name,fn)=>events[name]=fn,dispatchEvent:()=>{},setInterval:()=>{},
    supabase:{createClient:()=>({auth:{getSession:async()=>({data:{session:{user:{id:server.authId}}}})},
      rpc:async(name,args)=>{
        if(server.offline) return {error:{message:'Failed to fetch'}};
        if(name==='get_my_player')return {data:{id:server.playerId,ranking_visibility:server.visibility,account_type:'student'}};
        if(name==='submit_saved_play'){
          server.calls.push(args);
          if(args.p_player_id!==server.playerId)return {error:{code:'42501',message:'wrong owner'}};
          const id=args.p_payload.clientEventId;
          if(server.sessions.has(id))return {data:{...server.sessions.get(id),duplicate:true}};
          if(args.p_visibility!==server.visibility)return {error:{code:'IC001',message:'Publication setting changed'}};
          if(server.reject)return {error:{code:'P0001',message:'Assignment is outside the allowed time window'}};
          const result={session_id:randomUUID(),publication_required:server.visibility==='ask'};
          server.sessions.set(id,result);
          if(server.dropReply){server.dropReply=false;return {error:{message:'Lost response'}}}
          return {data:result};
        }
        throw Error(name);
      }})}};
  ctx.window=ctx;vm.createContext(ctx);
  for(const name of ['offline-outbox-v205.js','cloud.js'])vm.runInContext(fs.readFileSync(path.join(__dirname,'..',name),'utf8'),ctx);
  return ctx;
}
const payload = () => ({mode:'TEXT',score:42,totalAnswers:2,correctAnswers:1,maxCombo:1,avgResponse:400});
(async()=>{
  const store=storage(), server={authId:'auth-a',playerId:'player-a',visibility:'ask',calls:[],sessions:new Map()};
  let h=harness(store,server),c=h.IntervalCosmosCloud;
  await c.init();await c.syncSavedPlays();
  server.offline=true;
  const queued=await c.submitScore(payload());assert(queued.queued);assert.equal(c.getSavedPlays().length,1);
  const original=c.getSavedPlays()[0].payload;
  // Reload while disconnected retains the same owner, event and timestamp.
  h=harness(store,server);c=h.IntervalCosmosCloud;
  assert.equal((await c.init()).status,'offline');
  server.offline=false;await c.syncSavedPlays();
  assert.equal(server.sessions.size,1);assert.equal(c.getSavedPlays()[0].payload.playedAt,original.playedAt);
  assert.equal(server.calls[0].p_payload.clientEventId,queued.client_event_id);
  // Server committed, but client did not receive acknowledgement.
  server.dropReply=true;const lost=await c.submitScore(payload());assert(lost.queued);
  await Promise.all([c.syncSavedPlays(),c.syncSavedPlays()]);
  assert.equal(server.sessions.size,2);assert(c.getSavedPlays().find(r=>r.payload.clientEventId===lost.client_event_id).result.duplicate);
  // Changed publication policy must block without a new insertion.
  server.offline=true;const privateWait=await c.submitScore(payload());server.offline=false;server.visibility='always_public';
  await c.syncSavedPlays();assert.equal(server.sessions.size,2);
  assert.equal(c.getSavedPlays().find(r=>r.payload.clientEventId===privateWait.client_event_id).errorCode,'IC001');
  await assert.rejects(c.retrySavedPlay(privateWait.client_event_id,'ask'));
  await c.retrySavedPlay(privateWait.client_event_id,'always_public');assert.equal(server.sessions.size,3);
  // Unlinked / different auth identity may not replay the old account's queue.
  server.offline=true;const pending=await c.submitScore(payload());server.offline=false;server.authId='auth-b';
  await c.syncSavedPlays();assert.equal(server.sessions.size,3);
  server.authId='auth-a';server.playerId='player-b';await c.syncSavedPlays();assert.equal(server.sessions.size,3);
  server.playerId='player-a';server.reject=true;await c.syncSavedPlays();
  assert.equal(c.getSavedPlays().find(r=>r.payload.clientEventId===pending.client_event_id).status,'blocked');
  // Storage failure is an error, never a false saved/sent confirmation.
  const put=store.setItem;store.setItem=()=>{throw Error('QuotaExceededError')};
  await assert.rejects(c.submitScore(payload()),/保存できません/);store.setItem=put;
  // An SDK download that failed offline must be retried after reconnection.
  h=harness(store,server);c=h.IntervalCosmosCloud;
  const sdk=h.supabase;delete h.supabase;
  let script=null, online=false, downloads=0;
  h.document.querySelector=()=>script;
  h.document.createElement=()=>({dataset:{},remove(){script=null;}});
  h.document.head={appendChild(s){
    script=s;downloads++;
    if(online){h.supabase=sdk;s.onload();}else s.onerror();
  }};
  assert.equal((await c.init()).status,'offline');assert.equal(script,null);
  online=true;server.reject=false;
  assert.equal((await c.init()).status,'ready');assert.equal(downloads,2);
  console.log('PASS durable replay, lost acknowledgement, repeated sync, privacy hold, identity binding, retained rejection and quota failure');
})().catch(e=>{console.error(e);process.exitCode=1});
