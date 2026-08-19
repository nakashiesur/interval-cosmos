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
  ['complete deletion requires typed DELETE confirmation',js.includes("typed:'DELETE'")&&js.includes("confirmation:'DELETE'"))],
  ['complete deletion uses Edge Function rather than browser service key',js.includes("functions.invoke('admin-delete-player'")&&!js.includes('SERVICE_ROLE')],
  ['Edge Function requires service role only server-side',edge.includes("Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')")&&edge.includes('auth.admin.deleteUser')],
  ['Edge Function verifies caller is admin',edge.includes("rpc('is_current_admin')")&&edge.includes('adminAllowed !== true')],
  ['database mutation RPCs enforce admin authorization',[
    'admin_get_player_management','admin_update_player_profile','admin_set_player_suspended','admin_unpublish_player_rankings','admin_delete_player_rankings'
  ].every(name=>sql.includes(name))&&((sql.match(/if not public\.is_current_admin\(\) then/g)||[]).length>=5)],
  ['application-row delete is not granted to authenticated',sql.includes('revoke execute on function public.admin_delete_player_application_row(uuid) from authenticated')&&sql.includes('grant execute on function public.admin_delete_player_application_row(uuid) to service_role')],
  ['management CSS contains explicit danger zone',css.includes('.danger-zone')&&css.includes('.v205-admin-confirm-overlay')],
];

let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
