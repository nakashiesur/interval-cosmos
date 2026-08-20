const fs=require('fs');
const path=require('path');

const root=path.join(__dirname,'..');
const js=fs.readFileSync(path.join(root,'phase8-admin-player-management-v205.js'),'utf8');
const css=fs.readFileSync(path.join(root,'phase8-admin-player-management-v205.css'),'utf8');
const sql=fs.readFileSync(path.join(root,'sql','admin-player-management-v2.0.5.sql'),'utf8');
const edge=fs.readFileSync(path.join(root,'supabase','functions','admin-delete-player','index.ts'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');

const tests=[
  ['admin management UI is loaded',index.includes('phase8-admin-player-management-v205.js?v=alpha9.0')&&index.includes('phase8-admin-player-management-v205.css?v=alpha9.0')],
  ['service worker caches admin management UI',sw.includes('phase8-admin-player-management-v205.js')&&sw.includes('phase8-admin-player-management-v205.css')],
  ['UI requires cached admin role',js.includes('is_admin')&&js.includes('if (!isAdmin() || !playerId) return')],
  ['profile edit RPC is wired',js.includes("rpc('admin_update_player_profile'")&&sql.includes('admin_update_player_profile')],
  ['suspension RPC is wired',js.includes("rpc('admin_set_player_suspended'")&&sql.includes('admin_set_player_suspended')],
  ['ranking unpublish and delete are separate actions',js.includes('admin_unpublish_player_rankings')&&js.includes('admin_delete_player_rankings')&&sql.includes('admin_unpublish_player_rankings')&&sql.includes('admin_delete_player_rankings')],
  ['destructive ranking deletion requires typed confirmation',js.includes("typed:'RANKING'")],
  ['complete deletion requires typed DELETE confirmation',js.includes("typed:'DELETE'")&&js.includes("confirmation:'DELETE'")],
  ['complete deletion uses Edge Function rather than browser service key',js.includes("functions.invoke('admin-delete-player'")&&!js.includes('SERVICE_ROLE')],
  ['Edge Function requires service role only server-side',edge.includes("Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')")&&edge.includes('auth.admin.deleteUser')],
  ['Edge Function verifies caller is admin',edge.includes("rpc('is_current_admin')")&&edge.includes('adminAllowed !== true')],
  ['Edge Function tolerates already-missing Auth users on retry',edge.includes('alreadyMissing')&&edge.includes('status === 404')&&edge.includes('if (!alreadyMissing) throw error')],
  ['database browser mutation RPCs enforce admin authorization',[
    'admin_get_player_management','admin_update_player_profile','admin_set_player_suspended','admin_unpublish_player_rankings','admin_delete_player_rankings'
  ].every(name=>sql.includes(name))&&((sql.match(/if not public\.is_current_admin\(\) then/g)||[]).length>=5)],
  ['application-row delete requires service_role JWT',sql.includes("coalesce(auth.role(), '') <> 'service_role'")&&sql.includes('grant execute on function public.admin_delete_player_application_row(uuid) to service_role')&&sql.includes('from public, anon, authenticated')],
  ['legacy request.jwt.claim.role check removed',!sql.includes("current_setting('request.jwt.claim.role'")],
  ['management CSS contains explicit danger zone',css.includes('.danger-zone')&&css.includes('.v205-admin-confirm-overlay')],
  ['management UI injects only from student detail and never from non-admin state',js.includes('data-v205-admin-manage-open')&&js.includes('if (!isAdmin() || !currentPlayerId) return')],
];

let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;

/*
Runtime authorization verification (development Supabase, 2026-08-20):
- actual admin auth context -> admin_get_player_management: ALLOWED
- actual non-admin authenticated context -> admin_get_player_management: DENIED with `Admin account required`
This file intentionally keeps the executable regression checks credential-free; real-user JWT-context verification is recorded in Issue #10 / V2.0.5_MASTER_PROGRESS.md.
*/
