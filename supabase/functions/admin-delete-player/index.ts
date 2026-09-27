import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (req.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const authorization = req.headers.get('Authorization');

    if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
      return json({ error: 'Server configuration or authorization is missing' }, 500);
    }

    const body = await req.json().catch(() => ({}));
    const playerId = typeof body?.player_id === 'string' ? body.player_id : '';
    const confirmation = typeof body?.confirmation === 'string' ? body.confirmation : '';

    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(playerId)) {
      return json({ error: 'Invalid player_id' }, 400);
    }
    if (confirmation !== 'DELETE') {
      return json({ error: 'Explicit deletion confirmation is required' }, 400);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: adminAllowed, error: adminError } = await userClient.rpc('is_current_admin');
    if (adminError || adminAllowed !== true) {
      return json({ error: 'Admin account required' }, 403);
    }

    const { data: me, error: meError } = await userClient.rpc('get_my_player');
    if (meError) return json({ error: meError.message }, 403);
    const currentPlayerId = Array.isArray(me) ? me[0]?.player_id : me?.player_id;
    if (currentPlayerId === playerId) {
      return json({ error: 'You cannot delete your own admin account' }, 400);
    }

    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: devices, error: devicesError } = await serviceClient
      .from('player_devices')
      .select('auth_user_id')
      .eq('player_id', playerId);
    if (devicesError) throw devicesError;

    const authIds = [...new Set((devices || []).map((row) => row.auth_user_id).filter(Boolean))];
    let deletedAuthUsers = 0;

    // Auth deletion can succeed before a later application-row deletion fails.
    // Treat an already-missing Auth user as success so the whole operation is
    // safely retryable after a partial failure.
    for (const authUserId of authIds) {
      const { error } = await serviceClient.auth.admin.deleteUser(authUserId);
      if (error) {
        const status = Number((error as { status?: number })?.status || 0);
        const message = String(error?.message || '');
        const alreadyMissing = status === 404 || /user(?:\s+was)?\s+not\s+found|not\s+found/i.test(message);
        if (!alreadyMissing) throw error;
      } else {
        deletedAuthUsers += 1;
      }
    }

    // Run the reviewed cascade deletion through the database function rather
    // than issuing an unrestricted client-side table delete.
    const { error: deleteError } = await serviceClient.rpc('admin_delete_player_application_row', {
      p_player_id: playerId,
    });
    if (deleteError) throw deleteError;

    return json({ ok: true, player_id: playerId, deleted_auth_users: deletedAuthUsers }, 200);
  } catch (error) {
    console.error('[admin-delete-player]', error);
    return json({ error: error instanceof Error ? error.message : 'Deletion failed' }, 500);
  }
});

function json(payload: unknown, status: number) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' },
  });
}
