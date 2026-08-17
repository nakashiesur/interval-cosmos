const fs = require('fs');
const vm = require('vm');
const path = require('path');

const app = { innerHTML: '', addEventListener(){} };
const overlayRoot = { append(){}, appendChild(){} };
const ctx2d = { setTransform(){}, fillRect(){}, beginPath(){}, arc(){}, fill(){}, fillStyle:'' };
const canvas = { style:{}, getContext(){ return ctx2d; } };
const classList = { toggle(){}, add(){}, remove(){} };
const document = {
  documentElement: { classList },
  querySelector(sel){
    if(sel==='#app') return app;
    if(sel==='#overlay-root') return overlayRoot;
    if(sel==='#starfield') return canvas;
    if(sel==='#resultScore') return null;
    return null;
  },
  querySelectorAll(){ return []; },
  createElement(){ return { style:{}, className:'', textContent:'', innerHTML:'', append(){}, remove(){}, click(){}, setAttribute(){}, addEventListener(){} }; },
};
const storage = new Map();
// Simulate a device carrying legacy preferences with obsolete preferences still present.
storage.set('intervalCosmos.settings.v2', JSON.stringify({
  sound:true, volume:.5, audioStyle:'both', autoPlay:true,
  labels:'symbol', reducedMotion:true, direction:'mixed'
}));
const localStorage = {
  getItem:k=>storage.has(k)?storage.get(k):null,
  setItem:(k,v)=>storage.set(k,String(v)),
  removeItem:k=>storage.delete(k)
};
const windowObj = {
  INTERVAL_COSMOS_CLOUD:{}, IntervalCosmosCloud:{configured:()=>false},
  addEventListener(){}, setTimeout(){return 0;}, clearTimeout(){},
  requestAnimationFrame(){return 0;}, cancelAnimationFrame(){},
  innerWidth:430, innerHeight:932, devicePixelRatio:1,
  localStorage,
};
const context = {
  console, document, window:windowObj, localStorage, navigator:{}, location:{protocol:'file:'},
  innerWidth:430, innerHeight:932, performance:{now:()=>1000},
  requestAnimationFrame:()=>0, cancelAnimationFrame(){},
  setTimeout:()=>0, clearTimeout(){}, confirm:()=>true,
  crypto:{randomUUID:()=> 'uuid'}, Blob, URL,
};
windowObj.document=document; windowObj.performance=context.performance; windowObj.crypto=context.crypto;
vm.createContext(context);
const code=fs.readFileSync(path.join(__dirname, '..', 'app.js'),'utf8');
vm.runInContext(code,context,{filename:'app.js'});
const val = expr => vm.runInContext(expr,context);

const out={};
out.splash=app.innerHTML;
val("state.screen='home'; render()"); out.home=app.innerHTML;
val("state.screen='practice'; render()"); out.practice=app.innerHTML;
val("state.screen='guide'; render()"); out.guide=app.innerHTML;
val("state.screen='interval-select'; render()"); out.intervalSelect=app.innerHTML;
val("state.modeId='orbitText'; state.game=gameTemplate(); state.question={id:'q',intervalKey:'M3',direction:'up',base:'C',target:'E',baseMidi:60,targetMidi:64}; state.screen='play'; state.phase='running'; state.answerLabelLang='jp'; render()"); out.playJP=app.innerHTML;
val("state.answerLabelLang='symbol'; render()"); out.playSymbol=app.innerHTML;
val("state.showSettings=true; render()"); out.settings=app.innerHTML;
val("state.showSettings=false; state.showRecords=true; state.screen='home'; render()"); out.ranking=app.innerHTML;

// Result with local-only/offline ranking state must still display a non-zero score.
val("state.showRecords=false; state.modeId='orbitText'; state.game=gameTemplate(); state.game.score=1234; state.game.total=4; state.game.correct=3; state.game.answers.M3.seen=2; state.game.answers.M3.correct=1; state.game.answers.m2.seen=2; state.game.answers.m2.correct=2; state.rankingSubmit={status:'unavailable'}; state.screen='result'; render()");
out.result=app.innerHTML;

