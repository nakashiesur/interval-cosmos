(() => {
  const groups = [['overview','概要',[0]],['appearance','着せ替え',[1,2]],['achievements','実績',[3]]];
  let active = 'overview', previousOverlay = null;
  function scan() {
    const overlay = document.querySelector('.v205-cosmos-overlay');
    if (!overlay) {previousOverlay = null; active = 'overview'; return;}
    if (overlay !== previousOverlay) {active = 'overview'; previousOverlay = overlay;}
    const card = overlay.querySelector('.v205-cosmos-card');
    if (!card || card.querySelector('.cosmos-folder-nav')) return;
    const sections = [...card.querySelectorAll(':scope > .v205-cosmos-section')];
    const evolution = card.querySelector('.v205-evolution');
    if (sections.length !== 4 || !evolution) return;
    const nav = document.createElement('nav');nav.className = 'cosmos-folder-nav';
    nav.setAttribute('role','tablist');nav.setAttribute('aria-label','MY COSMOSの表示');
    evolution.after(nav);
    for (const [id,label,indexes] of groups) {
      const button = document.createElement('button');button.type='button';button.textContent=label;
      button.id=`cosmos-tab-${id}`;button.dataset.cosmosTab=id;button.setAttribute('role','tab');
      button.setAttribute('aria-controls',`cosmos-pane-${id}`);nav.append(button);
      const pane = document.createElement('div');pane.className='cosmos-folder-pane';pane.id=`cosmos-pane-${id}`;
      pane.dataset.cosmosPane=id;pane.setAttribute('role','tabpanel');pane.setAttribute('aria-labelledby',button.id);
      indexes.forEach(i=>pane.append(sections[i]));card.append(pane);
    }
    function select(id, scroll = false) {
      active = groups.some(g=>g[0]===id) ? id : 'overview';
      nav.querySelectorAll('button').forEach(b=>{const selected=b.dataset.cosmosTab===active;b.setAttribute('aria-selected',String(selected));b.tabIndex=selected?0:-1;});
      card.querySelectorAll('[data-cosmos-pane]').forEach(p=>p.classList.toggle('is-active',p.dataset.cosmosPane===active));
      if (scroll && matchMedia('(max-width:780px)').matches) card.scrollTo({top:0,behavior:matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth'});
    }
    nav.addEventListener('click',e=>{const b=e.target.closest('[data-cosmos-tab]');if(b)select(b.dataset.cosmosTab,true)});
    nav.addEventListener('keydown',e=>{
      if (!['ArrowLeft','ArrowRight','Home','End'].includes(e.key)) return;
      e.preventDefault();const ids=groups.map(g=>g[0]);let i=ids.indexOf(active);
      i=e.key==='Home'?0:e.key==='End'?2:(i+(e.key==='ArrowRight'?1:2))%3;
      select(ids[i],true);nav.querySelector(`[data-cosmos-tab="${ids[i]}"]`).focus();
    });
    select(active);
  }
  new MutationObserver(scan).observe(document.documentElement,{childList:true,subtree:true});
  scan();
})();
