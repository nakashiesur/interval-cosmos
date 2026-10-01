(() => {
  const VERSION='2.0.5';
  const root=new URL('./',document.currentScript.src);
  let checking=false, updateDialog=null;
  function showUpdate(){
    if(updateDialog)return;
    updateDialog=document.createElement('dialog');updateDialog.className='ic-action-dialog';
    updateDialog.setAttribute('aria-label','最新版への更新');
    updateDialog.innerHTML='<h2>アップデートがあります</h2><p>最新版を読み込んで続けてください。アカウントと保存済みの記録は引き継がれます。</p><button>更新する</button><p role="status"></p>';
    updateDialog.addEventListener('cancel',e=>e.preventDefault());
    document.body.append(updateDialog);updateDialog.showModal();
    updateDialog.querySelector('button').onclick=async()=>{
      const button=updateDialog.querySelector('button');button.disabled=true;
      try {
        if(navigator.onLine===false)throw Error('オンラインに戻してから更新してください。');
        const registration=await navigator.serviceWorker?.getRegistration();
        if(registration){
          await registration.update();
          const worker=registration.installing||registration.waiting;
          if(worker&&worker.state!=='activated')await new Promise((resolve,reject)=>{
            const timer=setTimeout(()=>reject(Error('更新の読み込みに時間がかかっています。もう一度お試しください。')),20000);
            const changed=()=>{if(worker.state==='activated'){clearTimeout(timer);resolve();}else if(worker.state==='redundant'){clearTimeout(timer);reject(Error('更新を読み込めませんでした。再試行してください。'));}};
            worker.addEventListener('statechange',changed);changed();
          });
        }
        location.reload();
      } catch(e){updateDialog.querySelector('[role=status]').textContent=e.message;button.disabled=false;}
    };
  }
  async function check(){
    if(checking||updateDialog||document.hidden||navigator.onLine===false)return;
    checking=true;
    const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),7000);
    try{
      const response=await fetch(new URL('release.json',root),{cache:'no-store',signal:controller.signal});
      if(response.ok){const data=await response.json();if(typeof data.version==='string'&&data.version!==VERSION)showUpdate();}
    }catch(_){}finally{clearTimeout(timer);checking=false;}
  }
  ['online','pageshow','interval-cosmos-sync'].forEach(type=>window.addEventListener(type,check));
  document.addEventListener('visibilitychange',check);
  setInterval(check,60000);check();
})();
