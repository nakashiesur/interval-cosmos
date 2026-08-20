const fs=require('fs');
const path=require('path');

const css=fs.readFileSync(path.join(__dirname,'..','phase6-game-layout-v205.css'),'utf8');
const js=fs.readFileSync(path.join(__dirname,'..','phase6-assignments-v205.js'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');

const tests=[
  ['layout stylesheet loaded',index.includes('phase6-game-layout-v205.css?v=alpha5.4')],
  ['assignment runtime cache-busted',index.includes('phase6-assignments-v205.js?v=alpha5.4')],
  ['layout stylesheet cached',sw.includes("'./phase6-game-layout-v205.css'" )],
  ['game-only overlay scope',css.includes('.v205-assignment-overlay:has(> .v205-a-game)')],
  ['normal play selectors are not globally overridden',!/(^|\n)\.play-shell\s*\{/.test(css)&&!/(^|\n)\.play-screen\s*\{/.test(css)],
  ['assignment game aligned to normal width',css.includes('width:min(100%,920px)')],
  ['assignment game uses flex column rhythm',css.includes('display:flex')&&css.includes('flex-direction:column')],
  ['question sizing has desktop alignment',css.includes('min-height:205px')&&css.includes('min-height:195px')],
  ['answer height is viewport responsive',css.includes('height:clamp(56px,7.1dvh,86px)')],
  ['mobile layout is explicitly handled',css.includes('@media (max-width:620px)')&&css.includes('height:clamp(48px,6.4dvh,66px)')],
  ['short viewport layout is explicitly handled',css.includes('@media (max-height:720px)')],
  ['hyper assignment styling remains assignment-scoped',css.includes('.v205-assignment-overlay:has(> .v205-a-game.hyper)')],
  ['assignment footer remains compact',css.includes('.v205-a-game-foot')&&css.includes('grid-template-columns:minmax(0,1fr) auto')],
  ['P1/P8 questions expose octave register',js.includes("q.intervalKey==='P1'||q.intervalKey==='P8'")&&js.includes('v205-a-note-register')&&js.includes('displayQuestionNote')],
  ['answer feedback distinguishes correct and wrong',js.includes("game.feedbackType=ok?'correct':'wrong'")&&js.includes("feedback-${game.feedbackType}")&&js.includes('v205-a-feedback-banner')],
  ['wrong answer highlights chosen and correct answers separately',js.includes("game.feedbackType==='wrong'&&k===game.chosenKey")&&js.includes("k===game.question?.intervalKey")],
  ['feedback remains visible long enough to read',js.includes('},ok?620:1050)')],
  ['feedback styling has strong green/red states',css.includes('.v205-a-game.feedback-correct .question-card')&&css.includes('.v205-a-game.feedback-wrong .question-card')&&css.includes('.v205-a-game .answer-btn.correct')&&css.includes('.v205-a-game .answer-btn.wrong')],
];

let fail=0;
for(const [name,ok] of tests){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
process.exitCode=fail?1:0;
