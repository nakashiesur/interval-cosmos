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
  ['home exposes dedicated MY COSMOS route',js.includes('v205-home-command-deck')&&js.includes('data-v205-cosmos-open')&&js.includes('PROFILE & GROWTH')],
  ['home exposes ranking and settings beside MY COSMOS',js.includes('data-action="records"')&&js.includes('data-action="settings"')],
  ['legacy MY COSMOS settings source stays mounted but hidden',js.includes('v205-settings-legacy-sources')&&js.includes('v205-cosmos-setting')&&css.includes('.v205-settings-legacy-sources{display:none!important}')],
  ['settings are divided into four master categories',['game','controls','ranking','account'].every(id=>js.includes(id))&&js.includes('GAME & AUDIO')&&js.includes('RANKING & PRIVACY')&&js.includes('ACCOUNT & DEVICE')],
  ['settings selected category is retained across rerenders',js.includes("let settingsCategory = 'game'")&&js.includes('getSettingsCategory')],
  ['injected PC and recovery settings have explicit category rules',js.includes('v205-pc-settings-entry')&&js.includes('v205-recovery-setting')],
  ['mobile home vertical rhythm has Phase 10 overrides',css.includes('@media(max-width:700px)')&&css.includes('.home-screen .mode-card.practice-top')],
  ['unlock cut-in contrast baseline is strengthened',css.includes('.v205-unlock-burst section')&&css.includes('text-shadow')],
];
let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
