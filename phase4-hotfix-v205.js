(() => {
  const INTERVALS = new Set(['P1','m2','M2','m3','M3','P4','TT','P5','m6','M6','m7','M7','P8']);

  function later(fn, ms = 40) {
    window.setTimeout(fn, ms);
  }

  function chooseOnly(intervalKey) {
    document.querySelector('[data-action="clear-all"]')?.click();
    later(() => document.querySelector(`[data-interval="${intervalKey}"]`)?.click(), 25);
  }

  function enterFocus(intervalKey, preferredView) {
    const finishFromPractice = () => {
      document.querySelector(`[data-view="${preferredView}"]`)?.click();
      const manual = document.querySelector('[data-practice="manual"]');
      if (manual) {
        manual.click();
        later(() => chooseOnly(intervalKey), 40);
        return;
      }
      if (document.querySelector('[data-action="clear-all"]')) chooseOnly(intervalKey);
    };

    const go = () => {
      const practiceButton = document.querySelector('[data-action="practice"]');
      if (practiceButton) {
        practiceButton.click();
        later(finishFromPractice, 50);
        return;
      }
      finishFromPractice();
    };

    if (document.querySelector('.result-panel')) {
      document.querySelector('[data-action="home"]')?.click();
      later(go, 55);
    } else {
      go();
    }
  }

  function start(intervalKey, preferredView) {
    if (!INTERVALS.has(intervalKey)) return;

    document.querySelector('.v205-practice-choice')?.remove();
    document.querySelector('.v205-history-overlay')?.remove();

    const closeSettings = document.querySelector('[data-action="close-settings"]');
    if (closeSettings) {
      closeSettings.click();
      later(() => enterFocus(intervalKey, preferredView), 60);
      return;
    }

    enterFocus(intervalKey, preferredView);
  }

  // Loaded before phase4-v205.js so this capture handler can consume the
  // focus-choice click before the older Phase 4 navigation handler runs.
  window.addEventListener('click', event => {
    const view = event.target.closest?.('[data-v205-focus-view]');
    if (!view) return;

    const intervalKey = view.dataset.interval;
    const preferredView = view.dataset.v205FocusView === 'keys' ? 'keys' : 'text';
    event.preventDefault();
    event.stopImmediatePropagation();
    start(intervalKey, preferredView);
  }, true);
})();
