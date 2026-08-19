(() => {
  const cloud = window.IntervalCosmosCloud;
  const singleton = window.IntervalCosmosSupabaseSingleton;
  if (!cloud || !singleton || cloud.__v205StaffRegistrationInstalled) return;
  cloud.__v205StaffRegistrationInstalled = true;

  function client() {
    const c = singleton.getClient?.();
    if (!c) throw new Error('オンライン接続の準備ができていません。');
    return c;
  }

  function firstRow(data) {
    return Array.isArray(data) ? (data[0] || null) : (data || null);
  }

  function esc(value) {
    return String(value ?? '').replace(/[&<>'"]/g, c => ({
      '&':'&amp;', '<':'&lt;', '>':'&gt;', "'":'&#39;', '"':'&quot;'
    }[c]));
  }

  async function createStaffAccount({ realName, playerName }) {
    const real = String(realName || '').trim();
    const name = String(playerName || '').trim();
    if (real.length < 2 || real.length > 40) throw new Error('氏名は2〜40文字で入力してください。');
    if (name.length < 2 || name.length > 16) throw new Error('プレイヤー名は2〜16文字で入力してください。');

    const { error } = await client().rpc('create_staff_account', {
      p_real_name: real,
      p_player_name: name,
    });
    if (error) throw error;
    cloud.setGuestMode?.(false);
    return cloud.getMyPlayer();
  }

  async function getMyPrivateIdentity() {
    const { data, error } = await client().rpc('get_my_private_identity');
    if (error) throw error;
    return firstRow(data);
  }

  async function updateMyStaffIdentity(realName) {
    const real = String(realName || '').trim();
    if (real.length < 2 || real.length > 40) throw new Error('氏名は2〜40文字で入力してください。');
    const { error } = await client().rpc('update_my_staff_identity', { p_real_name: real });
    if (error) throw error;
  }

  cloud.createStaffAccount = createStaffAccount;
  cloud.getMyPrivateIdentity = getMyPrivateIdentity;
  cloud.updateMyStaffIdentity = updateMyStaffIdentity;

  function root() {
    let node = document.querySelector('#account-ui-root');
    if (!node) {
      node = document.createElement('div');
      node.id = 'account-ui-root';
      document.body.appendChild(node);
    }
    return node;
  }

  function showStaffForm() {
    root().innerHTML = `<div class="ic-account-layer">
      <div class="ic-account-stars" aria-hidden="true"></div>
      <section class="ic-account-panel">
        <header class="ic-account-head">
          <span class="ic-account-kicker">STAFF ACCESS</span>
          <h1>教職員登録</h1>
          <p>氏名は管理用、プレイヤー名はランキング等に表示される公開名です。</p>
        </header>
        <form class="ic-account-form" id="v205StaffForm">
          <div class="ic-staff-card">
            <span class="ic-avatar-art avatar-teacher" aria-hidden="true"><i></i><b></b></span>
            <div><strong>TEACHER IDENTITY</strong><p>教職員アイコンは固定です。学籍番号・教職員番号・所属コースの入力は不要です。</p></div>
          </div>
          <label><span>氏名 <em>PRIVATE</em></span><input id="v205StaffRealName" type="text" autocomplete="name" maxlength="40" placeholder="例：中島 慧" required></label>
          <label><span>プレイヤー名 <em>PUBLIC</em></span><input id="v205StaffPlayerName" type="text" autocomplete="nickname" maxlength="16" placeholder="2〜16文字" required></label>
          <p class="ic-account-footnote">氏名はランキング・公開プロフィールには表示されません。教職員として自己登録したアカウントに管理者権限は付与されません。</p>
          <div class="ic-form-message" id="v205StaffMessage" aria-live="polite"></div>
          <div class="ic-account-actions"><button type="button" class="ic-btn secondary" data-v205-staff-cancel>戻る</button><button type="submit" class="ic-btn primary">教職員として登録</button></div>
        </form>
      </section>
      <div class="ic-account-version">ver.2.0.5</div>
    </div>`;
  }

  function setMessage(text, type = '') {
    const node = document.querySelector('#v205StaffMessage');
    if (!node) return;
    node.textContent = text || '';
    node.className = `ic-form-message ${type}`;
  }

  async function submitStaffForm(form) {
    const realName = String(document.querySelector('#v205StaffRealName')?.value || '').trim();
    const playerName = String(document.querySelector('#v205StaffPlayerName')?.value || '').trim();
    if (realName.length < 2 || realName.length > 40) return setMessage('氏名は2〜40文字で入力してください。', 'error');
    if (playerName.length < 2 || playerName.length > 16) return setMessage('プレイヤー名は2〜16文字で入力してください。', 'error');

    const submit = form.querySelector('button[type="submit"]');
    if (submit) { submit.disabled = true; submit.textContent = 'CREATING...'; }
    setMessage('教職員アカウントを作成しています…');
    try {
      await createStaffAccount({ realName, playerName });
      setMessage('登録しました。ゲームを起動します。', 'success');
      window.setTimeout(() => location.reload(), 350);
    } catch (error) {
      console.error('[staff registration]', error);
      setMessage(error?.message || '登録できませんでした。', 'error');
      if (submit) { submit.disabled = false; submit.textContent = '教職員として登録'; }
    }
  }

  async function enhanceStaffProfileEditor() {
    const form = document.querySelector('#v205ProfileForm');
    if (!form || form.dataset.v205StaffIdentity === '1') return;
    const profile = cloud.getCachedPlayer?.();
    if (profile?.account_type !== 'staff') return;
    form.dataset.v205StaffIdentity = '1';

    const playerNameLabel = form.querySelector('#v205EditName')?.closest('label');
    if (!playerNameLabel) return;
    const label = document.createElement('label');
    label.dataset.v205StaffRealNameRow = '1';
    label.innerHTML = '<span>氏名 <em>PRIVATE</em></span><input id="v205StaffEditRealName" maxlength="40" autocomplete="name" placeholder="管理用の氏名"><small>ランキング・公開プロフィールには表示されません</small>';
    playerNameLabel.insertAdjacentElement('beforebegin', label);

    try {
      const identity = await getMyPrivateIdentity();
      const input = document.querySelector('#v205StaffEditRealName');
      if (input && identity?.real_name) input.value = identity.real_name;
    } catch (error) {
      console.warn('[staff private identity]', error);
    }
  }

  let queued = false;
  const observer = new MutationObserver(() => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      enhanceStaffProfileEditor();
    });
  });
  observer.observe(document.documentElement, { subtree:true, childList:true });

  window.addEventListener('click', event => {
    const staffButton = event.target.closest?.('[data-v205-action="staff-info"]');
    if (staffButton) {
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation();
      showStaffForm();
      return;
    }
    const cancel = event.target.closest?.('[data-v205-staff-cancel]');
    if (cancel) {
      event.preventDefault();
      const ui = window.IntervalCosmosAccountUI;
      if (ui?.showChooser) ui.showChooser();
      else location.reload();
    }
  }, true);

  window.addEventListener('submit', event => {
    if (event.target.id === 'v205StaffForm') {
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation();
      submitStaffForm(event.target);
      return;
    }

    if (event.target.id !== 'v205ProfileForm') return;
    const profile = cloud.getCachedPlayer?.();
    if (profile?.account_type !== 'staff') return;
    const realInput = document.querySelector('#v205StaffEditRealName');
    if (!realInput) return;

    const realName = String(realInput.value || '').trim();
    const playerName = String(document.querySelector('#v205EditName')?.value || '').trim();
    const rankingVisibility = document.querySelector('#v205RankingVisibility')?.value || 'ask';
    if (realName && (realName.length < 2 || realName.length > 40)) {
      event.preventDefault(); event.stopPropagation(); event.stopImmediatePropagation();
      const message = document.querySelector('#v205EditMessage');
      if (message) { message.textContent = '氏名は2〜40文字で入力してください。'; message.className = 'ic-form-message error'; }
      return;
    }
    if (playerName.length < 2 || playerName.length > 16) return;

    event.preventDefault(); event.stopPropagation(); event.stopImmediatePropagation();
    const submit = event.target.querySelector('button[type="submit"]');
    if (submit) { submit.disabled = true; submit.textContent = 'SAVING...'; }
    Promise.resolve()
      .then(() => realName ? updateMyStaffIdentity(realName) : null)
      .then(() => cloud.updateMyProfile({ playerName, avatarId:'teacher', rankingVisibility }))
      .then(() => {
        const message = document.querySelector('#v205EditMessage');
        if (message) { message.textContent = '保存しました。画面を更新します。'; message.className = 'ic-form-message success'; }
        window.setTimeout(() => location.reload(), 450);
      })
      .catch(error => {
        const message = document.querySelector('#v205EditMessage');
        if (message) { message.textContent = error?.message || '保存できませんでした。'; message.className = 'ic-form-message error'; }
        if (submit) { submit.disabled = false; submit.textContent = '保存'; }
      });
  }, true);

  window.IntervalCosmosStaffRegistrationV205 = {
    showStaffForm,
    createStaffAccount,
  };
})();
