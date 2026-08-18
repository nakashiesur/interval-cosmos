(() => {
  const ANSWER_KEYS = Object.freeze({
    P1: '1', m2: '2', M2: '3', m3: '4', M3: '5', P4: '6', TT: '7', P5: '8',
    m6: '9', M6: '0', m7: 'Q', M7: 'W', P8: 'E',
  });
  let decorateQueued = false;

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

  function handleEscape(event) {
    // Admin analytics is a true overlay: close it first.
    const admin = document.querySelector('.v205-admin-dashboard-overlay');
    if (admin) return clickAndConsume(event, firstVisible(['[data-v205-admin-close]'], admin));

    const assignment = assignmentOverlay();
    if (assignment) {
      // Never bypass the explicit abort confirmation while an assignment game is active.
      if (assignment.querySelector('.v205-a-game, .v205-a-countdown')) return false;
      return clickAndConsume(event, firstVisible([
        '[data-a-mode-back]',
        '[data-a-back]',
        '[data-a-v2-back]',
        '[data-a-back-teacher]',
        '[data-a-close]',
      ], assignment));
    }

    // Existing app modals use their own close buttons. Triggering the visible button keeps
    // extension state (ranking/settings/profile) consistent with mouse/touch operation.
    const modalClose = firstVisible([
      '.settings-modal [data-action="close-settings"]',
      '.records-modal [data-action="close-records"]',
      '.player-modal [data-action="close-player"]',
    ]);
    if (modalClose) return clickAndConsume(event, modalClose);

    // During a timed run, long-press exit remains the only exit path to prevent accidental loss.
    if (document.querySelector('.play-screen') && !document.querySelector('.result-panel')) return false;

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
    if (assignment) {
      return clickAndConsume(event, firstVisible(['[data-a-retry]'], assignment));
    }
    return clickAndConsume(event, firstVisible(['.result-panel [data-action="retry"]']));
  }

  function decorateAnswers() {
    const normal = document.querySelectorAll('[data-answer]');
    for (const button of normal) {
      const key = ANSWER_KEYS[button.dataset.answer];
      if (key && button.dataset.pcKey !== key) button.dataset.pcKey = key;
    }
    const assignment = document.querySelectorAll('[data-a-answer]');
    for (const button of assignment) {
      const key = ANSWER_KEYS[button.dataset.aAnswer];
      if (key && button.dataset.pcKey !== key) button.dataset.pcKey = key;
    }

    for (const button of document.querySelectorAll('[data-action="replay"], [data-a-replay]')) {
      if (button.title !== 'Space：もう一度再生') button.title = 'Space：もう一度再生';
    }
    for (const button of document.querySelectorAll('[data-action="retry"], [data-a-retry]')) {
      if (button.title !== 'R：リトライ') button.title = 'R：リトライ';
    }
  }

  function scheduleDecorate() {
    if (decorateQueued) return;
    decorateQueued = true;
    queueMicrotask(() => {
      decorateQueued = false;
      decorateAnswers();
    });
  }

  window.addEventListener('keydown', event => {
    if (event.repeat || event.isComposing || event.metaKey || event.ctrlKey || event.altKey) return;
    if (isEditable(event.target)) return;

    if (event.key === 'Escape') {
      handleEscape(event);
      return;
    }
    if (event.key.toLowerCase() === 'r') {
      handleRetry(event);
    }
    // Space and answer keys continue to be handled by the existing normal/assignment engines.
    // This layer deliberately does not duplicate them.
  }, true);

  new MutationObserver(scheduleDecorate).observe(document.documentElement, { subtree: true, childList: true });
  window.addEventListener('DOMContentLoaded', scheduleDecorate, { once: true });
  scheduleDecorate();

  window.IntervalCosmosPcControlsV205 = {
    answerKeys: ANSWER_KEYS,
    decorate: decorateAnswers,
  };
})();
