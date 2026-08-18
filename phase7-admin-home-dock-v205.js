(() => {
  const cloud = window.IntervalCosmosCloud;
  let queued = false;
  let arranging = false;

  function isAdmin() {
    return Boolean(cloud?.getCachedPlayer?.()?.is_admin);
  }

  function ensureStyle() {
    if (document.querySelector('#v205AdminHomeDockStyle')) return;
    const style = document.createElement('style');
    style.id = 'v205AdminHomeDockStyle';
    style.textContent = `
      .v205-admin-home-row{margin-top:12px;padding-top:12px;border-top:1px solid rgba(116,145,201,.18);display:flex;align-items:center;gap:12px}
      .v205-admin-home-label{flex:0 0 auto;color:#5ee2ff;font-size:10px;font-weight:800;letter-spacing:.16em;white-space:nowrap}
      .v205-admin-home-actions{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;flex:1;min-width:0}
      .v205-admin-home-actions>.secondary-btn{width:100%;min-height:48px;white-space:normal;line-height:1.15;padding:10px 14px}
      @media(max-width:700px){.v205-admin-home-row{align-items:stretch;flex-direction:column}.v205-admin-home-label{align-self:flex-start}.v205-admin-home-actions{width:100%;grid-template-columns:1fr 1fr}}
      @media(max-width:430px){.v205-admin-home-actions{grid-template-columns:1fr}}
    `;
    document.head.appendChild(style);
  }

  function restoreIfNeeded(footer, row) {
    if (!row) return;
    const actions = row.querySelector('.v205-admin-home-actions');
    const assignment = actions?.querySelector('[data-a-open]');
    if (assignment && footer) footer.prepend(assignment);
    row.remove();
  }

  function arrange() {
    if (arranging) return;
    arranging = true;
    try {
      const footer = document.querySelector('.home-footer');
      if (!footer) return;
      let row = document.querySelector('.v205-admin-home-row');

      if (!isAdmin()) {
        restoreIfNeeded(footer, row);
        return;
      }

      ensureStyle();
      if (!row) {
        row = document.createElement('div');
        row.className = 'v205-admin-home-row';
        row.setAttribute('aria-label', '管理者専用ツール');
        row.innerHTML = '<span class="v205-admin-home-label">ADMIN TOOLS</span><div class="v205-admin-home-actions"></div>';
        footer.insertAdjacentElement('afterend', row);
      } else if (row.previousElementSibling !== footer) {
        footer.insertAdjacentElement('afterend', row);
      }

      const actions = row.querySelector('.v205-admin-home-actions');
      if (!actions) return;

      // Only these two admin-specific controls are moved. Ordinary player controls remain untouched.
      const dashboard = document.querySelector('[data-v205-admin-dashboard-open]');
      const assignment = document.querySelector('[data-a-open]');
      if (dashboard && dashboard.parentElement !== actions) actions.appendChild(dashboard);
      if (assignment && assignment.parentElement !== actions) actions.appendChild(assignment);
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

  new MutationObserver(schedule).observe(document.documentElement, { subtree: true, childList: true });
  window.addEventListener('DOMContentLoaded', schedule, { once: true });
  schedule();

  window.IntervalCosmosAdminHomeDockV205 = { arrange };
})();
