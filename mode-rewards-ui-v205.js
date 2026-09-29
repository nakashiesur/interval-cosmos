(() => {
  const modes={orbitText:'TEXT',orbitKeys:'KEYS',hyperText:'HD_TEXT',hyperKeys:'HD_KEYS',earLink:'EAR_LINK'};
  let rows=[],fetching=false,lastFetch=0,day='',queued=false;
  const receipts=new Map();
  const guest=()=>!window.IntervalCosmosCloud?.getCachedPlayer?.()||window.IntervalCosmosCloud.getCachedPlayer().is_guest;
  const today=()=>new Date().toLocaleDateString('en-CA',{timeZone:'Asia/Tokyo'});
  function label(row){const left=Math.max(0,Number(row.daily_limit||5)-Number(row.earned_count||0));return {left,text:`PT 残り ${left}/5${left===0?' · 本日終了':''}`};}
  async function refresh(force=false){
    if(guest()||fetching||(!force&&Date.now()-lastFetch<30000&&day===today()))return;
    fetching=true;
    try{const d=await window.IntervalCosmosProgressV205.fetchProgress();rows=d.mode_clear_rewards||[];day=today();lastFetch=Date.now();render();}catch{}finally{fetching=false;}
  }
  function render(){
    for(const card of document.querySelectorAll('.mode-card[data-mode]')){
      const row=day===today()&&!guest()?rows.find(r=>r.mode===modes[card.dataset.mode]):null;
      let badge=card.querySelector('.ic-mode-remaining');
      if(!row){badge?.remove();continue;}
      if(!badge){badge=document.createElement('small');badge.className='ic-mode-remaining';let seconds=card.querySelector('.mode-badge');if(!seconds){seconds=document.createElement('span');seconds.className='mode-badge';seconds.textContent='75 SEC + BONUS';card.append(seconds);}seconds.append(badge);}
      const l=label(row);if(badge.textContent!==l.text)badge.textContent=l.text;badge.classList.toggle('exhausted',l.left===0);
    }
    const hyper=document.querySelector('.mode-card[data-action="hyper"]');
    if(hyper){
      const values=day===today()&&!guest()?['HD_TEXT','HD_KEYS'].map(m=>rows.find(r=>r.mode===m)):[];
      let summary=hyper.querySelector('.ic-mode-remaining');
      if(values.length===2&&values.every(Boolean)){
        if(!summary){summary=document.createElement('small');summary.className='ic-mode-remaining';hyper.querySelector('.mode-badge')?.append(summary);}
        const text='PT '+values.map((r,i)=>`${i?'KEYS':'TEXT'} ${label(r).left}/5`).join(' · ');
        if(summary.textContent!==text)summary.textContent=text;
        summary.classList.toggle('exhausted',values.every(r=>label(r).left===0));
      }else summary?.remove();
    }
    const panel=document.querySelector('.result-panel');if(!panel)return;
    const receipt=receipts.get(panel.dataset.rewardEvent);
    const status=panel.dataset.rewardStatus;
    let box=panel.querySelector('.ic-mode-reward-result');
    if(!receipt&&status!=='queued'){box?.remove();return;}
    if(!box){box=document.createElement('aside');box.className='ic-mode-reward-result';box.setAttribute('aria-live','polite');panel.querySelector('.result-actions')?.before(box);}
    const message=!receipt?'オフライン保存済み・同期後にPTを確認':receipt.status==='earned'?'モードクリアPT獲得':receipt.status==='conditions_not_met'?'条件未達のためPTなし・回数は減りません':receipt.status==='daily_limit'?'本日の獲得上限です':'このプレイはPT対象外です';
    const html=`<strong>${receipt?`+${Number(receipt.points)||0} PT`:'同期待ち'}</strong><span>${message}</span>${receipt?.min_answers!=null?`<small>条件：${Number(receipt.min_answers)}問以上・正答率${Number(receipt.min_accuracy)}%以上</small><small class="${receipt.remaining===0?'exhausted':''}">このプレイ日の残り ${Number(receipt.remaining)}/5 回</small>`:''}`;
    if(box.innerHTML!==html)box.innerHTML=html;
    box.classList.toggle('presentation-busy',Boolean(document.querySelector('.rank-burst,.v205-publication-overlay,.v205-unlock-burst')));
  }
  window.addEventListener('ic-mode-reward-ready',async e=>{
    const id=e.detail?.client_event_id;if(!id)return;
    try{const {data,error}=await window.IntervalCosmosSupabaseSingleton.getClient().rpc('get_my_mode_reward_receipt',{p_client_event_id:id});if(error)throw error;receipts.set(id,data);render();await refresh(true);}catch{}
  });
  function schedule(){if(queued)return;queued=true;queueMicrotask(()=>{queued=false;render();if(document.querySelector('.mode-card'))refresh();});}
  new MutationObserver(schedule).observe(document.documentElement,{subtree:true,childList:true});
  window.addEventListener('interval-cosmos-sync',()=>refresh(true));window.addEventListener('online',()=>refresh(true));
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh(true);});
  setInterval(()=>{if(!document.hidden&&document.querySelector('.mode-card'))refresh();},60000);schedule();
})();
