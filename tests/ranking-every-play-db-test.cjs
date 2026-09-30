// Local, disposable PostgreSQL (PGlite) regression. Never connects to Supabase.
// PGLITE_PATH=/absolute/path/to/pglite node tests/ranking-every-play-db-test.cjs
const {PGlite}=require(process.env.PGLITE_PATH || '@electric-sql/pglite');
const fs=require('fs'),path=require('path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');const read=p=>fs.readFileSync(path.join(root,p),'utf8');
(async()=>{
 const db=new PGlite();
 await db.exec(`create role anon;create role authenticated;create table public.players(id uuid primary key,ranking_visibility text,is_suspended boolean default false);
 insert into players values('00000000-0000-0000-0000-000000000001','ask',false);
 create function public.current_player_id() returns uuid language sql as $$select '00000000-0000-0000-0000-000000000001'::uuid$$;
 create function public.is_current_admin() returns boolean language sql as $$select true$$;`);
 const schema=read('sql/base-v2.0.5/part-02.sql');await db.exec(schema.slice(schema.indexOf('create table public.assignments'),schema.indexOf('-- 5. Achievements')));
 const base=Array.from({length:8},(_,i)=>read(`sql/base-v2.0.5/part-${String(i+1).padStart(2,'0')}.sql`)).join('');
 const original=base.slice(base.indexOf('create or replace function public.submit_play_session(')).split('\n$$;')[0]+'\n$$;';
 await db.exec(original);
 let n=1;
 const submit=async(score,source='ranked',event=null)=>(await db.query(`select * from public.submit_play_session($1,$2,'TEXT',$3,10,8,4,1,'{}',clock_timestamp(),null)`,[event||`10000000-0000-0000-0000-${String(n++).padStart(12,'0')}`,source,score])).rows[0];
 await submit(1000);const broken=await submit(500);assert.equal(broken.publication_required,false);console.log('PASS reproduces missing prompt below private best while public ranking is empty');
 const migration=fs.readdirSync(path.join(root,'supabase/migrations')).find(n=>n.endsWith('_ranking_prompt_every_play.sql'));await db.exec(read('supabase/migrations/'+migration));
 for(const score of [500,1000,1200]){const r=await submit(score);assert.equal(r.publication_required,true);console.log('PASS asks for score '+score);}
 let pub=read('supabase/migrations/20260927103943_suspended_account_actions.sql');pub=pub.slice(pub.indexOf('create or replace function public.publish_play_session(')).split('\n$$;')[0]+'\n$$;';await db.exec(pub);
 const low=await submit(400);await db.query('select * from publish_play_session($1)',[low.session_id]);
 assert.equal((await db.query('select min(public_score) score from ranking_bests')).rows[0].score,400);console.log('PASS lower-than-private-best play can enter an empty public ranking');
 const lower=await submit(200);await db.query('select * from publish_play_session($1)',[lower.session_id]);assert.equal((await db.query('select min(public_score) score from ranking_bests')).rows[0].score,400);console.log('PASS publishing a lower score preserves public best');
 await db.exec(read('supabase/migrations/20260929142912_admin_ranking_entry_delete.sql'));
 for(const row of (await db.query('select * from ranking_bests')).rows)await db.query("select admin_delete_ranking_entry($1,$2,$3,$4,$5,'Delete')",[row.player_id,row.mode,row.period,row.public_score,row.public_updated_at]);
 const after=await submit(300);assert.equal(after.publication_required,true);await db.query('select * from publish_play_session($1)',[after.session_id]);assert.equal((await db.query('select min(public_score) score from ranking_bests')).rows[0].score,300);console.log('PASS new play after admin deletion asks and can be published');
 for(const policy of ['always_private','always_public']){await db.query('update players set ranking_visibility=$1',[policy]);assert.equal((await submit(1300)).publication_required,false);console.log('PASS respects '+policy);}
 await db.exec("update players set ranking_visibility='ask'");assert.equal((await submit(50,'practice')).publication_required,false);console.log('PASS practice does not ask');
 const event='20000000-0000-0000-0000-000000000001';await submit(50,'ranked',event);assert.equal((await submit(50,'ranked',event)).publication_required,false);console.log('PASS duplicate direct submissions do not re-prompt');
 await db.close();
})().catch(e=>{console.error(e);process.exitCode=1});
