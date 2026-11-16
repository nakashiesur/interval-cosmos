// Disposable PostgreSQL verification for ranking milestones and admin activity; no network or production database.
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
const bundle=read('dist/interval-cosmos-v2.0.5-complete.sql');
const marker=bundle.lastIndexOf('-- >>> BEGIN');
await db.exec(bundle.slice(0,marker));
const ids=Array.from({length:4},()=>randomUUID());
const [student,rival,admin,suspended]=ids;
const authIds=Array.from({length:4},()=>randomUUID());
for (const [i,id] of ids.entries()){
  await db.query("insert into auth.users values($1,'authenticated','authenticated',true)",[authIds[i]]);
  if(id===admin) await db.query("insert into players(id,account_type,player_name,avatar_id,is_admin) values($1,'staff','Admin QA','teacher',true)",[id]);
  else await db.query("insert into players(id,account_type,student_number,player_name,course_code,avatar_id,is_suspended) values($1,'student',$2,$3,(select code from courses limit 1),'nova',$4)",[id,String(900+i),'Student '+i,id===suspended]);
  await db.query("insert into player_devices(auth_user_id,player_id) values($1,$2)",[authIds[i],id]);
}
await db.query("insert into player_frames(player_id,frame_id) values($1,'pulsar')",[rival]);
await db.exec(bundle.slice(marker));
const one=async(sql,args=[]) => (await db.query(sql,args)).rows[0];
const has=async (id,frame) => (await one('select exists(select 1 from player_frames where player_id=$1 and frame_id=$2) ok',[id,frame])).ok;
const award=async (id,f)=>db.query("insert into player_frames(player_id,frame_id) values($1,$2) on conflict do nothing",[id,f]);
assert(await has(rival,'pulsar'));
assert.equal((await one("select unlock_rule->>'requires_frame' prev from frame_catalog where id='omega'")).prev,'event_horizon');
await award(student,'supernova');assert(!(await has(student,'supernova')));
await db.query(`insert into learning_answers(player_id,event_id,interval_key,chosen_key,response_ms,answered_at)
 select $1,gen_random_uuid(),k,case when n<=15 then k when k='P1' then 'M2' else 'P1' end,100,now()
 from unnest(array['P1','m2','M2','m3','M3','P4','TT','P5','m6','M6','m7','M7','P8']) k cross join generate_series(1,20) n`,[student]);
await award(student,'supernova');assert(await has(student,'supernova'));
await award(student,'pulsar');assert(!(await has(student,'pulsar')));
await db.query(`insert into learning_answers(player_id,event_id,interval_key,chosen_key,response_ms,answered_at)
 select $1,gen_random_uuid(),k,k,100,now() from (select distinct interval_key k from learning_answers where player_id=$1) s cross join generate_series(1,30)`,[student]);
await award(student,'pulsar');assert(!(await has(student,'pulsar')));
// Drive the actual evaluator with prior achievements and enough earned PT.
await db.query(`insert into player_achievements(player_id,achievement_id,points_awarded)
  select $1,id,case when id='first_signal' then 23500 else points end from achievement_catalog
  where (select unlock_rule->'ids' from frame_catalog where id='omega') ? id`,[student]);
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[authIds[0]]);
await one('select evaluate_my_progress()');
assert(await has(student,'event_horizon'));
assert(await has(student,'omega')); // 45/50 = 90%, no PULSAR.
assert(!(await has(student,'pulsar')));
const resolve=(i)=>db.query("select set_config('request.jwt.claim.sub',$1,false)",[authIds[i]]);
const submit=async(i,mode,score,visibility)=>{
 await resolve(i);
 await db.query('update players set ranking_visibility=$2 where id=$1',[ids[i],visibility]);
 return one("select * from submit_play_session($1,'ranked',$2,$3,20,20,20,1,'{}',now(),null)",[randomUUID(),mode,score]);
};
const wins=async()=> (await one('select count(*)::int n from ic_progress_private.monthly_firsts where player_id=$1',[student])).n;
await submit(0,'TEXT',100,'always_private');assert.equal(await wins(),0);
const ask=await submit(0,'TEXT',200,'ask');assert.equal(await wins(),0);
await db.query('select publish_play_session($1)',[ask.session_id]);assert.equal(await wins(),1);
await submit(0,'TEXT',225,'always_public');assert.equal(await wins(),1);
await submit(1,'TEXT',300,'always_public');assert.equal(await wins(),1);
await submit(0,'KEYS',250,'always_public');assert.equal(await wins(),2);
await award(student,'pulsar');assert(await has(student,'pulsar'));
await db.query("update players set is_suspended=true where id=$1",[admin]);
await resolve(2);await db.exec('set role authenticated');
await assert.rejects(()=>one('select * from get_admin_recent_plays()'),{code:'42501'});
await db.exec('reset role');await db.query("update players set is_suspended=false where id=$1",[admin]);
await resolve(0);await db.exec('set role authenticated');
await assert.rejects(()=>one('select * from get_admin_recent_plays()'),{code:'42501'});
await assert.rejects(()=>one('select * from ic_progress_private.monthly_firsts'),{code:'42501'});
await resolve(2);
const recent=(await db.query('select * from get_admin_recent_plays()')).rows;
assert(recent.length>=5);
assert(recent.every(r=>r.player_name.startsWith('Student ') && !('student_number' in r)));
assert(recent.every((r,i)=>!i||recent[i-1].played_at>=r.played_at));
assert.equal((await db.query("select * from get_admin_recent_plays(7,'not-a-course')")).rows.length,0);
console.log('PASS existing frame ownership, all three mastery gates, private scores, manual/automatic publication, deduplication, durable first place, admin permissions and filters');
} finally {await db.close()}})().catch(e=>{console.error(e);process.exitCode=1});