const assertions = [
  ['splash logo', out.splash.includes('nakashima-logo.png')],
  ['splash version v2.0.4', out.splash.includes('ver.2.0.4')],
  ['no final edition', ![out.splash,out.home,out.practice,out.guide,out.playJP,out.settings,out.ranking,out.result].join('').match(/final edition/i)],
  ['home subtitle', out.home.includes('プレイするモードを選択。')],
  ['practice first', out.home.indexOf('PRACTICE MODE') < out.home.indexOf('STANDARD')],
  ['practice beginner mark', out.home.includes('🔰 PRACTICE')],
  ['no top trophy button', !/top-actions[^]*?🏆/.test(out.home.split('</div></div>')[0] || '')],
  ['no player chip on home', !out.home.includes('player-chip')],
  ['natural weak-practice label', out.home.includes('苦手を重点練習')],
  ['expert zone retained', out.home.includes('EXPERT ZONE') && out.home.includes('ULTRA HARD')],
  ['practice title not duplicated mode', out.practice.includes('PRACTICE MODE') && out.practice.includes('TRAINING MENU')],
  ['guide entry exists', out.practice.includes('はじめての音程ガイド') && out.practice.includes('🔰')],
  ['guide content exists', out.guide.includes('音程の導き出し方') && out.guide.includes('まず「何度」かを数える') && out.guide.includes('13音程 早見表')],
  ['core7 label', out.intervalSelect.includes('CORE 7')],
  ['answer rows 7', (out.playJP.match(/class="answer-row cols-/g)||[]).length===7],
  ['answer buttons 13', (out.playJP.match(/data-answer=/g)||[]).length===13],
  ['jp labels only when jp', out.playJP.includes('<span class="answer-main">完全1度</span>') && !out.playJP.includes('<span class="answer-main">P1</span>')],
  ['symbol labels only when symbol', out.playSymbol.includes('<span class="answer-main">P1</span>') && !out.playSymbol.includes('<span class="answer-main">完全1度</span>')],
  ['hold end exists', out.playJP.includes('data-action="hold-end"') && out.playJP.includes('hold-fill')],
  ['no ascending-only UI copy', !out.playJP.includes('上行のみ') && !out.playJP.includes('全問、上行形') && !out.playJP.includes('ASCENDING ONLY')],
  ['standard replaces orbit', out.playJP.includes('STANDARD / TEXT') && !out.playJP.includes('ORBIT / TEXT')],
  ['settings removes answer labels', !out.settings.includes('Answer labels')],
  ['settings removes reduced motion', !out.settings.includes('Reduced motion')],
  ['playback Japanese help', out.settings.includes('基準音 → 到達音の順に') && out.settings.includes('2音を同時に鳴らします') && out.settings.includes('MELODICとHARMONICを続けて再生')],
  ['both order selector visible', out.settings.includes('BOTHの再生順') && out.settings.includes('HARMONIC → MELODIC') && out.settings.includes('MELODIC → HARMONIC')],
  ['both order upgrade default', val("state.settings.bothOrder") === 'harmonicFirst'],
  ['settings gear normal-size class', out.home.includes('settings-gear-btn') && out.practice.includes('settings-gear-btn')],
  ['obsolete settings removed from state', !val("Object.prototype.hasOwnProperty.call(state.settings,'labels')") && !val("Object.prototype.hasOwnProperty.call(state.settings,'reducedMotion')") && !val("Object.prototype.hasOwnProperty.call(state.settings,'direction')")],
  ['settings version v2.0.4', out.settings.includes('ver.2.0.4')],
  ['online ranking UI retained', out.ranking.includes('ONLINE RANKING') && out.ranking.includes('月間') && out.ranking.includes('殿堂入り')],
  ['offline result score visible', out.result.includes('>1,234</div>')],
  ['missed interval analysis visible', out.result.includes('MISSED INTERVALS') && out.result.includes('短3度') && out.result.includes('誤答 50%')],
];

const directions = val("state.modeId='orbitText'; Array.from({length:100},()=>buildQuestion()).map(q=>[q.direction,q.targetMidi>=q.baseMidi])");
assertions.push(['all questions ascending', directions.every(x=>x[0]==='up'&&x[1])]);
assertions.push(['long hold returns home', code.includes("if (p >= 1) { cancelHold(); goHome(); return; }")]);
assertions.push(['core7 exact set', code.includes("new Set(['m3','M3','P4','TT','P5','m6','M6'])")]);
assertions.push(['label language randomized on new question', code.includes("state.answerLabelLang = Math.random() < 0.5 ? 'jp' : 'symbol';")]);
assertions.push(['both playback supports both orders', code.includes("state.settings.bothOrder === 'melodicFirst'") && code.includes('this.playMelodic(question, now)') && code.includes('this.playHarmonic(question, now)')]);

let fail=0;
for(const [name,ok] of assertions){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
