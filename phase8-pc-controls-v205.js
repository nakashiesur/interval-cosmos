(() => {
  const STORAGE_KEY = 'intervalCosmos.pcKeys.v205';
  const PREFIX_TIMEOUT = 1800;
  const RESERVED_KEYS = new Set(['Escape', 'Space']);
  const INTERVALS = Object.freeze([
    ['P1','完全1度'],['m2','短2度'],['M2','長2度'],['m3','短3度'],['M3','長3度'],
    ['P4','完全4度'],['TT','三全音'],['P5','完全5度'],['m6','短6度'],['M6','長6度'],
    ['m7','短7度'],['M7','長7度'],['P8','完全8度'],
  ]);
  const DEFAULT_BINDINGS = Object.freeze({
    P1:{prefix:null,key:'1'},
    m2:{prefix:'m',key:'2'}, M2:{prefix:null,key:'2'},
    m3:{prefix:'m',key:'3'}, M3:{prefix:null,key:'3'},
    P4:{prefix:null,key:'4'}, TT:{prefix:null,key:'t'}, P5:{prefix:null,key:'5'},
    m6:{prefix:'m',key:'6'}, M6:{prefix:null,key:'6'},
    m7:{prefix:'m',key:'7'}, M7:{prefix:null,key:'7'},
    P8:{prefix:null,key:'8'},
  });

  let bindings = loadBindings();
  let draftBindings = null;
  let recordTarget = null;
  let armedPrefix = null;
  let armedUntil = 0;
  let prefixTimer = 0;
  let decorateQueued = false;

  function cloneBindings(source = bindings) {
    return Object.fromEntries(INTERVALS.map(([id]) => [id, { ...(source[id] || DEFAULT_BINDINGS[id]) }]));
  }

  function normalizeStoredKey(value) {
    if (value == null || value === '') return null;
    const text = String(value);
    if (text === 'Escape' || text === 'Space') return text;
    return text.length === 1 ? text.toLowerCase() : text;
  }

  function normalizeEventKey(event) {
    if (event.key === 'Escape') return 'Escape';
    if (event.code === 'Space' || event.key === ' ') return 'Space';
    const key = String(event.key || '');
    return key.length === 1 ? key.toLowerCase() : key;
  }

  function displayKey(key) {
    if (!key) return '—';
    if (key === 'Escape') return 'ESC';
    if (key === 'Space') return 'SPACE';
    if (key.length === 1 && /[a-z]/i.test(key)) return key.toUpperCase();
    return key;
  }

  function bindingLabel(binding) {
    if (!binding) return '';
    return binding.prefix ? `${displayKey(binding.prefix)}→${displayKey(binding.key)}` : displayKey(binding.key);
  }

  function loadBindings() {
    try {
      const raw = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
      if (!raw || typeof raw !== 'object') return cloneDefaults();
      const out = {};
      for (const [id] of INTERVALS) {
        const src = raw[id] || DEFAULT_BINDINGS[id];
        out[id] = {
          prefix: normalizeStoredKey(src.prefix),
          key: normalizeStoredKey(src.key) || DEFAULT_BINDINGS[id].key,
        };
      }
      return out;
    } catch {
      return cloneDefaults();
    }
  }

  function cloneDefaults() {
    return Object.fromEntries(INTERVALS.map(([id]) => [id, { ...DEFAULT_BINDINGS[id] }]));
  }

  function saveBindings() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(bindings));
  }

  function isEditable(target) {
    if (!(target instanceof Element)) return false;
    return Boolean(target.closest('input, textarea, select, [contenteditable="true"], [role="textbox"]'));
  }

  function visible(node) {
    if (!(node instanceof Element)) return false;
    const rect = node.getBoundingClientRect();
    const style = getComputedStyle(node);
    return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
  }

  function firstVisible(selectors, root = document) {
    for (const selector of selectors) {
      const nodes = root.querySelectorAll(selector);
      for (const node of nodes) if (visible(node)) return node;
    }
    return null;
  }

  function clickAndConsume(event, node) {
    if (!node || node.disabled) return false;
    event.preventDefault();
    event.stopImmediatePropagation();
    node.click();
    return true;
  }

  function assignmentOverlay() {
    return document.querySelector('.v205-assignment-overlay');
  }

  function syntheticHome(event) {
    const app = document.querySelector('#app');
    if (!app) return false;
    const button = document.createElement('button');
    button.type = 'button';
    button.hidden = true;
    button.dataset.action = 'home';
    app.appendChild(button);
    event.preventDefault();
    event.stopImmediatePropagation();
    button.click();
    button.remove();
    return true;
  }

  function handleEscape(event) {
    const config = document.querySelector('.v205-pc-config-overlay');
    if (config) {
      event.preventDefault();
      event.stopImmediatePropagation();
      if (recordTarget) {
        recordTarget = null;
        renderConfig();
      } else closeConfig();
      return true;
    }

    const admin = document.querySelector('.v205-admin-dashboard-overlay');
    if (admin) return clickAndConsume(event, firstVisible(['[data-v205-admin-close]'], admin));

    const assignment = assignmentOverlay();
    if (assignment) {
      const activeGame = assignment.querySelector('.v205-a-game');
      if (activeGame) return clickAndConsume(event, firstVisible(['[data-a-abort]'], activeGame));
      if (assignment.querySelector('.v205-a-countdown')) return false;
      return clickAndConsume(event, firstVisible([
        '[data-a-mode-back]', '[data-a-back]', '[data-a-v2-back]', '[data-a-back-teacher]', '[data-a-close]',
      ], assignment));
    }

    const modalClose = firstVisible([
      '.settings-modal [data-action="close-settings"]',
      '.records-modal [data-action="close-records"]',
      '.player-modal [data-action="close-player"]',
    ]);
    if (modalClose) return clickAndConsume(event, modalClose);

    if (document.querySelector('.play-screen') && !document.querySelector('.result-panel')) {
      return syntheticHome(event);
    }

    const normalBack = firstVisible([
      '.result-panel [data-action="home"]',
      '.hyper-select-panel [data-action="home"]',
      '.select-panel .topbar [data-action="practice"]',
      '.select-panel .topbar [data-action="home"]',
      '.guide-panel [data-action="guide-back"]',
      '.practice-list ~ * [data-action="home"]',
      '[data-action="home"]',
    ]);
    return clickAndConsume(event, normalBack);
  }

  function handleRetry(event) {
    const assignment = assignmentOverlay();
    if (assignment) return clickAndConsume(event, firstVisible(['[data-a-retry]'], assignment));
    return clickAndConsume(event, firstVisible(['.result-panel [data-action="retry"]']));
  }

  function clearPrefix() {
    armedPrefix = null;
    armedUntil = 0;
    clearTimeout(prefixTimer);
    prefixTimer = 0;
    document.querySelector('.v205-pc-prefix-indicator')?.remove();
  }

  function showPrefix(prefix) {
    clearTimeout(prefixTimer);
    let node = document.querySelector('.v205-pc-prefix-indicator');
    if (!node) {
      node = document.createElement('div');
      node.className = 'v205-pc-prefix-indicator';
      document.body.appendChild(node);
    }
    node.textContent = `${displayKey(prefix)} → …`;
    prefixTimer = setTimeout(clearPrefix, PREFIX_TIMEOUT);
  }

  function resolveAnswerKey(key) {
    const now = performance.now();
    if (armedPrefix && now <= armedUntil) {
      const prefix = armedPrefix;
      clearPrefix();
      const match = INTERVALS.find(([id]) => bindings[id].prefix === prefix && bindings[id].key === key);
      if (match) return { interval: match[0], pending: false };
    } else if (armedPrefix) {
      clearPrefix();
    }

    const direct = INTERVALS.find(([id]) => !bindings[id].prefix && bindings[id].key === key);
    if (direct) return { interval: direct[0], pending: false };

    const usedAsPrefix = INTERVALS.some(([id]) => bindings[id].prefix === key);
    if (usedAsPrefix) {
      armedPrefix = key;
      armedUntil = performance.now() + PREFIX_TIMEOUT;
      showPrefix(key);
      return { interval: null, pending: true };
    }
    return { interval: null, pending: false };
  }

  function answerButtonsVisible() {
    return [...document.querySelectorAll('[data-answer], [data-a-answer]')].some(button => visible(button) && !button.disabled);
  }

  function handleAnswerShortcut(event) {
    if (!answerButtonsVisible()) return false;
    const key = normalizeEventKey(event);
    const resolved = resolveAnswerKey(key);
    if (resolved.pending) {
      event.preventDefault();
      event.stopImmediatePropagation();
      return true;
    }
    if (!resolved.interval) return false;
    const button = firstVisible([
      `[data-a-answer="${resolved.interval}"]`,
      `[data-answer="${resolved.interval}"]`,
    ]);
    return clickAndConsume(event, button);
  }

  function decorateAnswers() {
    for (const button of document.querySelectorAll('[data-answer]')) {
      const binding = bindings[button.dataset.answer];
      const label = bindingLabel(binding);
      if (label && button.dataset.pcKey !== label) button.dataset.pcKey = label;
    }
    for (const button of document.querySelectorAll('[data-a-answer]')) {
      const binding = bindings[button.dataset.aAnswer];
      const label = bindingLabel(binding);
      if (label && button.dataset.pcKey !== label) button.dataset.pcKey = label;
    }
    for (const button of document.querySelectorAll('[data-action="replay"], [data-a-replay]')) {
      if (button.title !== 'Space：もう一度再生') button.title = 'Space：もう一度再生';
    }
    for (const button of document.querySelectorAll('[data-action="retry"], [data-a-retry]')) {
      if (button.title !== 'R：リトライ') button.title = 'R：リトライ';
    }
    injectSettingsEntry();
  }

  function injectSettingsEntry() {
    const card = document.querySelector('.settings-modal .modal-card');
    if (!card || card.querySelector('[data-pc-config-entry]')) return;
    const row = document.createElement('div');
    row.className = 'setting-row v205-pc-settings-entry';
    row.dataset.pcConfigEntry = '1';
    row.innerHTML = `<div class="setting-label"><div><strong>PC KEY CONFIG</strong><span>回答キーをカスタマイズ</span></div><button type="button" class="secondary-btn" data-pc-config-open>OPEN</button></div>`;
    card.appendChild(row);
  }

  function validateDraft(source = draftBindings) {
    if (!source) return { ok: false, message: '設定を読み込めません。' };
    const sequenceOwners = new Map();
    const prefixes = new Set();
    const directKeys = new Set();
    for (const [id, label] of INTERVALS) {
      const binding = source[id];
      if (!binding?.key) return { ok:false, message:`${label} の決定キーを設定してください。` };
      if (RESERVED_KEYS.has(binding.key) || RESERVED_KEYS.has(binding.prefix)) {
        return { ok:false, message:'ESC と SPACE はシステム操作のため回答キーには設定できません。' };
      }
      if (binding.prefix) prefixes.add(binding.prefix); else directKeys.add(binding.key);
      const sequence = `${binding.prefix || ''}>${binding.key}`;
      if (sequenceOwners.has(sequence)) {
        return { ok:false, message:`${label} と ${sequenceOwners.get(sequence)} が同じキー操作になっています。` };
      }
      sequenceOwners.set(sequence, label);
    }
    for (const prefix of prefixes) {
      if (directKeys.has(prefix)) {
        return { ok:false, message:`${displayKey(prefix)} が「単独の決定キー」と「予備キー」の両方に使われています。` };
      }
    }
    return { ok:true, message:'' };
  }

  function configRow(id, label) {
    const b = draftBindings[id];
    const recPrefix = recordTarget?.id === id && recordTarget.slot === 'prefix';
    const recKey = recordTarget?.id === id && recordTarget.slot === 'key';
    return `<div class="v205-pc-bind-row" data-pc-bind-row="${id}">
      <div class="v205-pc-interval"><strong>${id}</strong><span>${label}</span></div>
      <button type="button" class="v205-pc-keybox aux ${recPrefix?'recording':''}" data-pc-record="prefix" data-pc-id="${id}">${recPrefix?'REC':displayKey(b.prefix)}</button>
      <span class="v205-pc-arrow">→</span>
      <button type="button" class="v205-pc-keybox primary ${recKey?'recording':''}" data-pc-record="key" data-pc-id="${id}">${recKey?'REC':displayKey(b.key)}</button>
    </div>`;
  }

  function renderConfig(message = '') {
    const overlay = document.querySelector('.v205-pc-config-overlay');
    if (!overlay || !draftBindings) return;
    const validation = validateDraft();
    overlay.innerHTML = `<section class="v205-pc-config-panel">
      <header class="v205-pc-config-head"><div><p>PC CONTROLS</p><h2>KEY CONFIG</h2><span>予備キーは任意、決定キーは必須です。クリックしてRECになったら希望のキーを押してください。</span></div><button type="button" class="icon-btn" data-pc-config-close>×</button></header>
      <div class="v205-pc-column-head"><span>音程</span><span>予備キー</span><span></span><span>決定キー</span></div>
      <div class="v205-pc-bindings">${INTERVALS.map(([id,label]) => configRow(id,label)).join('')}</div>
      <div class="v205-pc-config-note">初期値：長・完全は度数の数字、短音程は <b>M → 度数</b>、三全音は <b>T</b>。予備キーを消すにはREC中にDelete / Backspace。</div>
      <div class="v205-pc-config-message ${validation.ok?'':'error'}">${message || validation.message || '同じ予備キーは複数の音程で共有できます。完全に同じ組み合わせだけが競合です。'}</div>
      <footer class="v205-pc-config-actions"><button type="button" class="secondary-btn" data-pc-config-reset>初期値に戻す</button><span></span><button type="button" class="secondary-btn" data-pc-config-close>キャンセル</button><button type="button" class="primary-btn" data-pc-config-save ${validation.ok?'':'disabled'}>保存</button></footer>
    </section>`;
  }

  function openConfig() {
    closeConfig();
    draftBindings = cloneBindings();
    recordTarget = null;
    const overlay = document.createElement('div');
    overlay.className = 'v205-pc-config-overlay';
    document.body.appendChild(overlay);
    renderConfig();
  }

  function closeConfig() {
    document.querySelector('.v205-pc-config-overlay')?.remove();
    draftBindings = null;
    recordTarget = null;
  }

  function captureConfigKey(event) {
    if (!recordTarget || !draftBindings) return false;
    event.preventDefault();
    event.stopImmediatePropagation();
    if (event.key === 'Escape') {
      recordTarget = null;
      renderConfig('RECをキャンセルしました。');
      return true;
    }
    if ((event.key === 'Backspace' || event.key === 'Delete') && recordTarget.slot === 'prefix') {
      draftBindings[recordTarget.id].prefix = null;
      recordTarget = null;
      renderConfig('予備キーを解除しました。');
      return true;
    }
    const key = normalizeEventKey(event);
    if (!key || RESERVED_KEYS.has(key)) {
      renderConfig('ESC と SPACE はシステム操作として予約されています。別のキーを選んでください。');
      return true;
    }
    draftBindings[recordTarget.id][recordTarget.slot] = key;
    recordTarget = null;
    renderConfig();
    return true;
  }

  function scheduleDecorate() {
    if (decorateQueued) return;
    decorateQueued = true;
    queueMicrotask(() => {
      decorateQueued = false;
      decorateAnswers();
    });
  }

  document.addEventListener('click', event => {
    const open = event.target.closest?.('[data-pc-config-open]');
    if (open) { event.preventDefault(); openConfig(); return; }
    const close = event.target.closest?.('[data-pc-config-close]');
    if (close) { event.preventDefault(); closeConfig(); return; }
    const reset = event.target.closest?.('[data-pc-config-reset]');
    if (reset) { event.preventDefault(); draftBindings = cloneDefaults(); recordTarget = null; renderConfig('初期値に戻しました。保存すると確定します。'); return; }
    const save = event.target.closest?.('[data-pc-config-save]');
    if (save) {
      event.preventDefault();
      const validation = validateDraft();
      if (!validation.ok) { renderConfig(validation.message); return; }
      bindings = cloneBindings(draftBindings);
      saveBindings();
      closeConfig();
      decorateAnswers();
      return;
    }
    const rec = event.target.closest?.('[data-pc-record]');
    if (rec && draftBindings) {
      event.preventDefault();
      recordTarget = { id: rec.dataset.pcId, slot: rec.dataset.pcRecord };
      renderConfig('REC中です。希望のキーを1つ押してください。');
    }
  }, true);

  window.addEventListener('keydown', event => {
    if (document.querySelector('.v205-pc-config-overlay')) {
      if (recordTarget) { captureConfigKey(event); return; }
      if (event.key === 'Escape') { handleEscape(event); return; }
    }
    if (event.repeat || event.isComposing || event.metaKey || event.ctrlKey || event.altKey) return;
    if (isEditable(event.target)) return;

    if (event.key === 'Escape') {
      handleEscape(event);
      return;
    }
    if (handleAnswerShortcut(event)) return;
    if (event.key.toLowerCase() === 'r') handleRetry(event);
    // Space is intentionally left to the existing normal / assignment audio engines.
  }, true);

  new MutationObserver(scheduleDecorate).observe(document.documentElement, { subtree: true, childList: true });
  window.addEventListener('DOMContentLoaded', scheduleDecorate, { once: true });
  scheduleDecorate();

  window.IntervalCosmosPcControlsV205 = {
    getBindings: () => cloneBindings(),
    defaults: cloneDefaults,
    decorate: decorateAnswers,
    openConfig,
    resolveKey: key => resolveAnswerKey(normalizeStoredKey(key)),
  };
})();
