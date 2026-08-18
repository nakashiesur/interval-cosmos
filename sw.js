const CACHE = 'interval-cosmos-v2-0-5-alpha4-2-1';
const ASSETS = [
  './', './index.html', './styles.css', './account-v205.css', './phase2-recovery-v205.css', './phase3-v205.css', './phase4-v205.css', './phase4-hotfix-v205.css', './phase5-v205.css',
  './account-gate.js', './phase2-recovery-v205-fixed.js', './runtime-v205.js', './phase3-v205.js', './phase4-hotfix-v205.js', './phase4-v205.js', './phase5-progression-v205.js', './app.js', './cloud.js',
  './nakashima-logo.png', './icon.svg', './manifest.webmanifest'
];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);

  if (url.pathname.endsWith('/cloud-config.js')) {
    event.respondWith(fetch(event.request, { cache: 'no-store' }).catch(() => caches.match(event.request)));
    return;
  }

  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then(response => {
          const copy = response.clone();
          caches.open(CACHE).then(cache => cache.put('./index.html', copy));
          return response;
        })
        .catch(() => caches.match('./index.html'))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
      if (url.origin === self.location.origin) {
        const copy = response.clone();
        caches.open(CACHE).then(cache => cache.put(event.request, copy));
      }
      return response;
    }))
  );
});
