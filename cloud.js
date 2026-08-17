(() => {
  const config = window.INTERVAL_COSMOS_CLOUD || {};
  let client = null;
  let user = null;
  let profile = null;

  const configured = () => Boolean(config.supabaseUrl && (config.supabasePublishableKey || config.supabaseAnonKey));

  async function loadSdk() {
    if (window.supabase?.createClient) return;
    await new Promise((resolve, reject) => {
      const existing = document.querySelector('script[data-supabase-sdk]');
      if (existing) {
        existing.addEventListener('load', resolve, { once: true });
        existing.addEventListener('error', () => reject(new Error('Supabase SDKを読み込めませんでした。')), { once: true });
        return;
      }
      const script = document.createElement('script');
      script.src = config.sdkUrl || 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';
      script.async = true;
      script.dataset.supabaseSdk = 'true';
      script.onload = resolve;
      script.onerror = () => reject(new Error('Supabase SDKを読み込めませんでした。'));
      document.head.appendChild(script);
    });
  }

  async function init() {
    if (!configured()) return { configured: false, status: 'unconfigured' };
    await loadSdk();
    if (!window.supabase?.createClient) throw new Error('Supabase SDKを読み込めませんでした。');
    if (!client) {
      client = window.supabase.createClient(
        config.supabaseUrl,
        config.supabasePublishableKey || config.supabaseAnonKey,
        { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }
      );
    }

    const { data: sessionData, error: sessionError } = await client.auth.getSession();
    if (sessionError) throw sessionError;
    if (!sessionData.session) {
      const { data, error } = await client.auth.signInAnonymously();
      if (error) throw error;
      user = data.user;
    } else {
      user = sessionData.session.user;
    }
    if (!user) {
      const { data, error } = await client.auth.getUser();
      if (error) throw error;
      user = data.user;
    }

    const { data: profileData, error: profileError } = await client
      .from(config.profilesTable || 'profiles')
      .select('id, student_number, player_name, avatar, updated_at')
      .eq('id', user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    profile = profileData || null;
    return { configured: true, status: 'ready', user, profile };
  }

  async function saveProfile({ studentNumber, playerName, avatar }) {
    if (!client || !user) await init();
    const payload = {
      id: user.id,
      student_number: String(studentNumber || profile?.student_number || '').trim(),
      player_name: String(playerName || '').trim(),
      avatar: avatar || '🌟',
      updated_at: new Date().toISOString(),
    };
    const { data, error } = await client
      .from(config.profilesTable || 'profiles')
      .upsert(payload, { onConflict: 'id' })
      .select('id, student_number, player_name, avatar, updated_at')
      .single();
    if (error) throw error;
    profile = data;
    return data;
  }

  function jstMonth() {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Tokyo', year: 'numeric', month: '2-digit'
    }).formatToParts(new Date());
    const year = parts.find(p => p.type === 'year')?.value;
    const month = parts.find(p => p.type === 'month')?.value;
    return `${year}-${month}`;
  }

  async function submitScore(payload) {
    if (!client || !user) await init();
    if (!profile) throw new Error('プレイヤー情報が未設定です。');
    const { data, error } = await client.rpc(config.submitScoreFunction || 'submit_interval_cosmos_score', {
      p_mode: payload.mode,
      p_score: Math.max(0, Math.round(payload.score || 0)),
      p_total_answers: Math.max(0, Math.round(payload.totalAnswers || 0)),
      p_correct_answers: Math.max(0, Math.round(payload.correctAnswers || 0)),
      p_max_combo: Math.max(0, Math.round(payload.maxCombo || 0)),
      p_avg_response: Number(payload.avgResponse || 0),
    });
    if (error) throw error;
    return Array.isArray(data) ? data[0] : data;
  }

  async function fetchRankings({ mode, scope = 'monthly', limit = 50 }) {
    if (!client || !user) await init();
    const period = scope === 'hall' ? 'ALL' : jstMonth();
    const { data, error } = await client
      .from(config.rankingsTable || 'rankings')
      .select('user_id, player_name, avatar, mode, period, score, total_answers, correct_answers, max_combo, avg_response, updated_at')
      .eq('mode', mode)
      .eq('period', period)
      .order('score', { ascending: false })
      .order('updated_at', { ascending: true })
      .limit(limit);
    if (error) throw error;
    return { rows: data || [], period, currentUserId: user.id };
  }

  window.IntervalCosmosCloud = {
    configured,
    init,
    saveProfile,
    submitScore,
    fetchRankings,
    jstMonth,
  };
})();
