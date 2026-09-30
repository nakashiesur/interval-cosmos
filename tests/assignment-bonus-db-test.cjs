// Disposable full-schema PostgreSQL verification; no network or production database.
const fs=require('fs'),path=require('path'),assert=require('node:assert/strict'),cp=require('child_process'),{randomUUID}=require('crypto');
const pkg=process.env.PGLITE_PATH||'@electric-sql/pglite';const {PGlite}=require(pkg);
const {pgcrypto}=require(path.join(pkg,'dist/contrib/pgcrypto.cjs'));
const root=path.resolve(__dirname,'..');const read=p=>fs.readFileSync(path.join(root,p),'utf8');
(async()=>{const db=new PGlite({extensions:{pgcrypto}});try{
await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create schema extensions;
create table auth.users(id uuid primary key,aud text,role text,is_anonymous boolean);
create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create function auth.role() returns text language sql as $$select coalesce(nullif(current_setting('request.jwt.claim.role',true),''),'authenticated')$$;
grant usage on schema auth to authenticated,anon;grant execute on all functions in schema auth to authenticated,anon;`);
cp.execFileSync(process.execPath,['scripts/build-v2.0.5-supabase-bundle.js'],{cwd:root});
const migration=fs.readdirSync(path.join(root,'supabase/migrations')).find(x=>x.endsWith('_assignment_completion_bonus.sql'));
const bundle=read('dist/interval-cosmos-v2.0.5-complete.sql');const marker=bundle.indexOf(': supabase/migrations/'+migration);const start=bundle.lastIndexOf('-- >>> BEGIN',marker);assert(start>0);await db.exec(bundle.slice(0,start));console.log('PASS entire existing database builds locally');
const auth=randomUUID(),player=randomUUID();await db.query('insert into auth.users values($1,\'authenticated\',\'authenticated\',true)',[auth]);await db.query("insert into players(id,account_type,player_name,avatar_id,is_admin) values($1,'staff','Bonus QA','teacher',true)",[player]);await db.query('insert into player_devices(auth_user_id,player_id) values($1,$2)',[auth,player]);await db.query("select set_config('request.jwt.claim.sub',$1,false)",[auth]);
const createOld=async()=> (await db.query("select create_assignment_v2('Before bonus','',array['TEXT','KEYS'],array['P1'],now()-interval '1 day',now()+interval '1 day',null,80,true) id")).rows[0].id;
const submit=async(id,{score=500,total=10,correct=10,mode='TEXT',event=randomUUID()}={})=>({event,result:(await db.query("select submit_assignment_session_v2($1,$2,$3,$4,$5,$6,1,1,'{}',clock_timestamp()) result",[event,id,mode,score,total,correct])).rows[0].result});
const old=await createOld();await submit(old);const waiting=await createOld();
await db.exec(read('supabase/migrations/'+migration));console.log('PASS migration applies to complete real schema');
assert.equal((await db.query('select bonus_points from assignments where id=$1',[waiting])).rows[0].bonus_points,100);
assert.equal((await submit(old)).result.bonus_earned,0);assert.equal((await db.query('select sum(reward_points) n from player_assignment_rewards')).rows[0].n,0);console.log('PASS preexisting completions excluded even on later retries; old assignments default to 100');
await db.exec('set role authenticated');
const create=async(points=375)=> (await db.query("select create_assignment_v3('New task','',array['TEXT','KEYS'],array['P1'],now()-interval '1 day',now()+interval '1 day',null,80,true,$1) id",[points])).rows[0].id;
const a=await create();assert.equal((await submit(a,{score:1000,correct:5})).result.bonus_earned,0);
const first=await submit(a,{score:500});assert.equal(first.result.bonus_earned,375);assert.equal(first.result.bonus_awarded,375);assert.equal(first.result.best_score,1000);console.log('PASS lower-score qualifying clear awards configured points despite earlier higher failing score');
assert.equal((await submit(a,{event:first.event})).result.bonus_earned,375);assert.equal((await submit(a,{mode:'KEYS'})).result.bonus_earned,0);
const payload={clientEventId:first.event,source:'assignment',assignmentId:a,mode:'TEXT',score:500,totalAnswers:10,correctAnswers:10,maxCombo:1,avgResponse:1,playedAt:new Date().toISOString()};
const duplicate=(await db.query("select submit_saved_play($1,'ask',$2::jsonb) result",[player,JSON.stringify(payload)])).rows[0].result;assert.equal(duplicate.bonus_earned,375);assert.equal(duplicate.duplicate,true);
let progress=(await db.query('select get_my_cosmos_progress() result')).rows[0].result;assert.equal(progress.point_breakdown.assignments,375);const total=progress.player.achievement_points;progress=(await db.query('select get_my_cosmos_progress() result')).rows[0].result;assert.equal(progress.player.achievement_points,total);assert.equal(progress.point_breakdown.assignments,375);console.log('PASS retries, second mode, lost acknowledgement and point recalculation do not double-award or lose bonus');
assert.equal((await submit(waiting)).result.bonus_earned,100);
const zero=await create(0);assert.equal((await submit(zero)).result.bonus_earned,0);
const noAnswers=await create(90);const empty=await submit(noAnswers,{total:0,correct:0});assert.equal(empty.result.this_run_achieved,false);assert.equal(empty.result.bonus_earned,0);assert.equal((await submit(noAnswers)).result.bonus_earned,90);console.log('PASS prospective 100-point default, zero reward, zero answers and later real completion');
for(const n of [-1,10001,null])await assert.rejects(()=>create(n));await assert.rejects(()=>db.query('select * from player_assignment_rewards'));await assert.rejects(()=>db.query('insert into player_assignment_rewards(player_id,assignment_id,reward_points,reason) values($1,$2,999,\'earned\')',[player,zero]));console.log('PASS validation and direct-ledger access denied');
const offlineOld=await create(50);const beforeLaunch=(await db.query("select submit_assignment_session_v2($1,$2,'TEXT',500,10,10,1,1,'{}',now()-interval '1 hour') r",[randomUUID(),offlineOld])).rows[0].r;assert.equal(beforeLaunch.bonus_earned,0);assert.equal(beforeLaunch.bonus_excluded,true);assert.equal((await submit(offlineOld)).result.bonus_earned,0);console.log('PASS delayed offline completion from before bonus enablement is excluded');
const optional=(await db.query("select create_assignment_v3('No goals','',array['TEXT'],array['P1'],now()-interval '1 day',now()+interval '1 day',null,null,true,0) id")).rows[0].id;assert.equal((await submit(optional,{total:0,correct:0})).result.this_run_achieved,false);console.log('PASS even assignments without optional targets require an answer');

const other=randomUUID(),otherPlayer=randomUUID();await db.exec('reset role');await db.query('insert into auth.users values($1,\'authenticated\',\'authenticated\',true)',[other]);await db.query("insert into players(id,account_type,player_name,avatar_id,is_admin) values($1,'staff','Other QA','nova',false)",[otherPlayer]);await db.query('insert into player_devices(auth_user_id,player_id) values($1,$2)',[other,otherPlayer]);await db.query("select set_config('request.jwt.claim.sub',$1,false)",[other]);await db.exec('set role authenticated');await assert.rejects(()=>create(100));const own=(await db.query('select get_my_assignment_status($1) s',[a])).rows[0].s;assert.equal(own.bonus_awarded,null);assert.equal((await submit(a)).result.bonus_earned,375);console.log('PASS non-admin cannot set rewards and each player has an independent one-time bonus');
await db.exec('reset role');const earned=(await db.query('select sum(reward_points) n from player_assignment_rewards where player_id=$1',[player])).rows[0].n;assert.equal(earned,565);console.log('PASS final original-player ledger sum exactly 565 PT');
}finally{await db.close()}})().catch(e=>{console.error(e.message);process.exitCode=1});
