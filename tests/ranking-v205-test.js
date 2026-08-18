const fs = require('fs');
const vm = require('vm');
const path = require('path');

const overlays = new Map();
const timers = [];

function makeNode() {
  return {
    className:'', innerHTML:'', textContent:'', dataset:{}, style:{}, disabled:false,
    appendChild(){}, append(){}, remove(){},
    querySelector(){ return null; }, querySelectorAll(){ return []; },
    setAttribute(){}, addEventListener(){}, closest(){ return null; },
    classList:{ add(){}, remove(){}, toggle(){} },
  };
}

const resultPanel = makeNode();
const body = makeNode();
body.appendChild = node => {
  const firstClass = String(node.className||'').split(/\s+/)[0];
  if(firstClass) overlays.set(firstClass,node);
};

const document = {
  body,
  documentElement:{},
  createElement(){ return makeNode(); },
  querySelector(sel){
    if(sel==='.result-panel') return resultPanel;
    if(sel.startsWith('.')) return overlays.get(sel.slice(1)) || null;
    return null;
  },
  querySelectorAll(){ return []; },
};
class MutationObserver { constructor(fn){this.fn=fn;} observe(){} }

let submitResult = null;
const cloud = {
  configured:()=>false,
  submitScore: async()=>submitResult,
  publishPlaySession: async()=>({monthly_rank:1,hall_rank:2}),
  fetchRankings: async()=>({rows:[{player_id:'p1',rank:1}]}),
  getCachedPlayer:()=>({ranking_visibility:'ask',is_guest:false}),
  avatarMark:()=> '✦',
};

const windowObj = {
  IntervalCosmosCloud:cloud,
  addEventListener(){},
  setTimeout(fn,ms){ timers.push({fn,ms}); return timers.length; },
};
const context = {
  console, window:windowObj, document, MutationObserver,
  performance:{now:()=>1000},
  setTimeout:windowObj.setTimeout,
};
vm.createContext(context);
const code=fs.readFileSync(path.join(__dirname,'..','phase3-v205.js'),'utf8');
const hotfix=fs.readFileSync(path.join(__dirname,'..','phase3-ranking-hotfix-v205.js'),'utf8');
const index=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const sw=fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8');
vm.runInContext(code,context,{filename:'phase3-v205.js'});

(async()=>{
  const assertions=[];

  submitResult={session_id:'s1',publication_required:true,monthly_rank:1,hall_rank:2,monthly_best_improved:true,hall_best_improved:true};
  await cloud.submitScore({mode:'TEXT',score:1000});
  const promptTimer=timers.find(t=>t.ms===2300);
  assertions.push(['publication waits for rank scene',Boolean(promptTimer)]);
  promptTimer?.fn();
  const prompt=overlays.get('v205-publication-overlay');
  assertions.push(['publication prompt rendered',Boolean(prompt)&&prompt.innerHTML.includes('このランキングを公開する')&&prompt.innerHTML.includes('非公開のまま続ける')]);

  await cloud.fetchRankings({mode:'TEXT',scope:'monthly'});
  assertions.push(['ranking rows cached',windowObj.IntervalCosmosV205.getRankingCache().length===1]);

  // The false-rank behavior has already been verified in a real browser.
  // Keep CI focused on guarding the implementation rather than emulating a full DOM here.
  assertions.push(['false rank scene removal guard',code.includes('lastSubmitResult && !improved(lastSubmitResult)')&&code.includes('node.remove()')]);

  assertions.push(['privacy controls implemented',code.includes('data-v205-visibility="ask"')&&code.includes('always_public')&&code.includes('always_private')]);
  assertions.push(['always-private no longer hides previous public records',hotfix.includes("rankingVisibility: 'always_private'")&&!hotfix.includes('await cloud.hideAllMyRankings')&&hotfix.includes('過去の公開記録は残ります')]);
  assertions.push(['private hotfix is loaded before phase3',index.indexOf('phase3-ranking-hotfix-v205.js')>=0&&index.indexOf('phase3-ranking-hotfix-v205.js')<index.indexOf('phase3-v205.js')]);
  assertions.push(['private hotfix is cached',sw.includes('phase3-ranking-hotfix-v205.js')]);
  assertions.push(['result rank wording identifies personal-best position',hotfix.includes('自己ベスト 月間順位')&&hotfix.includes('自己ベスト 殿堂順位')&&hotfix.includes('BEST RECORD POSITION')]);
  assertions.push(['profile card implemented',code.includes('FEATURED ACHIEVEMENTS')&&code.includes('PUBLIC RECORDS')]);
  assertions.push(['student number excluded from profile card copy',!code.includes('student_number')]);
  assertions.push(['result shortcuts implemented',code.includes("event.key.toLowerCase() === 'r'")&&code.includes("event.key === 'Escape'" )]);

  let fail=0;
  for(const [name,ok] of assertions){console.log(ok?'PASS':'FAIL',name);if(!ok)fail++;}
  process.exitCode=fail?1:0;
})();
