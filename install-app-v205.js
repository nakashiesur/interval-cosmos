(() => {
  let deferred=null;
  const installed=()=>matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;
  window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();deferred=event;});
  window.addEventListener('appinstalled',()=>{deferred=null;render();});
  function instructions(){
    const ios=/iPad|iPhone|iPod/.test(navigator.userAgent)||(/Macintosh/.test(navigator.userAgent)&&navigator.maxTouchPoints>1);
    if(ios)return 'Safariの共有ボタン（□に↑）から「ホーム画面に追加」を選び、「追加」を押してください。「Webアプリとして開く」が表示される場合はONにします。';
    if(/Android/.test(navigator.userAgent))return 'Chromeのメニュー（︙）から「アプリをインストール」または「ホーム画面に追加」を選んでください。表示されない場合はChromeでこのサイトを開いてください。';
    return 'Chrome／Edgeではアドレスバーのインストールアイコン、またはメニューの「アプリをインストール」を選んでください。MacのSafariでは「ファイル」→「Dockに追加」を使用できます。対応していないブラウザではブックマークをご利用ください。';
  }
  async function install(){
    if(installed())return;
    if(deferred){const prompt=deferred;deferred=null;try{await prompt.prompt();const choice=await prompt.userChoice;if(choice.outcome==='accepted')return;}catch(_){} }
    const dialog=document.createElement('dialog');dialog.className='ic-action-dialog';dialog.innerHTML='<h2>ホーム画面へ追加</h2><p></p><p>追加したアイコンから、アプリとして起動できます。</p><p>登録済みの方：ホーム画面版でPLAYER ACCESSが表示されたら、新規登録は不要です。このSafariで引き継ぎPINを発行 → ホーム画面版の「すでにアカウントがある」で入力 → Safariに戻って接続を承認してください。同じアカウントの記録を引き継げます。</p><button data-link>引き継ぎPINを発行</button><button data-close>閉じる</button>';
    dialog.querySelector('p').textContent=instructions();document.body.append(dialog);dialog.showModal();dialog.querySelector('[data-close]').onclick=()=>dialog.close();const link=dialog.querySelector('[data-link]');link.hidden=!window.IntervalCosmosCloud?.getCachedPlayer?.()||window.IntervalCosmosCloud.getCachedPlayer().is_guest;link.onclick=()=>{dialog.close();window.IntervalCosmosAccountUI?.openSourceLink();};dialog.onclose=()=>dialog.remove();
  }
  function render(){
    const card=document.querySelector('.settings-modal .modal-card');if(!card)return;
    let row=card.querySelector('[data-install-app-row]');
    if(!row){row=document.createElement('div');row.className='setting-row';row.dataset.installAppRow='';row.innerHTML='<strong>アプリとして使う</strong><p>ホーム画面からすぐに起動できます。</p><button type="button" class="ic-install-button"></button>';card.append(row);row.querySelector('button').onclick=install;}
    const button=row.querySelector('button'),text=installed()?'アプリとして起動中':'ホーム画面へ追加';
    if(button.textContent!==text)button.textContent=text;
    if(button.disabled!==installed())button.disabled=installed();
  }
  new MutationObserver(render).observe(document.documentElement,{childList:true,subtree:true});render();
})();
