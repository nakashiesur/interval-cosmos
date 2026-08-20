from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_one(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


js_path = ROOT / "phase6-assignments-v205.js"
js = js_path.read_text(encoding="utf-8")

js = replace_one(
    js,
    "  function accidental(a){return a===1?'♯':a===-1?'♭':''}\n  function realize(base,acc,iv){",
    "  function accidental(a){return a===1?'♯':a===-1?'♭':''}\n"
    "  const octaveNumber=midi=>Math.floor(Number(midi||0)/12)-1;\n"
    "  function displayQuestionNote(q,side){\n"
    "    const note=side==='base'?q.base:q.target,midi=side==='base'?q.baseMidi:q.targetMidi;\n"
    "    const register=q.intervalKey==='P1'||q.intervalKey==='P8'?`<sub class=\"v205-a-note-register\">${octaveNumber(midi)}</sub>`:'';\n"
    "    return `<span class=\"v205-a-note-name\">${esc(note)}</span>${register}`;\n"
    "  }\n"
    "  function realize(base,acc,iv){",
    "insert register-aware note renderer",
)

js = replace_one(
    js,
    "    game={def,keys,score:0,combo:0,maxCombo:0,total:0,correct:0,response:[],previous:null,locked:true,reveal:false,flash:null,feedback:'',finished:false,labelSymbol:Math.random()<.5,wallDeadline:Date.now()+def.duration*1000,question:null,questionAt:0};",
    "    game={def,keys,score:0,combo:0,maxCombo:0,total:0,correct:0,response:[],previous:null,locked:true,reveal:false,flash:null,feedback:'',feedbackType:null,chosenKey:null,finished:false,labelSymbol:Math.random()<.5,wallDeadline:Date.now()+def.duration*1000,question:null,questionAt:0};",
    "extend assignment game feedback state",
)

old_render = """  function answerGrid(){const groups=[['P1'],['m2','M2'],['m3','M3'],['P4','TT','P5'],['m6','M6'],['m7','M7'],['P8']],symbol=game.labelSymbol;return `<div class=\"answer-rows\">${groups.map(g=>`<div class=\"answer-row cols-${g.length}\">${g.map(k=>`<button class=\"answer-btn answer-btn-large ${game.flash?.key===k?game.flash.type:''}\" data-a-answer=\"${k}\" ${game.locked?'disabled':''}><span class=\"answer-main\">${symbol?k:IV[k].jp}</span></button>`).join('')}</div>`).join('')}</div>`}\n  function renderGame(){\n    if(!game)return;const remain=Math.max(0,(game.wallDeadline-Date.now())/1000),q=game.question,def=game.def;\n    const main=def.view==='keys'?keyboard(q):def.view==='ear'?`<div class=\"ear-prompt\"><span class=\"ear-wave\"><i></i><i></i><i></i><i></i><i></i></span><strong>LISTEN</strong><small>音だけで判定</small></div>${game.reveal?`<div class=\"note-question note-pair\"><span>${esc(q.base)}</span><span class=\"note-gap\"></span><span>${esc(q.target)}</span></div>`:''}`:`<div class=\"note-question note-pair\"><span>${esc(q.base)}</span><span class=\"note-gap\"></span><span>${esc(q.target)}</span></div>`;\n    overlay().innerHTML=`<section class=\"v205-a-game ${def.hyper?'hyper':''}\">\n      <header class=\"play-hud\"><div class=\"hud-left\"><span class=\"mode-mini\">ASSIGNMENT</span><small>${esc(currentAssignment.title)}</small></div><div class=\"hud-center\"><div class=\"v205-a-timer\">${Math.ceil(remain)}</div></div><div class=\"hud-right\">${def.hyper?`<div class=\"metric combo\"><span class=\"metric-label\">COMBO</span><span class=\"metric-value\">${game.combo}</span></div>`:''}<div class=\"metric\"><span class=\"metric-label\">SCORE</span><span class=\"metric-value\">${fmt(game.score)}</span></div></div></header>\n      <section class=\"question-zone\"><div class=\"question-card glass\"><p class=\"question-label\">${def.view==='ear'?'AUDIO IDENTIFICATION':'INTERVAL IDENTIFICATION'}</p>${main}<div class=\"sound-controls\"><button class=\"secondary-btn\" data-a-replay>▶ REPLAY</button></div></div></section>\n      <section class=\"answer-area\">${answerGrid()}</section><footer class=\"v205-a-game-foot\"><div>${game.feedback||`${esc(def.label)} ・ ${esc(intervalText(currentAssignment))}`}</div><button class=\"secondary-btn danger\" data-a-abort>課題を中断</button></footer>\n    </section>`;\n  }\n"""

new_render = """  function answerGrid(){\n    const groups=[['P1'],['m2','M2'],['m3','M3'],['P4','TT','P5'],['m6','M6'],['m7','M7'],['P8']],symbol=game.labelSymbol;\n    return `<div class=\"answer-rows\">${groups.map(g=>`<div class=\"answer-row cols-${g.length}\">${g.map(k=>{\n      let flash='';\n      if(game.feedbackType){\n        if(k===game.question?.intervalKey)flash='correct';\n        else if(game.feedbackType==='wrong'&&k===game.chosenKey)flash='wrong';\n      }\n      return `<button class=\"answer-btn answer-btn-large ${flash}\" data-a-answer=\"${k}\" ${game.locked?'disabled':''}><span class=\"answer-main\">${symbol?k:IV[k].jp}</span></button>`;\n    }).join('')}</div>`).join('')}</div>`;\n  }\n  function renderGame(){\n    if(!game)return;const remain=Math.max(0,(game.wallDeadline-Date.now())/1000),q=game.question,def=game.def;\n    const notePair=`<div class=\"note-question note-pair\"><span>${displayQuestionNote(q,'base')}</span><span class=\"note-gap\"></span><span>${displayQuestionNote(q,'target')}</span></div>`;\n    const main=def.view==='keys'?keyboard(q):def.view==='ear'?`<div class=\"ear-prompt\"><span class=\"ear-wave\"><i></i><i></i><i></i><i></i><i></i></span><strong>LISTEN</strong><small>音だけで判定</small></div>${game.reveal?notePair:''}`:notePair;\n    const feedbackBanner=game.feedbackType?`<div class=\"v205-a-feedback-banner ${game.feedbackType}\"><span>${game.feedbackType==='correct'?'✓':'✕'}</span><div><strong>${game.feedbackType==='correct'?'CORRECT':'WRONG'}</strong><small>${game.feedbackType==='correct'?IV[q.intervalKey].jp:`正解：${IV[q.intervalKey].jp}`}</small></div></div>`:'';\n    overlay().innerHTML=`<section class=\"v205-a-game ${def.hyper?'hyper':''} ${game.feedbackType?`feedback-${game.feedbackType}`:''}\">\n      <header class=\"play-hud\"><div class=\"hud-left\"><span class=\"mode-mini\">ASSIGNMENT</span><small>${esc(currentAssignment.title)}</small></div><div class=\"hud-center\"><div class=\"v205-a-timer\">${Math.ceil(remain)}</div></div><div class=\"hud-right\">${def.hyper?`<div class=\"metric combo\"><span class=\"metric-label\">COMBO</span><span class=\"metric-value\">${game.combo}</span></div>`:''}<div class=\"metric\"><span class=\"metric-label\">SCORE</span><span class=\"metric-value\">${fmt(game.score)}</span></div></div></header>\n      <section class=\"question-zone\"><div class=\"question-card glass\"><p class=\"question-label\">${def.view==='ear'?'AUDIO IDENTIFICATION':'INTERVAL IDENTIFICATION'}</p>${main}${feedbackBanner}<div class=\"sound-controls\"><button class=\"secondary-btn\" data-a-replay>▶ REPLAY</button></div></div></section>\n      <section class=\"answer-area\">${answerGrid()}</section><footer class=\"v205-a-game-foot\"><div>${game.feedback||`${esc(def.label)} ・ ${esc(intervalText(currentAssignment))}`}</div><button class=\"secondary-btn danger\" data-a-abort>課題を中断</button></footer>\n    </section>`;\n  }\n"""
js = replace_one(js, old_render, new_render, "replace assignment question/feedback renderer")

old_answer = """  function answer(k){\n    if(!game||game.finished||game.locked||!game.question)return;const q=game.question,ms=Math.max(80,performance.now()-game.questionAt),sec=ms/1000,ok=k===q.intervalKey,delta=calcPoints(sec,ok,ok?game.combo:0);\n    game.total++;if(ok)game.correct++;game.combo=ok?game.combo+1:0;game.maxCombo=Math.max(game.maxCombo,game.combo);game.response.push(sec);game.score=Math.max(-9999,game.score+delta);updateMastery(q.intervalKey,k,ok,ms);if(game.def.hyper&&ok&&game.combo>0&&game.combo%10===0)game.wallDeadline+=3000;\n    game.flash={key:k,type:ok?'correct':'wrong'};game.feedback=ok?`<strong class=\"ok\">CORRECT</strong>　${IV[q.intervalKey].jp}　${sec.toFixed(2)}s`:`<strong class=\"ng\">${IV[k].jp}</strong> ではなく <strong class=\"ok\">${IV[q.intervalKey].jp}</strong>`;game.locked=true;game.reveal=true;renderGame();if(!ok)audio.play(q).catch(()=>{});\n    setTimeout(()=>{if(!game||game.finished)return;game.previous=q.intervalKey;game.question=makeQuestion(game.keys,game.previous);game.questionAt=performance.now();game.locked=false;game.reveal=false;game.flash=null;game.labelSymbol=Math.random()<.5;renderGame();audio.play(game.question).catch(()=>{})},ok?360:780);\n  }\n"""

new_answer = """  function answer(k){\n    if(!game||game.finished||game.locked||!game.question)return;const q=game.question,ms=Math.max(80,performance.now()-game.questionAt),sec=ms/1000,ok=k===q.intervalKey,delta=calcPoints(sec,ok,ok?game.combo:0);\n    game.total++;if(ok)game.correct++;game.combo=ok?game.combo+1:0;game.maxCombo=Math.max(game.maxCombo,game.combo);game.response.push(sec);game.score=Math.max(-9999,game.score+delta);updateMastery(q.intervalKey,k,ok,ms);if(game.def.hyper&&ok&&game.combo>0&&game.combo%10===0)game.wallDeadline+=3000;\n    game.flash={key:k,type:ok?'correct':'wrong'};game.chosenKey=k;game.feedbackType=ok?'correct':'wrong';game.feedback=ok?`<strong class=\"ok\">✓ CORRECT</strong>　${IV[q.intervalKey].jp}　${sec.toFixed(2)}s`:`<strong class=\"ng\">✕ ${IV[k].jp}</strong>　→　正解 <strong class=\"ok\">${IV[q.intervalKey].jp}</strong>`;game.locked=true;game.reveal=true;renderGame();if(!ok)audio.play(q).catch(()=>{});\n    setTimeout(()=>{if(!game||game.finished)return;game.previous=q.intervalKey;game.question=makeQuestion(game.keys,game.previous);game.questionAt=performance.now();game.locked=false;game.reveal=false;game.flash=null;game.feedback='';game.feedbackType=null;game.chosenKey=null;game.labelSymbol=Math.random()<.5;renderGame();audio.play(game.question).catch(()=>{})},ok?620:1050);\n  }\n"""
js = replace_one(js, old_answer, new_answer, "replace assignment answer feedback")
js_path.write_text(js, encoding="utf-8")

css_path = ROOT / "phase6-game-layout-v205.css"
css = css_path.read_text(encoding="utf-8")
marker = "/* v2.0.5 assignment answer clarity hotfix */"
if marker not in css:
    css += """

/* v2.0.5 assignment answer clarity hotfix */
.v205-a-game .note-question .v205-a-note-register{font-size:.28em;line-height:1;vertical-align:sub;margin-left:.06em;color:#7ee8ff;font-weight:800;text-shadow:0 0 14px rgba(80,220,255,.38)}
.v205-a-game .question-card{position:relative;transition:border-color .16s ease,box-shadow .16s ease,background .16s ease}
.v205-a-game.feedback-correct .question-card{border-color:rgba(91,238,184,.72)!important;box-shadow:0 0 0 1px rgba(91,238,184,.22),0 0 34px rgba(55,221,167,.16),inset 0 0 42px rgba(55,221,167,.055)!important}
.v205-a-game.feedback-wrong .question-card{border-color:rgba(255,102,148,.72)!important;box-shadow:0 0 0 1px rgba(255,102,148,.2),0 0 34px rgba(255,76,136,.15),inset 0 0 42px rgba(255,76,136,.05)!important}
.v205-a-feedback-banner{position:absolute;left:50%;bottom:18px;transform:translateX(-50%);display:flex;align-items:center;gap:10px;min-width:190px;padding:10px 16px;border-radius:999px;backdrop-filter:blur(14px);z-index:2;pointer-events:none;animation:v205-a-feedback-pop .2s ease-out both}
.v205-a-feedback-banner>span{width:28px;height:28px;border-radius:50%;display:grid;place-items:center;font-size:18px;font-weight:950}.v205-a-feedback-banner>div{display:grid;gap:1px}.v205-a-feedback-banner strong{font-size:13px;letter-spacing:.14em}.v205-a-feedback-banner small{font-size:10px;color:#d7e2f4}
.v205-a-feedback-banner.correct{color:#71f1c2;border:1px solid rgba(91,238,184,.45);background:rgba(17,68,57,.82)}.v205-a-feedback-banner.correct>span{background:rgba(91,238,184,.16);border:1px solid rgba(91,238,184,.46)}
.v205-a-feedback-banner.wrong{color:#ff8eb3;border:1px solid rgba(255,102,148,.46);background:rgba(76,23,45,.84)}.v205-a-feedback-banner.wrong>span{background:rgba(255,102,148,.14);border:1px solid rgba(255,102,148,.45)}
.v205-a-game .answer-btn.correct{border-color:rgba(91,238,184,.85)!important;background:linear-gradient(135deg,rgba(32,113,91,.58),rgba(34,70,91,.48))!important;color:#ecfff8!important;box-shadow:0 0 0 2px rgba(91,238,184,.18),0 0 24px rgba(55,221,167,.22)!important;transform:translateY(-1px)}
.v205-a-game .answer-btn.wrong{border-color:rgba(255,102,148,.88)!important;background:linear-gradient(135deg,rgba(119,35,68,.58),rgba(76,28,65,.5))!important;color:#fff0f5!important;box-shadow:0 0 0 2px rgba(255,102,148,.17),0 0 24px rgba(255,76,136,.2)!important;animation:v205-a-wrong-shake .24s ease-out both}
@keyframes v205-a-feedback-pop{from{opacity:0;transform:translate(-50%,8px) scale(.96)}to{opacity:1;transform:translate(-50%,0) scale(1)}}
@keyframes v205-a-wrong-shake{0%,100%{transform:translateX(0)}30%{transform:translateX(-4px)}65%{transform:translateX(4px)}}
@media(max-width:720px){.v205-a-feedback-banner{bottom:12px;min-width:165px;padding:8px 12px}.v205-a-feedback-banner>span{width:24px;height:24px;font-size:15px}.v205-a-feedback-banner strong{font-size:11px}.v205-a-feedback-banner small{font-size:9px}}
"""
css_path.write_text(css, encoding="utf-8")

index_path = ROOT / "index.html"
index = index_path.read_text(encoding="utf-8")
index = index.replace('phase6-assignments-v205.js?v=alpha5.1', 'phase6-assignments-v205.js?v=alpha5.4')
index = index.replace('phase6-game-layout-v205.css?v=alpha5.3', 'phase6-game-layout-v205.css?v=alpha5.4')
index_path.write_text(index, encoding="utf-8")

sw_path = ROOT / "sw.js"
sw = sw_path.read_text(encoding="utf-8")
sw = sw.replace("const CACHE = 'interval-cosmos-v2-0-5-alpha9-0';", "const CACHE = 'interval-cosmos-v2-0-5-alpha9-1';")
sw_path.write_text(sw, encoding="utf-8")

print('patched assignment P1/P8 register clarity and answer feedback')
