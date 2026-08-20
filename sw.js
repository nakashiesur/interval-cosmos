const CACHE = 'interval-cosmos-v2-0-5-alpha10-11';
const ASSETS = [
  './', './index.html', './styles.css', './account-v205.css', './phase2-recovery-v205.css', './phase3-v205.css', './phase4-v205.css', './phase4-hotfix-v205.css', './phase5-v205.css', './phase6-assignments-v205.css', './phase6-multimode-v205.css', './phase6-game-layout-v205.css', './phase7-admin-dashboard-v205.css', './phase8-admin-player-management-v205.css', './phase8-pc-controls-v205.css', './phase8-config-polish-v205.css', './phase10-ui-foundation-v205.css', './phase10-header-polish-v205.css', './phase10-practice-polish-v205.css', './phase10-result-polish-v205.css',
  './account-gate.js', './supabase-singleton-v205.js', './phase9-staff-registration-v205.js', './phase2-recovery-v205-fixed.js', './runtime-v205.js', './phase3-ranking-hotfix-v205.js', './phase3-v205.js', './phase4-hotfix-v205.js', './phase4-v205.js', './phase4-analysis-hotfix-v205.js', './phase5-progression-v205.js', './phase5-unlock-copy-hotfix-v205.js', './phase5-scroll-retention-v205.js', './phase6-admin-policy-v205.js', './phase6-multimode-v205.js', './phase6-assignments-v205.js', './phase7-admin-dashboard-v205.js', './phase7-admin-home-dock-v205.js', './phase8-admin-player-management-v205.js', './phase8-pc-controls-v205.js', './phase8-config-polish-v205.js', './phase0-wallclock-v205.js', './phase10-ui-foundation-v205.js', './app.js', './cloud.js',
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
    event.respondWith(fetch(event.request, { cache: 'no-store' }).catch(() => caches.match(event.request, { ignoreSearch: true })));
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

  const localAsset = url.origin === self.location.origin;

  if (localAsset && url.search) {
    event.respondWith(
      fetch(event.request)
        .then(response => {
          const copy = response.clone();
          caches.open(CACHE).then(cache => cache.put(event.request, copy));
          return response;
        })
        .catch(() => caches.match(event.request, { ignoreSearch: true }))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
      if (localAsset) {
        const copy = response.clone();
        caches.open(CACHE).then(cache => cache.put(event.request, copy));
      }
      return response;
    }))
  );
});
