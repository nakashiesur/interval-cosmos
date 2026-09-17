(async()=>{
  const panel=document.createElement('aside');
  panel.style.cssText='position:fixed;bottom:0;right:0;z-index:20000;background:#192232;color:white;padding:8px;border:1px solid cyan;font:12px sans-serif';
  panel.innerHTML='<strong>通信テスト</strong> <span role="status">準備中</span> <button data-transport="disconnect">通信を切る</button> <button data-transport="reconnect">通信を戻す</button>';
  document.body.append(panel);
  const registration=await navigator.serviceWorker.register('/tests/offline-app/sw.js',{scope:'/tests/offline-app/'});
  const refresh=()=>navigator.serviceWorker.controller?.postMessage('status');
  navigator.serviceWorker.addEventListener('message',e=>{if(e.data?.transport)panel.querySelector('span').textContent=e.data.transport;});
  navigator.serviceWorker.addEventListener('controllerchange',refresh);
  panel.addEventListener('click',e=>{const action=e.target.dataset.transport;if(action)registration.active?.postMessage(action)});
  refresh();
})();
