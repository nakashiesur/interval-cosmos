(() => {
  let queued = false;
  let arranging = false;
  let settingsCategory = 'game';

  const CATEGORY_ORDER = ['game', 'controls', 'ranking', 'account'];
  const CATEGORY_LABELS = {
    game: ['GAME & AUDIO', '音・再生'],
    controls: ['CONTROLS', '操作・回答'],
    ranking: ['RANKING & PRIVACY', 'ランキング・公開'],
    account: ['ACCOUNT & DEVICE', 'アカウント・端末'],
  };

  function classifySetting(node) {
    const text = String(node?.textContent || '').toLowerCase();
    const cls = String(node?.className || '').toLowerCase();
    if (cls.includes('v205-pc-settings-entry') || /pc key|key config|shortcut|keyboard|回答キー|操作/.test(text)) return 'controls';
    if (/ranking|privacy|公開|殿堂|monthly|hall/.test(text)) return 'ranking';
    if (cls.includes('v205-recovery-setting') || /player|profile|account|recovery|復旧|端末|device|学籍|教職員|staff|course|コース|avatar|アバター|名前/.test(text)) return 'account';
    return 'game';
  }

  function ensureHomeDeck() {
    const panel = document.querySelector('.home-panel');
    const topbar = panel?.querySelector('.topbar-home');
    if (!panel || !topbar) return;

    let deck = panel.querySelector('.v205-home-command-deck');
    if (!deck) {
      deck = document.createElement('section');
      deck.className = 'v205-home-command-deck';
      deck.setAttribute('aria-label', 'プレイヤーメニュー');
      deck.innerHTML = `
        <button type="button" class="v205-home-command cosmos" data-v205-cosmos-open>
          <span class="v205-home-command-kicker">PROFILE & GROWTH</span>
          <strong>MY COSMOS</strong>
          <small>実績・称号・フレーム</small>
        </button>
        <button type="button" class="v205-home-command ranking" data-action="records">
          <span class="v205-home-command-kicker">ONLINE</span>
          <strong>RANKING</strong>
          <small>月間・殿堂・公開プロフィール</small>
        </button>
        <button type="button" class="v205-home-command settings" data-action="settings">
          <span class="v205-home-command-kicker">SYSTEM</span>
          <strong>SETTINGS</strong>
          <small>音・操作・公開・端末</small>
        </button>`;
      topbar.insertAdjacentElement('afterend', deck);
    }

    const footer = panel.querySelector('.home-footer');
    const legacyCosmos = footer?.querySelector('[data-v205-cosmos-open]');
    const legacyRanking = footer?.querySelector('[data-action="records"]');
    if (legacyCosmos && !legacyCosmos.closest('.v205-home-command-deck')) legacyCosmos.classList.add('v205-phase10-source-hidden');
    if (legacyRanking && !legacyRanking.closest('.v205-home-command-deck')) legacyRanking.classList.add('v205-phase10-source-hidden');
  }

  function ensureSettingsShell(card) {
    const head = card.querySelector(':scope > .modal-head');
    const title = head?.querySelector('h2');
    const copy = head?.querySelector('p');
    if (title && title.textContent !== 'SETTINGS') title.textContent = 'SETTINGS';
    if (copy && copy.textContent !== 'カテゴリを選んで設定を調整します。') copy.textContent = 'カテゴリを選んで設定を調整します。';

    let legacy = card.querySelector(':scope > .v205-settings-legacy-sources');
    if (!legacy) {
      legacy = document.createElement('div');
      legacy.className = 'v205-settings-legacy-sources';
      legacy.setAttribute('aria-hidden', 'true');
    }

    const cosmosLegacy = card.querySelector('.v205-cosmos-setting');
    if (cosmosLegacy && cosmosLegacy.parentElement !== legacy) legacy.appendChild(cosmosLegacy);

    let nav = card.querySelector(':scope > .v205-settings-nav');
    if (!nav) {
      nav = document.createElement('div');
      nav.className = 'v205-settings-nav';
      nav.setAttribute('role', 'tablist');
      nav.innerHTML = CATEGORY_ORDER.map(id => {
        const [tabTitle, sub] = CATEGORY_LABELS[id];
        return `<button type="button" class="v205-settings-tab" role="tab" data-v205-settings-category="${id}"><strong>${tabTitle}</strong><small>${sub}</small></button>`;
      }).join('');
    }

    let groups = card.querySelector(':scope > .v205-settings-groups');
    if (!groups) {
      groups = document.createElement('div');
      groups.className = 'v205-settings-groups';
      groups.innerHTML = CATEGORY_ORDER.map(id => {
        const [groupTitle, sub] = CATEGORY_LABELS[id];
        return `<section class="v205-settings-group" data-v205-settings-group="${id}"><header><span>${groupTitle}</span><small>${sub}</small></header><div class="v205-settings-group-body"></div></section>`;
      }).join('');
    }

    if (head) {
      if (nav.parentElement !== card) head.insertAdjacentElement('afterend', nav);
      else if (nav.previousElementSibling !== head) head.insertAdjacentElement('afterend', nav);
      if (groups.parentElement !== card) nav.insertAdjacentElement('afterend', groups);
      else if (groups.previousElementSibling !== nav) nav.insertAdjacentElement('afterend', groups);
      if (legacy.parentElement !== card) card.appendChild(legacy);
    }

    return { nav, groups, legacy };
  }

  function arrangeSettings() {
    const card = document.querySelector('.settings-modal .modal-card');
    if (!card) return;
    card.classList.add('v205-settings-card');

    const { nav, groups, legacy } = ensureSettingsShell(card);
    const directRows = [...card.children].filter(node => node.classList?.contains('setting-row'));
    for (const row of directRows) {
      if (row.classList.contains('v205-cosmos-setting')) {
        legacy.appendChild(row);
        continue;
      }
      const category = classifySetting(row);
      groups.querySelector(`[data-v205-settings-group="${category}"] .v205-settings-group-body`)?.appendChild(row);
    }

    // Existing injectors may append rows inside the card after this layer runs.
    // Sweep them into a category without cloning or replacing the real controls.
    for (const row of card.querySelectorAll(':scope > .setting-row')) {
      if (row.classList.contains('v205-cosmos-setting')) legacy.appendChild(row);
      else {
        const category = classifySetting(row);
        groups.querySelector(`[data-v205-settings-group="${category}"] .v205-settings-group-body`)?.appendChild(row);
      }
    }

    const existingCosmos = card.querySelector('.v205-cosmos-setting');
    if (existingCosmos && existingCosmos.parentElement !== legacy) legacy.appendChild(existingCosmos);

    let active = settingsCategory;
    const activeGroup = groups.querySelector(`[data-v205-settings-group="${active}"]`);
    if (!activeGroup || !activeGroup.querySelector('.setting-row')) {
      active = CATEGORY_ORDER.find(id => groups.querySelector(`[data-v205-settings-group="${id}"] .setting-row`)) || 'game';
      settingsCategory = active;
    }

    for (const tab of nav.querySelectorAll('[data-v205-settings-category]')) {
      const on = tab.dataset.v205SettingsCategory === active;
      tab.classList.toggle('active', on);
      tab.setAttribute('aria-selected', String(on));
    }
    for (const group of groups.querySelectorAll('[data-v205-settings-group]')) {
      const hasRows = Boolean(group.querySelector('.setting-row'));
      const on = hasRows && group.dataset.v205SettingsGroup === active;
      group.hidden = !on;
      nav.querySelector(`[data-v205-settings-category="${group.dataset.v205SettingsGroup}"]`)?.classList.toggle('empty', !hasRows);
    }

    const version = card.querySelector(':scope > .settings-version');
    if (version && version.previousElementSibling !== groups) groups.insertAdjacentElement('afterend', version);
  }

  function improveUnlockContrast() {
    document.querySelectorAll('.v205-unlock-burst section').forEach(section => section.classList.add('v205-phase10-readable'));
  }

  function arrange() {
    if (arranging) return;
    arranging = true;
    try {
      ensureHomeDeck();
      arrangeSettings();
      improveUnlockContrast();
    } finally {
      arranging = false;
    }
  }

  function schedule() {
    if (queued) return;
    queued = true;
    queueMicrotask(() => {
      queued = false;
      arrange();
    });
  }

  window.addEventListener('click', event => {
    const tab = event.target.closest?.('[data-v205-settings-category]');
    if (!tab) return;
    event.preventDefault();
    event.stopPropagation();
    settingsCategory = tab.dataset.v205SettingsCategory || 'game';
    arrangeSettings();
  }, true);

  new MutationObserver(schedule).observe(document.documentElement, { subtree:true, childList:true });
  window.addEventListener('DOMContentLoaded', schedule, { once:true });
  schedule();

  window.IntervalCosmosPhase10UIV205 = {
    arrange,
    getSettingsCategory: () => settingsCategory,
    setSettingsCategory: value => {
      if (CATEGORY_ORDER.includes(value)) settingsCategory = value;
      arrangeSettings();
    },
  };
})();
