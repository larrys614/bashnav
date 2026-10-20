// The launcher's own cache.  Each tool caches itself under its own
// scope, so a tool updating does not invalidate this and vice versa.
const CACHE = 'bashnav-launcher-v1';
const FILES = ['./', './launcher.css', './launcher.js', './manifest.webmanifest',
               './icon.svg', './icons/bashnav.svg', './icons/celnav.svg',
               './icons/colregs.svg', './icons/tides.svg', './icons/weather.svg',
               './icons/deck-log.svg'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(caches.match(e.request).then(hit => hit ||
    fetch(e.request).catch(() => caches.match('./'))));
});
