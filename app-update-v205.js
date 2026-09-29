(() => {
  if (!('serviceWorker' in navigator) || !/^https?:$/.test(location.protocol)) return;
  let checking = false;
  async function check() {
    if (checking || document.hidden || navigator.onLine === false) return;
    checking = true;
    try {
      const registration = await navigator.serviceWorker.getRegistration();
      if (registration) await registration.update();
    } catch (_) { /* Offline users keep their cached app and saved records. */ }
    finally { checking = false; }
  }
  window.addEventListener('online', check);
  window.addEventListener('pageshow', check);
  document.addEventListener('visibilitychange', check);
  setInterval(check, 60000);
  check();
})();
