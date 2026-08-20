const fs=require('fs');
const path=require('path');
const root=path.join(__dirname,'..');
const js=fs.readFileSync(path.join(root,'phase10-ui-foundation-v205.js'),'utf8');
const css=fs.readFileSync(path.join(root,'phase10-ui-foundation-v205.css'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');

const tests=[
  ['Phase 10 foundation assets are loaded',index.includes('phase10-ui-foundation-v205.js')&&index.includes('phase10-ui-foundation-v205.css')],
  ['service worker caches Phase 10 foundation',sw.includes('phase10-ui-foundation-v205.js')&&sw.includes('phase10-ui-foundation-v205.css')],
  ['home puts MY COSMOS beside existing settings gear',js.includes('v205-home-cosmos-pill')&&js.includes('data-v205-cosmos-open')&&js.includes("querySelector('[data-action=\"settings\"]')")],
  ['learning history is exposed beside MY COSMOS on desktop and mobile',js.includes('configureHistoryEntry')&&js.includes('v205-home-history-pill')&&js.includes('data-v205-history-open')&&css.includes('.v205-home-history-pill')&&css.includes('.v205-phase10-history-source-hidden{display:none!important}')],
  ['history source remains mounted in footer to prevent reinjection churn',js.includes("panel?.querySelector('.home-footer [data-v205-history-open]')")&&js.includes("source.classList.add('v205-phase10-history-source-hidden')")],
  ['desktop history header keeps icon and labels in a stable two-row layout',css.includes('grid-template-areas:"icon title" "icon subtitle"')&&css.includes('flex:0 0 148px')&&css.includes('white-space:nowrap')],
  ['mobile history header collapses to icon only',css.includes('flex:0 0 44px')&&css.includes('.v205-home-history-pill strong,.v205-home-history-pill small{display:none}')],
  ['home moves ranking to a dedicated EAR LINK follow-up bar',js.includes('v205-home-ranking-bar')&&js.includes('earlink-elite')&&js.includes('ONLINE RANKING')],
  ['redundant command deck is removed',js.includes("querySelector('.v205-home-command-deck')?.remove()")&&css.includes('.v205-home-command-deck{display:none!important}')],
  ['legacy footer MY COSMOS and ranking controls are hidden',js.includes('v205-phase10-source-hidden')&&css.includes('.v205-phase10-source-hidden{display:none!important}')],
  ['legacy MY COSMOS settings source stays mounted but hidden',js.includes('v205-settings-legacy-sources')&&js.includes('v205-cosmos-setting')&&css.includes('.v205-settings-legacy-sources{display:none!important}')],
  ['settings are divided into four master categories',['game','controls','ranking','account'].every(id=>js.includes(id))&&js.includes('GAME & AUDIO')&&js.includes('RANKING & PRIVACY')&&js.includes('ACCOUNT & DEVICE')],
  ['cloud profile row is classified as account while ranking privacy stays ranking',js.includes("cls.includes('cloud-setting')")&&js.includes("cls.includes('v205-ranking-privacy')")],
  ['late-injected settings are re-homed from any category body',js.includes("card.querySelectorAll('.setting-row')")&&js.includes('row.parentElement !== target')],
  ['settings selected category is retained across rerenders',js.includes("let settingsCategory = 'game'")&&js.includes('getSettingsCategory')],
  ['settings category change animates content height from a fixed top anchor',js.includes('animateSettingsCategory')&&js.includes('fromHeight')&&js.includes('toHeight')&&css.includes('align-items:flex-start!important')],
  ['desktop and mobile reuse compact practice slot as PRACTICE MODE',js.includes('configurePracticeEntry')&&js.includes("shortcut.dataset.action = 'practice'")&&js.includes('🔰')&&js.includes('PRACTICE MODE')&&js.includes('v205-phase10-practice-source-hidden')&&css.includes('.v205-phase10-practice-source-hidden{display:none!important}')&&css.includes('v205-practice-entry')],
  ['mobile mode select uses compact two-column STANDARD cards',css.includes('@media(max-width:700px)')&&css.includes('grid-template-columns:repeat(2,minmax(0,1fr))')&&css.includes('.home-screen .mode-grid-home .mode-desc{display:none}')],
  ['unlock cut-in contrast baseline is strengthened',css.includes('.v205-unlock-burst section')&&css.includes('text-shadow')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
