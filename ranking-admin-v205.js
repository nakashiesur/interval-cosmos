(() => {
  const allowed=()=>Boolean(window.IntervalCosmosCloud?.getCachedPlayer?.()?.is_admin&&!window.IntervalCosmosAssignmentAdminPolicyV205?.isStudentView());
  let hold=null,dialog=null;
  function cancel(){if(hold)clearTimeout(hold.timer);hold=null;}
  function confirmRemoval(button){
    if(!allowed()||!button.isConnected||dialog)return;
    const entry=JSON.parse(button.dataset.rankDelete);
    dialog=document.createElement('dialog');dialog.className='ic-action-dialog';
    dialog.innerHTML='<h2>ランキングの記録を削除</h2><p data-target></p><p>このモード・期間のランキングから除外します。学習履歴は残り、新しいプレイは再び登録できます。削除前の記録は再掲載されません。</p><label>確認のため <b>Delete</b> と入力<input autocomplete="off" aria-label="Deleteと入力"></label><p role="status"></p><div><button data-cancel>キャンセル</button><button data-delete disabled>削除する</button></div>';
    dialog.querySelector('[data-target]').textContent=`${entry.name} / ${entry.mode} / ${entry.period==='ALL'?'殿堂':entry.period} / ${entry.score} PT`;
    document.body.append(dialog);dialog.showModal();
    const input=dialog.querySelector('input'),submit=dialog.querySelector('[data-delete]');
    input.oninput=()=>submit.disabled=input.value!=='Delete';
    dialog.onclose=()=>{dialog.remove();dialog=null;};
    dialog.querySelector('[data-cancel]').onclick=()=>dialog.close();
    submit.onclick=async()=>{
      if(!allowed()||input.value!=='Delete')return;
      submit.disabled=true;
      try{
        const c=window.IntervalCosmosSupabaseSingleton.getClient();
        const {error}=await c.rpc('admin_delete_ranking_entry',{p_player_id:entry.id,p_mode:entry.mode,p_period:entry.period,p_expected_score:entry.score,p_expected_updated_at:entry.updated,p_confirmation:input.value});
        if(error)throw error;
        dialog?.close();window.dispatchEvent(new Event('interval-cosmos-ranking-changed'));
      }catch(e){if(dialog){dialog.querySelector('[role=status]').textContent=e.message||'削除できませんでした。';submit.disabled=false;}}
    };
    input.focus();
  }
  function start(button,x=0,y=0){cancel();if(!allowed())return;hold={x,y,timer:setTimeout(()=>{hold=null;confirmRemoval(button);},800)};}
  window.addEventListener('pointerdown',e=>{const b=e.target.closest?.('[data-rank-delete]');if(b&&e.button===0)start(b,e.clientX,e.clientY);},true);
  window.addEventListener('pointermove',e=>{if(hold&&Math.hypot(e.clientX-hold.x,e.clientY-hold.y)>10)cancel();},true);
  ['pointerup','pointercancel','blur','scroll'].forEach(type=>window.addEventListener(type,cancel,true));
  window.addEventListener('keydown',e=>{const b=e.target.closest?.('[data-rank-delete]');if(b&&['Enter',' '].includes(e.key)){e.preventDefault();if(!e.repeat)start(b);}},true);
  window.addEventListener('keyup',cancel,true);
  window.addEventListener('click',e=>{if(e.target.closest?.('[data-rank-delete]')){e.preventDefault();e.stopImmediatePropagation();}},true);
  window.addEventListener('contextmenu',e=>{if(e.target.closest?.('[data-rank-delete]'))e.preventDefault();},true);
})();
