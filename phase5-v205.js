(() => {
  const VERSION = 'ver.2.0.5-alpha4';
  const cloud = window.IntervalCosmosCloud;
  const config = window.INTERVAL_COSMOS_CLOUD || {};
  let client = null;
  let cache = null;
  let opening = false;
  let queued = false;
  let unlockQueue = [];
  let unlockShowing = false;

  const CATEGORY_LABELS = Object.freeze({
    basic:'BASIC', accuracy:'ACCURACY', combo:'COMBO', interval:'INTERVAL',
    mode:'MODE', streak:'STREAK', improvement:'IMPROVEMENT', assignment:'ASSIGNMENT',
    ranking:'RANKING', hidden:'SECRET'
  });
  const POINT_FRAME_IDS = new Set(['normal','bronze','silver','gold','platinum','cosmic']);

  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[c]));
  const pct = (value, max) => max > 0 ? Math.max(0, Math.min(100, Math.round((value / max) * 100))) : 0;

  async function ensureProgressClient() {
    if (client) return client;
    if (!config.supabaseUrl || !(config.supabasePublishableKey || config.supabaseAnonKey)) {
      throw new Error('オンライン設定がありません。');
    }
    await cloud?.init?.();
    if (!window.supabase?.createClient) throw new Error('Supabase SDKを読み込めませんでした。');
    client = window.supabase.createClient(
      config.supabaseUrl,
      config.supabasePublishableKey || config.supabaseAnonKey,
      { auth:{ persistSession:true, autoRefreshToken:false, detectSessionInUrl:false } }
    );
    return client;
  }

  async function rpc(name, args = undefined) {
    const c = await ensureProgressClient();
    const { data, error } = await c.rpc(name, args);
    if (error) throw error;
    return data;
  }

  async function evaluateProgress() {
    const result = await rpc('evaluate_my_progress');
    if (result?.player) {
      try { await cloud?.getMyPlayer?.(); } catch {}
    }
    enqueueUnlocks(result);
    return result;
  }

  async function fetchProgress() {
    cache = await rpc('get_my_cosmos_progress');
    return cache;
  }

  async function toggleFeatured(id) {
    if (!id) return;
    await rpc('toggle_featured_achievement', { p_achievement_id:id });
    await refreshOpenPanel();
  }

  function enqueueUnlocks(result) {
    if (!result) return;
    const items = [];
    for (const a of result.new_achievements || []) items.push({type:'ACHIEVEMENT', name:a.name, sub:`+${a.points || 0} PT`});
    for (const t of result.new_titles || []) items.push({type:'TITLE UNLOCKED', name:t.name, sub:'称号を獲得'});
    for (const f of result.new_frames || []) items.push({type:'FRAME UNLOCKED', name:f.name, sub:f.animated ? 'DYNAMIC FRAME' : 'NEW FRAME'});
    for (const m of result.new_daily_completions || []) items.push({type:'DAILY COMPLETE', name:m.name, sub:`+${m.reward_points || 0} PT`});
    unlockQueue.push(...items);
    showNextUnlock();
  }

  function showNextUnlock() {
    if (unlockShowing || !unlockQueue.length) return;
    unlockShowing = true;
    const item = unlockQueue.shift();
    const node = document.createElement('div');
    node.className = 'v205-unlock-burst';
    node.innerHTML = `<div class="v205-unlock-rings"></div><section>
      <p>${esc(item.type)}</p><h2>${esc(item.name || 'UNLOCKED')}</h2><span>${esc(item.sub || '')}</span>
    </section>`;
    document.body.appendChild(node);
    window.setTimeout(() => {
      node.classList.add('out');
      window.setTimeout(() => { node.remove(); unlockShowing = false; showNextUnlock(); }, 320);
    }, 2100);
  }

  function overlay() {
    let node = document.querySelector('.v205-cosmos-overlay');
    if (node) return node;
    node = document.createElement('div');
    node.className = 'v205-cosmos-overlay';
    document.body.appendChild(node);
    return node;
  }
  function close() { document.querySelector('.v205-cosmos-overlay')?.remove(); }
  function loading() {
    overlay().innerHTML = `<section class="v205-cosmos-card">
      <button class="icon-btn v205-cosmos-close" data-v205-cosmos-close>×</button>
      <div class="v205-cosmos-loading"><span class="spinner"></span><strong>CALCULATING COSMOS PROGRESS...</strong><small>実績・フレーム・デイリーミッションを同期しています</small></div>
    </section>`;
  }

  function frameProgress(data) {
    const frames = (data.frames || []).filter(f => f.id && POINT_FRAME_IDS.has(f.id)).sort((a,b)=>(a.tier||0)-(b.tier||0));
    const points = Number(data.player?.achievement_points || 0);
    const unlocked = frames.filter(f => f.unlocked);
    const current = unlocked[unlocked.length - 1] || frames[0];
    const next = frames.find(f => !f.unlocked && Number(f.points_required || 0) > points) || null;
    const from = Number(current?.points_required || 0);
    const to = Number(next?.points_required || from || 1);
    return { current, next, points, progress: next ? pct(points - from, Math.max(1,to-from)) : 100 };
  }

  function renderDaily(data) {
    const rows = data.daily_missions || [];
    return `<section class="v205-cosmos-section">
      <div class="v205-cosmos-section-head"><div><p>DAILY MISSIONS</p><h3>今日の3ミッション</h3></div><span>${esc(data.mission_date || '')}</span></div>
      <div class="v205-daily-grid">${rows.map(m => {
        const progress = Math.min(Number(m.progress||0), Number(m.target||1));
        return `<article class="v205-daily-card ${m.completed ? 'done' : ''}">
          <div class="v205-daily-top"><span>0${m.slot}</span><b>${m.completed ? 'COMPLETE' : `+${m.reward_points} PT`}</b></div>
          <h4>${esc(m.name)}</h4><p>${esc(m.description)}</p>
          <div class="v205-progress"><i style="width:${pct(progress,Number(m.target||1))}%"></i></div>
          <small>${progress} / ${m.target}${m.completed ? '　✓' : ''}</small>
        </article>`;
      }).join('')}</div>
      <p class="v205-cosmos-note">デイリーミッションはゲームスコアを増やしません。獲得PTはプロフィール／フレーム成長にのみ使用されます。</p>
    </section>`;
  }

  function renderFrames(data) {
    return `<section class="v205-cosmos-section">
      <div class="v205-cosmos-section-head"><div><p>FRAME EVOLUTION</p><h3>フレーム</h3></div><span>段階成長＋複合解放</span></div>
      <div class="v205-frame-grid">${(data.frames||[]).map(f => {
        const locked = !f.unlocked;
        const pointType = f.id && POINT_FRAME_IDS.has(f.id);
        let requirement = '???';
        if (!f.hidden && pointType) requirement = f.id === 'normal' ? 'BASE' : `${Number(f.points_required||0).toLocaleString('ja-JP')} PT`;
        else if (!f.hidden && f.unlock_rule?.type === 'achievement_combo') requirement = '複数実績で解放';
        else if (f.unlocked) requirement = 'UNLOCKED';
        return `<button class="v205-frame-card v205-frame-${esc(f.id || 'secret')} ${f.animated ? 'animated' : ''} ${locked ? 'locked' : ''} ${f.equipped ? 'equipped' : ''}"
          ${f.unlocked && f.id ? `data-v205-equip-frame="${esc(f.id)}"` : 'disabled'}>
          <span class="v205-frame-orb">${locked ? '?' : '✦'}</span><strong>${esc(f.name || '???')}</strong><small>${esc(requirement)}</small>
          ${f.equipped ? '<em>EQUIPPED</em>' : f.unlocked ? '<em>SELECT</em>' : ''}
        </button>`;
      }).join('')}</div>
      <p class="v205-cosmos-note">NORMAL → BRONZE → SILVER → GOLD → PLATINUM → COSMIC はPTで自動成長。AURORA以降には複数条件の特殊解放があります。</p>
    </section>`;
  }

  function renderTitles(data) {
    const visible = (data.titles || []).filter(t => !t.hidden || t.unlocked);
    return `<section class="v205-cosmos-section">
      <div class="v205-cosmos-section-head"><div><p>TITLES</p><h3>称号</h3></div><span>ランキングにはメイン称号1個</span></div>
      <div class="v205-title-grid">${visible.map(t => `<button class="v205-title-card ${t.unlocked?'unlocked':'locked'} ${t.equipped?'equipped':''}"
        ${t.unlocked ? `data-v205-equip-title="${esc(t.id)}"` : 'disabled'}>
        <strong>${esc(t.name)}</strong><span>${esc(t.description || '')}</span><small>${t.equipped ? 'MAIN TITLE' : t.unlocked ? 'SELECT' : 'LOCKED'}</small>
      </button>`).join('')}</div>
    </section>`;
  }

  function renderAchievements(data) {
    const rows = data.achievements || [];
    const featuredCount = rows.filter(a => a.featured_order).length;
    const groups = new Map();
    for (const a of rows) { const k=a.category||'basic'; if(!groups.has(k)) groups.set(k,[]); groups.get(k).push(a); }
    const order = ['basic','accuracy','combo','mode','interval','streak','ranking','assignment','hidden'];
    return `<section class="v205-cosmos-section">
      <div class="v205-cosmos-section-head"><div><p>ACHIEVEMENTS</p><h3>実績</h3></div><span>代表実績 ${featuredCount} / 3</span></div>
      ${order.filter(k=>groups.has(k)).map(category => `<div class="v205-achievement-group"><h4>${CATEGORY_LABELS[category] || category.toUpperCase()}</h4>
        <div class="v205-achievement-list">${groups.get(category).map(a => {
          const secret = a.hidden && !a.unlocked;
          return `<article class="v205-achievement-item ${a.unlocked?'unlocked':'locked'} ${secret?'secret':''} ${a.featured_order?'featured':''}">
            <div class="v205-achievement-mark">${a.unlocked ? '✓' : secret ? '?' : '·'}</div>
            <div><strong>${esc(a.name || '???')}</strong><p>${esc(a.description || '???')}</p><small>${a.unlocked ? `UNLOCKED${a.points != null ? `　+${a.points} PT` : ''}` : secret ? 'CONDITION ???' : `${a.points || 0} PT`}</small></div>
            ${a.unlocked && a.id ? `<button class="v205-feature-btn ${a.featured_order?'on':''}" data-v205-feature="${esc(a.id)}">${a.featured_order ? `★ ${a.featured_order}` : '☆ 代表'}</button>` : ''}
          </article>`;
        }).join('')}</div></div>`).join('')}
    </section>`;
  }

  function render(data) {
    const node = overlay();
    const profile = data.player || {};
    const avatar = cloud?.avatarMark?.(profile.avatar_id) || '✦';
    const fp = frameProgress(data);
    node.innerHTML = `<section class="v205-cosmos-card">
      <button class="icon-btn v205-cosmos-close" data-v205-cosmos-close>×</button>
      <header class="v205-cosmos-hero">
        <div class="v205-cosmos-avatar v205-frame-${esc(profile.equipped_frame_id || 'normal')}">${esc(avatar)}</div>
        <div class="v205-cosmos-id"><p>MY COSMOS</p><h2>${esc(profile.player_name || 'PLAYER')}</h2><span>${esc((data.titles||[]).find(t=>t.equipped)?.name || 'NO TITLE')}</span></div>
        <div class="v205-points"><small>COSMOS PT</small><strong>${Number(profile.achievement_points||0).toLocaleString('ja-JP')}</strong><span>${esc(fp.current?.name || 'NORMAL')} FRAME</span></div>
      </header>
      <div class="v205-evolution"><div><span>${esc(fp.current?.name || 'NORMAL')}</span><b>${fp.next ? esc(fp.next.name) : 'MAX POINT TIER'}</b></div><div class="v205-progress big"><i style="width:${fp.progress}%"></i></div><small>${fp.next ? `${fp.points.toLocaleString('ja-JP')} / ${Number(fp.next.points_required||0).toLocaleString('ja-JP')} PT` : 'ポイント成長段階を完遂'}</small></div>
      ${renderDaily(data)}${renderFrames(data)}${renderTitles(data)}${renderAchievements(data)}
    </section>`;
  }

  async function open() {
    if (opening) return;
    opening = true; loading();
    try {
      const profile = cloud?.getCachedPlayer?.();
      if (profile?.is_guest) throw new Error('GUESTではオンライン実績は保存されません。');
      render(await fetchProgress());
    } catch (error) {
      console.error('[v2.0.5 cosmos]', error);
      overlay().innerHTML = `<section class="v205-cosmos-card"><button class="icon-btn v205-cosmos-close" data-v205-cosmos-close>×</button><div class="v205-cosmos-error"><p>MY COSMOS</p><h2>PROGRESSION SETUP REQUIRED</h2><span>${esc(error?.message || '進行データを取得できませんでした。')}</span><small>Phase 5のSupabase追加SQLを実行後、再度開いてください。</small></div></section>`;
    } finally { opening = false; }
  }

  async function refreshOpenPanel() { if(document.querySelector('.v205-cosmos-overlay')) render(await fetchProgress()); }
  async function equipTitle(id) { if(id&&cloud?.updateMyProfile){ await cloud.updateMyProfile({mainTitleId:id}); await refreshOpenPanel(); } }
  async function equipFrame(id) { if(id&&cloud?.updateMyProfile){ await cloud.updateMyProfile({equippedFrameId:id}); await refreshOpenPanel(); } }

  function injectButtons() {
    const footer = document.querySelector('.home-footer');
    if (footer && !footer.querySelector('[data-v205-cosmos-open]')) {
      const b=document.createElement('button'); b.className='secondary-btn v205-cosmos-launch'; b.type='button'; b.dataset.v205CosmosOpen='1'; b.innerHTML='✦ MY COSMOS'; footer.appendChild(b);
    }
    const settings = document.querySelector('.settings-modal .modal-card');
    if (settings && !settings.querySelector('.v205-cosmos-setting')) {
      const row=document.createElement('div'); row.className='setting-row v205-cosmos-setting'; row.innerHTML='<div class="setting-label"><strong>My Cosmos</strong><span>実績・称号・フレーム・デイリー</span></div><button type="button" class="secondary-btn" data-v205-cosmos-open>開く</button>';
      const version=settings.querySelector('.settings-version'); if(version) version.insertAdjacentElement('beforebegin',row); else settings.appendChild(row);
    }
    document.querySelectorAll('.splash-version,.settings-version').forEach(n=>{if(n.textContent!==VERSION)n.textContent=VERSION;});
  }

  if (cloud?.submitScore && !cloud.__v205Phase5Wrapped) {
    const originalSubmit=cloud.submitScore.bind(cloud);
    cloud.submitScore=async payload=>{const result=await originalSubmit(payload); if(!result?.guest)evaluateProgress().catch(e=>console.debug('[progress pending]',e?.message||e)); return result;};
    if(cloud.publishPlaySession){const originalPublish=cloud.publishPlaySession.bind(cloud); cloud.publishPlaySession=async sessionId=>{const result=await originalPublish(sessionId); evaluateProgress().catch(e=>console.debug('[progress pending]',e?.message||e)); return result;};}
    cloud.__v205Phase5Wrapped=true;
  }

  function queueEnhance(){if(queued)return;queued=true;queueMicrotask(()=>{queued=false;injectButtons();});}
  new MutationObserver(queueEnhance).observe(document.documentElement,{subtree:true,childList:true});
  window.addEventListener('DOMContentLoaded',queueEnhance,{once:true});

  window.addEventListener('click',async event=>{
    if(event.target.closest?.('[data-v205-cosmos-open]')){open();return;}
    if(event.target.closest?.('[data-v205-cosmos-close]')||event.target===document.querySelector('.v205-cosmos-overlay')){close();return;}
    const title=event.target.closest?.('[data-v205-equip-title]'); if(title){try{await equipTitle(title.dataset.v205EquipTitle);}catch(e){console.error(e);}return;}
    const frame=event.target.closest?.('[data-v205-equip-frame]'); if(frame){try{await equipFrame(frame.dataset.v205EquipFrame);}catch(e){console.error(e);}return;}
    const feature=event.target.closest?.('[data-v205-feature]'); if(feature){try{await toggleFeatured(feature.dataset.v205Feature);}catch(e){alert(e?.message||'代表実績を変更できませんでした。');}}
  },true);
  window.addEventListener('keydown',event=>{if(event.key==='Escape'&&document.querySelector('.v205-cosmos-overlay')){event.preventDefault();event.stopImmediatePropagation();close();}},true);

  window.IntervalCosmosProgressV205={version:VERSION,open,fetchProgress,evaluateProgress,getCache:()=>cache};
})();
