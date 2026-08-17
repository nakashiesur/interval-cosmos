(() => {
  const config = window.INTERVAL_COSMOS_CLOUD || {};
  const GUEST_STORAGE_KEY = 'intervalCosmos.guest.v205';
  let client = null;
  let authUser = null;
  let player = null;

  const configured = () =>
    Boolean(config.supabaseUrl && (config.supabasePublishableKey || config.supabaseAnonKey));

  const firstRow = (data) => Array.isArray(data) ? (data[0] || null) : (data || null);

  const AVATAR_MARKS = Object.freeze({
    nova: '✦', orbit: '◎', pulse: '∿', prism: '◇', comet: '⟋', nebula: '⁂',
    vector: '△', echo: '◉', quasar: '⊹', lumen: '⊙', wave: '≈', aster: '✧', teacher: 'T',
  });

  function avatarMark(avatarId) {
    return AVATAR_MARKS[avatarId] || AVATAR_MARKS.nova;
  }

  function isGuestMode() {
    try { return localStorage.getItem(GUEST_STORAGE_KEY) === '1'; } catch { return false; }
  }

  function setGuestMode(active) {
    try {
      if (active) localStorage.setItem(GUEST_STORAGE_KEY, '1');
      else localStorage.removeItem(GUEST_STORAGE_KEY);
    } catch {}
  }

  function guestProfile() {
    return {
      player_id: null,
      id: null,
      account_type: 'guest',
      student_number: null,
      player_name: 'GUEST',
      course_code: null,
      avatar_id: 'nova',
      avatar: avatarMark('nova'),
      ranking_visibility: 'always_private',
      main_title_id: null,
      equipped_frame_id: 'normal',
      achievement_points: 0,
      is_suspended: false,
      is_admin: false,
      is_guest: true,
    };
  }

  function normalizePlayer(row) {
    if (!row) return null;
    return {
      ...row,
      id: row.player_id || row.id || null,
      avatar: row.avatar || avatarMark(row.avatar_id),
      is_guest: row.account_type === 'guest',
    };
  }

  function normalizeStudentNumber(value) {
    const fullWidth = '０１２３４５６７８９';
    return String(value ?? '')
      .replace(/[０-９]/g, ch => String(fullWidth.indexOf(ch)))
      .replace(/[^0-9]/g, '');
  }

  function createClientEventId() {
    if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  async function loadSdk() {
    if (window.supabase?.createClient) return;
    await new Promise((resolve, reject) => {
      const existing = document.querySelector('script[data-supabase-sdk]');
      if (existing) {
        if (window.supabase?.createClient) return resolve();
        existing.addEventListener('load', resolve, { once: true });
        existing.addEventListener(
          'error',
          () => reject(new Error('Supabase SDKを読み込めませんでした。')),
          { once: true }
        );
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

  async function ensureClient() {
    if (!configured()) return null;
    await loadSdk();
    if (!window.supabase?.createClient) {
      throw new Error('Supabase SDKを読み込めませんでした。');
    }

    if (!client) {
      client = window.supabase.createClient(
        config.supabaseUrl,
        config.supabasePublishableKey || config.supabaseAnonKey,
        {
          auth: {
            persistSession: true,
            autoRefreshToken: true,
            detectSessionInUrl: true,
          },
        }
      );
    }
    return client;
  }

  async function ensureAuth() {
    await ensureClient();
    if (!client) return null;

    const { data: sessionData, error: sessionError } = await client.auth.getSession();
    if (sessionError) throw sessionError;

    if (!sessionData.session) {
      const { data, error } = await client.auth.signInAnonymously();
      if (error) throw error;
      authUser = data.user;
    } else {
      authUser = sessionData.session.user;
    }

    if (!authUser) {
      const { data, error } = await client.auth.getUser();
      if (error) throw error;
      authUser = data.user;
    }

    return authUser;
  }

  async function loadActualPlayer() {
    await ensureAuth();
    if (!client || !authUser) return null;

    const { data, error } = await client.rpc('get_my_player');
    if (error) throw error;

    player = firstRow(data);
    if (player) setGuestMode(false);
    return player;
  }

  async function getMyPlayer() {
    const actual = await loadActualPlayer();
    return actual ? normalizePlayer(actual) : (isGuestMode() ? guestProfile() : null);
  }

  async function init() {
    if (!configured()) {
      return { configured: false, status: 'unconfigured', user: null, profile: null, player: null };
    }

    await ensureAuth();
    const profile = await getMyPlayer();

    return {
      configured: true,
      status: profile?.is_guest ? 'guest' : 'ready',
      user: authUser,
      profile,
      player: profile,
    };
  }

  async function createStudentAccount({
    studentNumber,
    playerName,
    courseCode,
    avatarId = 'nova',
  }) {
    await ensureAuth();

    const normalized = normalizeStudentNumber(studentNumber);
    if (normalized.length < 3 || normalized.length > 20) {
      throw new Error('学籍番号を確認してください。');
    }
    if (String(playerName || '').trim().length < 2 || String(playerName || '').trim().length > 16) {
      throw new Error('プレイヤー名は2〜16文字で入力してください。');
    }
    if (!courseCode) {
      throw new Error('所属コースを選択してください。');
    }

    const { data, error } = await client.rpc('create_player_account', {
      p_account_type: 'student',
      p_student_number: normalized,
      p_player_name: String(playerName).trim(),
      p_course_code: courseCode,
      p_avatar_id: avatarId || 'nova',
    });
    if (error) throw error;

    player = firstRow(data);
    setGuestMode(false);
    return normalizePlayer(player);
  }

  async function updateMyProfile({
    playerName = null,
    avatarId = null,
    rankingVisibility = null,
    mainTitleId = null,
    equippedFrameId = null,
  } = {}) {
    await ensureAuth();
    if (!player) await loadActualPlayer();
    if (!player) throw new Error('正式アカウントが必要です。');

    const { error } = await client.rpc('update_my_profile', {
      p_player_name: playerName,
      p_avatar_id: avatarId,
      p_ranking_visibility: rankingVisibility,
      p_main_title_id: mainTitleId,
      p_equipped_frame_id: equippedFrameId,
    });
    if (error) throw error;

    return getMyPlayer();
  }

  async function saveProfile({
    studentNumber,
    playerName,
    avatar,
    avatarId,
    courseCode,
    rankingVisibility,
  }) {
    if (!player) await loadActualPlayer();

    if (!player) {
      if (!courseCode) {
        throw new Error('v2.0.5のアカウント作成画面から所属コースを選択してください。');
      }
      return createStudentAccount({
        studentNumber,
        playerName,
        courseCode,
        avatarId: avatarId || 'nova',
      });
    }

    return updateMyProfile({
      playerName,
      avatarId: avatarId || null,
      rankingVisibility: rankingVisibility || null,
    });
  }

  function jstMonth(date = new Date()) {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Tokyo',
      year: 'numeric',
      month: '2-digit',
    }).formatToParts(date);

    const year = parts.find(p => p.type === 'year')?.value;
    const month = parts.find(p => p.type === 'month')?.value;
    return `${year}-${month}`;
  }

  async function submitScore(payload) {
    await ensureAuth();
    if (!player) await loadActualPlayer();

    if (!player && isGuestMode()) {
      return {
        guest: true,
        publication_required: false,
        monthly_rank: null,
        hall_rank: null,
        monthly_best_improved: false,
        hall_best_improved: false,
        monthly_improved: false,
        hall_improved: false,
      };
    }
    if (!player) throw new Error('プレイヤー情報が未設定です。');

    const clientEventId = payload.clientEventId || createClientEventId();
    const playedAt = payload.playedAt || new Date().toISOString();

    const { data, error } = await client.rpc('submit_play_session', {
      p_client_event_id: clientEventId,
      p_source: payload.source || 'ranked',
      p_mode: payload.mode,
      p_score: Math.max(0, Math.round(payload.score || 0)),
      p_total_answers: Math.max(0, Math.round(payload.totalAnswers || 0)),
      p_correct_answers: Math.max(0, Math.round(payload.correctAnswers || 0)),
      p_max_combo: Math.max(0, Math.round(payload.maxCombo || 0)),
      p_avg_response: Number(payload.avgResponse || 0),
      p_interval_stats: payload.intervalStats || {},
      p_played_at: playedAt,
      p_assignment_id: payload.assignmentId || null,
    });
    if (error) throw error;

    const result = firstRow(data) || {};
    return {
      ...result,
      monthly_improved: Boolean(result.monthly_best_improved),
      hall_improved: Boolean(result.hall_best_improved),
      client_event_id: clientEventId,
      played_at: playedAt,
    };
  }

  async function publishPlaySession(sessionId) {
    await ensureAuth();
    const { data, error } = await client.rpc('publish_play_session', {
      p_session_id: sessionId,
    });
    if (error) throw error;
    return firstRow(data);
  }

  async function hideAllMyRankings() {
    await ensureAuth();
    const { error } = await client.rpc('hide_all_my_rankings');
    if (error) throw error;
  }

  async function fetchRankings({ mode, scope = 'monthly', limit = 50 }) {
    await ensureAuth();
    if (!player) await loadActualPlayer();

    const { data, error } = await client.rpc('get_public_rankings', {
      p_mode: mode,
      p_scope: scope === 'hall' ? 'hall' : 'monthly',
      p_limit: limit,
    });
    if (error) throw error;

    const rows = (data || []).map(row => ({
      ...row,
      user_id: row.player_id,
      avatar: avatarMark(row.avatar_id),
    }));

    return {
      rows,
      period: scope === 'hall' ? 'ALL' : jstMonth(),
      currentUserId: player?.player_id || null,
    };
  }

  async function fetchPublicProfileCard(playerId) {
    await ensureAuth();
    const { data, error } = await client.rpc('get_public_profile_card', {
      p_player_id: playerId,
    });
    if (error) throw error;
    if (!data) return null;
    return { ...data, avatar: avatarMark(data.avatar_id) };
  }

  async function fetchCatalogs() {
    await ensureAuth();

    const [
      { data: courses, error: coursesError },
      { data: avatars, error: avatarsError },
      { data: frames, error: framesError },
    ] = await Promise.all([
      client.from('courses').select('code, department_code, display_name, sort_order').order('sort_order'),
      client.from('avatar_catalog').select('id, display_name, asset_path, staff_only, sort_order').order('sort_order'),
      client.from('frame_catalog').select('id, display_name, tier, points_required, animated, sort_order').order('sort_order'),
    ]);

    if (coursesError) throw coursesError;
    if (avatarsError) throw avatarsError;
    if (framesError) throw framesError;

    return {
      courses: courses || [],
      avatars: avatars || [],
      frames: frames || [],
    };
  }

  async function fetchAssignments() {
    await ensureAuth();
    const { data, error } = await client
      .from('assignments')
      .select('id, title, description, mode, interval_keys, rule_config, start_at, deadline_at, target_score, target_accuracy')
      .eq('is_published', true)
      .order('deadline_at', { ascending: true });
    if (error) throw error;
    return data || [];
  }

  async function fetchLearningHistory({ limit = 200 } = {}) {
    await ensureAuth();
    if (!player) await loadActualPlayer();
    if (!player) return [];

    const { data, error } = await client
      .from('play_sessions')
      .select('id, client_event_id, source, mode, score, total_answers, correct_answers, max_combo, avg_response, interval_stats, assignment_id, played_at, received_at')
      .order('played_at', { ascending: false })
      .limit(Math.max(1, Math.min(Number(limit) || 200, 1000)));
    if (error) throw error;
    return data || [];
  }

  async function createDeviceLinkPin() {
    await ensureAuth();
    if (!player) await loadActualPlayer();
    if (!player) throw new Error('正式アカウントが必要です。');
    const { data, error } = await client.rpc('create_device_link_request');
    if (error) throw error;
    return firstRow(data);
  }

  async function claimDeviceLinkPin(pin) {
    await ensureAuth();
    if (!player) await loadActualPlayer();
    if (player) throw new Error('この端末はすでにアカウントへ接続されています。');
    setGuestMode(false);
    const normalized = String(pin || '').replace(/[^0-9]/g, '').slice(0, 6);
    const { data, error } = await client.rpc('claim_device_link_request', { p_pin: normalized });
    if (error) throw error;
    return firstRow(data);
  }

  async function getDeviceLinkSourceStatus(requestId) {
    await ensureAuth();
    const { data, error } = await client.rpc('get_device_link_source_status', {
      p_request_id: requestId,
    });
    if (error) throw error;
    return firstRow(data);
  }

  async function getDeviceLinkTargetStatus(requestId) {
    await ensureAuth();
    const { data, error } = await client.rpc('get_device_link_target_status', {
      p_request_id: requestId,
    });
    if (error) throw error;
    const result = firstRow(data);
    if (result?.status === 'confirmed') await loadActualPlayer();
    return result;
  }

  async function confirmDeviceLink(requestId) {
    await ensureAuth();
    const { data, error } = await client.rpc('confirm_device_link_request', {
      p_request_id: requestId,
    });
    if (error) throw error;
    return firstRow(data);
  }

  async function cancelDeviceLink(requestId) {
    await ensureAuth();
    const { error } = await client.rpc('cancel_device_link_request', {
      p_request_id: requestId,
    });
    if (error) throw error;
  }

  function getCachedPlayer() {
    return player ? normalizePlayer(player) : (isGuestMode() ? guestProfile() : null);
  }

  function getAuthUser() {
    return authUser;
  }

  window.IntervalCosmosCloud = {
    configured,
    init,
    getMyPlayer,
    createStudentAccount,
    updateMyProfile,
    saveProfile,
    submitScore,
    publishPlaySession,
    hideAllMyRankings,
    fetchRankings,
    fetchPublicProfileCard,
    fetchCatalogs,
    fetchAssignments,
    fetchLearningHistory,
    createDeviceLinkPin,
    claimDeviceLinkPin,
    getDeviceLinkSourceStatus,
    getDeviceLinkTargetStatus,
    confirmDeviceLink,
    cancelDeviceLink,
    normalizeStudentNumber,
    createClientEventId,
    jstMonth,
    avatarMark,
    isGuestMode,
    setGuestMode,
    getCachedPlayer,
    getAuthUser,
  };
})();
