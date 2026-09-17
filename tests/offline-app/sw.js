// Test scope only. The real app and real test DB are used; this worker cuts transport.
const QA_CACHE = 'qa-offline-app-v1';
const STATE = new URL('./transport-state', self.location.href).href;
self.addEventListener('install', e=>e.waitUntil(self.skipWaiting()));
self.addEventListener('activate', e=>e.waitUntil(self.clients.claim()));
self.addEventListener('message', e=>e.waitUntil((async()=>{
  const cache = await caches.open(QA_CACHE);
  if (e.data==='disconnect') await cache.put(STATE,new Response('offline'));
  if (e.data==='reconnect') await cache.delete(STATE);
  e.source?.postMessage({transport:await cache.match(STATE)?'切断':'接続'});
})()));
self.addEventListener('fetch', e=>e.respondWith((async()=>{
  const cache=await caches.open(QA_CACHE);
  const offline=await cache.match(STATE);
  if (offline) return (e.request.method==='GET' ? await cache.match(e.request) : null) || Response.error();
  const response=await fetch(e.request);
  // Cache app files only, never backend responses or tokens.
  if (e.request.method==='GET' && new URL(e.request.url).origin===self.location.origin && response.ok) {
    await cache.put(e.request,response.clone());
  }
  return response;
})()));
