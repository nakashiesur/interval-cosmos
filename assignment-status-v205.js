(() => {
  const cloud = window.IntervalCosmosCloud;
  const TTL = 60000;
  let owner = null, generation = 0, rows = null, state = 'loading', checkedAt = 0;
  let pending = null, queued = false, wasHome = false, refreshAgain = false;
  const playerKey = () => {
    const p = cloud?.getCachedPlayer?.();
    if (!p || p.is_guest || (p.is_admin && !window.IntervalCosmosAssignmentAdminPolicyV205?.isStudentView?.())) return null;
    return p.player_id || p.id || null;
  };
  function resetOwner() {
    const key = playerKey();
    if (key !== owner) {
      owner = key; generation++; rows = null; state = 'loading'; checkedAt = 0; pending = null; refreshAgain = false;
    }
    return key;
  }
  function summarize(list, now = Date.now()) {
    const active = list.filter(a => Date.parse(a.start_at) <= now && Date.parse(a.deadline_at) >= now);
    const unfinished = active.filter(a => !a.achieved);
    if (unfinished.length) return {state:'pending', count:unfinished.length, unanswered:unfinished.filter(a => !Number(a.attempts)).length};
    if (active.length) return {state:'complete', count:active.length};
    if (list.some(a => Date.parse(a.start_at) > now)) return {state:'upcoming', count:0};
    return {state:list.length ? 'closed' : 'empty', count:0};
  }
  function render(button = document.querySelector('[data-a-open]')) {
    if (!button) return;
    const key = resetOwner();
    if (!key) {
      if (button.dataset.assignmentStatus) {
        delete button.dataset.assignmentStatus; delete button.dataset.assignmentSignature;
        button.removeAttribute('aria-label'); button.removeAttribute('title');
        button.textContent = cloud?.getCachedPlayer?.()?.is_admin ? '▣ ADMIN ASSIGNMENTS' : '▣ ASSIGNMENTS';
      }
      return;
    }
    const summary = state === 'ready' ? summarize(rows || []) : {state, count:0};
    const label = {loading:'確認中',error:'再確認',offline:'オフライン',pending:summary.unanswered ? '未回答あり' : '未クリア',complete:'全クリア',empty:'課題なし',upcoming:'受付前',closed:'受付終了'}[summary.state];
    const badge = summary.state === 'pending' ? String(summary.count) : summary.state === 'complete' ? '✓' : '—';
    const detail = summary.state === 'pending' ? `受付中の課題 ${summary.count}件が未クリア。うち未回答 ${summary.unanswered}件。` : summary.state === 'complete' ? '受付中の課題はすべてクリアしています。' : label;
    const signature = [key,summary.state,summary.count,label].join(':');
    if (button.dataset.assignmentSignature === signature) return;
    button.dataset.assignmentSignature = signature;
    button.dataset.assignmentStatus = summary.state;
    button.setAttribute('aria-label', `先生からの課題。${detail} 課題一覧を開く`);
    button.title = `先生からの課題を確認・提出できます。${detail}`;
    button.innerHTML = `<span class="ic-assignment-line"><strong>ASSIGNMENTS</strong><span class="ic-assignment-badge" aria-hidden="true">${badge}</span></span><span class="ic-assignment-caption">先生からの課題 <span>· ${label}</span></span>`;
  }
  async function refresh(force = false) {
    const key = resetOwner();
    if (!key) { render(); return; }
    if (pending) { if (force) refreshAgain = true; return pending; }
    if (!force && checkedAt && Date.now() - checkedAt < TTL) { render(); return; }
    const token = generation;
    checkedAt = Date.now();
    if (navigator.onLine === false) { state = 'offline'; render(); return; }
    const job = (async () => {
      try {
        await cloud.init();
        if (token !== generation || key !== playerKey()) return;
        const client = window.IntervalCosmosSupabaseSingleton?.getClient?.();
        if (!client) throw new Error('Assignment connection unavailable');
        const {data,error} = await client.rpc('get_my_assignments');
        if (error) throw error;
        if (!Array.isArray(data)) throw new Error('Invalid assignment response');
        if (token !== generation || key !== playerKey()) return;
        rows = data; state = 'ready';
      } catch (_) {
        if (token !== generation || key !== playerKey()) return;
        rows = null; state = 'error';
      } finally {
        if (token === generation && key === playerKey()) {
          pending = null; render();
          if (refreshAgain) { refreshAgain = false; queueMicrotask(() => refresh(true)); }
        }
      }
    })();
    pending = job;
    return job;
  }
  function schedule() {
    if (queued) return;
    queued = true;
    queueMicrotask(() => {
      queued = false; resetOwner();
      const home = Boolean(document.querySelector('.home-footer [data-a-open]'));
      const returned = home && !wasHome;
      wasHome = home;
      render();
      if (home) refresh(returned);
    });
  }
  window.IntervalCosmosAssignmentStatusV205 = {render, refresh, summarize};
  new MutationObserver(schedule).observe(document.documentElement, {childList:true,subtree:true});
  window.addEventListener('DOMContentLoaded', schedule, {once:true});
  window.addEventListener('focus', () => refresh(true));
  window.addEventListener('online', () => refresh(true));
  window.addEventListener('offline', () => { generation++; pending = null; rows = null; state = 'offline'; render(); });
  window.addEventListener('interval-cosmos-sync', () => refresh(true));
  window.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') refresh(true); });
  window.addEventListener('click', event => {
    if (event.target.closest?.('[data-a-close],[data-a-back],[data-a-refresh],[data-v205-admin-view-toggle]')) queueMicrotask(() => refresh(true));
  });
  window.setInterval(() => {
    if (document.visibilityState === 'visible' && document.querySelector('.home-footer [data-a-open]')) refresh();
  }, TTL);
  schedule();
})();
