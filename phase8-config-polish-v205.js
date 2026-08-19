(() => {
  let queued = false;

  function polishConfig() {
    const overlay = document.querySelector('.v205-pc-config-overlay');
    if (!overlay) return;

    const help = overlay.querySelector('.v205-pc-config-head span');
    const helpText = '予備キーは任意、決定キーは必須です。変更したい枠をクリックして、希望するキーを押してください。';
    if (help && help.textContent !== helpText) help.textContent = helpText;

    const note = overlay.querySelector('.v205-pc-config-note');
    if (note) {
      const html = '初期値：長・完全は度数の数字、短音程は <b>M → 度数</b>、三全音は <b>T</b>。予備キーを消すには、予備キーの枠を選択中に Delete / Backspace。';
      if (note.innerHTML !== html) note.innerHTML = html;
    }

    for (const button of overlay.querySelectorAll('.v205-pc-keybox.aux')) {
      if (!button.classList.contains('recording') && button.textContent.trim() === '—') {
        button.textContent = '';
        button.classList.add('empty');
        button.setAttribute('aria-label', '予備キー：未設定');
      }
    }

    const recording = overlay.querySelector('.v205-pc-keybox.recording');
    if (recording) {
      if (recording.textContent.trim() === 'REC') recording.textContent = '…';
      recording.setAttribute('aria-label', 'キー入力待ち');
      recording.title = '希望するキーを押してください';
    }

    const message = overlay.querySelector('.v205-pc-config-message');
    if (message) {
      const raw = message.textContent.trim();
      if (raw === 'RECをキャンセルしました。') {
        message.textContent = 'キー入力をキャンセルしました。';
      }
      if (recording) {
        message.classList.add('learning');
        const current = message.textContent.trim();
        if (/REC中です|希望のキーを1つ押してください/.test(current)) {
          message.textContent = '希望するキーを押してください';
        }
        if (/予約されています|別のキーを選んでください|同じキー操作|設定してください/.test(message.textContent)) {
          message.classList.add('error');
        }
      } else {
        message.classList.remove('learning');
      }
    }
  }

  function schedule() {
    if (queued) return;
    queued = true;
    queueMicrotask(() => {
      queued = false;
      polishConfig();
    });
  }

  new MutationObserver(schedule).observe(document.documentElement, { subtree: true, childList: true });
  document.addEventListener('click', event => {
    if (event.target.closest?.('[data-pc-record]')) schedule();
  }, true);
  window.addEventListener('DOMContentLoaded', schedule, { once: true });
  schedule();
})();
